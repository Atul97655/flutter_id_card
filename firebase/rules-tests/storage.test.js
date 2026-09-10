const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc } = require('firebase/firestore');
const { ref, uploadBytes, getBytes } = require('firebase/storage');

const ADMIN = 'uid-admin';
const TEACHER_A = 'uid-teacher-a';
const TEACHER_B = 'uid-teacher-b';
const SCHOOL_A = 'school-a';
const SCHOOL_B = 'school-b';

const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const png = { contentType: 'image/png' };
const exe = { contentType: 'application/x-msdownload' };

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'id-entity-rules-test',
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '../firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
    storage: {
      rules: fs.readFileSync(path.resolve(__dirname, '../storage.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
});

after(async () => testEnv && testEnv.cleanup());

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();

  // The Storage rules read membership and roles out of Firestore, so the
  // Firestore fixture has to exist for any Storage test to mean anything.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', ADMIN), { role: 'Admin', active: true });
    await setDoc(doc(db, 'users', TEACHER_A), { role: 'Teacher', active: true, schoolId: SCHOOL_A });
    await setDoc(doc(db, 'users', TEACHER_B), { role: 'Teacher', active: true, schoolId: SCHOOL_B });
    await setDoc(doc(db, 'chats', 'chat-a'), { members: [ADMIN, TEACHER_A], kind: 'direct' });
    await setDoc(doc(db, 'chats', 'chat-b'), { members: [ADMIN, TEACHER_B], kind: 'direct' });
  });

  // Seed one attachment inside Teacher B's private conversation.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(ref(ctx.storage(), 'chats/chat-b/secret.png'), PNG, png);
    await uploadBytes(ref(ctx.storage(), `schools/${SCHOOL_B}/photos/entry-b.png`), PNG, png);
  });
});

const as = (uid) => testEnv.authenticatedContext(uid).storage();

describe('Student photo storage', () => {
  it('a teacher can upload a photo for their own school', async () => {
    await assertSucceeds(
      uploadBytes(ref(as(TEACHER_A), `schools/${SCHOOL_A}/photos/e1.png`), PNG, png),
    );
  });

  it('a teacher cannot upload into another school', async () => {
    await assertFails(
      uploadBytes(ref(as(TEACHER_A), `schools/${SCHOOL_B}/photos/e1.png`), PNG, png),
    );
  });

  it('a teacher cannot read another school photos', async () => {
    await assertFails(getBytes(ref(as(TEACHER_A), `schools/${SCHOOL_B}/photos/entry-b.png`)));
  });

  it('a non-image is rejected even in your own school', async () => {
    await assertFails(
      uploadBytes(ref(as(TEACHER_A), `schools/${SCHOOL_A}/photos/evil.exe`), PNG, exe),
    );
  });

  it('branding assets are admin-only', async () => {
    await assertFails(uploadBytes(ref(as(TEACHER_A), `schools/${SCHOOL_A}/logo.png`), PNG, png));
    await assertSucceeds(uploadBytes(ref(as(ADMIN), `schools/${SCHOOL_A}/logo.png`), PNG, png));
  });
});

describe('Chat attachment storage', () => {
  it('a member can upload into their own conversation', async () => {
    await assertSucceeds(uploadBytes(ref(as(TEACHER_A), 'chats/chat-a/photo.png'), PNG, png));
  });

  it('a member can read their own conversation attachments', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), 'chats/chat-a/ours.png'), PNG, png);
    });
    await assertSucceeds(getBytes(ref(as(TEACHER_A), 'chats/chat-a/ours.png')));
  });

  it('a non-member CANNOT read another conversation attachments', async () => {
    // The original rules allowed this to any signed-in user and relied on the
    // path being unguessable. Chat ids are visible to every member and stored
    // in plain text in Firestore, so that was not a control at all.
    await assertFails(getBytes(ref(as(TEACHER_A), 'chats/chat-b/secret.png')));
  });

  it('a non-member CANNOT write into another conversation', async () => {
    await assertFails(uploadBytes(ref(as(TEACHER_A), 'chats/chat-b/planted.png'), PNG, png));
  });

  it('an executable is rejected even by a member', async () => {
    await assertFails(uploadBytes(ref(as(TEACHER_A), 'chats/chat-a/payload.exe'), PNG, exe));
  });

  it('the admin can read any conversation attachment', async () => {
    await assertSucceeds(getBytes(ref(as(ADMIN), 'chats/chat-b/secret.png')));
  });
});

describe('Unknown paths', () => {
  it('are denied outright', async () => {
    await assertFails(uploadBytes(ref(as(ADMIN), 'random/place.png'), PNG, png));
    await assertFails(getBytes(ref(as(TEACHER_A), 'random/place.png')));
  });
});
