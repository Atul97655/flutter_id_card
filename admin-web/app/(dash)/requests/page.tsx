'use client';

import { useMemo, useState } from 'react';
import Link from 'next/link';
import { AnimatePresence, motion } from 'framer-motion';
import {
  CheckCircle2,
  ChevronRight,
  Inbox,
  X,
  XCircle,
} from 'lucide-react';
import { Topbar } from '@/components/layout/topbar';
import {
  Banner,
  Button,
  EmptyState,
  Field,
  MOTION,
  Panel,
  Skeleton,
  StatusChip,
  inputClass,
  staggerDelay,
} from '@/components/ui/primitives';
import { useAuth } from '@/lib/auth-context';
import { useSchoolName, useStore } from '@/lib/store';
import { reviewMany } from '@/lib/data';
import {
  APPROVAL_LABELS,
  APPROVAL_STATUSES,
  hasPhoto,
  isPrintable,
  type ApprovalStatus,
  type StudentEntry,
} from '@/lib/types';
import { EntryPhoto } from '@/components/ui/entry-photo';

/**
 * The review queue - the admin's main job.
 *
 * Defaults to `pending` because that is the only tab that represents work
 * waiting on this person. Everything else is a record.
 */
export default function RequestsPage() {
  const { profile } = useAuth();
  const { entries, schools, loading, config } = useStore();
  const schoolName = useSchoolName();

  const [status, setStatus] = useState<ApprovalStatus | 'all'>('pending');
  const [schoolFilter, setSchoolFilter] = useState<string>('all');
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [rejecting, setRejecting] = useState(false);
  const [reason, setReason] = useState('');

  const key = (e: StudentEntry) => `${e.schoolId}/${e.id}`;

  const counts = useMemo(() => {
    const c: Record<string, number> = { all: entries.length };
    for (const s of APPROVAL_STATUSES) c[s] = 0;
    for (const e of entries) c[e.approvalStatus]++;
    return c;
  }, [entries]);

  const filtered = useMemo(() => {
    const needle = search.trim().toUpperCase();
    return entries
      .filter((e) => status === 'all' || e.approvalStatus === status)
      .filter((e) => schoolFilter === 'all' || e.schoolId === schoolFilter)
      .filter((e) => {
        if (!needle) return true;
        return (
          e.name.includes(needle) ||
          e.studentClass.includes(needle) ||
          e.division.includes(needle) ||
          e.rollNumber.includes(needle) ||
          e.mobile.includes(needle)
        );
      })
      .sort((a, b) => (b.createdAt ?? '').localeCompare(a.createdAt ?? ''));
  }, [entries, status, schoolFilter, search]);

  const selectedEntries = filtered.filter((e) => selected.has(key(e)));
  const allShownSelected =
    filtered.length > 0 && filtered.every((e) => selected.has(key(e)));

  const toggle = (e: StudentEntry) => {
    setSelected((prev) => {
      const next = new Set(prev);
      const k = key(e);
      if (next.has(k)) next.delete(k);
      else next.add(k);
      return next;
    });
  };

  const toggleAll = () => {
    setSelected((prev) => {
      if (allShownSelected) return new Set();
      const next = new Set(prev);
      for (const e of filtered) next.add(key(e));
      return next;
    });
  };

  const runReview = async (decision: 'approved' | 'rejected', why?: string) => {
    if (!profile || selectedEntries.length === 0) return;
    setBusy(true);
    setNotice(null);
    try {
      const n = await reviewMany(
        selectedEntries.map((e) => ({ id: e.id, schoolId: e.schoolId })),
        decision,
        profile.uid,
        why,
      );
      setNotice(
        `${n} card${n === 1 ? '' : 's'} ${
          decision === 'approved' ? 'approved' : 'sent back'
        }.`,
      );
      setSelected(new Set());
      setRejecting(false);
      setReason('');
    } catch (e) {
      setNotice((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <Topbar
        greeting="Card submissions"
        title="ID Card Requests"
        onSearch={setSearch}
        searchValue={search}
        searchPlaceholder="Search name, class, roll, mobile"
      />

      {notice ? (
        <Banner
          tone="success"
          title={notice}
          action={
            <button
              type="button"
              onClick={() => setNotice(null)}
              className="shrink-0 rounded-lg p-1 text-ink-500 transition hover:bg-white/70"
              aria-label="Dismiss"
            >
              <X size={14} />
            </button>
          }
        />
      ) : null}

      {/* Filters */}
      <Panel className="px-4 py-3">
        <div className="flex flex-wrap items-center gap-2">
          <FilterChip
            label="All"
            count={counts.all}
            active={status === 'all'}
            onClick={() => setStatus('all')}
          />
          {APPROVAL_STATUSES.map((s) => (
            <FilterChip
              key={s}
              label={APPROVAL_LABELS[s]}
              count={counts[s]}
              active={status === s}
              status={s}
              onClick={() => setStatus(s)}
            />
          ))}

          <span className="mx-1 hidden h-5 w-px bg-ink-400/15 sm:block" />

          <select
            value={schoolFilter}
            onChange={(e) => setSchoolFilter(e.target.value)}
            className="rounded-full border border-ink-400/20 bg-white/80 px-3 py-1.5 text-[12.5px] font-medium text-ink-600 outline-none transition focus:border-mint-500"
          >
            <option value="all">Every school</option>
            {schools.map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </select>
        </div>
      </Panel>

      {/* Bulk action bar */}
      <AnimatePresence>
        {selectedEntries.length > 0 ? (
          <motion.div
            initial={{ opacity: 0, y: -8, height: 0 }}
            animate={{ opacity: 1, y: 0, height: 'auto' }}
            exit={{ opacity: 0, y: -8, height: 0 }}
            transition={{ duration: MOTION.normal, ease: MOTION.ease }}
          >
            <div className="glass flex flex-wrap items-center gap-3 rounded-[var(--radius-panel)] px-4 py-3">
              <span className="text-[13px] font-semibold text-ink-700">
                {selectedEntries.length} selected
              </span>
              <button
                type="button"
                onClick={() => setSelected(new Set())}
                className="text-[12.5px] font-medium text-ink-500 underline-offset-2 hover:underline"
              >
                Clear
              </button>

              <div className="ml-auto flex flex-wrap items-center gap-2">
                <Button
                  size="sm"
                  variant="success"
                  icon={CheckCircle2}
                  busy={busy && !rejecting}
                  onClick={() => void runReview('approved')}
                >
                  Approve
                </Button>
                <Button
                  size="sm"
                  variant="danger"
                  icon={XCircle}
                  onClick={() => setRejecting((v) => !v)}
                >
                  Send back
                </Button>
              </div>

              <AnimatePresence>
                {rejecting ? (
                  <motion.div
                    initial={{ opacity: 0, height: 0 }}
                    animate={{ opacity: 1, height: 'auto' }}
                    exit={{ opacity: 0, height: 0 }}
                    transition={{ duration: MOTION.normal, ease: MOTION.ease }}
                    className="w-full overflow-hidden"
                  >
                    <div className="pt-3">
                      <Field
                        label="Why is it being sent back?"
                        hint="The operator sees this exact text, so name the specific problem."
                      >
                        <div className="flex gap-2">
                          <input
                            value={reason}
                            onChange={(e) => setReason(e.target.value)}
                            placeholder="Photo is too dark - retake in better light"
                            className={inputClass}
                          />
                          <Button
                            variant="danger"
                            busy={busy}
                            disabled={!reason.trim()}
                            onClick={() => void runReview('rejected', reason)}
                          >
                            Send back
                          </Button>
                        </div>
                      </Field>
                    </div>
                  </motion.div>
                ) : null}
              </AnimatePresence>
            </div>
          </motion.div>
        ) : null}
      </AnimatePresence>

      {/* Table */}
      <Panel className="overflow-hidden" index={1}>
        {loading ? (
          <div className="flex flex-col gap-2 p-5">
            <Skeleton className="h-12" />
            <Skeleton className="h-12" />
            <Skeleton className="h-12" />
          </div>
        ) : filtered.length === 0 ? (
          <EmptyState
            icon={status === 'pending' ? CheckCircle2 : Inbox}
            title={
              entries.length === 0
                ? 'No submissions yet'
                : status === 'pending'
                  ? 'Nothing waiting'
                  : 'No cards match'
            }
            body={
              entries.length === 0
                ? 'Cards submitted from the mobile app appear here for review.'
                : status === 'pending'
                  ? 'Every submission has been reviewed.'
                  : 'Try a different tab, school or search term.'
            }
          />
        ) : (
          <>
            <div className="hidden overflow-x-auto lg:block">
            <table className="w-full min-w-[720px] border-collapse">
              <thead>
                <tr className="border-b border-ink-400/10 text-[10.5px] uppercase tracking-wider text-ink-400">
                  <th className="w-10 px-4 py-2.5">
                    <input
                      type="checkbox"
                      checked={allShownSelected}
                      onChange={toggleAll}
                      aria-label="Select all shown"
                      className="size-3.5 cursor-pointer accent-[var(--color-mint-600)]"
                    />
                  </th>
                  <th className="px-2 py-2.5 text-left font-bold">Student</th>
                  <th className="px-2 py-2.5 text-left font-bold">School</th>
                  <th className="px-2 py-2.5 text-left font-bold">Class</th>
                  <th className="px-2 py-2.5 text-left font-bold">Status</th>
                  <th className="px-2 py-2.5 text-left font-bold">Submitted</th>
                  <th className="w-10 px-2 py-2.5" />
                </tr>
              </thead>
              <tbody>
                {filtered.slice(0, 200).map((e, i) => (
                  <Row
                    key={key(e)}
                    entry={e}
                    school={schoolName(e.schoolId)}
                    checked={selected.has(key(e))}
                    onToggle={() => toggle(e)}
                    index={i}
                    printingEnabled={config.printingEnabled}
                  />
                ))}
              </tbody>
            </table>

            {filtered.length > 200 ? (
              <p className="border-t border-ink-400/10 px-4 py-3 text-[12.5px] text-ink-400">
                Showing the first 200 of {filtered.length}. Narrow the search or
                filter to see the rest.
              </p>
            ) : null}
          </div>

          {/* Below lg the same rows are cards.
              A 720px table on a 375px phone means dragging sideways to read a
              name and then back again to see its status - on the screen the
              office spends most of its day in. The card carries the same
              fields in the order they are actually read. */}
          <ul className="flex flex-col gap-2 p-3 lg:hidden">
            {filtered.slice(0, 200).map((e, i) => (
              <MobileRow
                key={key(e)}
                entry={e}
                school={schoolName(e.schoolId)}
                checked={selected.has(key(e))}
                onToggle={() => toggle(e)}
                index={i}
                printingEnabled={config.printingEnabled}
              />
            ))}
            {filtered.length > 200 ? (
              <li className="px-1 py-2 text-[12.5px] text-ink-400">
                Showing the first 200 of {filtered.length}. Narrow the search or
                filter to see the rest.
              </li>
            ) : null}
            </ul>
          </>
        )}
      </Panel>
    </div>
  );
}

function FilterChip({
  label,
  count,
  active,
  onClick,
  status,
}: {
  label: string;
  count: number;
  active: boolean;
  onClick: () => void;
  status?: ApprovalStatus;
}) {
  const tint =
    status === 'pending'
      ? 'var(--color-status-pending)'
      : status === 'approved'
        ? 'var(--color-status-approved)'
        : status === 'rejected'
          ? 'var(--color-status-rejected)'
          : status === 'printed'
            ? 'var(--color-status-printed)'
            : 'var(--color-mint-600)';

  return (
    <button
      type="button"
      onClick={onClick}
      className="rounded-full border px-3 py-1.5 text-[12.5px] font-semibold transition"
      style={
        active
          ? {
              color: tint,
              background: `color-mix(in srgb, ${tint} 13%, transparent)`,
              borderColor: `color-mix(in srgb, ${tint} 40%, transparent)`,
            }
          : {
              color: 'var(--color-ink-500)',
              background: 'rgb(255 255 255 / 0.7)',
              borderColor: 'rgb(124 138 150 / 0.2)',
            }
      }
    >
      {label} <span className="nums opacity-70">({count})</span>
    </button>
  );
}

/**
 * One submission as a card, for phone-width screens.
 *
 * Same data as [Row] and the same selection behaviour - the checkbox has to
 * work here too, or bulk approve becomes desktop-only.
 */
function MobileRow({
  entry,
  school,
  checked,
  onToggle,
  index,
  printingEnabled,
}: {
  entry: StudentEntry;
  school: string;
  checked: boolean;
  onToggle: () => void;
  index: number;
  printingEnabled: boolean;
}) {
  const blocked =
    printingEnabled && isPrintable(entry.approvalStatus) && !hasPhoto(entry);

  return (
    <motion.li
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{
        duration: MOTION.normal,
        ease: MOTION.ease,
        delay: staggerDelay(index),
      }}
      className={`rounded-[var(--radius-card)] border transition-colors ${
        checked
          ? 'border-mint-500/40 bg-mint-500/8'
          : 'border-ink-400/10 bg-white/65'
      }`}
    >
      <div className="flex items-start gap-3 p-3">
        <input
          type="checkbox"
          checked={checked}
          onChange={onToggle}
          aria-label={`Select ${entry.name || 'unnamed student'}`}
          className="mt-1 size-4 shrink-0 cursor-pointer accent-[var(--color-mint-600)]"
        />

        <Link
          href={`/requests/${entry.schoolId}/${entry.id}`}
          className="flex min-w-0 flex-1 items-start gap-3"
        >
          <span className="grid size-11 shrink-0 place-items-center overflow-hidden rounded-lg bg-ink-400/10 text-ink-400">
            <EntryPhoto entry={entry} iconSize={16} />
          </span>

          <span className="min-w-0 flex-1">
            <span className="block truncate text-[14px] font-semibold text-ink-700">
              {entry.name || 'UNNAMED'}
            </span>
            <span className="mt-0.5 block truncate text-[12px] text-ink-400">
              {school}
            </span>
            <span className="mt-0.5 block truncate text-[12px] text-ink-400">
              {entry.studentClass || 'No class'}
              {entry.division ? ` / ${entry.division}` : ''}
              {entry.rollNumber ? ` · Roll ${entry.rollNumber}` : ''}
            </span>

            <span className="mt-2 flex flex-wrap items-center gap-2">
              <StatusChip status={entry.approvalStatus} dense />
              {blocked ? (
                <span className="text-[10.5px] font-semibold text-[var(--color-status-rejected)]">
                  no photo — cannot print
                </span>
              ) : null}
            </span>
          </span>

          <ChevronRight
            size={16}
            className="mt-1 shrink-0 text-ink-400"
            aria-hidden
          />
        </Link>
      </div>
    </motion.li>
  );
}

function Row({
  entry,
  school,
  checked,
  onToggle,
  index,
  printingEnabled,
}: {
  entry: StudentEntry;
  school: string;
  checked: boolean;
  onToggle: () => void;
  index: number;
  printingEnabled: boolean;
}) {
  // Approved but with no photo can never be printed. Flagged inline because
  // it otherwise looks complete in every count until someone tries to print.
  const blocked =
    printingEnabled && isPrintable(entry.approvalStatus) && !hasPhoto(entry);

  return (
    <motion.tr
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{
        duration: MOTION.normal,
        ease: MOTION.ease,
        delay: staggerDelay(index),
      }}
      className={`group border-b border-ink-400/8 transition-colors last:border-0 ${
        checked ? 'bg-mint-500/6' : 'hover:bg-white/60'
      }`}
    >
      <td className="px-4 py-2.5">
        <input
          type="checkbox"
          checked={checked}
          onChange={onToggle}
          aria-label={`Select ${entry.name}`}
          className="size-3.5 cursor-pointer accent-[var(--color-mint-600)]"
        />
      </td>

      <td className="px-2 py-2.5">
        <div className="flex items-center gap-2.5">
          <span className="grid size-9 shrink-0 place-items-center overflow-hidden rounded-lg bg-ink-400/10 text-ink-400">
            <EntryPhoto entry={entry} iconSize={14} />
          </span>
          <div className="min-w-0">
            <p className="truncate text-[13px] font-semibold text-ink-700">
              {entry.name || 'UNNAMED'}
            </p>
            {entry.rollNumber ? (
              <p className="truncate text-[11.5px] text-ink-400">
                Roll {entry.rollNumber}
              </p>
            ) : null}
          </div>
        </div>
      </td>

      <td className="max-w-[170px] px-2 py-2.5">
        <p className="truncate text-[12.5px] text-ink-600">{school}</p>
      </td>

      <td className="px-2 py-2.5 text-[12.5px] text-ink-600">
        {entry.studentClass || '—'}
        {entry.division ? ` / ${entry.division}` : ''}
      </td>

      <td className="px-2 py-2.5">
        <div className="flex flex-col items-start gap-1">
          <StatusChip status={entry.approvalStatus} dense />
          {blocked ? (
            <span className="text-[10.5px] font-semibold text-[var(--color-status-rejected)]">
              no photo — cannot print
            </span>
          ) : null}
        </div>
      </td>

      <td className="px-2 py-2.5 text-[12px] text-ink-400">
        {entry.createdAt
          ? new Date(entry.createdAt).toLocaleDateString(undefined, {
              day: '2-digit',
              month: 'short',
            })
          : '—'}
      </td>

      <td className="px-2 py-2.5">
        <Link
          href={`/requests/${entry.schoolId}/${entry.id}`}
          className="grid size-7 place-items-center rounded-lg text-ink-400 transition group-hover:bg-white group-hover:text-mint-600"
          aria-label={`Open ${entry.name}`}
        >
          <ChevronRight size={15} />
        </Link>
      </td>
    </motion.tr>
  );
}
