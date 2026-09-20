'use client';

import { useState } from 'react';
import { Database, ExternalLink, Printer, ShieldCheck } from 'lucide-react';
import { Topbar } from '@/components/layout/topbar';
import { Banner, Panel, PanelHeader } from '@/components/ui/primitives';
import { useAuth } from '@/lib/auth-context';
import { useStore } from '@/lib/store';
import { FIREBASE_PROJECT_ID } from '@/lib/firebase';
import { hasPhoto } from '@/lib/types';
import { savePanelConfig } from '@/lib/data';

/**
 * Settings.
 *
 * Deliberately thin. Card configuration belongs to the school it affects, so
 * it lives on the Schools page; this is only what is true of the whole
 * installation.
 */
export default function SettingsPage() {
  const { profile } = useAuth();
  const { schools, entries, users, config } = useStore();
  const [savingPrint, setSavingPrint] = useState(false);
  const [printError, setPrintError] = useState<string | null>(null);

  const noPhoto = entries.filter((e) => !hasPhoto(e)).length;

  return (
    <div className="flex flex-col gap-4">
      <Topbar greeting="Installation" title="Settings" />

      {config.printingEnabled && noPhoto > 0 ? (
        <Banner tone="warn" title={`${noPhoto} submission${noPhoto === 1 ? '' : 's'} without a photo`}>
          {noPhoto} of {entries.length} records have no picture on the server
          yet. Photos travel inside Firestore on this project — Cloud Storage is
          not enabled, and does not need to be — so anything submitted before
          that release is still holding its photo on the capturing phone. Each
          uploads by itself on that phone&apos;s next sync, with no re-entry.
        </Banner>
      ) : null}

      <Panel>
        <PanelHeader title="Card printing" />
        <div className="flex flex-col gap-4 px-5 pb-5 sm:flex-row sm:items-start">
          <span className="grid size-10 shrink-0 place-items-center rounded-xl bg-mint-500/12 text-mint-700">
            <Printer size={18} />
          </span>

          <div className="min-w-0 flex-1">
            <p className="text-[13px] leading-relaxed text-ink-600">
              Whether this office prints the cards itself. Turning it off hides
              the Print Center, the print-readiness tiles and every &ldquo;cannot
              be printed&rdquo; warning — which are otherwise permanent alarms
              about a job nobody is doing.
            </p>
            <p className="mt-2 text-[12.5px] leading-relaxed text-ink-400">
              Nothing is deleted. The A4 and 12&nbsp;×&nbsp;18 sheet pipeline,
              the batch history and every card stay exactly as they are, so
              turning it back on restores the feature untouched.
            </p>

            {printError ? (
              <p className="mt-2 text-[12.5px] font-medium text-[var(--color-status-rejected)]">
                {printError}
              </p>
            ) : null}
          </div>

          <button
            type="button"
            role="switch"
            aria-checked={config.printingEnabled}
            aria-label="Card printing"
            disabled={savingPrint}
            onClick={async () => {
              setSavingPrint(true);
              setPrintError(null);
              try {
                await savePanelConfig({
                  printingEnabled: !config.printingEnabled,
                });
              } catch (e) {
                setPrintError(
                  e instanceof Error ? e.message : 'Could not save that.',
                );
              } finally {
                setSavingPrint(false);
              }
            }}
            className={`relative h-7 w-12 shrink-0 rounded-full transition-colors disabled:opacity-60 ${
              config.printingEnabled ? 'bg-mint-600' : 'bg-ink-400/30'
            }`}
          >
            <span
              className={`absolute top-1 size-5 rounded-full bg-white shadow transition-[left] duration-200 ${
                config.printingEnabled ? 'left-6' : 'left-1'
              }`}
            />
          </button>
        </div>
      </Panel>

      <div className="grid gap-4 lg:grid-cols-2">
        <Panel>
          <PanelHeader title="Firebase project" />
          <dl className="flex flex-col gap-2.5 px-5 pb-5 text-[12.5px]">
            <Row label="Project" value={FIREBASE_PROJECT_ID} mono />
            <Row label="Schools" value={String(schools.length)} />
            <Row label="Accounts" value={String(users.length)} />
            <Row label="Cards" value={String(entries.length)} />
          </dl>
          <div className="px-5 pb-5">
            <a
              href={`https://console.firebase.google.com/project/${FIREBASE_PROJECT_ID}/overview`}
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center gap-1.5 text-[12.5px] font-semibold text-mint-600 transition hover:text-mint-700"
            >
              Open the Firebase console <ExternalLink size={12} />
            </a>
          </div>
        </Panel>

        <Panel index={1}>
          <PanelHeader title="Your account" />
          <dl className="flex flex-col gap-2.5 px-5 pb-5 text-[12.5px]">
            <Row label="Name" value={profile?.displayName || '—'} />
            <Row label="Email" value={profile?.email ?? '—'} />
            <Row label="Role" value={profile?.role ?? '—'} />
            <Row label="Auth UID" value={profile?.uid ?? '—'} mono />
          </dl>
          <div className="px-5 pb-5">
            <p className="text-[11.5px] leading-relaxed text-ink-400">
              Passwords are changed through Firebase Authentication, not here.
            </p>
          </div>
        </Panel>

        <Panel index={2} className="lg:col-span-2">
          <PanelHeader title="How access is enforced" />
          <div className="flex flex-col gap-3 px-5 pb-5">
            <div className="flex items-start gap-2.5">
              <ShieldCheck size={16} className="mt-0.5 shrink-0 text-mint-600" />
              <p className="text-[12.5px] leading-relaxed text-ink-500">
                The role check this panel performs decides what it renders. What
                actually protects the data is the Firestore and Storage rules,
                which run the identical check on the server for every read and
                write. A teacher cannot reach another school&rsquo;s students
                even by calling the API directly.
              </p>
            </div>
            <div className="flex items-start gap-2.5">
              <Database size={16} className="mt-0.5 shrink-0 text-mint-600" />
              <p className="text-[12.5px] leading-relaxed text-ink-500">
                This panel and the mobile app read and write the same documents.
                A change saved here appears on an operator&rsquo;s device on
                their next sync, and a card submitted on a tablet appears here
                immediately.
              </p>
            </div>
          </div>
        </Panel>
      </div>
    </div>
  );
}

function Row({
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
