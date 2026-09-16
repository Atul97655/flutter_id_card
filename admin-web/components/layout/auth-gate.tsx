'use client';

import { useState, type FormEvent } from 'react';
import { motion } from 'framer-motion';
import { AlertCircle, LogIn, ShieldAlert } from 'lucide-react';
import { useAuth } from '@/lib/auth-context';
import { Button, Field, MOTION, Spinner, inputClass } from '@/components/ui/primitives';

/**
 * Stands between a visitor and the panel.
 *
 * Three outcomes worth distinguishing, because the fix for each is different:
 * not signed in, signed in but not an admin, and signed in as an admin. The
 * middle case matters most - an operator who tries the web panel needs to be
 * told to use the app, not shown an empty dashboard.
 */
export function AuthGate({ children }: { children: React.ReactNode }) {
  const { phase } = useAuth();

  if (phase === 'loading') return <FullScreenLoading />;
  if (phase === 'ready') return <>{children}</>;
  if (phase === 'not-admin') return <NotAdmin />;
  return <LoginScreen />;
}

function FullScreenLoading() {
  return (
    <div className="grid min-h-screen place-items-center">
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: MOTION.slow }}
        className="flex flex-col items-center gap-3 text-ink-500"
      >
        <Spinner size={22} />
        <p className="text-[13px]">Checking your session…</p>
      </motion.div>
    </div>
  );
}

function Shell({ children }: { children: React.ReactNode }) {
  return (
    <div className="grid min-h-screen place-items-center px-5 py-10">
      <motion.div
        initial={{ opacity: 0, y: 16, scale: 0.98 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        transition={{ duration: MOTION.slow, ease: MOTION.ease }}
        className="glass w-full max-w-[400px] rounded-[var(--radius-panel)] p-7"
      >
        {children}
      </motion.div>
    </div>
  );
}

function Brand() {
  return (
    <div className="mb-6 flex items-center gap-3">
      <div className="grid size-11 place-items-center rounded-2xl bg-gradient-to-br from-mint-500 to-mint-700 text-white shadow-[0_8px_18px_-8px_rgb(38_133_115/0.9)]">
        <svg viewBox="0 0 24 24" className="size-6" fill="none" aria-hidden>
          <rect
            x="3"
            y="5.5"
            width="18"
            height="13"
            rx="3"
            stroke="currentColor"
            strokeWidth="1.8"
          />
          <circle cx="9" cy="11" r="2.1" fill="currentColor" />
          <path
            d="M5.9 16c.5-1.5 1.7-2.3 3.1-2.3s2.6.8 3.1 2.3"
            stroke="currentColor"
            strokeWidth="1.6"
            strokeLinecap="round"
          />
          <path
            d="M14.8 10.2h4M14.8 13.4h4"
            stroke="currentColor"
            strokeWidth="1.6"
            strokeLinecap="round"
          />
        </svg>
      </div>
      <div>
        <p className="text-[19px] font-bold tracking-tight text-ink-900">ID entity</p>
        <p className="text-[12px] text-ink-400">Admin panel</p>
      </div>
    </div>
  );
}

function LoginScreen() {
  const { signIn } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await signIn(email, password);
    } catch (err) {
      setError((err as Error).message);
      setBusy(false);
    }
    // On success the auth listener swaps this screen out, so `busy` is left
    // true deliberately - flipping it back would flash the button first.
  };

  return (
    <Shell>
      <Brand />

      <h1 className="text-[21px] font-bold tracking-tight text-ink-900">
        Sign in to the office
      </h1>
      <p className="mt-1.5 text-[13px] leading-relaxed text-ink-500">
        Review submissions, print card sheets and message the schools that send
        them.
      </p>

      <form onSubmit={submit} className="mt-6 flex flex-col gap-3.5">
        <Field label="Email">
          <input
            type="email"
            required
            autoComplete="username"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="you@example.com"
            className={inputClass}
          />
        </Field>

        <Field label="Password">
          <input
            type="password"
            required
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="••••••••"
            className={inputClass}
          />
        </Field>

        {error ? (
          <motion.p
            initial={{ opacity: 0, y: -4 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: MOTION.fast }}
            className="flex items-start gap-2 rounded-xl bg-[var(--color-status-rejected)]/9 px-3 py-2.5 text-[12.5px] leading-snug text-[var(--color-status-rejected)]"
          >
            <AlertCircle size={15} className="mt-px shrink-0" />
            {error}
          </motion.p>
        ) : null}

        <Button type="submit" busy={busy} icon={LogIn} className="mt-1 w-full">
          Sign in
        </Button>
      </form>

      <p className="mt-5 text-[11.5px] leading-relaxed text-ink-400">
        Operators and schools use the ID entity mobile app. This panel is for
        admin accounts only.
      </p>
    </Shell>
  );
}

function NotAdmin() {
  const { error, logOut, profile } = useAuth();

  return (
    <Shell>
      <Brand />

      <div className="flex items-start gap-3 rounded-[var(--radius-card)] border border-[var(--color-status-pending)]/30 bg-[var(--color-status-pending)]/9 px-4 py-3.5">
        <ShieldAlert
          size={18}
          className="mt-px shrink-0 text-[var(--color-status-pending)]"
        />
        <div>
          <p className="text-[13.5px] font-semibold text-ink-700">
            This account cannot open the panel
          </p>
          <p className="mt-1 text-[12.5px] leading-relaxed text-ink-600">
            {error ?? 'Admin access is required.'}
          </p>
        </div>
      </div>

      {profile ? (
        <dl className="mt-4 space-y-1.5 text-[12.5px]">
          <div className="flex justify-between gap-4">
            <dt className="text-ink-400">Signed in as</dt>
            <dd className="truncate font-medium text-ink-600">{profile.email}</dd>
          </div>
          <div className="flex justify-between gap-4">
            <dt className="text-ink-400">Role</dt>
            <dd className="font-medium text-ink-600">{profile.role}</dd>
          </div>
        </dl>
      ) : null}

      <Button variant="outline" onClick={() => void logOut()} className="mt-5 w-full">
        Sign in with a different account
      </Button>
    </Shell>
  );
}
