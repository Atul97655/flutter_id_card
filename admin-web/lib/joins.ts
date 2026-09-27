'use client';

import {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  onSnapshot,
  query,
  setDoc,
  updateDoc,
  where,
  writeBatch,
  type Unsubscribe,
} from 'firebase/firestore';
import { firebaseDb } from './firebase';
import { toJoinCode, toJoinRequest } from './converters';
import type { JoinCode, JoinRequest, TeacherAssignment } from './types';

/**
 * QR join codes and the pending list they feed.
 *
 * Kept out of `data.ts` because it is a different lifecycle: everything here
 * is about accounts that do not yet have access, whereas `data.ts` reads and
 * writes the records of schools that do. The security boundary runs between
 * the two, so the seam is worth keeping visible.
 */

/**
 * The alphabet used for a join code.
 *
 * No `0`/`O`, no `1`/`l`/`I`. A code is printed, pinned to a noticeboard and
 * typed in by hand when the camera will not focus, so the characters people
 * reliably confuse with each other are simply not in it.
 */
const TOKEN_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';

/**
 * A fresh join token.
 *
 * `crypto.getRandomValues` rather than `Math.random`: this is the only thing
 * standing between a stranger and a school's pending list, and a predictable
 * token would make the pending list reachable by guesswork. 10 characters of
 * this alphabet is about 57 bits, which is far past guessable and still
 * short enough to read off a printed sheet.
 */
export function generateJoinToken(length = 10): string {
  const bytes = new Uint32Array(length);
  crypto.getRandomValues(bytes);
  let out = '';
  for (let i = 0; i < length; i += 1) {
    out += TOKEN_ALPHABET[bytes[i] % TOKEN_ALPHABET.length];
  }
  return out;
}

/** Every pending join, newest school first. Admin-only, per the rules. */
export function watchJoinRequests(
  onData: (requests: JoinRequest[]) => void,
  onError: (e: Error) => void,
): Unsubscribe {
  return onSnapshot(
    query(collectionGroup(firebaseDb(), 'joinRequests'), where('status', '==', 'pending')),
    (snap) => onData(snap.docs.map(toJoinRequest)),
    onError,
  );
}

/** The live code for one school, if it has one. */
export function watchJoinCode(
  schoolId: string,
  onData: (code: JoinCode | null) => void,
  onError: (e: Error) => void,
): Unsubscribe {
  return onSnapshot(
    // A plain collection query, not a collection group: `joinCodes` is a
    // root collection, and the `list` rule that permits this is written on
    // `/joinCodes/{token}` for admins only.
    query(collection(firebaseDb(), 'joinCodes'), where('schoolId', '==', schoolId)),
    (snap) => onData(snap.empty ? null : toJoinCode(snap.docs[0])),
    onError,
  );
}

export async function fetchJoinCode(token: string): Promise<JoinCode | null> {
  const snap = await getDoc(doc(firebaseDb(), 'joinCodes', token));
  if (!snap.exists()) return null;
  return toJoinCode(snap);
}

/**
 * Issues a new code for a school, retiring whichever one it had.
 *
 * Both writes go in one batch so the school can never briefly have two live
 * codes or none. Retiring is a delete, which is what makes every printed
 * copy of the old code stop resolving the moment this returns - the point of
 * the "issue a new code" button on A8.
 *
 * Teachers who already joined are not touched. Their access hangs off
 * `users/{uid}.schoolId`, which never references a token.
 */
export async function issueJoinCode(
  schoolId: string,
  schoolName: string,
  previousToken: string | null,
): Promise<string> {
  const token = generateJoinToken();
  const batch = writeBatch(firebaseDb());

  if (previousToken) {
    batch.delete(doc(firebaseDb(), 'joinCodes', previousToken));
  }
  batch.set(doc(firebaseDb(), 'joinCodes', token), {
    schoolId,
    schoolName,
    issuedAt: new Date().toISOString(),
  });

  await batch.commit();
  return token;
}

/**
 * Approves a pending teacher and scopes them to a section.
 *
 * Two documents, one batch, and the ORDER of what they do matters more than
 * it looks. `users/{uid}.schoolId` is the field every read rule in this
 * project reaches a school through - writing it is what actually grants
 * access, and nothing else here does. The join request is only bookkeeping
 * for the office's list.
 *
 * Batched so the two can never disagree: an account with access but no
 * recorded assignment would read the whole school, and an assignment with no
 * access would be a teacher who has been told they are approved and can see
 * nothing.
 */
export async function approveJoin(
  request: JoinRequest,
  classLevel: string,
  division: string,
  approvedBy: string,
): Promise<void> {
  const assignment: TeacherAssignment = {
    schoolId: request.schoolId,
    classLevel,
    division,
    status: 'active',
  };

  const batch = writeBatch(firebaseDb());
  batch.update(doc(firebaseDb(), 'users', request.uid), {
    schoolId: request.schoolId,
    assignment,
    assignedBy: approvedBy,
    assignedAt: new Date().toISOString(),
  });
  batch.delete(
    doc(firebaseDb(), 'schools', request.schoolId, 'joinRequests', request.uid),
  );

  await batch.commit();
}

/**
 * Declines a pending join.
 *
 * Deletes the request rather than marking it declined, because the design
 * says a decline is not a ban - the teacher can scan again if it was a
 * mistake, and a tombstone row would block that. Nothing is written to the
 * user document, so the account keeps exactly the access it had, which is
 * none.
 */
export async function declineJoin(request: JoinRequest): Promise<void> {
  await deleteDoc(
    doc(firebaseDb(), 'schools', request.schoolId, 'joinRequests', request.uid),
  );
}

/**
 * Moves an already-approved teacher to a different section.
 *
 * Existing submissions are not moved. A card records the section it was
 * filed under at the time, and rewriting history because a teacher changed
 * class would make last term's cards wrong.
 */
export async function assignSection(
  uid: string,
  schoolId: string,
  classLevel: string,
  division: string,
  assignedBy: string,
): Promise<void> {
  const assignment: TeacherAssignment = {
    schoolId,
    classLevel,
    division,
    status: 'active',
  };
  await updateDoc(doc(firebaseDb(), 'users', uid), {
    schoolId,
    assignment,
    assignedBy,
    assignedAt: new Date().toISOString(),
  });
}

/**
 * Removes a teacher's section scope, returning them to the whole school.
 *
 * Deliberately sets the assignment to null rather than deleting the field,
 * so the panel can tell "never assigned" from "assignment cleared" if that
 * distinction is ever needed. The rules read both as unscoped.
 */
export async function clearSection(uid: string): Promise<void> {
  await updateDoc(doc(firebaseDb(), 'users', uid), { assignment: null });
}

/** Used by the QR page to seed a code for a school that has never had one. */
export async function ensureJoinCode(
  schoolId: string,
  schoolName: string,
  existing: JoinCode | null,
): Promise<string> {
  if (existing) return existing.token;
  const token = generateJoinToken();
  await setDoc(doc(firebaseDb(), 'joinCodes', token), {
    schoolId,
    schoolName,
    issuedAt: new Date().toISOString(),
  });
  return token;
}
