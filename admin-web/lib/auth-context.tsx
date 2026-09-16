'use client';

import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import {
  browserLocalPersistence,
  onAuthStateChanged,
  setPersistence,
  signInWithEmailAndPassword,
  signOut,
  type User,
} from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { firebaseAuth, firebaseDb } from './firebase';
import type { ManagedUser } from './types';
import { toManagedUser } from './converters';

/**
 * Who is signed in, and whether they are actually an admin.
 *
 * The role is read from `users/{uid}` in Firestore, never from anything the
 * client can set. That check is what this app uses to decide what to render -
 * but it is a convenience, not a control: the deployed security rules perform
 * the identical check server side, so a tampered client still cannot read a
 * single document it should not.
 */

export type AuthPhase = 'loading' | 'signed-out' | 'not-admin' | 'ready';

interface AuthState {
  phase: AuthPhase;
  user: User | null;
  profile: ManagedUser | null;
  error: string | null;
  signIn: (email: string, password: string) => Promise<void>;
  logOut: () => Promise<void>;
}

const Ctx = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [phase, setPhase] = useState<AuthPhase>('loading');
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<ManagedUser | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const auth = firebaseAuth();
    const db = firebaseDb();

    // Survives a refresh so the office is not re-typing a password all day.
    void setPersistence(auth, browserLocalPersistence);

    return onAuthStateChanged(auth, async (u) => {
      setUser(u);

      if (!u) {
        setProfile(null);
        setPhase('signed-out');
        return;
      }

      try {
        const snap = await getDoc(doc(db, 'users', u.uid));

        if (!snap.exists()) {
          // The rules look users up by Auth UID. A signed-in account with no
          // document - or one keyed by an auto-id - can read nothing at all,
          // so say that plainly instead of showing an empty dashboard.
          setProfile(null);
          setError(
            'This account has no user record in the database. It must exist at ' +
              `users/${u.uid} — keyed by the Auth UID, not an auto-generated id.`,
          );
          setPhase('not-admin');
          return;
        }

        const p = toManagedUser(snap as Parameters<typeof toManagedUser>[0]);
        setProfile(p);

        if (p.role !== 'Admin') {
          setError('This panel is for admin accounts. Operators use the mobile app.');
          setPhase('not-admin');
          return;
        }
        if (!p.active) {
          setError('This account has been deactivated.');
          setPhase('not-admin');
          return;
        }

        setError(null);
        setPhase('ready');
      } catch {
        // A permission error here means the rules refused the profile read,
        // which for a signed-in user means the document is missing or the
        // account is deactivated. Either way it is not an admin session.
        setError('Could not verify this account against the database.');
        setPhase('not-admin');
      }
    });
  }, []);

  const value = useMemo<AuthState>(
    () => ({
      phase,
      user,
      profile,
      error,
      signIn: async (email, password) => {
        setError(null);
        try {
          await signInWithEmailAndPassword(firebaseAuth(), email.trim(), password);
        } catch (e) {
          const code = (e as { code?: string }).code ?? '';
          throw new Error(
            code === 'auth/invalid-credential' ||
            code === 'auth/wrong-password' ||
            code === 'auth/user-not-found'
              ? 'That email and password do not match an account.'
              : code === 'auth/too-many-requests'
                ? 'Too many attempts. Wait a minute and try again.'
                : code === 'auth/network-request-failed'
                  ? 'No connection to Firebase. Check the network.'
                  : 'Could not sign in. Please try again.',
          );
        }
      },
      logOut: async () => {
        await signOut(firebaseAuth());
      },
    }),
    [phase, user, profile, error],
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useAuth(): AuthState {
  const v = useContext(Ctx);
  if (!v) throw new Error('useAuth must be used inside <AuthProvider>');
  return v;
}
