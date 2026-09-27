'use client';

import { useMemo } from 'react';
import { motion } from 'framer-motion';
import type { ManagedUser, StudentEntry } from '@/lib/types';
import { sectionLabel } from '@/lib/types';
import { MOTION, Panel, PanelHeader, staggerDelay } from '@/components/ui/primitives';

/**
 * Where the cards are coming from — by class, and by teacher (A12).
 *
 * Both halves answer the same question from opposite ends: which parts of the
 * school are producing ID cards and which are not. The per-teacher half only
 * became answerable when entries started recording who submitted them.
 *
 * Bars rather than a chart library. These are counts on a common scale with a
 * handful of rows, which is the one case where a bar is strictly better than
 * a chart: it reads at a glance, it prints, and it costs nothing to render.
 */

interface Row {
  key: string;
  label: string;
  sub?: string;
  value: number;
  isNew?: boolean;
}

export function SubmissionsBreakdown({
  entries,
  users,
  index = 0,
}: {
  entries: StudentEntry[];
  users: ManagedUser[];
  index?: number;
}) {
  const byClass = useMemo<Row[]>(() => {
    const counts = new Map<string, number>();
    for (const e of entries) {
      const key = e.studentClass.trim();
      if (!key) continue;
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }
    return [...counts.entries()]
      .map(([key, value]) => ({ key, label: `Class ${key}`, value }))
      .sort((a, b) => b.value - a.value)
      .slice(0, 8);
  }, [entries]);

  const byTeacher = useMemo<Row[]>(() => {
    const counts = new Map<string, number>();
    for (const e of entries) {
      if (!e.submittedByUid) continue;
      counts.set(e.submittedByUid, (counts.get(e.submittedByUid) ?? 0) + 1);
    }

    const named = new Map(users.map((u) => [u.uid, u]));

    // Teachers with an assignment and no cards belong here too. A teacher who
    // has submitted nothing is the single most useful row on this panel, and
    // counting only what exists would leave them off it entirely.
    for (const u of users) {
      if (u.role === 'Admin') continue;
      if (u.assignment && !counts.has(u.uid)) counts.set(u.uid, 0);
    }

    return [...counts.entries()]
      .map(([uid, value]) => {
        const u = named.get(uid);
        const fallback = entries.find((e) => e.submittedByUid === uid);
        return {
          key: uid,
          label: u?.displayName || u?.email || fallback?.submittedByName || 'Unknown',
          sub: u?.assignment ? sectionLabel(u.assignment) : undefined,
          value,
          isNew: value === 0,
        };
      })
      .sort((a, b) => b.value - a.value)
      .slice(0, 8);
  }, [entries, users]);

  const unattributed = entries.filter((e) => !e.submittedByUid).length;

  return (
    <div className="grid gap-4 lg:grid-cols-2">
      <Panel index={index} className="overflow-hidden">
        <PanelHeader title="Submissions by class" />
        <Bars rows={byClass} empty="No cards have been filed under a class yet." />
      </Panel>

      <Panel index={index + 1} className="overflow-hidden">
        <PanelHeader title="Submissions by teacher" />
        <Bars rows={byTeacher} empty="No cards have a teacher recorded against them yet." />
        {unattributed > 0 ? (
          <p className="px-5 pb-4 text-[11.5px] leading-relaxed text-ink-400">
            {unattributed} card{unattributed === 1 ? '' : 's'} predate this panel
            recording who submitted them, and are not counted here.
          </p>
        ) : null}
      </Panel>
    </div>
  );
}

function Bars({ rows, empty }: { rows: Row[]; empty: string }) {
  // Never divide by zero, and never let a single row fill the whole track on
  // a count of one - which would read as "complete".
  const max = Math.max(1, ...rows.map((r) => r.value));

  if (rows.length === 0) {
    return <p className="px-5 pb-5 text-[13px] text-ink-500">{empty}</p>;
  }

  return (
    <ul className="flex flex-col gap-2.5 px-5 pb-5">
      {rows.map((r, i) => (
        <li key={r.key} className="flex items-center gap-3">
          <span className="w-[112px] shrink-0 truncate text-[12.5px] text-ink-600">
            {r.label}
            {r.sub ? (
              <span className="block truncate text-[11px] text-ink-400">{r.sub}</span>
            ) : null}
          </span>

          <span className="relative h-2.5 min-w-0 flex-1 overflow-hidden rounded-full bg-ink-400/12">
            <motion.span
              initial={{ width: 0 }}
              animate={{ width: `${(r.value / max) * 100}%` }}
              transition={{
                duration: MOTION.slow,
                ease: MOTION.ease,
                delay: staggerDelay(i),
              }}
              className="absolute inset-y-0 left-0 rounded-full bg-mint-600"
            />
          </span>

          <span className="nums w-14 shrink-0 text-right text-[12.5px] text-ink-600">
            {r.value}
          </span>

          {r.isNew ? (
            <span className="shrink-0 rounded-md bg-[rgb(245_124_0/0.12)] px-1.5 py-0.5 text-[10.5px] font-semibold text-[#e65100]">
              New
            </span>
          ) : null}
        </li>
      ))}
    </ul>
  );
}
