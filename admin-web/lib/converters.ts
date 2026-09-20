import { Timestamp, type DocumentData, type QueryDocumentSnapshot } from 'firebase/firestore';
import type {
  ApprovalStatus,
  Chat,
  ChatKind,
  ChatMessage,
  ManagedUser,
  MessageKind,
  SchoolConfig,
  StudentEntry,
  UserRole,
} from './types';

/**
 * Firestore -> domain mapping.
 *
 * Every reader here is defensive on purpose. Firestore hands back whatever is
 * in the document, and these documents are written by a different client (the
 * Flutter app) whose version may be older or newer than this panel. A missing
 * or misshapen field must render as an empty value, never crash the dashboard
 * - the same rule the Dart `fromFirestoreMap` helpers follow.
 */

const str = (v: unknown, fallback = ''): string =>
  typeof v === 'string' ? v : fallback;

const strOrNull = (v: unknown): string | null =>
  typeof v === 'string' && v.length > 0 ? v : null;

const bool = (v: unknown, fallback = false): boolean =>
  typeof v === 'boolean' ? v : fallback;

const strList = (v: unknown): string[] =>
  Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : [];

const ts = (v: unknown): Timestamp | null => (v instanceof Timestamp ? v : null);

/**
 * Dates arrive as ISO strings from the Flutter app, but a document touched
 * from the Firebase console may carry a real Timestamp instead. Normalise both
 * to ISO so the UI has one thing to format.
 */
const isoDate = (v: unknown): string | null => {
  if (typeof v === 'string' && v.length > 0) return v;
  if (v instanceof Timestamp) return v.toDate().toISOString();
  return null;
};

const APPROVALS: ApprovalStatus[] = ['pending', 'approved', 'rejected', 'printed'];

/**
 * An unrecognised status falls back to `pending`, never to something
 * privileged. A value written by a newer build must not let unreviewed work
 * look approved - "needs review" is the only safe default.
 */
const approval = (v: unknown): ApprovalStatus =>
  APPROVALS.includes(v as ApprovalStatus) ? (v as ApprovalStatus) : 'pending';

/** Least privilege: anything unrecognised is an operator, never an Admin. */
const role = (v: unknown): UserRole => {
  const raw = str(v).trim().toLowerCase();
  if (raw === 'admin') return 'Admin';
  if (raw === 'teacher') return 'Teacher';
  return 'School';
};

/** Broadcast is the privileged shape; only an exact match earns it. */
const chatKind = (v: unknown): ChatKind => (v === 'broadcast' ? 'broadcast' : 'direct');

const messageKind = (v: unknown): MessageKind =>
  v === 'image' || v === 'document' ? (v as MessageKind) : 'text';

// ---------------------------------------------------------------------------

export function toStudentEntry(
  snap: QueryDocumentSnapshot<DocumentData>,
  schoolId: string,
): StudentEntry {
  const d = snap.data();
  return {
    id: snap.id,
    schoolId: str(d.schoolId, schoolId),
    name: str(d.name),
    fatherName: str(d.fatherName),
    studentClass: str(d.studentClass),
    division: str(d.division),
    rollNumber: str(d.rollNumber),
    bloodGroup: str(d.bloodGroup),
    dob: strOrNull(d.dob),
    mobile: str(d.mobile),
    address: str(d.address),
    photoUrl: strOrNull(d.photoUrl),
    photoThumb: strOrNull(d.photoThumb),
    approvalStatus: approval(d.approvalStatus),
    rejectionReason: strOrNull(d.rejectionReason),
    reviewedBy: strOrNull(d.reviewedBy),
    reviewedAt: isoDate(d.reviewedAt),
    createdAt: isoDate(d.createdAt),
    updatedAt: isoDate(d.updatedAt),
  };
}

export function toSchoolConfig(
  snap: QueryDocumentSnapshot<DocumentData>,
): SchoolConfig {
  const d = snap.data();

  const colours: Record<string, string> = {};
  const raw = d.divisionColors;
  if (raw && typeof raw === 'object') {
    for (const [k, v] of Object.entries(raw as Record<string, unknown>)) {
      if (typeof v === 'string') colours[k.trim().toUpperCase()] = v;
    }
  }

  return {
    id: snap.id,
    name: str(d.name, 'SCHOOL'),
    addressLine: str(d.addressLine),
    contactLine: str(d.contactLine),
    logoUrl: strOrNull(d.logoUrl),
    principalSignatureUrl: strOrNull(d.principalSignatureUrl),
    cardSizeId: str(d.cardSizeId, 'v54x86'),
    templateId: str(d.templateId, 'default_vertical'),
    enabledFields: strList(d.enabledFields),
    classes: strList(d.classes),
    divisions: strList(d.divisions),
    primaryColor: str(d.primaryColor, '#D32F2F'),
    secondaryColor: str(d.secondaryColor, '#1565C0'),
    headerColor: str(d.headerColor, '#1565C0'),
    photoBackground: str(d.photoBackground, '#FFFFFF'),
    divisionColors: colours,
    updatedAt: isoDate(d.updatedAt),
  };
}

export function toManagedUser(
  snap: QueryDocumentSnapshot<DocumentData>,
): ManagedUser {
  const d = snap.data();
  return {
    uid: snap.id,
    email: str(d.email),
    role: role(d.role),
    schoolId: strOrNull(d.schoolId),
    displayName: str(d.displayName),
    // Absent means active: an account created before this field existed must
    // not silently lose access.
    active: bool(d.active, true),
    lastLoginDate: ts(d.lastLoginDate),
    createdAt: ts(d.createdAt),
  };
}

export function toChat(snap: QueryDocumentSnapshot<DocumentData>): Chat {
  const d = snap.data();
  return {
    id: snap.id,
    title: str(d.title, 'Conversation'),
    members: strList(d.members),
    kind: chatKind(d.kind),
    schoolId: strOrNull(d.schoolId),
    lastMessage: str(d.lastMessage),
    lastMessageAt: isoDate(d.lastMessageAt),
    lastSenderId: strOrNull(d.lastSenderId),
    unreadFor: strList(d.unreadFor),
  };
}

export function toChatMessage(
  snap: QueryDocumentSnapshot<DocumentData>,
  chatId: string,
): ChatMessage {
  const d = snap.data();
  return {
    id: snap.id,
    chatId,
    senderId: str(d.senderId),
    senderName: str(d.senderName, 'Unknown'),
    sentAt: isoDate(d.sentAt),
    body: str(d.body),
    kind: messageKind(d.kind),
    attachmentUrl: strOrNull(d.attachmentUrl),
    attachmentName: strOrNull(d.attachmentName),
    attachmentThumb: strOrNull(d.attachmentThumb),
    attachmentInline: d.attachmentInline === true,
    attachmentBytes:
      typeof d.attachmentBytes === 'number' ? d.attachmentBytes : null,
    readBy: strList(d.readBy),
  };
}

/**
 * Colours are stored as `#RRGGBB` or `AARRGGBB` depending on which client last
 * wrote them. Normalise to a CSS-usable `#RRGGBB`.
 */
export function toCssColor(hex: string, fallback = '#1565C0'): string {
  const clean = hex.replace('#', '').trim();
  if (clean.length === 8) return `#${clean.slice(2)}`;
  if (clean.length === 6) return `#${clean}`;
  return fallback;
}
