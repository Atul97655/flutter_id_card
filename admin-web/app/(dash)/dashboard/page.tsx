'use client';

import { useMemo } from 'react';
import Link from 'next/link';
import { motion } from 'framer-motion';
import {
  ArrowRight,
  Building2,
  CheckCircle2,
  Clock,
  ImageOff,
  Inbox,
  Megaphone,
  Printer,
  Users,
} from 'lucide-react';
import { Topbar } from '@/components/layout/topbar';
import { StatTile } from '@/components/dashboard/stat-tile';
import {
  AnimatedNumber,
  Banner,
  Button,
  EmptyState,
  MOTION,
  Panel,
  PanelHeader,
  Skeleton,
  StatusChip,
  staggerDelay,
} from '@/components/ui/primitives';
import { useAuth } from '@/lib/auth-context';
import { useSchoolName, useStore } from '@/lib/store';
import { hasPhoto, isPrintable, type StudentEntry } from '@/lib/types';
import { EntryPhoto } from '@/components/ui/entry-photo';

export default function DashboardPage() {
  const { profile } = useAuth();
  const { entries, schools, users, chats, loading } = useStore();
  const schoolName = useSchoolName();

  const stats = useMemo(() => {
    let pending = 0;
    let approved = 0;
    let rejected = 0;
    let printed = 0;
    let readyToPrint = 0;
    let missingPhoto = 0;

    for (const e of entries) {
      if (e.approvalStatus === 'pending') pending++;
      else if (e.approvalStatus === 'approved') approved++;
      else if (e.approvalStatus === 'rejected') rejected++;
      else if (e.approvalStatus === 'printed') printed++;

      if (isPrintable(e.approvalStatus)) {
        if (hasPhoto(e)) readyToPrint++;
        else missingPhoto++;
      }
    }

    return { pending, approved, rejected, printed, readyToPrint, missingPhoto };
  }, [entries]);

  const operators = users.filter((u) => u.role !== 'Admin');
  const activeOperators = operators.filter((u) => u.active).length;

  const recent = useMemo(
    () =>
      [...entries]
        .sort((a, b) => (b.createdAt ?? '').localeCompare(a.createdAt ?? ''))
        .slice(0, 6),
    [entries],
  );

  /** Per-school progress, the standings table from the reference. */
  const bySchool = useMemo(() => {
    const rows = schools.map((s) => {
      const mine = entries.filter((e) => e.schoolId === s.id);
      const done = mine.filter((e) => e.approvalStatus === 'printed').length;
      return {
        id: s.id,
        name: s.name,
        total: mine.length,
        pending: mine.filter((e) => e.approvalStatus === 'pending').length,
        approved: mine.filter((e) => e.approvalStatus === 'approved').length,
        printed: done,
        progress: mine.length === 0 ? 0 : Math.round((done / mine.length) * 100),
      };
    });
    rows.sort((a, b) => b.total - a.total || a.name.localeCompare(b.name));
    return rows;
  }, [schools, entries]);

  const unread = chats.filter((c) => c.unreadFor.includes(profile?.uid ?? '')).length;
  const reviewed = stats.approved + stats.rejected + stats.printed;
  const total = entries.length;

  const firstName =
    (profile?.displayName || profile?.email?.split('@')[0] || 'there').split(' ')[0];

  return (
    <div className="flex flex-col gap-4">
      <Topbar greeting={`Welcome back, ${firstName}`} title="Dashboard" />

      {stats.missingPhoto > 0 ? (
        <Banner
          tone="warn"
          title={`${stats.missingPhoto} approved card${
            stats.missingPhoto === 1 ? '' : 's'
          } cannot be printed`}
          action={
            <Link
              href="/print"
              className="shrink-0 rounded-lg bg-white/80 px-3 py-1.5 text-[12px] font-semibold text-ink-700 transition hover:bg-white"
            >
              Open Print Center
            </Link>
          }
        >
          No photo has reached the server for them yet, so there is nothing to
          place on a sheet. Submissions made before the current app release left
          their photo on the phone that took it; each one is sent up
          automatically the next time that phone syncs. The details are safe and
          nothing needs re-entering.
        </Banner>
      ) : null}

      {/* Row 1 — review queue + workload */}
      <div className="grid gap-4 lg:grid-cols-[minmax(0,1.35fr)_minmax(0,1fr)]">
        <Panel className="overflow-hidden">
          <PanelHeader
            title="Review queue"
            action={
              <Link
                href="/requests"
                className="inline-flex items-center gap-1 text-[12.5px] font-semibold text-mint-600 transition hover:text-mint-700"
              >
                Open queue <ArrowRight size={13} />
              </Link>
            }
          />

          <div className="px-5 pb-5">
            {loading ? (
              <div className="flex flex-col gap-2.5">
                <Skeleton className="h-11" />
                <Skeleton className="h-11" />
                <Skeleton className="h-11" />
              </div>
            ) : stats.pending === 0 ? (
              <div className="flex items-center gap-3 rounded-[var(--radius-card)] bg-[var(--color-status-approved)]/8 px-4 py-5">
                <CheckCircle2
                  size={22}
                  className="shrink-0 text-[var(--color-status-approved)]"
                />
                <div>
                  <p className="text-[14px] font-semibold text-ink-700">
                    Nothing waiting
                  </p>
                  <p className="text-[12.5px] text-ink-500">
                    Every submission has been reviewed.
                  </p>
                </div>
              </div>
            ) : (
              <>
                <div className="flex items-end justify-between gap-4">
                  <div>
                    <AnimatedNumber
                      value={stats.pending}
                      className="text-[40px] font-bold leading-none tracking-tight text-[var(--color-status-pending)]"
                    />
                    <p className="mt-1 text-[13px] text-ink-500">
                      card{stats.pending === 1 ? '' : 's'} awaiting your review
                    </p>
                  </div>
                  <Link href="/requests">
                    <Button icon={Inbox}>Review now</Button>
                  </Link>
                </div>

                {/* How much of the whole intake is dealt with. */}
                <div className="mt-5">
                  <div className="mb-1.5 flex justify-between text-[11.5px] font-medium text-ink-400">
                    <span>Reviewed</span>
                    <span className="nums">
                      {reviewed} of {total}
                    </span>
                  </div>
                  <div className="h-2 overflow-hidden rounded-full bg-ink-400/12">
                    <motion.div
                      initial={{ width: 0 }}
                      animate={{
                        width: total === 0 ? '0%' : `${(reviewed / total) * 100}%`,
                      }}
                      transition={{ duration: 0.7, ease: MOTION.ease }}
                      className="h-full rounded-full bg-gradient-to-r from-mint-400 to-mint-600"
                    />
                  </div>
                </div>
              </>
            )}
          </div>
        </Panel>

        <div className="grid grid-cols-2 gap-4">
          <StatTile
            label="Pending"
            value={stats.pending}
            icon={Clock}
            tint="var(--color-status-pending)"
            href="/requests?status=pending"
            index={0}
          />
          <StatTile
            label="Approved"
            value={stats.approved}
            icon={CheckCircle2}
            tint="var(--color-status-approved)"
            href="/requests?status=approved"
            hint="signed off, not yet printed"
            index={1}
          />
          <StatTile
            label="Ready to print"
            value={stats.readyToPrint}
            icon={Printer}
            tint="var(--color-status-printed)"
            href="/print"
            hint="approved and has a photo"
            index={2}
          />
          <StatTile
            label="No photo"
            value={stats.missingPhoto}
            icon={ImageOff}
            tint="var(--color-status-rejected)"
            href="/print"
            hint="blocked from printing"
            index={3}
          />
        </div>
      </div>

      {/* Row 2 — schools table + side column */}
      <div className="grid gap-4 lg:grid-cols-[minmax(0,1.35fr)_minmax(0,1fr)]">
        <Panel className="overflow-hidden" index={1}>
          <PanelHeader
            title="Schools"
            action={
              <Link
                href="/schools"
                className="inline-flex items-center gap-1 text-[12.5px] font-semibold text-mint-600 transition hover:text-mint-700"
              >
                View all <ArrowRight size={13} />
              </Link>
            }
          />

          {loading ? (
            <div className="flex flex-col gap-2 px-5 pb-5">
              <Skeleton className="h-9" />
              <Skeleton className="h-9" />
              <Skeleton className="h-9" />
            </div>
          ) : bySchool.length === 0 ? (
            <EmptyState
              icon={Building2}
              title="No schools yet"
              body="Create a school so operators have somewhere to submit cards."
              action={
                <Link href="/schools">
                  <Button size="sm">Add a school</Button>
                </Link>
              }
            />
          ) : (
            <div className="overflow-x-auto px-2 pb-3">
              <table className="w-full min-w-[460px] border-collapse">
                <thead>
                  <tr className="text-[10.5px] uppercase tracking-wider text-ink-400">
                    <th className="px-3 py-2 text-left font-bold">School</th>
                    <th className="px-2 py-2 text-right font-bold">Cards</th>
                    <th className="px-2 py-2 text-right font-bold">Pending</th>
                    <th className="px-2 py-2 text-right font-bold">Printed</th>
                    <th className="px-3 py-2 text-left font-bold">Progress</th>
                  </tr>
                </thead>
                <tbody>
                  {bySchool.slice(0, 6).map((row, i) => (
                    <motion.tr
                      key={row.id}
                      initial={{ opacity: 0, y: 8 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{
                        duration: MOTION.normal,
                        ease: MOTION.ease,
                        delay: staggerDelay(i),
                      }}
                      className="group border-t border-ink-400/8"
                    >
                      <td className="px-3 py-2.5">
                        <Link
                          href={`/schools/${row.id}`}
                          className="text-[13px] font-semibold text-ink-700 transition group-hover:text-mint-600"
                        >
                          {row.name}
                        </Link>
                      </td>
                      <td className="nums px-2 py-2.5 text-right text-[13px] text-ink-600">
                        {row.total}
                      </td>
                      <td className="nums px-2 py-2.5 text-right text-[13px]">
                        {row.pending > 0 ? (
                          <span className="font-semibold text-[var(--color-status-pending)]">
                            {row.pending}
                          </span>
                        ) : (
                          <span className="text-ink-400">—</span>
                        )}
                      </td>
                      <td className="nums px-2 py-2.5 text-right text-[13px] text-ink-600">
                        {row.printed}
                      </td>
                      <td className="px-3 py-2.5">
                        <div className="flex items-center gap-2">
                          <div className="h-1.5 w-full max-w-[90px] overflow-hidden rounded-full bg-ink-400/12">
                            <motion.div
                              initial={{ width: 0 }}
                              animate={{ width: `${row.progress}%` }}
                              transition={{
                                duration: 0.6,
                                ease: MOTION.ease,
                                delay: staggerDelay(i) + 0.1,
                              }}
                              className="h-full rounded-full bg-gradient-to-r from-lilac-300 to-lilac-500"
                            />
                          </div>
                          <span className="nums w-8 text-right text-[11.5px] font-medium text-ink-400">
                            {row.progress}%
                          </span>
                        </div>
                      </td>
                    </motion.tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Panel>

        <div className="flex flex-col gap-4">
          <div className="grid grid-cols-2 gap-4">
            <StatTile
              label="Schools"
              value={schools.length}
              icon={Building2}
              tint="var(--color-mint-600)"
              href="/schools"
              index={4}
            />
            <StatTile
              label="Operators"
              value={activeOperators}
              icon={Users}
              tint="var(--color-lilac-500)"
              href="/accounts"
              hint={
                operators.length === activeOperators
                  ? 'all active'
                  : `${operators.length - activeOperators} disabled`
              }
              index={5}
            />
          </div>

          <Panel index={6} className="overflow-hidden">
            <PanelHeader
              title="Recent submissions"
              action={
                <Link
                  href="/requests"
                  className="text-[12.5px] font-semibold text-mint-600 transition hover:text-mint-700"
                >
                  All {total}
                </Link>
              }
            />
            <div className="px-3 pb-3">
              {loading ? (
                <div className="flex flex-col gap-2 px-2">
                  <Skeleton className="h-10" />
                  <Skeleton className="h-10" />
                </div>
              ) : recent.length === 0 ? (
                <p className="px-2 pb-3 text-[13px] text-ink-500">
                  Nothing submitted yet.
                </p>
              ) : (
                <ul className="flex flex-col">
                  {recent.map((e, i) => (
                    <RecentRow
                      key={`${e.schoolId}/${e.id}`}
                      entry={e}
                      school={schoolName(e.schoolId)}
                      index={i}
                    />
                  ))}
                </ul>
              )}
            </div>
          </Panel>

          {/* The promo card from the reference, repurposed as the next action. */}
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{
              duration: MOTION.normal,
              ease: MOTION.ease,
              delay: staggerDelay(7),
            }}
            className="relative overflow-hidden rounded-[var(--radius-panel)] bg-gradient-to-br from-mint-600 to-mint-700 p-5 text-white shadow-[0_18px_40px_-18px_rgb(33_107_94/0.8)]"
          >
            <div
              aria-hidden
              className="absolute -right-8 -top-10 size-36 rounded-full bg-white/10 blur-xl"
            />
            <div
              aria-hidden
              className="absolute -bottom-14 -left-6 size-32 rounded-full bg-lilac-300/20 blur-xl"
            />

            <div className="relative">
              <p className="text-[10.5px] font-bold uppercase tracking-wider text-white/70">
                {unread > 0 ? "Don't forget" : 'Keep schools posted'}
              </p>
              <p className="mt-1.5 text-[17px] font-bold leading-snug">
                {unread > 0
                  ? `${unread} conversation${unread === 1 ? '' : 's'} need a reply`
                  : 'Send an announcement to every school'}
              </p>
              <Link href={unread > 0 ? '/messages' : '/broadcast'}>
                <motion.span
                  whileTap={{ scale: 0.97 }}
                  className="mt-4 inline-flex items-center gap-1.5 rounded-full bg-white px-4 py-2 text-[12.5px] font-bold text-mint-700 shadow-sm"
                >
                  {unread > 0 ? (
                    <>Open messages <ArrowRight size={13} /></>
                  ) : (
                    <><Megaphone size={13} /> Compose</>
                  )}
                </motion.span>
              </Link>
            </div>
          </motion.div>
        </div>
      </div>
    </div>
  );
}

function RecentRow({
  entry,
  school,
  index,
}: {
  entry: StudentEntry;
  school: string;
  index: number;
}) {
  return (
    <motion.li
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{
        duration: MOTION.normal,
        ease: MOTION.ease,
        delay: staggerDelay(index),
      }}
    >
      <Link
        href={`/requests/${entry.schoolId}/${entry.id}`}
        className="flex items-center gap-2.5 rounded-xl px-2 py-2 transition hover:bg-white/70"
      >
        <span className="grid size-8 shrink-0 place-items-center overflow-hidden rounded-lg bg-ink-400/10 text-ink-400">
          <EntryPhoto entry={entry} iconSize={13} />
        </span>

        <span className="min-w-0 flex-1">
          <span className="block truncate text-[13px] font-semibold text-ink-700">
            {entry.name || 'UNNAMED'}
          </span>
          <span className="block truncate text-[11.5px] text-ink-400">
            {school}
            {entry.studentClass ? ` · Class ${entry.studentClass}` : ''}
          </span>
        </span>

        <StatusChip status={entry.approvalStatus} dense />
      </Link>
    </motion.li>
  );
}
