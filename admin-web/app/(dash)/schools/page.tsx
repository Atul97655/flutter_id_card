'use client';

import { useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import { Building2, Check, Palette, Plus, Save, X } from 'lucide-react';
import { Topbar } from '@/components/layout/topbar';
import {
  Banner,
  Button,
  EmptyState,
  Field,
  MOTION,
  Panel,
  PanelHeader,
  Skeleton,
  inputClass,
  staggerDelay,
} from '@/components/ui/primitives';
import { useStore } from '@/lib/store';
import { createSchool, saveSchool } from '@/lib/data';
import { toCssColor } from '@/lib/converters';
import {
  CARD_SIZES,
  STUDENT_FIELDS,
  TEMPLATES,
  type SchoolConfig,
} from '@/lib/types';

/**
 * Schools and their card configuration.
 *
 * Everything on this page changes what gets PRINTED, so each control says what
 * it affects. Switching a field off does not delete data - it stops that row
 * appearing on the card and stops the form asking for it.
 */
export default function SchoolsPage() {
  const { schools, entries, loading } = useStore();
  const [openId, setOpenId] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const counts = useMemo(() => {
    const m = new Map<string, number>();
    for (const e of entries) m.set(e.schoolId, (m.get(e.schoolId) ?? 0) + 1);
    return m;
  }, [entries]);

  return (
    <div className="flex flex-col gap-4">
      <Topbar greeting="Configuration" title="Schools" />

      {error ? <Banner tone="error" title="Could not save">{error}</Banner> : null}

      <div className="flex justify-end">
        <Button icon={Plus} onClick={() => setCreating((v) => !v)}>
          {creating ? 'Cancel' : 'Add a school'}
        </Button>
      </div>

      {creating ? (
        <NewSchool
          onDone={() => setCreating(false)}
          onError={setError}
        />
      ) : null}

      {loading ? (
        <Panel>
          <div className="flex flex-col gap-2 p-5">
            <Skeleton className="h-16" />
            <Skeleton className="h-16" />
          </div>
        </Panel>
      ) : schools.length === 0 ? (
        <Panel>
          <EmptyState
            icon={Building2}
            title="No schools yet"
            body="A school holds its card design, its class and division lists, and the students submitted for it."
          />
        </Panel>
      ) : (
        <div className="flex flex-col gap-3">
          {schools.map((s, i) => (
            <SchoolCard
              key={s.id}
              school={s}
              cards={counts.get(s.id) ?? 0}
              open={openId === s.id}
              onToggle={() => setOpenId(openId === s.id ? null : s.id)}
              onError={setError}
              index={i}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function NewSchool({
  onDone,
  onError,
}: {
  onDone: () => void;
  onError: (e: string) => void;
}) {
  const [id, setId] = useState('');
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);

  const create = async () => {
    setBusy(true);
    try {
      await createSchool(id.trim().toLowerCase(), {
        name: name.trim().toUpperCase(),
        addressLine: '',
        contactLine: '',
        logoUrl: null,
        principalSignatureUrl: null,
        cardSizeId: 'v54x86',
        templateId: 'default_vertical',
        // Everything on by default; the admin switches off what this school
        // does not print, which is the safer direction.
        enabledFields: STUDENT_FIELDS.map((f) => String(f.key)),
        classes: ['NURSERY', 'LKG', 'UKG', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10'],
        divisions: ['A', 'B', 'C', 'D'],
        primaryColor: '#D32F2F',
        secondaryColor: '#1565C0',
        headerColor: '#1565C0',
        photoBackground: '#FFFFFF',
        divisionColors: {},
      });
      onDone();
    } catch (e) {
      onError((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  const valid = /^[a-z0-9-]{3,}$/.test(id.trim().toLowerCase()) && name.trim().length > 1;

  return (
    <Panel>
      <PanelHeader title="New school" />
      <div className="grid gap-3 px-5 pb-5 sm:grid-cols-2">
        <Field
          label="School code"
          hint="Lowercase letters, numbers and dashes. Operators type this to sign in, and it cannot be changed later."
        >
          <input
            value={id}
            onChange={(e) => setId(e.target.value)}
            placeholder="st-john-hubli"
            className={inputClass}
          />
        </Field>
        <Field label="School name" hint="Printed on the card, so it is stored in capitals.">
          <input
            value={name}
            onChange={(e) => setName(e.target.value.toUpperCase())}
            placeholder="ST JOHN SAMARITAN SCHOOL"
            className={inputClass}
          />
        </Field>
        <div className="sm:col-span-2">
          <Button icon={Plus} busy={busy} disabled={!valid} onClick={() => void create()}>
            Create school
          </Button>
        </div>
      </div>
    </Panel>
  );
}

function SchoolCard({
  school,
  cards,
  open,
  onToggle,
  onError,
  index,
}: {
  school: SchoolConfig;
  cards: number;
  open: boolean;
  onToggle: () => void;
  onError: (e: string) => void;
  index: number;
}) {
  const [draft, setDraft] = useState<Partial<SchoolConfig>>({});
  const [busy, setBusy] = useState(false);
  const [saved, setSaved] = useState(false);

  const v = <K extends keyof SchoolConfig>(k: K): SchoolConfig[K] =>
    (draft[k] ?? school[k]) as SchoolConfig[K];

  const dirty = Object.keys(draft).length > 0;

  const save = async () => {
    setBusy(true);
    setSaved(false);
    try {
      await saveSchool(school.id, draft);
      setDraft({});
      setSaved(true);
      setTimeout(() => setSaved(false), 2500);
    } catch (e) {
      onError((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  const enabled = new Set(v('enabledFields'));

  const toggleField = (key: string) => {
    const next = new Set(enabled);
    if (next.has(key)) next.delete(key);
    else next.add(key);
    setDraft((d) => ({ ...d, enabledFields: [...next].sort() }));
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{
        duration: MOTION.normal,
        ease: MOTION.ease,
        delay: staggerDelay(index),
      }}
      className="glass overflow-hidden rounded-[var(--radius-panel)]"
    >
      <button
        type="button"
        onClick={onToggle}
        className="flex w-full items-center gap-3 px-5 py-4 text-left transition hover:bg-white/40"
      >
        <span
          className="grid size-10 shrink-0 place-items-center rounded-xl text-white"
          style={{ background: toCssColor(school.headerColor) }}
        >
          <Building2 size={17} />
        </span>

        <span className="min-w-0 flex-1">
          <span className="block truncate text-[14px] font-semibold text-ink-700">
            {school.name}
          </span>
          <span className="block truncate text-[11.5px] text-ink-400">
            {school.id} · {cards} card{cards === 1 ? '' : 's'} ·{' '}
            {CARD_SIZES.find((c) => c.id === school.cardSizeId)?.label ??
              school.cardSizeId}
          </span>
        </span>

        <span className="shrink-0 text-[12px] font-semibold text-mint-600">
          {open ? 'Close' : 'Configure'}
        </span>
      </button>

      {open ? (
        <motion.div
          initial={{ height: 0, opacity: 0 }}
          animate={{ height: 'auto', opacity: 1 }}
          transition={{ duration: MOTION.normal, ease: MOTION.ease }}
          className="overflow-hidden border-t border-ink-400/10"
        >
          <div className="grid gap-4 px-5 py-4 lg:grid-cols-2">
            <Field label="School name" hint="Printed in the card header.">
              <input
                value={v('name')}
                onChange={(e) =>
                  setDraft((d) => ({ ...d, name: e.target.value.toUpperCase() }))
                }
                className={inputClass}
              />
            </Field>

            <Field label="Address line" hint="Printed under the school name.">
              <input
                value={v('addressLine')}
                onChange={(e) =>
                  setDraft((d) => ({ ...d, addressLine: e.target.value.toUpperCase() }))
                }
                className={inputClass}
              />
            </Field>

            <Field label="Contact line">
              <input
                value={v('contactLine')}
                onChange={(e) => setDraft((d) => ({ ...d, contactLine: e.target.value }))}
                className={inputClass}
              />
            </Field>

            <Field
              label="Card size"
              hint="The finished trim size. Changing it re-flows every card."
            >
              <select
                value={v('cardSizeId')}
                onChange={(e) => setDraft((d) => ({ ...d, cardSizeId: e.target.value }))}
                className={inputClass}
              >
                {CARD_SIZES.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.label}
                  </option>
                ))}
              </select>
            </Field>

            <Field label="Template" hint="The layout the card is drawn with.">
              <select
                value={v('templateId')}
                onChange={(e) => setDraft((d) => ({ ...d, templateId: e.target.value }))}
                className={inputClass}
              >
                {TEMPLATES.map((t) => (
                  <option key={t.id} value={t.id}>
                    {t.label}
                  </option>
                ))}
              </select>
            </Field>

            <Field
              label="Classes"
              hint="Comma separated. These become the dropdown on the operator's form."
            >
              <input
                value={v('classes').join(', ')}
                onChange={(e) =>
                  setDraft((d) => ({
                    ...d,
                    classes: e.target.value
                      .split(',')
                      .map((s) => s.trim().toUpperCase())
                      .filter(Boolean),
                  }))
                }
                className={inputClass}
              />
            </Field>

            <Field label="Divisions" hint="Comma separated.">
              <input
                value={v('divisions').join(', ')}
                onChange={(e) =>
                  setDraft((d) => ({
                    ...d,
                    divisions: e.target.value
                      .split(',')
                      .map((s) => s.trim().toUpperCase())
                      .filter(Boolean),
                  }))
                }
                className={inputClass}
              />
            </Field>

            {/* Colours */}
            <div className="lg:col-span-2">
              <p className="mb-2 flex items-center gap-1.5 text-[12.5px] font-semibold text-ink-600">
                <Palette size={14} /> Card colours
              </p>
              <div className="flex flex-wrap gap-4">
                {(
                  [
                    ['headerColor', 'Header band'],
                    ['primaryColor', 'Primary text'],
                    ['secondaryColor', 'Secondary text'],
                    ['photoBackground', 'Photo backdrop'],
                  ] as [keyof SchoolConfig, string][]
                ).map(([k, label]) => (
                  <label key={String(k)} className="flex items-center gap-2">
                    <input
                      type="color"
                      value={toCssColor(String(v(k)))}
                      onChange={(e) =>
                        setDraft((d) => ({ ...d, [k]: e.target.value.toUpperCase() }))
                      }
                      className="size-8 cursor-pointer rounded-lg border border-ink-400/20 bg-transparent"
                    />
                    <span className="text-[12px] text-ink-500">{label}</span>
                  </label>
                ))}
              </div>
            </div>

            {/* Printed fields */}
            <div className="lg:col-span-2">
              <p className="mb-2 text-[12.5px] font-semibold text-ink-600">
                Fields this school prints
              </p>
              <div className="flex flex-wrap gap-1.5">
                {STUDENT_FIELDS.map((f) => {
                  const key = String(f.key);
                  const on = f.locked || enabled.has(key);
                  return (
                    <button
                      key={key}
                      type="button"
                      disabled={f.locked}
                      onClick={() => toggleField(key)}
                      title={
                        f.locked
                          ? 'A card without this is not an ID card'
                          : undefined
                      }
                      className={`flex items-center gap-1.5 rounded-lg border px-2.5 py-1 text-[12px] font-medium transition ${
                        on
                          ? 'border-mint-500/45 bg-mint-500/13 text-mint-700'
                          : 'border-ink-400/20 bg-white/70 text-ink-400 hover:bg-white'
                      } ${f.locked ? 'cursor-default opacity-80' : ''}`}
                    >
                      {on ? <Check size={11} /> : <X size={11} />}
                      {f.label}
                    </button>
                  );
                })}
              </div>
              <p className="mt-2 text-[11.5px] leading-relaxed text-ink-400">
                Switching a field off stops it printing and stops the form asking
                for it. Existing data is kept. Too many fields on a small card
                force the renderer to shrink every row to fit.
              </p>
            </div>

            <div className="flex items-center gap-3 lg:col-span-2">
              <Button icon={Save} busy={busy} disabled={!dirty} onClick={() => void save()}>
                Save changes
              </Button>
              {saved ? (
                <motion.span
                  initial={{ opacity: 0, x: -6 }}
                  animate={{ opacity: 1, x: 0 }}
                  className="text-[12.5px] font-semibold text-[var(--color-status-approved)]"
                >
                  Saved — operators pick this up on their next sync.
                </motion.span>
              ) : null}
            </div>
          </div>
        </motion.div>
      ) : null}
    </motion.div>
  );
}
