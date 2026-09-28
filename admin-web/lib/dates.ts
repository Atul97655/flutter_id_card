import { format, isValid } from 'date-fns';

/**
 * Every date the panel prints.
 *
 * These exist because `toLocaleDateString(undefined, …)` is not safe in this
 * app. Next server-renders client components on first load, so a date is
 * formatted twice - once in Node and once in the browser - and `undefined`
 * means "use whatever locale you are". Node and Chrome disagree: one writes
 * "Sep 28, 02:22 PM", the other "28 Sept, 02:22 pm". React sees the mismatch,
 * throws away the server tree and re-renders the whole branch.
 *
 * That is not only a console warning. The discarded branch takes its
 * already-started entrance animations with it, and the replacement mounts
 * with `opacity: 0` and nothing left to animate it - which is how a page full
 * of data renders as a blank panel. It was found exactly that way.
 *
 * So: one fixed format, same string on both sides, no locale lookup. English
 * month abbreviations are what this office already reads on its own cards.
 */

/** Anything the panel stores a date as. */
type DateLike = Date | string | number | null | undefined;

function toDate(value: DateLike): Date | null {
  if (value == null) return null;
  const d = value instanceof Date ? value : new Date(value);
  return isValid(d) ? d : null;
}

/** `28 Sep 2026` */
export function formatDate(value: DateLike, fallback = '—'): string {
  const d = toDate(value);
  return d ? format(d, 'd MMM yyyy') : fallback;
}

/** `28 Sep, 02:22 PM` - a date close enough to now that the year is noise. */
export function formatDateTime(value: DateLike, fallback = '—'): string {
  const d = toDate(value);
  return d ? format(d, 'd MMM, hh:mm a') : fallback;
}

/** `28 Sep 2026, 02:22 PM` - for a record being read on its own. */
export function formatFull(value: DateLike, fallback = '—'): string {
  const d = toDate(value);
  return d ? format(d, 'd MMM yyyy, hh:mm a') : fallback;
}

/** `02:22 PM` - beside a message, where the day is the group heading. */
export function formatTime(value: DateLike, fallback = ''): string {
  const d = toDate(value);
  return d ? format(d, 'hh:mm a') : fallback;
}

/** `Sep 2026` */
export function formatMonth(value: DateLike, fallback = '—'): string {
  const d = toDate(value);
  return d ? format(d, 'MMM yyyy') : fallback;
}
