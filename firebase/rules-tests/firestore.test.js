const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc } = require('firebase/firestore');

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
