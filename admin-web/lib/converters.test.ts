import { describe, expect, it } from 'vitest';
import type { DocumentData, QueryDocumentSnapshot } from 'firebase/firestore';
import {
  toChatMessage,
  toJoinCode,
  toJoinRequest,
  toManagedUser,
  toPanelConfig,
  toStudentEntry,
} from './converters';
import { generateJoinToken } from './joins';
import {
  hasPhoto,
  isOperator,
  isScoped,
  sectionLabel,
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

/**
 * Section assignments and QR joins.
 *
 * The reading side of the boundary added in the screen spec. The dangerous
 * direction here is not what these let through - the rules decide that - but
 * what they read as "scoped" when it is not, because a teacher wrongly shown
 * as scoped is a teacher the office believes is covered when nobody is.
 */
describe('teacher assignments', () => {
  it('reads a complete assignment', () => {
    const u = toManagedUser(
      snap('u1', {
        role: 'Teacher',
        schoolId: 'sjs',
        assignment: {
          schoolId: 'sjs',
          classLevel: '10',
          division: 'A',
          status: 'active',
        },
      }),
    );

    expect(u.assignment).toEqual({
      schoolId: 'sjs',
      classLevel: '10',
      division: 'A',
      status: 'active',
    });
    expect(isScoped(u)).toBe(true);
  });

  // The failure direction that matters: unreadable means unscoped, which
  // means the whole school - the access the teacher already had. Reading it
  // the other way would look like data loss to them.
  it('a missing assignment is unscoped, not locked out', () => {
    const u = toManagedUser(snap('u1', { role: 'Teacher', schoolId: 'sjs' }));

    expect(u.assignment).toBeNull();
    expect(isScoped(u)).toBe(false);
  });

  it('a garbage assignment is unscoped', () => {
    for (const bad of [42, 'ten-a', [], null, {}]) {
      const u = toManagedUser(
        snap('u1', { role: 'Teacher', schoolId: 'sjs', assignment: bad }),
      );
      expect(isScoped(u)).toBe(false);
    }
  });

  it('an assignment with no class is not a scope', () => {
    const u = toManagedUser(
      snap('u1', {
        role: 'Teacher',
        assignment: { schoolId: 'sjs', division: 'A', status: 'active' },
      }),
    );

    expect(u.assignment).not.toBeNull();
    expect(isScoped(u)).toBe(false);
  });

  it('a pending assignment is not a scope', () => {
    const u = toManagedUser(
      snap('u1', {
        role: 'Teacher',
        assignment: {
          schoolId: 'sjs',
          classLevel: '10',
          division: 'A',
          status: 'pending',
        },
      }),
    );

    expect(isScoped(u)).toBe(false);
  });

  // An unknown status must never read as approved.
  it('an unrecognised status falls back to pending', () => {
    const u = toManagedUser(
      snap('u1', {
        role: 'Teacher',
        assignment: {
          schoolId: 'sjs',
          classLevel: '10',
          division: 'A',
          status: 'super-active',
        },
      }),
    );

    expect(u.assignment?.status).toBe('pending');
    expect(isScoped(u)).toBe(false);
  });

  it('labels a section the way the UI says it', () => {
    expect(
      sectionLabel({
        schoolId: 'sjs',
        classLevel: '10',
        division: 'A',
        status: 'active',
      }),
    ).toBe('10 - A');
  });

  it('labels an absent assignment without pretending', () => {
    expect(sectionLabel(null)).toBe('—');
    expect(
      sectionLabel({
        schoolId: 'sjs',
        classLevel: '',
        division: '',
        status: 'active',
      }),
    ).toBe('—');
  });
});

describe('join requests', () => {
  it('reads a pending request', () => {
    const r = toJoinRequest(
      snap('uid-ramesh', {
        uid: 'uid-ramesh',
        schoolId: 'sjs',
        displayName: 'RAMESH PATIL',
        email: 'ramesh@stjohn.edu',
        status: 'pending',
        requestedAt: '2026-09-28T09:14:00.000Z',
      }),
    );

    expect(r.uid).toBe('uid-ramesh');
    expect(r.displayName).toBe('RAMESH PATIL');
    expect(r.status).toBe('pending');
    expect(r.requestedAt).toBe('2026-09-28T09:14:00.000Z');
  });

  it('an unrecognised status reads as pending, never as approved', () => {
    const r = toJoinRequest(snap('u1', { schoolId: 'sjs', status: 'approved!' }));

    expect(r.status).toBe('pending');
  });

  it('survives a request with nothing but an id', () => {
    const r = toJoinRequest(snap('u1', {}));

    expect(r.uid).toBe('u1');
    expect(r.displayName).toBe('');
    expect(r.status).toBe('pending');
    expect(r.requestedAt).toBeNull();
  });
});

describe('join codes', () => {
  it('reads a code, keyed by its token', () => {
    const c = toJoinCode(
      snap('Kx7Rm2Qp', { schoolId: 'sjs', schoolName: 'ST. JOHN SAMARITAN' }),
    );

    expect(c.token).toBe('Kx7Rm2Qp');
    expect(c.schoolName).toBe('ST. JOHN SAMARITAN');
  });

  it('survives a code with a missing name', () => {
    const c = toJoinCode(snap('Kx7Rm2Qp', { schoolId: 'sjs' }));

    expect(c.schoolName).toBe('');
  });
});

describe('generated join tokens', () => {
  // These are printed and pinned to a noticeboard, then typed in by hand
  // when the camera will not focus.
  it('contain no characters people confuse with each other', () => {
    const confusable = /[0O1lI]/;
    for (let i = 0; i < 200; i += 1) {
      expect(generateJoinToken()).not.toMatch(confusable);
    }
  });

  it('do not repeat', () => {
    const seen = new Set<string>();
    for (let i = 0; i < 500; i += 1) seen.add(generateJoinToken());

    expect(seen.size).toBe(500);
  });

  it('are long enough not to be guessed', () => {
    expect(generateJoinToken()).toHaveLength(10);
  });
});
