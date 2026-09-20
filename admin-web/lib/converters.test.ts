import { describe, expect, it } from 'vitest';
import type { DocumentData, QueryDocumentSnapshot } from 'firebase/firestore';
import {
  toChatMessage,
  toManagedUser,
  toPanelConfig,
  toStudentEntry,
} from './converters';
import {
  hasPhoto,
  isOperator,
  isPrintable,
  isReadyToPrint,
  messageHasAttachment,
  messagePreviewSource,
  photoSrc,
  readCount,
  recipientCount,
  type Chat,
  type StudentEntry,
} from './types';

/**
 * The panel's reading layer.
 *
 * This is where a document written by a phone becomes something the office
 * acts on, and it is the only place in the panel where being wrong is
 * dangerous rather than ugly: these functions decide who is an admin, what
 * counts as reviewed, and whether a card may be printed. Everything else here
 * is layout.
 *
 * They are also the one part that can be tested honestly without Firebase -
 * pure functions over plain objects - so they are where the panel's tests
 * start.
 */

/** A Firestore snapshot is an interface, not a class - this is enough of one. */
function snap(id: string, data: DocumentData): QueryDocumentSnapshot<DocumentData> {
  return { id, data: () => data } as QueryDocumentSnapshot<DocumentData>;
}

describe('Reading a student entry', () => {
  it('keeps a leading zero on a roll number', () => {
    // Real registers use "0034" and "12/A". A number type would eat the zero
    // and the card would print the wrong register number.
    const e = toStudentEntry(snap('e1', { rollNumber: '0034' }), 'school-a');
    expect(e.rollNumber).toBe('0034');
  });

  it('falls back to the path when the document forgets its own school', () => {
    const e = toStudentEntry(snap('e1', { name: 'ATUL' }), 'school-a');
    expect(e.schoolId).toBe('school-a');
  });

  it('degrades an unknown approval status to pending, never to approved', () => {
    // The conservative direction: an unrecognised value must land in the
    // review queue, not slip out of it as signed off.
    const e = toStudentEntry(
      snap('e1', { approvalStatus: 'something_new' }),
      'school-a',
    );
    expect(e.approvalStatus).toBe('pending');
  });

  it('survives a document with nothing in it', () => {
    const e = toStudentEntry(snap('e1', {}), 'school-a');
    expect(e.name).toBe('');
    expect(e.approvalStatus).toBe('pending');
    expect(e.photoUrl).toBeNull();
    expect(e.photoThumb).toBeNull();
  });

  it('ignores a field of the wrong type instead of trusting it', () => {
    const e = toStudentEntry(
      snap('e1', { name: 42, photoUrl: { nope: true } }),
      'school-a',
    );
    expect(e.name).toBe('');
    expect(e.photoUrl).toBeNull();
  });
});

describe('Whether a card has a photo', () => {
  const base: StudentEntry = toStudentEntry(snap('e1', {}), 'school-a');

  it('counts a Storage URL', () => {
    expect(hasPhoto({ ...base, photoUrl: 'https://example/p.jpg' })).toBe(true);
  });

  it('counts an inline thumbnail', () => {
    // Storage has never worked on this project, so this is the only case that
    // actually occurs. Checking the URL alone marked every card unprintable.
    expect(hasPhoto({ ...base, photoThumb: 'BASE64' })).toBe(true);
  });

  it('does not count an empty string', () => {
    expect(hasPhoto({ ...base, photoUrl: '', photoThumb: '' })).toBe(false);
  });

  it('prefers the Storage URL for rendering when both exist', () => {
    const src = photoSrc({
      ...base,
      photoUrl: 'https://example/p.jpg',
      photoThumb: 'BASE64',
    });
    expect(src).toBe('https://example/p.jpg');
  });

  it('builds a data URI from the thumbnail otherwise', () => {
    expect(photoSrc({ ...base, photoThumb: 'BASE64' })).toBe(
      'data:image/jpeg;base64,BASE64',
    );
  });

  it('returns null when there is nothing to draw', () => {
    expect(photoSrc(base)).toBeNull();
  });
});

describe('Whether a card may be printed', () => {
  const base: StudentEntry = toStudentEntry(snap('e1', {}), 'school-a');

  it('needs a review decision AND a photo', () => {
    expect(isReadyToPrint({ ...base, approvalStatus: 'approved' })).toBe(false);
    expect(
      isReadyToPrint({ ...base, approvalStatus: 'pending', photoThumb: 'B' }),
    ).toBe(false);
    expect(
      isReadyToPrint({ ...base, approvalStatus: 'approved', photoThumb: 'B' }),
    ).toBe(true);
  });

  it('treats printed as still printable, for reprints', () => {
    // A reprint must not require resetting the review state.
    expect(isPrintable('printed')).toBe(true);
    expect(isPrintable('approved')).toBe(true);
    expect(isPrintable('pending')).toBe(false);
    expect(isPrintable('rejected')).toBe(false);
  });
});

describe('Reading an account', () => {
  it('reads an admin', () => {
    const u = toManagedUser(snap('uid-1', { role: 'Admin', active: true }));
    expect(u.role).toBe('Admin');
    expect(isOperator(u.role)).toBe(false);
  });

  it('degrades an unrecognised role to the lower privilege', () => {
    // The whole point. A future or misspelled role must never be read as
    // Admin - the panel gates its own navigation on this, and the rules gate
    // the data on the same string server side.
    const u = toManagedUser(snap('uid-1', { role: 'Superuser' }));
    expect(u.role).not.toBe('Admin');
    expect(isOperator(u.role)).toBe(true);
  });

  it('degrades a missing role too', () => {
    expect(toManagedUser(snap('uid-1', {})).role).not.toBe('Admin');
  });

  it('reads the wire value case-insensitively, as Dart writes it', () => {
    expect(toManagedUser(snap('uid-1', { role: 'admin' })).role).toBe('Admin');
  });

  it('is active unless the document says otherwise', () => {
    // A deactivated account keeps its credentials and loses access, so the
    // absence of the field must not read as deactivated.
    expect(toManagedUser(snap('uid-1', {})).active).toBe(true);
    expect(toManagedUser(snap('uid-1', { active: false })).active).toBe(false);
  });
});

describe('Reading panel settings', () => {
  it('uses the defaults when the document does not exist', () => {
    // Normal until an admin changes something - it must not blank the panel.
    expect(toPanelConfig(undefined).printingEnabled).toBe(false);
  });

  it('reads an explicit value', () => {
    expect(toPanelConfig({ printingEnabled: true }).printingEnabled).toBe(true);
    expect(toPanelConfig({ printingEnabled: false }).printingEnabled).toBe(false);
  });

  it('ignores a value of the wrong type', () => {
    expect(toPanelConfig({ printingEnabled: 'yes' }).printingEnabled).toBe(false);
  });
});

describe('Reading a message', () => {
  it('reads an inline attachment', () => {
    const m = toChatMessage(
      snap('m1', {
        kind: 'image',
        attachmentInline: true,
        attachmentThumb: 'BASE64',
      }),
      'chat-1',
    );
    expect(messageHasAttachment(m)).toBe(true);
    expect(messagePreviewSource(m)).toBe('data:image/jpeg;base64,BASE64');
  });

  it('still reads a message sent before inline attachments existed', () => {
    const m = toChatMessage(
      snap('m1', { kind: 'image', attachmentUrl: 'https://example/old.jpg' }),
      'chat-1',
    );
    expect(m.attachmentInline).toBe(false);
    expect(messagePreviewSource(m)).toBe('https://example/old.jpg');
  });

  it('has nothing to draw for a plain text message', () => {
    const m = toChatMessage(snap('m1', { body: 'hello' }), 'chat-1');
    expect(messageHasAttachment(m)).toBe(false);
    expect(messagePreviewSource(m)).toBeNull();
  });
});

describe('Broadcast delivery', () => {
  const chat: Chat = {
    id: 'bcast',
    title: 'Announcement',
    kind: 'broadcast',
    schoolId: null,
    members: ['admin-1', 'teacher-1', 'teacher-2'],
    lastMessage: '',
    lastMessageAt: null,
    lastSenderId: null,
    unreadFor: ['teacher-1'],
  };

  it('does not count the sender as a recipient', () => {
    expect(recipientCount(chat, 'admin-1')).toBe(2);
  });

  it('counts a read as a recipient who is no longer unread', () => {
    // The only honest measure: the write is one atomic batch, so there is no
    // per-recipient send failure to report.
    expect(readCount(chat, 'admin-1')).toBe(1);
  });

  it('reports zero recipients rather than a negative count', () => {
    expect(recipientCount({ ...chat, members: ['admin-1'] }, 'admin-1')).toBe(0);
  });
});
