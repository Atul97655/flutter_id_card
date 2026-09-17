'use client';

import { useMemo, useState } from 'react';
import Link from 'next/link';
import { motion } from 'framer-motion';
import { ImageOff, Printer, Ruler, Sheet } from 'lucide-react';
import { Topbar } from '@/components/layout/topbar';
import {
  AnimatedNumber,
  Banner,
  Button,
  EmptyState,
  MOTION,
  Panel,
  PanelHeader,
  staggerDelay,
} from '@/components/ui/primitives';
import { useStore } from '@/lib/store';
import { markPrinted } from '@/lib/data';
import { hasPhoto, isPrintable, type StudentEntry } from '@/lib/types';

/**
 * Print Center.
 *
 * Sheet generation itself lives in the Flutter app, which owns the renderer
 * and the millimetre-accurate PDF pipeline. Duplicating that here would mean
 * two implementations of the one thing that must be exactly right - a card
 * specified as 54 x 86 mm measuring 54 x 86 mm under a ruler.
 *
 * What this page does is the part the office needs a big screen for: seeing
 * what is ready per school, what is blocked and why, and recording that a
 * batch has been printed.
 */

const SHEETS = [
  { id: '12x18', label: '12 × 18 in sheet', perSheet: 25, note: '5 × 5, commercial press' },
  { id: 'a4', label: 'A4 landscape', perSheet: 10, note: '5 × 2, office printer' },
  { id: 'single', label: 'Single cards', perSheet: 1, note: 'one PDF per student' },
];

export default function PrintPage() {
  const { entries, schools, loading } = useStore();
  const [schoolId, setSchoolId] = useState<string>('all');
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);

  const scoped = useMemo(
    () => (schoolId === 'all' ? entries : entries.filter((e) => e.schoolId === schoolId)),
    [entries, schoolId],
  );

  const ready = useMemo(
    () => scoped.filter((e) => isPrintable(e.approvalStatus) && hasPhoto(e)),
    [scoped],
  );
  const blocked = useMemo(
    () => scoped.filter((e) => isPrintable(e.approvalStatus) && !hasPhoto(e)),
    [scoped],
  );
  const awaitingPrint = ready.filter((e) => e.approvalStatus === 'approved');

  const recordPrinted = async () => {
    setBusy(true);
    setNotice(null);
    try {
      const n = await markPrinted(
        awaitingPrint.map((e) => ({
          id: e.id,
          schoolId: e.schoolId,
          approvalStatus: e.approvalStatus,
        })),
      );
      setNotice(
        n === 0
          ? 'Nothing moved — these cards were already marked printed.'
          : `${n} card${n === 1 ? '' : 's'} marked as printed. The schools see this on their phones.`,
      );
    } catch (e) {
      setNotice((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <Topbar greeting="Production" title="Print Center" />

      {notice ? <Banner tone="success" title={notice} /> : null}

      <Panel className="px-4 py-3">
        <div className="flex flex-wrap items-center gap-2.5">
          <span className="text-[12.5px] font-semibold text-ink-600">School</span>
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
        </div>
      </Panel>

      {blocked.length > 0 ? (
        <Banner
          tone="warn"
          title={`${blocked.length} approved card${
            blocked.length === 1 ? '' : 's'
          } cannot be placed on a sheet`}
        >
          No photo has reached the server for them yet. These were submitted
          before the app could send photos, so the picture is still on the phone
          that took it. Nothing is lost — each one uploads by itself the next
          time that phone syncs, and the card becomes printable with no
          re-entry.
        </Banner>
      ) : null}

      <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,320px)]">
        <Panel className="overflow-hidden">
          <PanelHeader title="Ready to print" />

          <div className="px-5 pb-5">
            {loading ? (
              <p className="py-6 text-[13px] text-ink-500">Loading…</p>
            ) : ready.length === 0 ? (
              <EmptyState
                icon={Printer}
                title="Nothing ready yet"
                body={
                  blocked.length > 0
                    ? 'Every approved card here is waiting on its photo.'
                    : 'Approve cards in the review queue and they appear here.'
                }
                action={
                  <Link href="/requests">
                    <Button size="sm" variant="outline">
                      Open review queue
                    </Button>
                  </Link>
                }
              />
            ) : (
              <>
                <div className="flex flex-wrap items-end justify-between gap-4">
                  <div>
                    <AnimatedNumber
                      value={ready.length}
                      className="text-[40px] font-bold leading-none tracking-tight text-[var(--color-status-printed)]"
                    />
                    <p className="mt-1 text-[13px] text-ink-500">
                      card{ready.length === 1 ? '' : 's'} approved and carrying a
                      photo
                    </p>
                  </div>
                  {awaitingPrint.length > 0 ? (
                    <Button icon={Printer} busy={busy} onClick={() => void recordPrinted()}>
                      Mark {awaitingPrint.length} as printed
                    </Button>
                  ) : null}
                </div>

                <div className="mt-5 grid gap-2.5 sm:grid-cols-3">
                  {SHEETS.map((s, i) => {
                    const sheets = Math.ceil(ready.length / s.perSheet);
                    return (
                      <motion.div
                        key={s.id}
                        initial={{ opacity: 0, y: 8 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{
                          duration: MOTION.normal,
                          ease: MOTION.ease,
                          delay: staggerDelay(i),
                        }}
                        className="rounded-[var(--radius-card)] border border-ink-400/12 bg-white/60 p-3.5"
                      >
                        <Sheet size={15} className="text-ink-400" />
                        <p className="mt-2 text-[12.5px] font-semibold text-ink-700">
                          {s.label}
                        </p>
                        <p className="mt-0.5 text-[11.5px] text-ink-400">{s.note}</p>
                        <p className="nums mt-2 text-[19px] font-bold text-ink-700">
                          {sheets}
                          <span className="ml-1 text-[11.5px] font-medium text-ink-400">
                            sheet{sheets === 1 ? '' : 's'}
                          </span>
                        </p>
                      </motion.div>
                    );
                  })}
                </div>

                <div className="mt-4 rounded-[var(--radius-card)] border border-ink-400/12 bg-white/50 px-4 py-3">
                  <div className="flex items-start gap-2.5">
                    <Ruler size={15} className="mt-px shrink-0 text-ink-400" />
                    <p className="text-[12.5px] leading-relaxed text-ink-500">
                      Sheets are generated in the mobile app, which owns the
                      millimetre-accurate PDF pipeline. Print at{' '}
                      <strong className="font-semibold text-ink-700">
                        100% / Actual Size
                      </strong>{' '}
                      — never &ldquo;Fit to page&rdquo;, which silently rescales
                      the card.
                    </p>
                  </div>
                </div>
              </>
            )}
          </div>
        </Panel>

        <Panel index={1} className="overflow-hidden">
          <PanelHeader title="Blocked" />
          <div className="px-5 pb-5">
            {blocked.length === 0 ? (
              <p className="py-3 text-[13px] text-ink-500">
                Nothing blocked. Every approved card has its photo.
              </p>
            ) : (
              <ul className="flex flex-col gap-1.5">
                {blocked.slice(0, 12).map((e, i) => (
                  <BlockedRow key={`${e.schoolId}/${e.id}`} entry={e} index={i} />
                ))}
                {blocked.length > 12 ? (
                  <li className="px-1 pt-1 text-[11.5px] text-ink-400">
                    and {blocked.length - 12} more
                  </li>
                ) : null}
              </ul>
            )}
          </div>
        </Panel>
      </div>
    </div>
  );
}

function BlockedRow({ entry, index }: { entry: StudentEntry; index: number }) {
  return (
    <motion.li
      initial={{ opacity: 0, y: 5 }}
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
        <span className="grid size-7 shrink-0 place-items-center rounded-lg bg-[var(--color-status-rejected)]/10 text-[var(--color-status-rejected)]">
          <ImageOff size={13} />
        </span>
        <span className="min-w-0 flex-1">
          <span className="block truncate text-[12.5px] font-semibold text-ink-700">
            {entry.name || 'UNNAMED'}
          </span>
          <span className="block truncate text-[11px] text-ink-400">
            {entry.studentClass ? `Class ${entry.studentClass}` : 'No class'}
            {entry.division ? ` · ${entry.division}` : ''}
          </span>
        </span>
      </Link>
    </motion.li>
  );
}
