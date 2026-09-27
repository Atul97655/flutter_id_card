const assert = require('assert');
const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collectionGroup, collection,
  getDocs,
} = require('firebase/firestore');

// Teacher A and Teacher B belong to DIFFERENT schools - that is the whole
// point of the cross-tenant tests below.
const ADMIN = 'uid-admin';
const TEACHER_A = 'uid-teacher-a';
const TEACHER_B = 'uid-teacher-b';
const SCHOOL_A = 'school-a';
const SCHOOL_B = 'school-b';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'id-entity-rules-test',
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '../firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => testEnv && testEnv.cleanup());

beforeEach(async () => {
  await testEnv.clearFirestore();

  // Seeded with rules disabled - this is the fixture, not the thing under test.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', ADMIN), { role: 'Admin', active: true });
    await setDoc(doc(db, 'users', TEACHER_A), { role: 'Teacher', active: true, schoolId: SCHOOL_A });
    await setDoc(doc(db, 'users', TEACHER_B), { role: 'Teacher', active: true, schoolId: SCHOOL_B });

    await setDoc(doc(db, 'schools', SCHOOL_A), { name: 'SCHOOL A' });
    await setDoc(doc(db, 'schools', SCHOOL_B), { name: 'SCHOOL B' });

    await setDoc(doc(db, 'schools', SCHOOL_A, 'entries', 'entry-a'), {
      schoolId: SCHOOL_A, name: 'STUDENT A', approvalStatus: 'pending',
    });
    await setDoc(doc(db, 'schools', SCHOOL_B, 'entries', 'entry-b'), {
      schoolId: SCHOOL_B, name: 'STUDENT B', approvalStatus: 'pending',
    });

    await setDoc(doc(db, 'chats', 'chat-a'), {
      title: 'SCHOOL A', members: [ADMIN, TEACHER_A], kind: 'direct',
      lastMessage: '', unreadFor: [],
    });
    await setDoc(doc(db, 'chats', 'chat-b'), {
      title: 'SCHOOL B', members: [ADMIN, TEACHER_B], kind: 'direct',
      lastMessage: '', unreadFor: [],
    });
    await setDoc(doc(db, 'chats', 'bcast'), {
      title: 'Notice', members: [ADMIN, TEACHER_A, TEACHER_B], kind: 'broadcast',
      lastMessage: '', unreadFor: [],
    });
    await setDoc(doc(db, 'chats', 'chat-b', 'messages', 'm-b'), {
      senderId: ADMIN, body: 'private to B', readBy: [ADMIN],
    });
  });
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();
const anon = () => testEnv.unauthenticatedContext().firestore();

// ---------------------------------------------------------------------------
// The plan's non-negotiable: cross-teacher isolation.
// ---------------------------------------------------------------------------
describe('Cross-teacher isolation (Plan of Action, Section 4)', () => {
  it('Teacher A cannot read the other school entries', async () => {
    await assertFails(getDoc(doc(as(TEACHER_A), 'schools', SCHOOL_B, 'entries', 'entry-b')));
  });

  it('Teacher A cannot write into the other school', async () => {
    await assertFails(setDoc(doc(as(TEACHER_A), 'schools', SCHOOL_B, 'entries', 'new'), {
      schoolId: SCHOOL_B, name: 'INTRUDER',
    }));
  });

  it('Teacher A cannot read the other conversation', async () => {
    await assertFails(getDoc(doc(as(TEACHER_A), 'chats', 'chat-b')));
  });

  it('Teacher A cannot read messages in the other conversation', async () => {
    await assertFails(getDoc(doc(as(TEACHER_A), 'chats', 'chat-b', 'messages', 'm-b')));
  });

  it('Teacher A cannot post into the other conversation', async () => {
    await assertFails(setDoc(doc(as(TEACHER_A), 'chats', 'chat-b', 'messages', 'x'), {
      senderId: TEACHER_A, body: 'hello', readBy: [TEACHER_A],
    }));
  });

  it('Teacher A cannot read the other school settings', async () => {
    await assertFails(getDoc(doc(as(TEACHER_A), 'schools', SCHOOL_B)));
  });

  it('an unauthenticated caller can read nothing', async () => {
    await assertFails(getDoc(doc(anon(), 'schools', SCHOOL_A, 'entries', 'entry-a')));
    await assertFails(getDoc(doc(anon(), 'chats', 'chat-a')));
  });
});

// ---------------------------------------------------------------------------
// The admin panel reads every school's submissions in one query.
// ---------------------------------------------------------------------------
describe('Entries as a collection group', () => {
  it('the admin CAN read every entry across every school at once', async () => {
    // Regression guard. A collectionGroup query does not match the nested
    // /schools/{id}/entries/{id} rule, so without a rule matching the
    // collection group itself this was refused even for an admin - the
    // dashboard loaded with "Could not load entries: Missing or insufficient
    // permissions" while schools and accounts loaded fine.
    const snap = await assertSucceeds(
      getDocs(collectionGroup(as(ADMIN), 'entries')),
    );
    assert.strictEqual(snap.size, 2);
  });

  it('a teacher CANNOT - it would span every school', async () => {
    await assertFails(getDocs(collectionGroup(as(TEACHER_A), 'entries')));
  });

  it('an unauthenticated caller cannot either', async () => {
    await assertFails(getDocs(collectionGroup(anon(), 'entries')));
  });

  it('a teacher can still read their OWN school through the scoped path',
    async () => {
      await assertSucceeds(
        getDoc(doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'entry-a')),
      );
    });
});

// ---------------------------------------------------------------------------
// The student's photo, carried inside Firestore because Cloud Storage is not
// provisioned on this project.
// ---------------------------------------------------------------------------
describe('Inline photos (entries/{id}/media/photo)', () => {
  // ---- the backfill's exact write, against the real rules ----------------
  //
  // Everything else here tests the media document. This tests the OTHER half:
  // the merge that puts `photoThumb` onto an entry the admin has already
  // approved. That write was only ever exercised against a fake Firestore,
  // which does not enforce rules - so if it were refused in production the
  // backfill would fail silently on every card, which is exactly the symptom
  // that has been reported twice.
  //
  // Three clauses could refuse it and all three are load-bearing:
  // `reviewFieldsUnchanged` (a merge must not look like an edit to the review
  // decision), `schoolId` equality, and `hasValidTextCapitalization` - which
  // runs against the MERGED document, so the entry's existing text has to
  // survive a write that never mentions it.
  describe("the backfill's photoThumb merge", () => {
    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(
          doc(ctx.firestore(), 'schools', SCHOOL_A, 'entries', 'approved-a'),
          {
            schoolId: SCHOOL_A,
            name: 'ATUL',
            fatherName: 'FATHER NAME',
            studentClass: '10',
            division: 'A',
            address: 'SOME STREET, SOME CITY',
            approvalStatus: 'approved',
            reviewedBy: 'admin-uid',
          },
        );
      });
    });

    it('a teacher CAN merge a thumbnail onto an approved card', async () => {
      await assertSucceeds(
        setDoc(
          doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'approved-a'),
          { photoThumb: 'BASE64THUMB' },
          { merge: true },
        ),
      );
    });

    it('and the review decision survives it untouched', async () => {
      await assertSucceeds(
        setDoc(
          doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'approved-a'),
          { photoThumb: 'BASE64THUMB' },
          { merge: true },
        ),
      );
      const after = await getDoc(
        doc(as(ADMIN), 'schools', SCHOOL_A, 'entries', 'approved-a'),
      );
      assert.strictEqual(after.data().approvalStatus, 'approved');
      assert.strictEqual(after.data().reviewedBy, 'admin-uid');
      assert.strictEqual(after.data().name, 'ATUL');
    });

    it('but the same merge cannot smuggle in a review change', async () => {
      await assertFails(
        setDoc(
          doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'approved-a'),
          { photoThumb: 'BASE64THUMB', approvalStatus: 'printed' },
          { merge: true },
        ),
      );
    });

    it("nor reach another school's card", async () => {
      await assertFails(
        setDoc(
          doc(as(TEACHER_B), 'schools', SCHOOL_A, 'entries', 'approved-a'),
          { photoThumb: 'BASE64THUMB' },
          { merge: true },
        ),
      );
    });

    it('a card holding lowercase text blocks its own thumbnail', async () => {
      // Worth pinning because it is surprising: the capitalisation rule runs
      // against the merged document, so a record that got lowercase text in
      // before that rule existed can no longer be written to AT ALL - not
      // even to attach its photo. The app uppercases every one of these
      // fields, so this is a legacy-data problem rather than a live one, but
      // it is the shape of failure to look for if a backfill ever stalls on
      // one particular card.
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(
          doc(ctx.firestore(), 'schools', SCHOOL_A, 'entries', 'legacy'),
          { schoolId: SCHOOL_A, name: 'Old Record', approvalStatus: 'approved' },
        );
      });

      await assertFails(
        setDoc(
          doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'legacy'),
          { photoThumb: 'BASE64THUMB' },
          { merge: true },
        ),
      );
    });
  });


  const photo = (chars = 100) => ({
    data: 'x'.repeat(chars),
    contentType: 'image/jpeg',
    bytes: chars,
  });

  it("a teacher can write their own school's photo", async () => {
    await assertSucceeds(
      setDoc(
        doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'entry-a', 'media', 'photo'),
        photo(),
      ),
    );
  });

  it("a teacher CANNOT write another school's photo", async () => {
    await assertFails(
      setDoc(
        doc(as(TEACHER_A), 'schools', SCHOOL_B, 'entries', 'entry-b', 'media', 'photo'),
        photo(),
      ),
    );
  });

  it("a teacher CANNOT read another school's photo", async () => {
    await assertFails(
      getDoc(
        doc(as(TEACHER_A), 'schools', SCHOOL_B, 'entries', 'entry-b', 'media', 'photo'),
      ),
    );
  });

  it('an unauthenticated caller can do neither', async () => {
    await assertFails(
      getDoc(doc(anon(), 'schools', SCHOOL_A, 'entries', 'entry-a', 'media', 'photo')),
    );
    await assertFails(
      setDoc(
        doc(anon(), 'schools', SCHOOL_A, 'entries', 'entry-a', 'media', 'photo'),
        photo(),
      ),
    );
  });

  it("the admin can read any school's photo", async () => {
    await assertSucceeds(
      getDoc(
        doc(as(ADMIN), 'schools', SCHOOL_B, 'entries', 'entry-b', 'media', 'photo'),
      ),
    );
  });

  it('an oversized photo is refused', async () => {
    // Firestore caps a document just under 1 MiB. Without the size rule a
    // client could write a photo field large enough that the document can no
    // longer be updated at all, stranding the student's record.
    await assertFails(
      setDoc(
        doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'entry-a', 'media', 'photo'),
        photo(800001),
      ),
    );
  });

  it('a photo with no data field is refused', async () => {
    await assertFails(
      setDoc(
        doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'entry-a', 'media', 'photo'),
        { contentType: 'image/jpeg' },
      ),
    );
  });

  it('a teacher cannot delete a photo - only the admin can', async () => {
    await assertFails(
      deleteDoc(
        doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'entry-a', 'media', 'photo'),
      ),
    );
    await assertSucceeds(
      deleteDoc(
        doc(as(ADMIN), 'schools', SCHOOL_A, 'entries', 'entry-a', 'media', 'photo'),
      ),
    );
  });

  it('a photo document is NOT swept up by the entries collection group',
    async () => {
      // The collection group rule matches collections named `entries`. A photo
      // lives in one named `media`, so it must not appear in the admin panel's
      // list query - if it did, every dashboard load would pull every full
      // photo in the system.
      const snap = await assertSucceeds(
        getDocs(collectionGroup(as(ADMIN), 'entries')),
      );
      assert.strictEqual(snap.size, 2);
    });
});

// ---------------------------------------------------------------------------
// Hub and spoke: teachers talk to the admin, never to each other.
// ---------------------------------------------------------------------------
describe('Hub-and-spoke messaging', () => {
  it('a teacher cannot create a conversation with anyone', async () => {
    await assertFails(setDoc(doc(as(TEACHER_A), 'chats', 'rogue'), {
      title: 'A to B', members: [TEACHER_A, TEACHER_B], kind: 'direct',
    }));
  });

  it('a teacher cannot add themselves to another conversation', async () => {
    await assertFails(updateDoc(doc(as(TEACHER_A), 'chats', 'chat-b'), {
      members: [ADMIN, TEACHER_B, TEACHER_A],
    }));
  });

  it('a teacher CAN send a message in their own conversation', async () => {
    // Regression guard. Sending is a batched write that also updates the
    // parent chat document; an admin-only update rule on /chats broke teacher
    // messaging entirely and was invisible until the rules were deployed.
    await assertSucceeds(setDoc(doc(as(TEACHER_A), 'chats', 'chat-a', 'messages', 'm1'), {
      senderId: TEACHER_A, body: 'hello office', readBy: [TEACHER_A],
    }));
    await assertSucceeds(updateDoc(doc(as(TEACHER_A), 'chats', 'chat-a'), {
      lastMessage: 'hello office',
      lastMessageAt: new Date().toISOString(),
      lastSenderId: TEACHER_A,
      unreadFor: [ADMIN],
    }));
  });

  it('a teacher CAN clear their own unread badge', async () => {
    await assertSucceeds(updateDoc(doc(as(TEACHER_A), 'chats', 'chat-a'), { unreadFor: [] }));
  });

  it('a teacher cannot rename or re-scope a conversation', async () => {
    await assertFails(updateDoc(doc(as(TEACHER_A), 'chats', 'chat-a'), { title: 'hacked' }));
    await assertFails(updateDoc(doc(as(TEACHER_A), 'chats', 'chat-a'), { kind: 'broadcast' }));
  });

  it('a teacher cannot post into a broadcast', async () => {
    await assertFails(setDoc(doc(as(TEACHER_A), 'chats', 'bcast', 'messages', 'reply'), {
      senderId: TEACHER_A, body: 'replying to an announcement', readBy: [TEACHER_A],
    }));
  });

  it('the admin CAN post into a broadcast', async () => {
    await assertSucceeds(setDoc(doc(as(ADMIN), 'chats', 'bcast', 'messages', 'notice'), {
      senderId: ADMIN, body: 'Holiday Monday', readBy: [ADMIN],
    }));
  });

  it('a teacher cannot forge the sender of a message', async () => {
    await assertFails(setDoc(doc(as(TEACHER_A), 'chats', 'chat-a', 'messages', 'fake'), {
      senderId: ADMIN, body: 'from the office', readBy: [ADMIN],
    }));
  });
});

// ---------------------------------------------------------------------------
// Installation settings.
// ---------------------------------------------------------------------------
describe('Panel settings (config/panel)', () => {
  it('every active account can read them', async () => {
    // Both the panel and the app need to know which features are part of this
    // installation before they can decide what to show.
    await assertSucceeds(getDoc(doc(as(TEACHER_A), 'config', 'panel')));
    await assertSucceeds(getDoc(doc(as(ADMIN), 'config', 'panel')));
  });

  it('only the admin can change them', async () => {
    // A feature switch an operator can flip is a feature switch that flips by
    // accident - and this one hides a whole section of the panel.
    await assertFails(
      setDoc(doc(as(TEACHER_A), 'config', 'panel'), { printingEnabled: false }),
    );
    await assertSucceeds(
      setDoc(doc(as(ADMIN), 'config', 'panel'), { printingEnabled: false }),
    );
  });

  it('an unauthenticated caller can do neither', async () => {
    await assertFails(getDoc(doc(anon(), 'config', 'panel')));
    await assertFails(
      setDoc(doc(anon(), 'config', 'panel'), { printingEnabled: false }),
    );
  });

  it('a deactivated admin loses the ability to change them', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', ADMIN), {
        role: 'Admin', active: false,
      });
    });
    await assertFails(
      setDoc(doc(as(ADMIN), 'config', 'panel'), { printingEnabled: false }),
    );
  });
});

// ---------------------------------------------------------------------------
// Chat attachments, carried inside Firestore because Storage is unprovisioned.
// ---------------------------------------------------------------------------
describe('Inline chat attachments (messages/{id}/media/file)', () => {
  const file = (chars = 100) => ({
    data: 'x'.repeat(chars),
    contentType: 'image/jpeg',
    bytes: chars,
    name: 'snap.jpg',
  });

  const pathFor = (db, chatId, messageId) =>
    doc(db, 'chats', chatId, 'messages', messageId, 'media', 'file');

  it('a member can attach a file to their own conversation', async () => {
    await assertSucceeds(
      setDoc(pathFor(as(TEACHER_A), 'chat-a', 'm-new'), file()),
    );
  });

  it("a non-member CANNOT attach to someone else's conversation", async () => {
    await assertFails(
      setDoc(pathFor(as(TEACHER_A), 'chat-b', 'm-b'), file()),
    );
  });

  it("a non-member CANNOT read someone else's attachment", async () => {
    await assertFails(getDoc(pathFor(as(TEACHER_A), 'chat-b', 'm-b')));
  });

  it('an unauthenticated caller can do neither', async () => {
    await assertFails(getDoc(pathFor(anon(), 'chat-a', 'm-a')));
    await assertFails(setDoc(pathFor(anon(), 'chat-a', 'm-a'), file()));
  });

  it('the admin can read any conversation attachment', async () => {
    await assertSucceeds(getDoc(pathFor(as(ADMIN), 'chat-b', 'm-b')));
  });

  it('a teacher cannot attach anything to a broadcast', async () => {
    // A broadcast is an announcement, not a thread. The message rule already
    // refuses the post; this stops an attachment being smuggled in beside it.
    await assertFails(setDoc(pathFor(as(TEACHER_A), 'bcast', 'm-x'), file()));
  });

  it('the admin CAN attach to a broadcast', async () => {
    await assertSucceeds(setDoc(pathFor(as(ADMIN), 'bcast', 'm-x'), file()));
  });

  it('an oversized attachment is refused', async () => {
    // Firestore caps a document just under 1 MiB. A document pushed to that
    // limit can no longer be written at all.
    await assertFails(
      setDoc(pathFor(as(TEACHER_A), 'chat-a', 'm-big'), file(800001)),
    );
  });

  it('an attachment with no data field is refused', async () => {
    await assertFails(
      setDoc(pathFor(as(TEACHER_A), 'chat-a', 'm-empty'), {
        contentType: 'image/jpeg',
      }),
    );
  });

  it('a deactivated member loses access to attachments too', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', TEACHER_A), {
        role: 'Teacher', active: false, schoolId: SCHOOL_A,
      });
    });
    await assertFails(getDoc(pathFor(as(TEACHER_A), 'chat-a', 'm-a')));
    await assertFails(setDoc(pathFor(as(TEACHER_A), 'chat-a', 'm-a'), file()));
  });
});

// ---------------------------------------------------------------------------
// Review workflow: approval is the admin's alone.
// ---------------------------------------------------------------------------
describe('Review workflow', () => {
  it('a teacher cannot approve their own submission', async () => {
    await assertFails(updateDoc(doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'entry-a'), {
      approvalStatus: 'approved',
    }));
  });

  it('a teacher cannot mark their own card printed', async () => {
    await assertFails(updateDoc(doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'entry-a'), {
      approvalStatus: 'printed',
    }));
  });

  it('a teacher cannot create an entry that is already approved', async () => {
    await assertFails(setDoc(doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'sneaky'), {
      schoolId: SCHOOL_A, name: 'SNEAKY', approvalStatus: 'approved',
    }));
  });

  it('a teacher CAN create a pending entry in their own school', async () => {
    await assertSucceeds(setDoc(doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'ok'), {
      schoolId: SCHOOL_A, name: 'REAL STUDENT', approvalStatus: 'pending',
    }));
  });

  it('the admin CAN approve', async () => {
    await assertSucceeds(updateDoc(doc(as(ADMIN), 'schools', SCHOOL_A, 'entries', 'entry-a'), {
      approvalStatus: 'approved',
    }));
  });

  it('lowercase card text is rejected', async () => {
    await assertFails(setDoc(doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'lower'), {
      schoolId: SCHOOL_A, name: 'lower case kid', approvalStatus: 'pending',
    }));
  });

  it('a lowercase roll number is rejected', async () => {
    await assertFails(setDoc(doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'roll'), {
      schoolId: SCHOOL_A, name: 'REAL KID', rollNumber: '12/a', approvalStatus: 'pending',
    }));
  });

  it('a teacher cannot delete a synced entry', async () => {
    await assertFails(deleteDoc(doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'entry-a')));
  });
});

// ---------------------------------------------------------------------------
// Privilege escalation.
// ---------------------------------------------------------------------------
describe('Privilege escalation', () => {
  it('a teacher CAN stamp their own last login', async () => {
    // The login path writes this on every sign-in with set(merge:true), which
    // Firestore evaluates as an update. If the rule rejected it, every teacher
    // login would log a permission error - the same class of bug as the chat
    // document, which only surfaced when the rules were actually exercised.
    await assertSucceeds(
      setDoc(
        doc(as(TEACHER_A), 'users', TEACHER_A),
        { lastLoginDate: new Date().toISOString() },
        { merge: true },
      ),
    );
  });

  it('but cannot smuggle another field alongside it', async () => {
    await assertFails(
      setDoc(
        doc(as(TEACHER_A), 'users', TEACHER_A),
        { lastLoginDate: new Date().toISOString(), role: 'Admin' },
        { merge: true },
      ),
    );
  });

  it('a teacher cannot make themselves an admin', async () => {
    await assertFails(updateDoc(doc(as(TEACHER_A), 'users', TEACHER_A), { role: 'Admin' }));
  });

  it('a teacher cannot move themselves to another school', async () => {
    await assertFails(updateDoc(doc(as(TEACHER_A), 'users', TEACHER_A), { schoolId: SCHOOL_B }));
  });

  it('a teacher cannot read another user profile', async () => {
    await assertFails(getDoc(doc(as(TEACHER_A), 'users', TEACHER_B)));
  });

  it('a teacher cannot create an account', async () => {
    await assertFails(setDoc(doc(as(TEACHER_A), 'users', 'new-uid'), {
      role: 'Teacher', active: true, schoolId: SCHOOL_A,
    }));
  });

  it('a teacher cannot edit school settings', async () => {
    await assertFails(updateDoc(doc(as(TEACHER_A), 'schools', SCHOOL_A), { name: 'RENAMED' }));
  });

  it('a deactivated account loses all access', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', TEACHER_A), {
        role: 'Teacher', active: false, schoolId: SCHOOL_A,
      });
    });
    await assertFails(getDoc(doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'entry-a')));
    await assertFails(getDoc(doc(as(TEACHER_A), 'chats', 'chat-a')));
  });
});

// ---------------------------------------------------------------------------
// QR onboarding (screens 15-18, pages A8 and A10).
//
// Opening Firebase Auth sign-up to the public is what makes the QR flow
// possible, and it is also the single largest change to this project's threat
// model. From here on, anybody can hold a valid identity. Everything that
// keeps a stranger away from a school's student records now lives in the
// rules, so these tests are the guarantee - not the onboarding screens, which
// had not been written when this was committed.
// ---------------------------------------------------------------------------

const STRANGER = 'uid-stranger';
const JOIN_TOKEN = 'Kx7Rm2Qp';

describe('Self-registration', () => {
  it('a new account can create its own profile as a teacher', async () => {
    await assertSucceeds(setDoc(doc(as(STRANGER), 'users', STRANGER), {
      role: 'Teacher', active: true, displayName: 'RAMESH PATIL',
    }));
  });

  it('a new account cannot make itself an admin', async () => {
    await assertFails(setDoc(doc(as(STRANGER), 'users', STRANGER), {
      role: 'Admin', active: true,
    }));
  });

  it('a new account cannot give itself a school', async () => {
    await assertFails(setDoc(doc(as(STRANGER), 'users', STRANGER), {
      role: 'Teacher', active: true, schoolId: SCHOOL_A,
    }));
  });

  it('a new account cannot give itself a section', async () => {
    await assertFails(setDoc(doc(as(STRANGER), 'users', STRANGER), {
      role: 'Teacher',
      active: true,
      assignment: {
        schoolId: SCHOOL_A, classLevel: '10', division: 'A', status: 'active',
      },
    }));
  });

  it('a new account cannot create a profile for somebody else', async () => {
    await assertFails(setDoc(doc(as(STRANGER), 'users', 'uid-someone-else'), {
      role: 'Teacher', active: true,
    }));
  });

  // The load-bearing assertion of this whole feature.
  it('a self-registered account can read nothing at all', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', STRANGER), {
        role: 'Teacher', active: true,
      });
    });

    await assertFails(getDoc(doc(as(STRANGER), 'schools', SCHOOL_A)));
    await assertFails(
      getDoc(doc(as(STRANGER), 'schools', SCHOOL_A, 'entries', 'entry-a')),
    );
    await assertFails(getDocs(collectionGroup(as(STRANGER), 'entries')));
    await assertFails(getDoc(doc(as(STRANGER), 'chats', 'chat-a')));
  });
});

describe('QR join codes', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'joinCodes', JOIN_TOKEN), {
        schoolId: SCHOOL_A, schoolName: 'SCHOOL A',
      });
      await setDoc(doc(db, 'users', STRANGER), {
        role: 'Teacher', active: true,
      });
    });
  });

  it('holding a code reveals the school name', async () => {
    const snap = await assertSucceeds(
      getDoc(doc(as(STRANGER), 'joinCodes', JOIN_TOKEN)),
    );
    assert.strictEqual(snap.data().schoolName, 'SCHOOL A');
  });

  it('an anonymous scanner gets nothing', async () => {
    await assertFails(getDoc(doc(anon(), 'joinCodes', JOIN_TOKEN)));
  });

  // Without this, one leaked login is a way into every school at once.
  it('codes cannot be enumerated', async () => {
    await assertFails(getDocs(collection(as(STRANGER), 'joinCodes')));
  });

  it('a teacher cannot mint a code', async () => {
    await assertFails(setDoc(doc(as(TEACHER_A), 'joinCodes', 'forged'), {
      schoolId: SCHOOL_A, schoolName: 'SCHOOL A',
    }));
  });

  it('an admin can issue and revoke one', async () => {
    await assertSucceeds(setDoc(doc(as(ADMIN), 'joinCodes', 'fresh'), {
      schoolId: SCHOOL_A, schoolName: 'SCHOOL A',
    }));
    await assertSucceeds(deleteDoc(doc(as(ADMIN), 'joinCodes', JOIN_TOKEN)));
  });

  // Rotation has to be safe for the people already inside.
  it('revoking a code does not disturb a teacher who already joined', async () => {
    await assertSucceeds(deleteDoc(doc(as(ADMIN), 'joinCodes', JOIN_TOKEN)));
    await assertSucceeds(
      getDoc(doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'entry-a')),
    );
  });

  it('a revoked code stops resolving', async () => {
    await assertSucceeds(deleteDoc(doc(as(ADMIN), 'joinCodes', JOIN_TOKEN)));
    const snap = await getDoc(doc(as(STRANGER), 'joinCodes', JOIN_TOKEN));
    assert.strictEqual(snap.exists(), false);
  });
});

describe('Pending joins', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', STRANGER), {
        role: 'Teacher', active: true,
      });
    });
  });

  const request = () => ({
    uid: STRANGER,
    schoolId: SCHOOL_A,
    status: 'pending',
    displayName: 'RAMESH PATIL',
    requestedAt: new Date().toISOString(),
  });

  const queue = (db) => setDoc(
    doc(db, 'schools', SCHOOL_A, 'joinRequests', STRANGER),
    request(),
  );

  it('a scanner can queue themselves once', async () => {
    await assertSucceeds(queue(as(STRANGER)));
  });

  it('a scanner cannot arrive pre-approved', async () => {
    await assertFails(setDoc(
      doc(as(STRANGER), 'schools', SCHOOL_A, 'joinRequests', STRANGER),
      Object.assign(request(), { status: 'active' }),
    ));
  });

  it('a scanner cannot queue under another name', async () => {
    await assertFails(setDoc(
      doc(as(STRANGER), 'schools', SCHOOL_A, 'joinRequests', TEACHER_B),
      Object.assign(request(), { uid: TEACHER_B }),
    ));
  });

  it('a scanner can check their own request', async () => {
    await queue(as(STRANGER));
    await assertSucceeds(getDoc(
      doc(as(STRANGER), 'schools', SCHOOL_A, 'joinRequests', STRANGER),
    ));
  });

  it('a scanner cannot read another request', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'schools', SCHOOL_A, 'joinRequests', TEACHER_B),
        { uid: TEACHER_B, schoolId: SCHOOL_A, status: 'pending' },
      );
    });
    await assertFails(getDoc(
      doc(as(STRANGER), 'schools', SCHOOL_A, 'joinRequests', TEACHER_B),
    ));
  });

  // Self-approval is the exact failure this flow exists to prevent.
  it('a scanner cannot approve themselves', async () => {
    await queue(as(STRANGER));
    await assertFails(updateDoc(
      doc(as(STRANGER), 'schools', SCHOOL_A, 'joinRequests', STRANGER),
      { status: 'active' },
    ));
  });

  it('a scanner cannot withdraw a request to hide it', async () => {
    await queue(as(STRANGER));
    await assertFails(deleteDoc(
      doc(as(STRANGER), 'schools', SCHOOL_A, 'joinRequests', STRANGER),
    ));
  });

  it('the office sees every pending join across all schools', async () => {
    await queue(as(STRANGER));
    const snap = await assertSucceeds(
      getDocs(collectionGroup(as(ADMIN), 'joinRequests')),
    );
    assert.strictEqual(snap.size, 1);
  });

  it('a teacher cannot sweep the pending list', async () => {
    await assertFails(getDocs(collectionGroup(as(TEACHER_A), 'joinRequests')));
  });

  it('the office can approve and decline', async () => {
    await queue(as(STRANGER));
    await assertSucceeds(updateDoc(
      doc(as(ADMIN), 'schools', SCHOOL_A, 'joinRequests', STRANGER),
      { status: 'active', classLevel: '10', division: 'C' },
    ));
    await assertSucceeds(deleteDoc(
      doc(as(ADMIN), 'schools', SCHOOL_A, 'joinRequests', STRANGER),
    ));
  });

  // Approving is really two writes: the request, and the schoolId that
  // actually grants access. Only the second one matters for security.
  it('access arrives only when the office writes schoolId', async () => {
    await assertFails(
      getDoc(doc(as(STRANGER), 'schools', SCHOOL_A, 'entries', 'entry-a')),
    );

    await assertSucceeds(updateDoc(doc(as(ADMIN), 'users', STRANGER), {
      schoolId: SCHOOL_A,
    }));

    await assertSucceeds(
      getDoc(doc(as(STRANGER), 'schools', SCHOOL_A, 'entries', 'entry-a')),
    );
  });
});

// ---------------------------------------------------------------------------
// Section scope (screens 19, 20 and page A9).
//
// The narrowest boundary in the project: not "which school" but "which
// section of which school". Every assertion here is about a teacher who is
// legitimately inside a school and must still be kept out of part of it.
// ---------------------------------------------------------------------------

describe('Section scope', () => {
  const scope = (classLevel, division, status = 'active') => ({
    role: 'Teacher',
    active: true,
    schoolId: SCHOOL_A,
    assignment: { schoolId: SCHOOL_A, classLevel, division, status },
  });

  const student = (id, classLevel, division) => ({
    schoolId: SCHOOL_A,
    name: 'STUDENT ' + id.toUpperCase(),
    studentClass: classLevel,
    division,
    approvalStatus: 'pending',
  });

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'schools', SCHOOL_A, 'entries', 'in-10a'),
        student('in-10a', '10', 'A'));
      await setDoc(doc(db, 'schools', SCHOOL_A, 'entries', 'in-10b'),
        student('in-10b', '10', 'B'));
      await setDoc(
        doc(db, 'schools', SCHOOL_A, 'entries', 'in-10b', 'media', 'photo'),
        { data: 'BBBB' },
      );
    });
  });

  const assign = (classLevel, division, status) => testEnv
    .withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'users', TEACHER_A),
        scope(classLevel, division, status),
      );
    });

  it('a scoped teacher reads their own section', async () => {
    await assign('10', 'A');
    await assertSucceeds(
      getDoc(doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'in-10a')),
    );
  });

  // The one that matters.
  it('a scoped teacher cannot read the next section along', async () => {
    await assign('10', 'A');
    await assertFails(
      getDoc(doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'in-10b')),
    );
  });

  // A photograph of a child is the most sensitive thing in this database.
  it('a scoped teacher cannot read a photo from another section', async () => {
    await assign('10', 'A');
    await assertFails(getDoc(doc(
      as(TEACHER_A),
      'schools', SCHOOL_A, 'entries', 'in-10b', 'media', 'photo',
    )));
  });

  it('a scoped teacher cannot file a student into another section', async () => {
    await assign('10', 'A');
    await assertFails(setDoc(
      doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'new-10b'),
      student('new-10b', '10', 'B'),
    ));
  });

  it('a scoped teacher can file into their own section', async () => {
    await assign('10', 'A');
    await assertSucceeds(setDoc(
      doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'new-10a'),
      student('new-10a', '10', 'A'),
    ));
  });

  // Moving a card out of your own section is how a scope gets escaped.
  it('a scoped teacher cannot move a card out of their section', async () => {
    await assign('10', 'A');
    await assertFails(updateDoc(
      doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'in-10a'),
      { division: 'B' },
    ));
  });

  it('a scoped teacher cannot reach into another section by editing', async () => {
    await assign('10', 'A');
    await assertFails(updateDoc(
      doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'in-10b'),
      { name: 'RENAMED' },
    ));
  });

  // Grandfathering: an installation that upgrades must not narrow anyone
  // until the office actually assigns a section.
  it('a teacher with no assignment still sees the whole school', async () => {
    await assertSucceeds(
      getDoc(doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'in-10a')),
    );
    await assertSucceeds(
      getDoc(doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'in-10b')),
    );
  });

  it('a pending assignment does not narrow anything either', async () => {
    await assign('10', 'A', 'pending');
    await assertSucceeds(
      getDoc(doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'in-10b')),
    );
  });

  it('a half-filled assignment does not narrow anything', async () => {
    await assign('10', '');
    await assertSucceeds(
      getDoc(doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'in-10b')),
    );
  });

  it('a teacher cannot widen their own scope', async () => {
    await assign('10', 'A');
    await assertFails(updateDoc(doc(as(TEACHER_A), 'users', TEACHER_A), {
      assignment: {
        schoolId: SCHOOL_A, classLevel: '10', division: 'B', status: 'active',
      },
    }));
  });

  it('the office can move a teacher to another section', async () => {
    await assign('10', 'A');
    await assertSucceeds(updateDoc(doc(as(ADMIN), 'users', TEACHER_A), {
      assignment: {
        schoolId: SCHOOL_A, classLevel: '10', division: 'C', status: 'active',
      },
    }));
  });

  it('an admin is never narrowed', async () => {
    await assign('10', 'A');
    await assertSucceeds(
      getDoc(doc(as(ADMIN), 'schools', SCHOOL_A, 'entries', 'in-10b')),
    );
  });
});

describe('Attribution', () => {
  it('a teacher cannot submit a card under another name', async () => {
    await assertFails(setDoc(
      doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'forged'),
      {
        schoolId: SCHOOL_A,
        name: 'STUDENT X',
        approvalStatus: 'pending',
        submittedByUid: TEACHER_B,
      },
    ));
  });

  it('a teacher can submit under their own', async () => {
    await assertSucceeds(setDoc(
      doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'honest'),
      {
        schoolId: SCHOOL_A,
        name: 'STUDENT Y',
        approvalStatus: 'pending',
        submittedByUid: TEACHER_A,
      },
    ));
  });

  // Pre-v10 rows have no submitter, and the app still writes some without
  // one when no session name is available.
  it('a card with no submitter is still accepted', async () => {
    await assertSucceeds(setDoc(
      doc(as(TEACHER_A), 'schools', SCHOOL_A, 'entries', 'anon'),
      { schoolId: SCHOOL_A, name: 'STUDENT Z', approvalStatus: 'pending' },
    ));
  });
});
