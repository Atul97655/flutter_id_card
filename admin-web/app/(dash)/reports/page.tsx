'use client';

import { useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import { Download, TrendingUp } from 'lucide-react';
import { Topbar } from '@/components/layout/topbar';
import {
  Button,
  EmptyState,
  MOTION,
  Panel,
  PanelHeader,
  StatusChip,
  staggerDelay,
} from '@/components/ui/primitives';
import { useStore } from '@/lib/store';
import {
  APPROVAL_LABELS,
  APPROVAL_STATUSES,
  hasPhoto,
  isPrintable,
  type ApprovalStatus,
  type StudentEntry,
} from '@/lib/types';

/**
 * Reports.
 *
 * Every number here is counted from the entries actually in Firestore. There
 * are no targets, projections or comparisons to invent - a school either has
 * submitted N cards or it has not.
 */
export default function ReportsPage() {
  const { entries, schools, loading } = useStore();
  const [schoolId, setSchoolId] = useState('all');

  const scoped = useMemo(
    () => (schoolId === 'all' ? entries : entries.filter((e) => e.schoolId === schoolId)),
    [entries, schoolId],
  );

  const byStatus = useMemo(() => {
    const m = new Map<ApprovalStatus, number>();
    for (const s of APPROVAL_STATUSES) m.set(s, 0);
    for (const e of scoped) m.set(e.approvalStatus, (m.get(e.approvalStatus) ?? 0) + 1);
    return m;
  }, [scoped]);

  /** Submissions per month, oldest first. */
  const byMonth = useMemo(() => {
    const m = new Map<string, number>();
    for (const e of scoped) {
      if (!e.createdAt) continue;
      const d = new Date(e.createdAt);
      if (Number.isNaN(d.getTime())) continue;
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
      m.set(key, (m.get(key) ?? 0) + 1);
    }
    return [...m.entries()].sort((a, b) => a[0].localeCompare(b[0])).slice(-12);
  }, [scoped]);

  const maxMonth = Math.max(1, ...byMonth.map(([, n]) => n));

  const perSchool = useMemo(() => {
    return schools
      .map((s) => {
        const mine = entries.filter((e) => e.schoolId === s.id);
        return {
          id: s.id,
          name: s.name,
          total: mine.length,
          pending: mine.filter((e) => e.approvalStatus === 'pending').length,
          approved: mine.filter((e) => e.approvalStatus === 'approved').length,
          printed: mine.filter((e) => e.approvalStatus === 'printed').length,
          rejected: mine.filter((e) => e.approvalStatus === 'rejected').length,
          noPhoto: mine.filter((e) => isPrintable(e.approvalStatus) && !hasPhoto(e)).length,
        };
      })
      .sort((a, b) => b.total - a.total);
  }, [schools, entries]);

  const exportCsv = () => {
    const rows = [
      [
        'Name',
        "Father's Name",
        'Class',
        'Division',
        'Roll No',
        'Blood Group',
        'DOB',
        'Mobile',
        'Address',
        'School',
        'Status',
        'Has photo',
        'Rejection reason',
        'Submitted',
      ],
      ...scoped.map((e: StudentEntry) => [
        e.name,
        e.fatherName,
        e.studentClass,
        e.division,
        e.rollNumber,
        e.bloodGroup,
        e.dob ?? '',
        e.mobile,
        e.address,
        schools.find((s) => s.id === e.schoolId)?.name ?? e.schoolId,
        APPROVAL_LABELS[e.approvalStatus],
        hasPhoto(e) ? 'Yes' : 'No',
        e.rejectionReason ?? '',
        e.createdAt ?? '',
      ]),
    ];

    // RFC 4180: quote every field, double any inner quote. A UTF-8 BOM makes
    // Excel open Indian names correctly instead of as mojibake.
    const csv =
      '﻿' +
      rows
        .map((r) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(','))
        .join('\r\n');

    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `id-entity-${schoolId}-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="flex flex-col gap-4">
      <Topbar greeting="Records" title="Reports" />

      <Panel className="px-4 py-3">
        <div className="flex flex-wrap items-center gap-2.5">
          <select
            value={schoolId}
            onChange={(e) => setSchoolId(e.target.value)}
            className="rounded-full border border-ink-400/20 bg-white/80 px-3 py-1.5 text-[12.5px] font-medium text-ink-600 outline-none transition focus:border-mint-500"
          >
            <option value="all">Every school</option>
            {schools.map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </select>

          <span className="nums text-[12.5px] text-ink-400">
            {scoped.length} card{scoped.length === 1 ? '' : 's'}
          </span>

          <Button
            size="sm"
            variant="outline"
            icon={Download}
            disabled={scoped.length === 0}
            onClick={exportCsv}
            className="ml-auto"
          >
            Export CSV
          </Button>
        </div>
      </Panel>

      {loading ? null : scoped.length === 0 ? (
        <Panel>
          <EmptyState
            icon={TrendingUp}
            title="Nothing to report yet"
            body="Numbers appear here once cards have been submitted."
          />
        </Panel>
      ) : (
        <>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {APPROVAL_STATUSES.map((s, i) => (
              <Panel key={s} index={i} className="p-4">
                <StatusChip status={s} dense />
                <p className="nums mt-2.5 text-[26px] font-bold leading-none tracking-tight text-ink-900">
                  {byStatus.get(s) ?? 0}
                </p>
                <p className="mt-1 text-[11.5px] text-ink-400">
                  {scoped.length === 0
                    ? '—'
                    : `${Math.round(((byStatus.get(s) ?? 0) / scoped.length) * 100)}% of submissions`}
                </p>
              </Panel>
            ))}
          </div>

          <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
            <Panel index={1} className="overflow-hidden">
              <PanelHeader title="Submissions by month" />
              <div className="px-5 pb-5">
                {byMonth.length === 0 ? (
                  <p className="py-6 text-[13px] text-ink-400">
                    No dated submissions yet.
                  </p>
                ) : (
                  <div className="flex h-[168px] items-end gap-1.5">
                    {byMonth.map(([month, n], i) => (
                      <div
                        key={month}
                        className="group flex min-w-0 flex-1 flex-col items-center gap-1.5"
                      >
                        <span className="nums text-[10.5px] font-semibold text-ink-500 opacity-0 transition group-hover:opacity-100">
                          {n}
                        </span>
                        <motion.div
                          initial={{ height: 0 }}
                          animate={{ height: `${(n / maxMonth) * 100}%` }}
                          transition={{
                            duration: 0.55,
                            ease: MOTION.ease,
                            delay: staggerDelay(i),
                          }}
                          className="w-full rounded-t-md bg-gradient-to-t from-mint-500 to-mint-400"
                          style={{ minHeight: 3 }}
                        />
                        <span className="w-full truncate text-center text-[9.5px] text-ink-400">
                          {new Date(`${month}-01`).toLocaleDateString(undefined, {
                            month: 'short',
                          })}
                        </span>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </Panel>

            <Panel index={2} className="overflow-hidden">
              <PanelHeader title="By school" />
              <div className="overflow-x-auto px-2 pb-3">
                <table className="w-full min-w-[420px] border-collapse">
                  <thead>
                    <tr className="text-[10.5px] uppercase tracking-wider text-ink-400">
                      <th className="px-3 py-2 text-left font-bold">School</th>
                      <th className="px-2 py-2 text-right font-bold">Total</th>
                      <th className="px-2 py-2 text-right font-bold">Pending</th>
                      <th className="px-2 py-2 text-right font-bold">Printed</th>
                      <th className="px-3 py-2 text-right font-bold">No photo</th>
                    </tr>
                  </thead>
                  <tbody>
                    {perSchool.map((r, i) => (
                      <motion.tr
                        key={r.id}
                        initial={{ opacity: 0, y: 6 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{
                          duration: MOTION.normal,
                          ease: MOTION.ease,
                          delay: staggerDelay(i),
                        }}
                        className="border-t border-ink-400/8"
                      >
                        <td className="max-w-[160px] truncate px-3 py-2.5 text-[12.5px] font-medium text-ink-700">
                          {r.name}
                        </td>
                        <td className="nums px-2 py-2.5 text-right text-[12.5px] text-ink-600">
                          {r.total}
                        </td>
                        <td className="nums px-2 py-2.5 text-right text-[12.5px]">
                          {r.pending || <span className="text-ink-400">—</span>}
                        </td>
                        <td className="nums px-2 py-2.5 text-right text-[12.5px] text-ink-600">
                          {r.printed}
                        </td>
                        <td className="nums px-3 py-2.5 text-right text-[12.5px]">
                          {r.noPhoto > 0 ? (
                            <span className="font-semibold text-[var(--color-status-rejected)]">
                              {r.noPhoto}
                            </span>
                          ) : (
                            <span className="text-ink-400">—</span>
                          )}
                        </td>
                      </motion.tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Panel>
          </div>
        </>
      )}
    </div>
  );
}
