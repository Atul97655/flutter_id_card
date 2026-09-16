'use client';

import { useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import { KeyRound, ShieldCheck, UserCog, Users } from 'lucide-react';
import { Topbar } from '@/components/layout/topbar';
import {
  Banner,
  Button,
  EmptyState,
  MOTION,
  Panel,
  Skeleton,
  staggerDelay,
} from '@/components/ui/primitives';
import { useSchoolName, useStore } from '@/lib/store';
import { setUserActive, updateUser } from '@/lib/data';
import type { ManagedUser } from '@/lib/types';

/**
 * Teacher and school accounts.
 *
 * Creating an account is deliberately NOT here. It needs two things at once -
 * a Firebase Auth user and a `users/{uid}` document keyed by that user's UID -
 * and only the Admin SDK can make the first from a server. Doing it from the
 * browser would mean signing the admin out of their own session, which is how
 * the client SDK's createUser behaves. The mobile app already creates accounts
 * correctly; this panel manages the ones that exist.
 */
export default function AccountsPage() {
  const { users, schools, entries, loading } = useStore();
  const schoolName = useSchoolName();

  const [search, setSearch] = useState('');
  const [busyUid, setBusyUid] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const operators = useMemo(() => {
    const needle = search.trim().toLowerCase();
    return users
      .filter((u) => u.role !== 'Admin')
      .filter(
        (u) =>
          !needle ||
          u.email.toLowerCase().includes(needle) ||
          u.displayName.toLowerCase().includes(needle) ||
          (u.schoolId ?? '').toLowerCase().includes(needle),
      )
      .sort((a, b) => Number(b.active) - Number(a.active) || a.email.localeCompare(b.email));
  }, [users, search]);

  const admins = users.filter((u) => u.role === 'Admin');

  /** Cards submitted per account, so activity is visible without a report. */
  const submissionCount = useMemo(() => {
    const bySchool = new Map<string, number>();
    for (const e of entries) {
      bySchool.set(e.schoolId, (bySchool.get(e.schoolId) ?? 0) + 1);
    }
    return bySchool;
  }, [entries]);

  const toggleActive = async (u: ManagedUser) => {
    setBusyUid(u.uid);
    setError(null);
    try {
      await setUserActive(u.uid, !u.active);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusyUid(null);
    }
  };

  const reassign = async (u: ManagedUser, schoolId: string) => {
    setBusyUid(u.uid);
    setError(null);
    try {
      await updateUser(u.uid, { schoolId: schoolId || null });
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusyUid(null);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <Topbar
        greeting="Access"
        title="Teachers & Schools"
        onSearch={setSearch}
        searchValue={search}
        searchPlaceholder="Search name, email or school"
      />

      {error ? <Banner tone="error" title="Could not update the account">{error}</Banner> : null}

      <Banner tone="info" title="New accounts are created in the mobile app">
        An account needs a Firebase Auth user and a matching{' '}
        <code className="rounded bg-white/70 px-1 py-0.5 font-mono text-[11.5px]">
          users/&#123;uid&#125;
        </code>{' '}
        document keyed by that user&rsquo;s UID. Creating the Auth user from a
        browser would sign you out of your own session, so the app does it. This
        page manages the accounts that already exist.
      </Banner>

      <Panel className="overflow-hidden">
        <div className="flex items-center justify-between gap-3 px-5 pt-4 pb-3">
          <h2 className="text-[15px] font-semibold text-ink-700">
            Operator accounts
          </h2>
          <span className="nums text-[12px] text-ink-400">
            {operators.filter((u) => u.active).length} active of {operators.length}
          </span>
        </div>

        {loading ? (
          <div className="flex flex-col gap-2 px-5 pb-5">
            <Skeleton className="h-12" />
            <Skeleton className="h-12" />
          </div>
        ) : operators.length === 0 ? (
          <EmptyState
            icon={Users}
            title={users.length <= 1 ? 'No operator accounts yet' : 'No accounts match'}
            body={
              users.length <= 1
                ? 'Create teacher or school accounts from the mobile app, and they appear here.'
                : 'Try a different search term.'
            }
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[720px] border-collapse">
              <thead>
                <tr className="border-b border-ink-400/10 text-[10.5px] uppercase tracking-wider text-ink-400">
                  <th className="px-5 py-2.5 text-left font-bold">Account</th>
                  <th className="px-2 py-2.5 text-left font-bold">Role</th>
                  <th className="px-2 py-2.5 text-left font-bold">School</th>
                  <th className="px-2 py-2.5 text-right font-bold">Cards</th>
                  <th className="px-2 py-2.5 text-left font-bold">Last sign-in</th>
                  <th className="px-5 py-2.5 text-right font-bold">Access</th>
                </tr>
              </thead>
              <tbody>
                {operators.map((u, i) => (
                  <motion.tr
                    key={u.uid}
                    initial={{ opacity: 0, y: 6 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{
                      duration: MOTION.normal,
                      ease: MOTION.ease,
                      delay: staggerDelay(i),
                    }}
                    className={`border-b border-ink-400/8 last:border-0 ${
                      u.active ? 'hover:bg-white/60' : 'opacity-60'
                    }`}
                  >
                    <td className="px-5 py-3">
                      <p className="text-[13px] font-semibold text-ink-700">
                        {u.displayName || u.email.split('@')[0]}
                      </p>
                      <p className="truncate text-[11.5px] text-ink-400">{u.email}</p>
                    </td>

                    <td className="px-2 py-3">
                      <span className="rounded-full bg-ink-400/10 px-2 py-0.5 text-[11px] font-semibold text-ink-600">
                        {u.role}
                      </span>
                    </td>

                    <td className="px-2 py-3">
                      <select
                        value={u.schoolId ?? ''}
                        disabled={busyUid === u.uid}
                        onChange={(e) => void reassign(u, e.target.value)}
                        className="max-w-[170px] rounded-lg border border-ink-400/20 bg-white/80 px-2 py-1 text-[12px] text-ink-600 outline-none transition focus:border-mint-500 disabled:opacity-50"
                      >
                        <option value="">— unassigned —</option>
                        {schools.map((s) => (
                          <option key={s.id} value={s.id}>
                            {s.name}
                          </option>
                        ))}
                      </select>
                    </td>

                    <td className="nums px-2 py-3 text-right text-[12.5px] text-ink-600">
                      {u.schoolId ? (submissionCount.get(u.schoolId) ?? 0) : '—'}
                    </td>

                    <td className="px-2 py-3 text-[12px] text-ink-400">
                      {u.lastLoginDate
                        ? u.lastLoginDate.toDate().toLocaleDateString(undefined, {
                            day: '2-digit',
                            month: 'short',
                            year: 'numeric',
                          })
                        : 'Never'}
                    </td>

                    <td className="px-5 py-3 text-right">
                      <Button
                        size="sm"
                        variant={u.active ? 'outline' : 'primary'}
                        busy={busyUid === u.uid}
                        onClick={() => void toggleActive(u)}
                      >
                        {u.active ? 'Disable' : 'Enable'}
                      </Button>
                    </td>
                  </motion.tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Panel>

      <div className="grid gap-4 sm:grid-cols-2">
        <Panel index={1}>
          <div className="px-5 py-4">
            <div className="flex items-center gap-2 text-ink-600">
              <ShieldCheck size={16} />
              <h2 className="text-[14px] font-semibold">Admin accounts</h2>
            </div>
            <ul className="mt-3 flex flex-col gap-2">
              {admins.map((a) => (
                <li key={a.uid} className="flex items-center justify-between gap-3">
                  <div className="min-w-0">
                    <p className="truncate text-[12.5px] font-medium text-ink-700">
                      {a.displayName || a.email}
                    </p>
                    <p className="truncate font-mono text-[10.5px] text-ink-400">
                      {a.uid}
                    </p>
                  </div>
                  {a.active ? null : (
                    <span className="shrink-0 text-[11px] font-semibold text-[var(--color-status-rejected)]">
                      disabled
                    </span>
                  )}
                </li>
              ))}
            </ul>
          </div>
        </Panel>

        <Panel index={2}>
          <div className="px-5 py-4">
            <div className="flex items-center gap-2 text-ink-600">
              <KeyRound size={16} />
              <h2 className="text-[14px] font-semibold">What disabling does</h2>
            </div>
            <p className="mt-2.5 text-[12.5px] leading-relaxed text-ink-500">
              A disabled account keeps its password but loses all data access —
              the security rules check it on every read and write. Their history
              stays intact, and enabling restores access immediately. Use it
              instead of deleting when someone leaves a school.
            </p>
            <div className="mt-3 flex items-center gap-1.5 text-ink-400">
              <UserCog size={13} />
              <span className="text-[11.5px]">
                Reassigning a school takes effect on their next sync.
              </span>
            </div>
          </div>
        </Panel>
      </div>
    </div>
  );
}
