'use client';

import { useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import { CheckCheck, Megaphone, Send } from 'lucide-react';
import { Topbar } from '@/components/layout/topbar';
import {
  Banner,
  Button,
  EmptyState,
  Field,
  MOTION,
  Panel,
  PanelHeader,
  inputClass,
  staggerDelay,
} from '@/components/ui/primitives';
import { useAuth } from '@/lib/auth-context';
import { useStore } from '@/lib/store';
import { sendBroadcast } from '@/lib/data';
import { readCount, recipientCount, type Chat } from '@/lib/types';

type Mode = 'everyone' | 'schools' | 'people';

/**
 * One announcement to many schools.
 *
 * Delivered as a single broadcast conversation whose members are every chosen
 * operator, NOT as a fan-out of private chats. A fan-out would give each
 * recipient a thread they could reply into, which the hub-and-spoke rules
 * deliberately do not want - an announcement is not a conversation.
 */
export default function BroadcastPage() {
  const { profile } = useAuth();
  const { users, schools, chats } = useStore();

  const [mode, setMode] = useState<Mode>('everyone');
  const [pickedSchools, setPickedSchools] = useState<Set<string>>(new Set());
  const [pickedPeople, setPickedPeople] = useState<Set<string>>(new Set());
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState<{ chatId: string; recipients: number } | null>(null);
  const [error, setError] = useState<string | null>(null);

  /** Only active operators. A disabled account cannot read it anyway. */
  const operators = useMemo(
    () => users.filter((u) => u.role !== 'Admin' && u.active),
    [users],
  );

  const recipients = useMemo(() => {
    if (mode === 'everyone') return operators;
    if (mode === 'schools') {
      return operators.filter((u) => u.schoolId && pickedSchools.has(u.schoolId));
    }
    return operators.filter((u) => pickedPeople.has(u.uid));
  }, [mode, operators, pickedSchools, pickedPeople]);

  const past = useMemo(
    () =>
      chats
        .filter((c) => c.kind === 'broadcast')
        .sort((a, b) => (b.lastMessageAt ?? '').localeCompare(a.lastMessageAt ?? '')),
    [chats],
  );

  const send = async () => {
    if (!profile) return;
    setBusy(true);
    setError(null);
    setSent(null);
    try {
      const result = await sendBroadcast(
        title,
        body,
        recipients.map((u) => u.uid),
        profile.uid,
        profile.displayName || 'Office',
      );
      setSent(result);
      setTitle('');
      setBody('');
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  const toggle = (set: Set<string>, id: string, apply: (s: Set<string>) => void) => {
    const next = new Set(set);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    apply(next);
  };

  return (
    <div className="flex flex-col gap-4">
      <Topbar greeting="Announcements" title="Bulk Message" />

      {error ? <Banner tone="error" title="Could not send">{error}</Banner> : null}

      <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,330px)]">
        <Panel className="overflow-hidden">
          <PanelHeader title="Compose" />

          <div className="flex flex-col gap-4 px-5 pb-5">
            {/* Recipients */}
            <div>
              <p className="mb-2 text-[12.5px] font-semibold text-ink-600">
                Who receives this
              </p>
              <div className="flex flex-wrap gap-2">
                {(
                  [
                    ['everyone', `Everyone (${operators.length})`],
                    ['schools', 'By school'],
                    ['people', 'Pick people'],
                  ] as [Mode, string][]
                ).map(([m, label]) => (
                  <button
                    key={m}
                    type="button"
                    onClick={() => setMode(m)}
                    className={`rounded-full border px-3 py-1.5 text-[12.5px] font-semibold transition ${
                      mode === m
                        ? 'border-mint-500/45 bg-mint-500/13 text-mint-700'
                        : 'border-ink-400/20 bg-white/70 text-ink-500 hover:bg-white'
                    }`}
                  >
                    {label}
                  </button>
                ))}
              </div>

              {mode === 'schools' ? (
                <div className="mt-3 flex flex-wrap gap-1.5">
                  {schools.map((s) => (
                    <Toggle
                      key={s.id}
                      label={s.name}
                      on={pickedSchools.has(s.id)}
                      onClick={() => toggle(pickedSchools, s.id, setPickedSchools)}
                    />
                  ))}
                </div>
              ) : null}

              {mode === 'people' ? (
                <div className="mt-3 flex flex-wrap gap-1.5">
                  {operators.map((u) => (
                    <Toggle
                      key={u.uid}
                      label={u.displayName || u.email.split('@')[0]}
                      on={pickedPeople.has(u.uid)}
                      onClick={() => toggle(pickedPeople, u.uid, setPickedPeople)}
                    />
                  ))}
                </div>
              ) : null}
            </div>

            <Field label="Title" hint="Shown as the conversation name.">
              <input
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="Holiday notice"
                className={inputClass}
              />
            </Field>

            <Field label="Message">
              <textarea
                value={body}
                onChange={(e) => setBody(e.target.value)}
                rows={5}
                placeholder="School will be closed on Monday. Card collection moves to Tuesday."
                className={`${inputClass} resize-y`}
              />
            </Field>

            <div className="flex flex-wrap items-center gap-3">
              <Button
                icon={Send}
                busy={busy}
                disabled={recipients.length === 0 || !body.trim()}
                onClick={() => void send()}
              >
                Send to {recipients.length} recipient
                {recipients.length === 1 ? '' : 's'}
              </Button>

              {recipients.length === 0 ? (
                <span className="text-[12px] text-ink-400">
                  Choose at least one recipient.
                </span>
              ) : null}
            </div>

            {sent ? (
              <Banner tone="success" title={`Sent to ${sent.recipients} recipients`}>
                Recipients see this the next time they open the app. Push
                notifications are not enabled, so it will not reach a closed app
                yet. Read counts below update as people open it.
              </Banner>
            ) : null}
          </div>
        </Panel>

        {/* History with live read counts */}
        <Panel index={1} className="overflow-hidden">
          <PanelHeader title="Past announcements" />
          <div className="px-4 pb-4">
            {past.length === 0 ? (
              <EmptyState
                icon={Megaphone}
                title="None sent yet"
                body="Announcements you send appear here with a live read count."
              />
            ) : (
              <ul className="flex flex-col gap-1">
                {past.slice(0, 10).map((c, i) => (
                  <HistoryRow
                    key={c.id}
                    chat={c}
                    adminUid={profile?.uid ?? ''}
                    index={i}
                  />
                ))}
              </ul>
            )}
          </div>
        </Panel>
      </div>
    </div>
  );
}

function Toggle({
  label,
  on,
  onClick,
}: {
  label: string;
  on: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`rounded-lg border px-2.5 py-1 text-[12px] font-medium transition ${
        on
          ? 'border-mint-500/45 bg-mint-500/13 text-mint-700'
          : 'border-ink-400/20 bg-white/70 text-ink-500 hover:bg-white'
      }`}
    >
      {label}
    </button>
  );
}

/**
 * One past announcement.
 *
 * "Delivered" is not something a send can report - writing the announcement is
 * one atomic batch, so it lands for everyone or nobody and there is no
 * per-recipient failure to count. What is measurable, and what the office
 * actually wants, is how many have OPENED it.
 */
function HistoryRow({
  chat,
  adminUid,
  index,
}: {
  chat: Chat;
  adminUid: string;
  index: number;
}) {
  const total = recipientCount(chat, adminUid);
  const read = readCount(chat, adminUid);
  const allRead = total > 0 && read === total;
  const pct = total === 0 ? 0 : (read / total) * 100;

  return (
    <motion.li
      initial={{ opacity: 0, y: 5 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{
        duration: MOTION.normal,
        ease: MOTION.ease,
        delay: staggerDelay(index),
      }}
      className="rounded-xl px-2.5 py-2.5 transition hover:bg-white/60"
    >
      <div className="flex items-start gap-2">
        <span
          className={`mt-0.5 shrink-0 ${
            allRead ? 'text-[var(--color-status-approved)]' : 'text-ink-400'
          }`}
        >
          {allRead ? <CheckCheck size={14} /> : <Megaphone size={14} />}
        </span>
        <div className="min-w-0 flex-1">
          <p className="truncate text-[12.5px] font-semibold text-ink-700">
            {chat.title || 'Announcement'}
          </p>
          <p className="truncate text-[11px] text-ink-400">
            {chat.lastMessageAt
              ? new Date(chat.lastMessageAt).toLocaleDateString(undefined, {
                  day: '2-digit',
                  month: 'short',
                })
              : ''}
            {chat.lastMessage ? ` · ${chat.lastMessage}` : ''}
          </p>

          <div className="mt-1.5 flex items-center gap-2">
            <div className="h-1 w-full overflow-hidden rounded-full bg-ink-400/12">
              <motion.div
                initial={{ width: 0 }}
                animate={{ width: `${pct}%` }}
                transition={{ duration: 0.6, ease: MOTION.ease }}
                className="h-full rounded-full"
                style={{
                  background: allRead
                    ? 'var(--color-status-approved)'
                    : 'var(--color-mint-500)',
                }}
              />
            </div>
            <span className="nums shrink-0 text-[10.5px] font-semibold text-ink-400">
              {read}/{total} read
            </span>
          </div>
        </div>
      </div>
    </motion.li>
  );
}
