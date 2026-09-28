'use client';

import { useMemo, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { UserCheck } from 'lucide-react';
import { Topbar } from '@/components/layout/topbar';
import { useAuth } from '@/lib/auth-context';
import { approveJoin, declineJoin } from '@/lib/joins';
import { useSchoolName, useStore } from '@/lib/store';
import type { JoinRequest, SchoolConfig } from '@/lib/types';
import { formatDateTime } from '@/lib/dates';
import {
  Banner,
  Button,
  EmptyState,
  MOTION,
  Panel,
  inputClass,
  staggerDelay,
} from '@/components/ui/primitives';

/**
 * Teachers waiting for a class (A10).
 *
 * Everyone on this page has already proved they hold the school's QR code
 * and can currently see nothing at all. Approving is what gives them access,
 * so the class and section pickers are not a convenience - a teacher cannot
 * be approved without them, because an approval with no section would put
 * someone into the whole school by accident.
 */
export default function PendingJoinsPage() {
  const { joinRequests, schools, loading } = useStore();
  const { user } = useAuth();
  const schoolName = useSchoolName();

  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [picks, setPicks] = useState<
    Record<string, { classLevel: string; division: string }>
  >({});

  const schoolsById = useMemo(
    () => new Map(schools.map((s) => [s.id, s])),
    [schools],
  );

  const waiting = useMemo(
    () =>
      [...joinRequests].sort((a, b) =>
        // Longest wait at the top. Somebody has been standing in a staffroom
        // unable to use the app since whenever this was written.
        (a.requestedAt ?? '').localeCompare(b.requestedAt ?? ''),
      ),
    [joinRequests],
  );

  const pick = (uid: string) => picks[uid] ?? { classLevel: '', division: '' };

  const setPick = (uid: string, patch: Partial<{ classLevel: string; division: string }>) =>
    setPicks((p) => ({ ...p, [uid]: { ...pick(uid), ...patch } }));

  async function onApprove(r: JoinRequest) {
    const { classLevel, division } = pick(r.uid);
    if (!classLevel || !division) {
      setError(
        `Choose a class and section for ${r.displayName || r.email} before approving.`,
      );
      return;
    }
    setBusy(r.uid);
    setError(null);
    try {
      await approveJoin(r, classLevel, division, user?.uid ?? '');
    } catch (e) {
      setError(`Could not approve: ${(e as Error).message}`);
    } finally {
      setBusy(null);
    }
  }

  async function onDecline(r: JoinRequest) {
    setBusy(r.uid);
    setError(null);
    try {
      await declineJoin(r);
    } catch (e) {
      setError(`Could not decline: ${(e as Error).message}`);
    } finally {
      setBusy(null);
    }
  }

  return (
    <div className="flex flex-col gap-4">
      {/*
        The Topbar carries the nav drawer, and on a phone the sidebar is
        hidden - so a page without one is a dead end with no way to reach any
        other page. Every page in this panel needs it for that reason alone.
      */}
      <Topbar greeting="Access" title="Pending Joins" />

      <p className="-mt-1 px-1 text-[13px] text-ink-400">
        Teachers who scanned a school QR code and are waiting for a class
      </p>

      {error ? (
        <Banner tone="error" title="That did not go through">
          {error}
        </Banner>
      ) : null}

      {waiting.length > 0 ? (
        <Banner
          tone="warn"
          title={`${waiting.length} ${waiting.length === 1 ? 'teacher is' : 'teachers are'} waiting`}
        >
          They cannot see or send anything until you assign a class and section,
          or decline them.
        </Banner>
      ) : null}

      <Panel>
        {loading && waiting.length === 0 ? (
          <div className="p-5 text-[13px] text-ink-400">Loading…</div>
        ) : waiting.length === 0 ? (
          <EmptyState
            icon={UserCheck}
            title="Nobody is waiting"
            body="When a teacher scans a school's QR code, they appear here until you give them a class and section."
          />
        ) : (
          <ul className="divide-y divide-black/5">
            <AnimatePresence initial={false}>
              {waiting.map((r, i) => (
                <motion.li
                  key={r.uid}
                  layout
                  initial={{ opacity: 0, y: 6 }}
                  animate={{
                    opacity: 1,
                    y: 0,
                    transition: {
                      duration: MOTION.normal,
                      ease: MOTION.ease,
                      delay: staggerDelay(i),
                    },
                  }}
                  exit={{
                    opacity: 0,
                    height: 0,
                    transition: { duration: MOTION.fast, ease: MOTION.ease },
                  }}
                  className="flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:gap-4 sm:p-5"
                >
                  <Who request={r} school={schoolName(r.schoolId)} />

                  <SectionPickers
                    school={schoolsById.get(r.schoolId)}
                    value={pick(r.uid)}
                    onChange={(patch) => setPick(r.uid, patch)}
                    disabled={busy === r.uid}
                  />

                  <div className="flex shrink-0 gap-2">
                    <Button
                      onClick={() => onApprove(r)}
                      busy={busy === r.uid}
                      disabled={busy !== null}
                    >
                      Approve
                    </Button>
                    <Button
                      variant="danger"
                      onClick={() => onDecline(r)}
                      disabled={busy !== null}
                    >
                      Decline
                    </Button>
                  </div>
                </motion.li>
              ))}
            </AnimatePresence>
          </ul>
        )}
      </Panel>

      <p className="px-1 text-[12px] text-ink-400">
        Declining removes the teacher&apos;s connection to this school. It is not a
        ban — they can scan again if it was a mistake.
      </p>
    </div>
  );
}

function Who({ request, school }: { request: JoinRequest; school: string }) {
  const when = formatDateTime(request.requestedAt, 'an unknown time');

  return (
    <div className="min-w-0 flex-1">
      <p className="truncate text-[14px] font-semibold text-ink-700">
        {request.displayName || request.email || request.uid}
      </p>
      <p className="truncate text-[12px] text-ink-400">
        {request.email ? `${request.email} · ` : ''}
        {school}
      </p>
      <p className="mt-0.5 text-[11.5px] text-ink-400">Scanned {when}</p>
    </div>
  );
}

/**
 * Class and section pickers, populated from the school's own lists.
 *
 * Falls back to a free-text box when the school has no configured classes.
 * Without the fallback an office that has not filled in Classes &amp; Sections
 * yet would find the Approve button permanently unusable with nothing on
 * screen explaining why.
 */
function SectionPickers({
  school,
  value,
  onChange,
  disabled,
}: {
  school: SchoolConfig | undefined;
  value: { classLevel: string; division: string };
  onChange: (patch: Partial<{ classLevel: string; division: string }>) => void;
  disabled: boolean;
}) {
  const classes = school?.classes ?? [];
  const divisions = school?.divisions ?? [];

  return (
    <div className="flex shrink-0 gap-2">
      <Picker
        label="Class"
        options={classes}
        value={value.classLevel}
        onChange={(v) => onChange({ classLevel: v })}
        disabled={disabled}
      />
      <Picker
        label="Section"
        options={divisions}
        value={value.division}
        onChange={(v) => onChange({ division: v })}
        disabled={disabled}
      />
    </div>
  );
}

function Picker({
  label,
  options,
  value,
  onChange,
  disabled,
}: {
  label: string;
  options: string[];
  value: string;
  onChange: (v: string) => void;
  disabled: boolean;
}) {
  if (options.length === 0) {
    return (
      <input
        aria-label={label}
        placeholder={label}
        className={`${inputClass} w-24`}
        value={value}
        disabled={disabled}
        onChange={(e) => onChange(e.target.value.toUpperCase())}
      />
    );
  }

  return (
    <select
      aria-label={label}
      className={`${inputClass} w-28`}
      value={value}
      disabled={disabled}
      onChange={(e) => onChange(e.target.value)}
    >
      <option value="">{label}</option>
      {options.map((o) => (
        <option key={o} value={o}>
          {o}
        </option>
      ))}
    </select>
  );
}
