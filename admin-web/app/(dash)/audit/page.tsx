'use client';

import { useMemo, useState } from 'react';
import Link from 'next/link';
import { motion } from 'framer-motion';
import { ScrollText } from 'lucide-react';
import { Topbar } from '@/components/layout/topbar';
import {
  Banner,
  EmptyState,
  MOTION,
  Panel,
  StatusChip,
  staggerDelay,
} from '@/components/ui/primitives';
import { useSchoolName, useStore } from '@/lib/store';

/**
 * Recent activity.
 *
 * Derived from the entries themselves - their review timestamps ARE the record
 * of what happened - rather than from a separate log. The mobile app keeps its
 * own audit table locally for print batches and exports, which never syncs to
 * Firestore, so inventing a second source here would show a different history
 * than the app does.
 */
export default function AuditPage() {
  const { entries, loading } = useStore();
  const schoolName = useSchoolName();
  const [limit, setLimit] = useState(60);

  const events = useMemo(() => {
    return entries
      .filter((e) => e.reviewedAt)
      .sort((a, b) => (b.reviewedAt ?? '').localeCompare(a.reviewedAt ?? ''))
      .slice(0, limit);
  }, [entries, limit]);

  return (
    <div className="flex flex-col gap-4">
      <Topbar greeting="History" title="Activity" />

      <Banner tone="info" title="Review decisions only">
        This is every approval and rejection, taken from the cards themselves.
        Print runs and CSV exports are logged on the machine that performed
        them and are not synced, so they do not appear here.
      </Banner>

      <Panel className="overflow-hidden">
        {loading ? (
          <p className="px-5 py-8 text-[13px] text-ink-500">Loading…</p>
        ) : events.length === 0 ? (
          <EmptyState
            icon={ScrollText}
            title="Nothing reviewed yet"
            body="Approvals and rejections appear here as they happen."
          />
        ) : (
          <ul className="flex flex-col">
            {events.map((e, i) => (
              <motion.li
                key={`${e.schoolId}/${e.id}`}
                initial={{ opacity: 0, y: 5 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{
                  duration: MOTION.normal,
                  ease: MOTION.ease,
                  delay: staggerDelay(i),
                }}
                className="border-b border-ink-400/8 last:border-0"
              >
                <Link
                  href={`/requests/${e.schoolId}/${e.id}`}
                  className="flex items-center gap-3 px-5 py-3 transition hover:bg-white/60"
                >
                  <StatusChip status={e.approvalStatus} dense />

                  <div className="min-w-0 flex-1">
                    <p className="truncate text-[13px] font-medium text-ink-700">
                      {e.name || 'UNNAMED'}
                    </p>
                    <p className="truncate text-[11.5px] text-ink-400">
                      {schoolName(e.schoolId)}
                      {e.rejectionReason ? ` — ${e.rejectionReason}` : ''}
                    </p>
                  </div>

                  <span className="shrink-0 text-[11.5px] text-ink-400">
                    {e.reviewedAt
                      ? new Date(e.reviewedAt).toLocaleString(undefined, {
                          day: '2-digit',
                          month: 'short',
                          hour: '2-digit',
                          minute: '2-digit',
                        })
                      : ''}
                  </span>
                </Link>
              </motion.li>
            ))}
          </ul>
        )}

        {entries.filter((e) => e.reviewedAt).length > limit ? (
          <button
            type="button"
            onClick={() => setLimit((l) => l + 60)}
            className="w-full border-t border-ink-400/10 py-3 text-[12.5px] font-semibold text-mint-600 transition hover:bg-white/60"
          >
            Show more
          </button>
        ) : null}
      </Panel>
    </div>
  );
}
