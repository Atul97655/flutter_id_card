'use client';

import {
  addDoc,
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
  arrayRemove,
  type Unsubscribe,
} from 'firebase/firestore';
import { firebaseDb } from './firebase';
import {
  toChat,
  toChatMessage,
  toManagedUser,
  toSchoolConfig,
  toStudentEntry,
} from './converters';
import type {
  ApprovalStatus,
  Chat,
  ChatMessage,
  ManagedUser,
  SchoolConfig,
  StudentEntry,
} from './types';

/**
 * All Firestore access for the admin panel.
 *
 * Reads are live subscriptions, not one-shot fetches. The Flutter app writes
 * to the same documents continuously - an operator submitting a card, a sync
 * worker landing a backlog - and a dashboard that needed refreshing to show
 * that would be misleading about what the office is looking at.
 *
 * Writes mirror what the Flutter admin screens do, so both clients leave the
 * data in the same shape. Where the deployed rules constrain a write, the
 * constraint is noted at the call site.
 */

// ---------------------------------------------------------------------------
// Schools
// ---------------------------------------------------------------------------

export function watchSchools(
  onData: (schools: SchoolConfig[]) => void,
  onError?: (e: Error) => void,
): Unsubscribe {
  const db = firebaseDb();
  return onSnapshot(
    query(collection(db, 'schools'), orderBy('name')),
    (snap) => onData(snap.docs.map(toSchoolConfig)),
    (e) => onError?.(e),
  );
}

export function watchSchool(
  schoolId: string,
  onData: (school: SchoolConfig | null) => void,
  onError?: (e: Error) => void,
): Unsubscribe {
  const db = firebaseDb();
  return onSnapshot(
    doc(db, 'schools', schoolId),
    (snap) =>
      onData(
        snap.exists()
          ? toSchoolConfig(snap as Parameters<typeof toSchoolConfig>[0])
          : null,
      ),
    (e) => onError?.(e),
  );
}

export async function saveSchool(
  schoolId: string,
  patch: Partial<Omit<SchoolConfig, 'id'>>,
): Promise<void> {
  const db = firebaseDb();
  await setDoc(
    doc(db, 'schools', schoolId),
    { ...patch, updatedAt: new Date().toISOString() },
    { merge: true },
  );
}

export async function createSchool(
  schoolId: string,
  school: Omit<SchoolConfig, 'id' | 'updatedAt'>,
): Promise<void> {
  const db = firebaseDb();
  const existing = await getDoc(doc(db, 'schools', schoolId));
  if (existing.exists()) {
    throw new Error(`A school with the code "${schoolId}" already exists.`);
  }
  await setDoc(doc(db, 'schools', schoolId), {
    ...school,
    updatedAt: new Date().toISOString(),
  });
}

// ---------------------------------------------------------------------------
// Student entries
// ---------------------------------------------------------------------------

export function watchEntries(
  schoolId: string,
  onData: (entries: StudentEntry[]) => void,
  onError?: (e: Error) => void,
): Unsubscribe {
  const db = firebaseDb();
  return onSnapshot(
    collection(db, 'schools', schoolId, 'entries'),
    (snap) => onData(snap.docs.map((d) => toStudentEntry(d, schoolId))),
    (e) => onError?.(e),
  );
}

/**
 * Every submission across every school, for the global review queue.
 *
 * A collectionGroup query needs its own index the first time it runs; Firestore
 * returns a `failed-precondition` error carrying a link that creates it. The
 * caller surfaces that link rather than showing a blank table, because the
 * alternative - N subscriptions, one per school - re-reads everything whenever
 * any school changes.
 */
export function watchAllEntries(
  onData: (entries: StudentEntry[]) => void,
  onError?: (e: Error) => void,
): Unsubscribe {
  const db = firebaseDb();
  return onSnapshot(
    collectionGroup(db, 'entries'),
    (snap) =>
      onData(
        snap.docs.map((d) => {
          // schools/{schoolId}/entries/{entryId} - the school is the grandparent.
          const schoolId = d.ref.parent.parent?.id ?? '';
          return toStudentEntry(d, schoolId);
        }),
      ),
    (e) => onError?.(e),
  );
}

/**
 * Records a review decision.
 *
 * Only an admin may write these four fields - `reviewFieldsUnchanged()` in the
 * rules blocks operators outright - so this is one of the things the panel can
 * do that the teacher's app cannot.
 */
export async function reviewEntry(
  schoolId: string,
  entryId: string,
  decision: 'approved' | 'rejected',
  reviewerUid: string,
  reason?: string,
): Promise<void> {
  const db = firebaseDb();
  if (decision === 'rejected' && !reason?.trim()) {
    throw new Error('A rejection must say why - the operator has to know what to fix.');
  }
  await updateDoc(doc(db, 'schools', schoolId, 'entries', entryId), {
    approvalStatus: decision,
    rejectionReason: decision === 'rejected' ? reason!.trim() : null,
    reviewedBy: reviewerUid,
    reviewedAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  });
}

/**
 * Bulk review, for clearing a whole class at once.
 *
 * Firestore caps a batch at 500 writes, so this chunks. Each chunk is atomic;
 * the whole run is not, which is the right trade - a partial bulk approve
 * leaves correct data, just less of it.
 */
export async function reviewMany(
  entries: Pick<StudentEntry, 'id' | 'schoolId'>[],
  decision: 'approved' | 'rejected',
  reviewerUid: string,
  reason?: string,
): Promise<number> {
  const db = firebaseDb();
  if (decision === 'rejected' && !reason?.trim()) {
    throw new Error('A rejection must say why - the operator has to know what to fix.');
  }
  const now = new Date().toISOString();
  const CHUNK = 450;
  let written = 0;

  for (let i = 0; i < entries.length; i += CHUNK) {
    const batch = writeBatch(db);
    for (const e of entries.slice(i, i + CHUNK)) {
      batch.update(doc(db, 'schools', e.schoolId, 'entries', e.id), {
        approvalStatus: decision,
        rejectionReason: decision === 'rejected' ? reason!.trim() : null,
        reviewedBy: reviewerUid,
        reviewedAt: now,
        updatedAt: now,
      });
      written++;
    }
    await batch.commit();
  }
  return written;
}

/**
 * Marks entries as printed after a batch is generated.
 *
 * Only promotes `approved` rows. A row still pending must not jump straight to
 * printed, and one already printed does not need its timestamps rewritten on
 * every reprint.
 */
export async function markPrinted(
  entries: Pick<StudentEntry, 'id' | 'schoolId' | 'approvalStatus'>[],
): Promise<number> {
  const db = firebaseDb();
  const eligible = entries.filter((e) => e.approvalStatus === 'approved');
  if (eligible.length === 0) return 0;

  const now = new Date().toISOString();
  const CHUNK = 450;
  let moved = 0;

  for (let i = 0; i < eligible.length; i += CHUNK) {
    const batch = writeBatch(db);
    for (const e of eligible.slice(i, i + CHUNK)) {
      batch.update(doc(db, 'schools', e.schoolId, 'entries', e.id), {
        approvalStatus: 'printed',
        updatedAt: now,
      });
      moved++;
    }
    await batch.commit();
  }
  return moved;
}

export async function updateEntry(
  schoolId: string,
  entryId: string,
  patch: Partial<StudentEntry>,
): Promise<void> {
  const db = firebaseDb();
  // The rules reject lowercase in any field the card prints in capitals, so
  // normalising here turns a server rejection into a non-event.
  const upper = (v: unknown) => (typeof v === 'string' ? v.toUpperCase() : v);
  await updateDoc(doc(db, 'schools', schoolId, 'entries', entryId), {
    ...patch,
    ...(patch.name !== undefined && { name: upper(patch.name) }),
    ...(patch.fatherName !== undefined && { fatherName: upper(patch.fatherName) }),
    ...(patch.studentClass !== undefined && { studentClass: upper(patch.studentClass) }),
    ...(patch.division !== undefined && { division: upper(patch.division) }),
    ...(patch.rollNumber !== undefined && { rollNumber: upper(patch.rollNumber) }),
    ...(patch.address !== undefined && { address: upper(patch.address) }),
    updatedAt: new Date().toISOString(),
  });
}

export async function deleteEntry(schoolId: string, entryId: string): Promise<void> {
  const db = firebaseDb();
  await deleteDoc(doc(db, 'schools', schoolId, 'entries', entryId));
}

/**
 * The student's full-resolution photo, as a data URI ready for an `<img src>`.
 *
 * Cloud Storage is not provisioned on this Firebase project, so the app sends
 * photos through Firestore instead: a thumbnail on the entry document, and the
 * full frame in its own `media/photo` document. This reads the latter.
 *
 * It is a one-shot read rather than a subscription on purpose. A card portrait
 * never changes once captured - re-capturing writes a new one, but nothing is
 * watching a photo waiting for it to redraw - and the print sheet fetches
 * dozens of these at once, where dozens of live listeners would be pure cost.
 *
 * Returns null when there is no photo document, which is the normal state for
 * an entry submitted before inline photos existed. Callers must render that as
 * "no photo" rather than as a failure.
 */
export async function fetchEntryPhoto(
  schoolId: string,
  entryId: string,
): Promise<string | null> {
  const db = firebaseDb();
  const snap = await getDoc(
    doc(db, 'schools', schoolId, 'entries', entryId, 'media', 'photo'),
  );
  if (!snap.exists()) return null;

  const d = snap.data();
  const data = d.data;
  if (typeof data !== 'string' || data.length === 0) return null;

  const contentType =
    typeof d.contentType === 'string' && d.contentType.startsWith('image/')
      ? d.contentType
      : 'image/jpeg';

  return `data:${contentType};base64,${data}`;
}

// ---------------------------------------------------------------------------
// Accounts
// ---------------------------------------------------------------------------

export function watchUsers(
  onData: (users: ManagedUser[]) => void,
  onError?: (e: Error) => void,
): Unsubscribe {
  const db = firebaseDb();
  return onSnapshot(
    collection(db, 'users'),
    (snap) => onData(snap.docs.map(toManagedUser)),
    (e) => onError?.(e),
  );
}

/**
 * Enables or disables an account.
 *
 * A deactivated account keeps its Auth credentials but loses all data access -
 * `isActive()` gates every rule - so someone can be cut off without deleting
 * their history.
 */
export async function setUserActive(uid: string, active: boolean): Promise<void> {
  const db = firebaseDb();
  await updateDoc(doc(db, 'users', uid), { active });
}

export async function updateUser(
  uid: string,
  patch: Partial<Pick<ManagedUser, 'displayName' | 'schoolId' | 'role'>>,
): Promise<void> {
  const db = firebaseDb();
  await updateDoc(doc(db, 'users', uid), patch);
}

// ---------------------------------------------------------------------------
// Messaging
// ---------------------------------------------------------------------------

export function watchChats(
  adminUid: string,
  onData: (chats: Chat[]) => void,
  onError?: (e: Error) => void,
): Unsubscribe {
  const db = firebaseDb();
  return onSnapshot(
    query(collection(db, 'chats'), where('members', 'array-contains', adminUid)),
    (snap) => {
      const chats = snap.docs.map(toChat);
      chats.sort((a, b) => (b.lastMessageAt ?? '').localeCompare(a.lastMessageAt ?? ''));
      onData(chats);
    },
    (e) => onError?.(e),
  );
}

export function watchMessages(
  chatId: string,
  onData: (messages: ChatMessage[]) => void,
  onError?: (e: Error) => void,
): Unsubscribe {
  const db = firebaseDb();
  return onSnapshot(
    query(collection(db, 'chats', chatId, 'messages'), orderBy('sentAt')),
    (snap) => onData(snap.docs.map((d) => toChatMessage(d, chatId))),
    (e) => onError?.(e),
  );
}

/**
 * Opens a conversation with one school.
 *
 * Only an admin can create a chat - that is the hub-and-spoke rule, enforced at
 * the database. A teacher cannot open one with anyone, so teacher-to-teacher
 * messaging is impossible by construction rather than hidden in the UI.
 */
export async function createChat(
  title: string,
  members: string[],
  schoolId: string | null,
  kind: 'direct' | 'broadcast' = 'direct',
): Promise<string> {
  const db = firebaseDb();
  const ref = await addDoc(collection(db, 'chats'), {
    title,
    members,
    kind,
    schoolId,
    lastMessage: '',
    lastMessageAt: null,
    lastSenderId: null,
    unreadFor: [],
  });
  return ref.id;
}

/**
 * Sends a message and updates the conversation's activity fields.
 *
 * Both writes go in one batch. The rules allow a member to touch exactly these
 * four fields on the chat document and nothing else - `members` stays
 * admin-only, which is what keeps hub-and-spoke intact.
 */
export async function sendMessage(
  chat: Chat,
  senderUid: string,
  senderName: string,
  body: string,
): Promise<void> {
  const db = firebaseDb();
  const text = body.trim();
  if (!text) return;

  const now = new Date().toISOString();
  const batch = writeBatch(db);
  const messageRef = doc(collection(db, 'chats', chat.id, 'messages'));

  batch.set(messageRef, {
    senderId: senderUid,
    senderName,
    sentAt: now,
    body: text,
    kind: 'text',
    attachmentUrl: null,
    attachmentName: null,
    readBy: [senderUid],
  });

  batch.update(doc(db, 'chats', chat.id), {
    lastMessage: text,
    lastMessageAt: now,
    lastSenderId: senderUid,
    unreadFor: chat.members.filter((u) => u !== senderUid),
  });

  await batch.commit();
}

/** Clears the admin's own unread badge on a conversation. */
export async function markChatRead(chatId: string, uid: string): Promise<void> {
  const db = firebaseDb();
  await updateDoc(doc(db, 'chats', chatId), { unreadFor: arrayRemove(uid) });
}

/**
 * Sends one announcement to many operators.
 *
 * Deliberately NOT a fan-out of N private chats: the plan describes an
 * announcement, and N chats would give every recipient a thread they could
 * reply into, which the hub-and-spoke rules do not want. Only the admin may
 * post into a `broadcast`, enforced by the rules.
 */
export async function sendBroadcast(
  title: string,
  bodyText: string,
  recipientUids: string[],
  adminUid: string,
  adminName: string,
): Promise<{ chatId: string; recipients: number }> {
  const db = firebaseDb();
  if (recipientUids.length === 0) {
    throw new Error('Choose at least one recipient.');
  }

  const chatId = await createChat(
    title.trim() || 'Announcement',
    [adminUid, ...recipientUids],
    null,
    'broadcast',
  );

  const now = new Date().toISOString();
  const batch = writeBatch(db);
  const messageRef = doc(collection(db, 'chats', chatId, 'messages'));

  batch.set(messageRef, {
    senderId: adminUid,
    senderName: adminName,
    sentAt: now,
    body: bodyText.trim(),
    kind: 'text',
    attachmentUrl: null,
    attachmentName: null,
    readBy: [adminUid],
  });

  batch.update(doc(db, 'chats', chatId), {
    lastMessage: bodyText.trim(),
    lastMessageAt: now,
    lastSenderId: adminUid,
    unreadFor: recipientUids,
  });

  await batch.commit();
  return { chatId, recipients: recipientUids.length };
}

// ---------------------------------------------------------------------------
// One-shot reads, for exports
// ---------------------------------------------------------------------------

export async function fetchEntriesOnce(schoolId: string): Promise<StudentEntry[]> {
  const db = firebaseDb();
  const snap = await getDocs(collection(db, 'schools', schoolId, 'entries'));
  return snap.docs.map((d) => toStudentEntry(d, schoolId));
}

export const APPROVAL_ORDER: ApprovalStatus[] = [
  'pending',
  'approved',
  'printed',
  'rejected',
];

export { serverTimestamp };
