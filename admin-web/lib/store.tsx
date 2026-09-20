'use client';

import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { useAuth } from './auth-context';
import {
  watchAllEntries,
  watchChats,
  watchPanelConfig,
  watchSchools,
  watchUsers,
} from './data';
import {
  DEFAULT_PANEL_CONFIG,
  type Chat,
  type ManagedUser,
  type PanelConfig,
  type SchoolConfig,
  type StudentEntry,
} from './types';

/**
 * One live mirror of the whole dataset, shared by every screen.
 *
 * Four subscriptions are opened once at the shell and read everywhere, rather
 * than each page opening its own. The dataset is small - a handful of schools,
 * a few thousand entries - and holding it in memory means switching pages is
 * instant and the sidebar badges, the dashboard and the review queue can never
 * disagree with each other about what is pending.
 */

interface StoreState {
  schools: SchoolConfig[];
  entries: StudentEntry[];
  users: ManagedUser[];
  chats: Chat[];
  config: PanelConfig;
  loading: boolean;
  /** Set when a subscription is refused or needs an index - surfaced, not swallowed. */
  error: string | null;
  /** Firestore hands back a console link for a missing composite index. */
  indexUrl: string | null;
}

const Ctx = createContext<StoreState | null>(null);

/** Firestore embeds the index-creation URL in the error message. */
function extractIndexUrl(message: string): string | null {
  const m = message.match(/https:\/\/console\.firebase\.google\.com\S+/);
  return m ? m[0].replace(/[).,]+$/, '') : null;
}

export function StoreProvider({ children }: { children: ReactNode }) {
  const { phase, user } = useAuth();

  const [schools, setSchools] = useState<SchoolConfig[]>([]);
  const [entries, setEntries] = useState<StudentEntry[]>([]);
  const [users, setUsers] = useState<ManagedUser[]>([]);
  const [chats, setChats] = useState<Chat[]>([]);
  const [config, setConfig] = useState<PanelConfig>(DEFAULT_PANEL_CONFIG);

  const [ready, setReady] = useState({
    schools: false,
    entries: false,
    users: false,
    chats: false,
  });
  const [error, setError] = useState<string | null>(null);
  const [indexUrl, setIndexUrl] = useState<string | null>(null);

  useEffect(() => {
    if (phase !== 'ready' || !user) return;

    const fail = (what: string) => (e: Error) => {
      const url = extractIndexUrl(e.message);
      if (url) setIndexUrl(url);
      setError(`Could not load ${what}: ${e.message}`);
      // Mark it settled regardless so the UI leaves its loading state and can
      // show the error instead of spinning forever.
      setReady((r) => ({ ...r, [what]: true }) as typeof r);
    };

    const unsubs = [
      watchSchools(
        (v) => {
          setSchools(v);
          setReady((r) => ({ ...r, schools: true }));
        },
        fail('schools'),
      ),
      watchAllEntries(
        (v) => {
          setEntries(v);
          setReady((r) => ({ ...r, entries: true }));
        },
        fail('entries'),
      ),
      watchUsers(
        (v) => {
          setUsers(v);
          setReady((r) => ({ ...r, users: true }));
        },
        fail('users'),
      ),
      watchChats(
        user.uid,
        (v) => {
          setChats(v);
          setReady((r) => ({ ...r, chats: true }));
        },
        fail('chats'),
      ),
      // Deliberately not part of `loading` and deliberately not surfaced
      // through `fail`: the panel has working defaults without it, and a
      // settings document that has never been written must not hold the
      // whole dashboard on a spinner or raise an error banner.
      watchPanelConfig(setConfig, () => {}),
    ];

    return () => unsubs.forEach((u) => u());
  }, [phase, user]);

  const value = useMemo<StoreState>(
    () => ({
      schools,
      entries,
      users,
      chats,
      config,
      loading: !(ready.schools && ready.entries && ready.users && ready.chats),
      error,
      indexUrl,
    }),
    [schools, entries, users, chats, config, ready, error, indexUrl],
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useStore(): StoreState {
  const v = useContext(Ctx);
  if (!v) throw new Error('useStore must be used inside <StoreProvider>');
  return v;
}

/** Name lookup for a school id, falling back to the raw code. */
export function useSchoolName(): (id: string) => string {
  const { schools } = useStore();
  return useMemo(() => {
    const map = new Map(schools.map((s) => [s.id, s.name]));
    return (id: string) => map.get(id) ?? id;
  }, [schools]);
}
