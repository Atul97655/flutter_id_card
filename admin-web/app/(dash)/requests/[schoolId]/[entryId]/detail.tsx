'use client';

import { useMemo, useState } from 'react';
import Link from 'next/link';
import { motion } from 'framer-motion';
import {
  ArrowLeft,
  CheckCircle2,
  ImageOff,
  MessageSquare,
  Save,
  SearchX,
  XCircle,
} from 'lucide-react';
import {
  Banner,
  Button,
  EmptyState,
  Field,
  MOTION,
  Panel,
  PanelHeader,
  StatusChip,
  inputClass,
  staggerDelay,
} from '@/components/ui/primitives';
import { useAuth } from '@/lib/auth-context';
import { useSchoolName, useStore } from '@/lib/store';
import { reviewEntry, updateEntry } from '@/lib/data';
import { isPrintable, type StudentEntry } from '@/lib/types';

/** Fields the office can correct before approving. */
const EDITABLE: { key: keyof StudentEntry; label: string; upper?: boolean }[] = [
  { key: 'name', label: 'Name', upper: true },
  { key: 'fatherName', label: "Father's Name", upper: true },
  { key: 'studentClass', label: 'Class', upper: true },
  { key: 'division', label: 'Div', upper: true },
  { key: 'rollNumber', label: 'Roll No', upper: true },
  { key: 'bloodGroup', label: 'Blood Group' },
  { key: 'dob', label: 'DOB (yyyy-mm-dd)' },
  { key: 'mobile', label: 'Mobile No' },
  { key: 'address', label: 'Address', upper: true },
];

export function RequestDetail({
  schoolId,
  entryId,
}: {
  schoolId: string;
  entryId: string;
}) {
  const { profile } = useAuth();
  const { entries, loading } = useStore();
  const schoolName = useSchoolName();

  const entry = useMemo(
    () => entries.find((e) => e.id === entryId && e.schoolId === schoolId) ?? null,
    [entries, entryId, schoolId],
  );

  const [draft, setDraft] = useState<Partial<StudentEntry>>({});
  const [busy, setBusy] = useState(false);
  const [rejecting, setRejecting] = useState(false);
  const [reason, setReason] = useState('');
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  if (loading && !entry) {
    return <p className="px-1 py-10 text-[13px] text-ink-500">Loading…</p>;
  }

  if (!entry) {
    return (
      <Panel>
        <EmptyState
          icon={SearchX}
          title="Submission not found"
          body="It may have been deleted, or the link points at a school this card does not belong to."
          action={
            <Link href="/requests">
              <Button size="sm" variant="outline">
                Back to the queue
              </Button>
            </Link>
          }
        />
      </Panel>
    );
  }

  const value = (k: keyof StudentEntry): string => {
    const v = draft[k] ?? entry[k];
    return typeof v === 'string' ? v : '';
  };

  const dirty = Object.keys(draft).length > 0;
  const blocked = isPrintable(entry.approvalStatus) && !entry.photoUrl;

  const save = async () => {
    setBusy(true);
    setError(null);
    try {
      await updateEntry(schoolId, entryId, draft);
      setDraft({});
      setNotice('Changes saved.');
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  const decide = async (decision: 'approved' | 'rejected') => {
    if (!profile) return;
    setBusy(true);
    setError(null);
    try {
      // Save pending corrections first, so an approval never signs off on
      // text the reviewer has edited but not committed.
      if (dirty) {
        await updateEntry(schoolId, entryId, draft);
        setDraft({});
      }
      await reviewEntry(
        schoolId,
        entryId,
        decision,
        profile.uid,
        decision === 'rejected' ? reason : undefined,
      );
      setNotice(decision === 'approved' ? 'Card approved.' : 'Card sent back.');
      setRejecting(false);
      setReason('');
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center gap-3 pb-1">
        <Link
          href="/requests"
          className="glass grid size-9 place-items-center rounded-full text-ink-600 transition hover:text-ink-900"
          aria-label="Back to the queue"
        >
          <ArrowLeft size={16} />
        </Link>
        <div className="min-w-0">
          <p className="text-[12.5px] font-medium text-mint-600">
            {schoolName(schoolId)}
          </p>
          <h1 className="truncate text-[26px] font-bold leading-tight tracking-tight text-ink-900">
            {entry.name || 'UNNAMED'}
          </h1>
        </div>
        <div className="ml-auto">
          <StatusChip status={entry.approvalStatus} />
        </div>
      </div>

      {notice ? <Banner tone="success" title={notice} /> : null}
      {error ? <Banner tone="error" title="Could not save" >{error}</Banner> : null}

      {entry.rejectionReason ? (
        <Banner tone="error" title="This card was sent back">
          {entry.rejectionReason}
        </Banner>
      ) : null}

      {blocked ? (
        <Banner tone="warn" title="Approved, but it cannot be printed">
          No photo reached the server for this student, so there is nothing to
          place on a sheet. The details are safe — the photo uploads by itself
          once Cloud Storage is enabled on the Firebase project.
        </Banner>
      ) : null}

      <div className="grid gap-4 lg:grid-cols-[minmax(0,320px)_minmax(0,1fr)]">
        {/* Photo + meta */}
        <div className="flex flex-col gap-4">
          <Panel className="overflow-hidden">
            <PanelHeader title="Photo" />
            <div className="px-5 pb-5">
              <div
                className="mx-auto grid w-full max-w-[220px] place-items-center overflow-hidden rounded-[var(--radius-card)] bg-ink-400/8"
                style={{ aspectRatio: '1.2 / 1.5' }}
              >
                {entry.photoUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={entry.photoUrl}
                    alt={`Photo of ${entry.name}`}
                    className="size-full object-cover"
                  />
                ) : (
                  <div className="flex flex-col items-center gap-2 px-4 text-center">
                    <ImageOff size={26} className="text-ink-400/70" />
                    <p className="text-[12px] leading-snug text-ink-400">
                      No photo on the server
                    </p>
                  </div>
                )}
              </div>
              <p className="mt-3 text-center text-[11.5px] text-ink-400">
                Prints at 1.2 × 1.5 in
              </p>
            </div>
          </Panel>

          <Panel index={1}>
            <PanelHeader title="Record" />
            <dl className="flex flex-col gap-2 px-5 pb-5 text-[12.5px]">
              <Meta label="Request ID" value={entry.id.replace(/-/g, '').slice(0, 6).toUpperCase()} mono />
              <Meta
                label="Submitted"
                value={
                  entry.createdAt
                    ? new Date(entry.createdAt).toLocaleString()
                    : 'Unknown'
                }
              />
              {entry.reviewedAt ? (
                <Meta
                  label="Reviewed"
                  value={new Date(entry.reviewedAt).toLocaleString()}
                />
              ) : null}
              {entry.reviewedBy ? (
                <Meta label="Reviewed by" value={entry.reviewedBy} mono />
              ) : null}
            </dl>
          </Panel>
        </div>

        {/* Details + actions */}
        <div className="flex flex-col gap-4">
          <Panel index={1}>
            <PanelHeader
              title="Student details"
              action={
                dirty ? (
                  <Button size="sm" icon={Save} busy={busy} onClick={() => void save()}>
                    Save changes
                  </Button>
                ) : (
                  <span className="text-[11.5px] text-ink-400">
                    Correct anything before approving
                  </span>
                )
              }
            />

            <div className="grid gap-3 px-5 pb-5 sm:grid-cols-2">
              {EDITABLE.map((f, i) => (
                <motion.div
                  key={f.key}
                  initial={{ opacity: 0, y: 6 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{
                    duration: MOTION.normal,
                    ease: MOTION.ease,
                    delay: staggerDelay(i),
                  }}
                  className={f.key === 'address' ? 'sm:col-span-2' : undefined}
                >
                  <Field label={f.label}>
                    <input
                      value={value(f.key)}
                      onChange={(e) =>
                        setDraft((d) => ({
                          ...d,
                          [f.key]: f.upper
                            ? e.target.value.toUpperCase()
                            : e.target.value,
                        }))
                      }
                      className={inputClass}
                    />
                  </Field>
                </motion.div>
              ))}
            </div>
          </Panel>

          <Panel index={2}>
            <PanelHeader title="Decision" />
            <div className="px-5 pb-5">
              {entry.approvalStatus === 'printed' ? (
                <p className="text-[13px] leading-relaxed text-ink-500">
                  This card has already been through a print run. It can be
                  reprinted from the Print Center, but its review is settled.
                </p>
              ) : (
                <>
                  <div className="flex flex-wrap gap-2">
                    <Button
                      variant="success"
                      icon={CheckCircle2}
                      busy={busy && !rejecting}
                      disabled={entry.approvalStatus === 'approved'}
                      onClick={() => void decide('approved')}
                    >
                      {entry.approvalStatus === 'approved'
                        ? 'Already approved'
                        : 'Approve'}
                    </Button>
                    <Button
                      variant="danger"
                      icon={XCircle}
                      onClick={() => setRejecting((v) => !v)}
                    >
                      Send back
                    </Button>
                    <Link href="/messages" className="ml-auto">
                      <Button variant="ghost" icon={MessageSquare}>
                        Message the school
                      </Button>
                    </Link>
                  </div>

                  {rejecting ? (
                    <motion.div
                      initial={{ opacity: 0, height: 0 }}
                      animate={{ opacity: 1, height: 'auto' }}
                      transition={{ duration: MOTION.normal, ease: MOTION.ease }}
                      className="overflow-hidden"
                    >
                      <div className="pt-4">
                        <Field
                          label="Why is it being sent back?"
                          hint="The operator sees this exact text on their phone, so name the specific problem."
                        >
                          <textarea
                            value={reason}
                            onChange={(e) => setReason(e.target.value)}
                            rows={2}
                            placeholder="Photo is too dark — retake it in better light."
                            className={`${inputClass} resize-y`}
                          />
                        </Field>
                        <Button
                          variant="danger"
                          busy={busy}
                          disabled={!reason.trim()}
                          onClick={() => void decide('rejected')}
                          className="mt-2.5"
                        >
                          Send back to the school
                        </Button>
                      </div>
                    </motion.div>
                  ) : null}
                </>
              )}
            </div>
          </Panel>
        </div>
      </div>
    </div>
  );
}

function Meta({
  label,
  value,
  mono = false,
}: {
  label: string;
  value: string;
  mono?: boolean;
}) {
  return (
    <div className="flex items-baseline justify-between gap-3">
      <dt className="shrink-0 text-ink-400">{label}</dt>
      <dd
        className={`min-w-0 truncate text-right font-medium text-ink-600 ${
          mono ? 'font-mono text-[11.5px]' : ''
        }`}
      >
        {value}
      </dd>
    </div>
  );
}
