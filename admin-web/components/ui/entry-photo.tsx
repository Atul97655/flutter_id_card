'use client';

import { useEffect, useState } from 'react';
import { ImageOff } from 'lucide-react';
import { fetchEntryPhoto } from '@/lib/data';
import { photoSrc, type StudentEntry } from '@/lib/types';

/**
 * A student's photo.
 *
 * Renders the thumbnail that rides on the entry document immediately, then -
 * only when `full` is asked for - fetches the full-resolution frame from the
 * entry's `media/photo` document and swaps it in. The thumbnail is already
 * loaded, so there is never an empty box while the larger read is in flight.
 *
 * List rows pass `full={false}` (the default): fetching a full photo per row
 * would mean one Firestore read and tens of kilobytes for every name in a
 * table, for a picture rendered at 36 px.
 */
export function EntryPhoto({
  entry,
  full: wantFull = false,
  className = '',
  iconSize = 14,
  alt,
}: {
  entry: StudentEntry;
  full?: boolean;
  className?: string;
  iconSize?: number;
  alt?: string;
}) {
  const thumb = photoSrc(entry);

  // The upgraded frame is stored WITH the entry it belongs to, and the
  // displayed source is derived from that rather than being reset by an
  // effect. Keeping the id alongside is what stops the worst bug this
  // component could have: navigating from one student to the next would
  // otherwise leave the previous student's face on screen until the new fetch
  // resolved, on the very screen where an admin decides whose card is correct.
  const [full, setFull] = useState<{ id: string; uri: string } | null>(null);
  const src = full && full.id === entry.id ? full.uri : thumb;

  useEffect(() => {
    if (!wantFull) return;
    // A Storage URL is already the full frame - nothing to upgrade to.
    if (entry.photoUrl) return;
    if (!entry.photoThumb) return;

    let cancelled = false;
    fetchEntryPhoto(entry.schoolId, entry.id)
      .then((uri) => {
        if (!cancelled && uri) setFull({ id: entry.id, uri });
      })
      // A failed upgrade is not worth surfacing: the thumbnail is still on
      // screen and still recognisably the right student.
      .catch(() => {});

    return () => {
      cancelled = true;
    };
  }, [wantFull, entry.schoolId, entry.id, entry.photoUrl, entry.photoThumb]);

  if (!src) {
    return <ImageOff size={iconSize} aria-hidden />;
  }

  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={src}
      alt={alt ?? ''}
      className={`size-full object-cover ${className}`}
      loading={wantFull ? 'eager' : 'lazy'}
    />
  );
}
