'use client';

import { useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import { Layers } from 'lucide-react';
import { Topbar } from '@/components/layout/topbar';
import { useStore } from '@/lib/store';
import {
  isScoped,
  type ManagedUser,
  type SchoolConfig,
  type StudentEntry,
} from '@/lib/types';
import {
  Banner,
  EmptyState,
  MOTION,
  Panel,
  inputClass,
  staggerDelay,
} from '@/components/ui/primitives';

/**
 * Classes and sections, with the teacher covering each (A11).
 *
 * The page exists for one question: which sections have nobody on them. A
 * section with no teacher is not a configuration detail, it is a class whose
 * ID cards are not being captured by anyone, and nothing else in the panel
 * makes that visible - the request queue only shows work that HAS arrived.
 */
export default function ClassesPage() {
  const { schools, users, entries, loading } = useStore();
  const [schoolId, setSchoolId] = useState<string>('');

  const school: SchoolConfig | undefined =
    schools.find((s) => s.id === schoolId) ?? schools[0];

  const rows = useMemo(
    () => (school ? buildRows(school, users, entries) : []),
    [school, users, entries],
  );

  const unstaffed = rows.reduce(
    (n, r) => n + r.sections.filter((s) => s.teachers.length === 0).length,
    0,
  );

  return (
    <div className="flex flex-col gap-4">
      {/* Carries the nav drawer - see the note in pending-joins. */}
      <Topbar greeting="Configuration" title="Classes & Sections" />

      <div className="flex flex-col gap-3 px-1 sm:flex-row sm:items-end sm:justify-between">
        <p className="text-[13px] text-ink-400">
          {school ? school.name : 'No schools yet'}
        </p>

        {schools.length > 1 ? (
          <select
            aria-label="School"
            className={`${inputClass} sm:w-64`}
            value={school?.id ?? ''}
            onChange={(e) => setSchoolId(e.target.value)}
          >
            {schools.map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </select>
        ) : null}
      </div>

      <Banner tone="info" title="How a student is filed">
        A student belongs to School → Class → Section. A teacher is assigned one
        section and sees only that.
      </Banner>

      {unstaffed > 0 ? (
        <Banner
          tone="warn"
          title={`${unstaffed} ${unstaffed === 1 ? 'section has' : 'sections have'} no teacher`}
        >
          Nobody is capturing ID cards for {unstaffed === 1 ? 'it' : 'them'}.
          Assign a teacher from Pending Joins or Teachers &amp; Schools.
        </Banner>
      ) : null}

      {loading && rows.length === 0 ? (
        <Panel>
          <div className="p-5 text-[13px] text-ink-400">Loading…</div>
        </Panel>
      ) : rows.length === 0 ? (
        <Panel>
          <EmptyState
            icon={Layers}
            title="No classes configured"
            body="Add classes and sections to this school in its settings, and they will appear here with the teacher covering each one."
          />
        </Panel>
      ) : (
        <div className="flex flex-col gap-3">
          {rows.map((row, i) => (
            <motion.div
              key={row.classLevel}
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{
                duration: MOTION.normal,
                ease: MOTION.ease,
                delay: staggerDelay(i),
              }}
            >
              <Panel>
                <div className="flex items-center justify-between gap-3 border-b border-black/5 px-5 py-3">
                  <span className="rounded-lg bg-mint-600/12 px-2.5 py-1 text-[12.5px] font-semibold text-mint-700">
                    Class {row.classLevel}
                  </span>
                  <span className="text-[12px] text-ink-400">
                    {row.sections.length}{' '}
                    {row.sections.length === 1 ? 'section' : 'sections'}
                  </span>
                </div>

                <ul className="divide-y divide-black/5">
                  {/*
                    Each row stacks on a phone. As one flex line, the name
                    column was squeezed between the chip and the count until
                    "No teacher assigned" truncated to "No te..." - the single
                    most important fact on this page being the one thing cut.
                  */}
                  {row.sections.map((s) => (
                    <li
                      key={s.division}
                      className="flex flex-col gap-1.5 px-5 py-3 sm:flex-row sm:flex-wrap sm:items-center sm:gap-x-4 sm:gap-y-1"
                    >
                      <span className="flex min-w-0 items-center gap-3 sm:flex-1">
                        <span className="grid size-7 shrink-0 place-items-center rounded-lg bg-mint-600/10 text-[12.5px] font-semibold text-mint-700">
                          {s.division}
                        </span>

                        <span className="min-w-0 flex-1 truncate text-[13.5px]">
                          {s.teachers.length === 0 ? (
                            <span className="font-semibold text-[#e65100]">
                              No teacher assigned
                            </span>
                          ) : (
                            <span className="text-ink-700">
                              {s.teachers
                                .map((t) => t.displayName || t.email)
                                .join(', ')}
                            </span>
                          )}
                        </span>
                      </span>

                      <span className="flex shrink-0 items-center gap-3 pl-10 sm:pl-0">
                        {s.teachers.length === 0 ? (
                          <span className="shrink-0 rounded-md bg-[rgb(245_124_0/0.12)] px-2 py-0.5 text-[11.5px] font-semibold text-[#e65100]">
                            Needs teacher
                          </span>
                        ) : null}

                        <span className="shrink-0 text-[12px] text-ink-400">
                          {s.cards} {s.cards === 1 ? 'card' : 'cards'} submitted
                        </span>
                      </span>
                    </li>
                  ))}
                </ul>
              </Panel>
            </motion.div>
          ))}
        </div>
      )}
    </div>
  );
}

interface SectionRow {
  division: string;
  teachers: ManagedUser[];
  cards: number;
}

interface ClassRow {
  classLevel: string;
  sections: SectionRow[];
}

/**
 * Folds schools, users and entries into one class-by-section view.
 *
 * Sections come from the union of what the school has configured and what
 * cards have actually been filed under, not from the configuration alone. A
 * section that exists in the data but not in the settings is exactly the kind
 * of thing this page should surface rather than hide - it usually means
 * somebody typed a section by hand before it was set up.
 */
function buildRows(
  school: SchoolConfig,
  users: ManagedUser[],
  entries: StudentEntry[],
): ClassRow[] {
  const mine = entries.filter((e) => e.schoolId === school.id);
  const staff = users.filter((u) => u.schoolId === school.id && isScoped(u));

  const classes = new Set<string>(school.classes);
  for (const e of mine) if (e.studentClass) classes.add(e.studentClass);
  for (const u of staff) if (u.assignment) classes.add(u.assignment.classLevel);

  const sorted = [...classes].sort(byClassOrder);

  return sorted.map((classLevel) => {
    const divisions = new Set<string>(school.divisions);
    for (const e of mine) {
      if (e.studentClass === classLevel && e.division) divisions.add(e.division);
    }
    for (const u of staff) {
      if (u.assignment?.classLevel === classLevel) divisions.add(u.assignment.division);
    }

    return {
      classLevel,
      sections: [...divisions].sort().map((division) => ({
        division,
        teachers: staff.filter(
          (u) =>
            u.assignment?.classLevel === classLevel &&
            u.assignment?.division === division,
        ),
        cards: mine.filter(
          (e) => e.studentClass === classLevel && e.division === division,
        ).length,
      })),
    };
  });
}

/**
 * Orders class names the way a school says them.
 *
 * Plain string sort puts 10 before 2, and puts NURSERY between them. Numbers
 * sort numerically and descending, so Class 10 is at the top where the
 * office's attention usually is; anything non-numeric (NURSERY, LKG, UKG)
 * keeps its configured order below.
 */
function byClassOrder(a: string, b: string): number {
  const na = Number.parseInt(a, 10);
  const nb = Number.parseInt(b, 10);
  const aNum = !Number.isNaN(na);
  const bNum = !Number.isNaN(nb);
  if (aNum && bNum) return nb - na;
  if (aNum) return -1;
  if (bNum) return 1;
  return a.localeCompare(b);
}
