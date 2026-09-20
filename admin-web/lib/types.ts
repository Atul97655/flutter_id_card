import { Timestamp } from 'firebase/firestore';

/**
 * Domain types mirroring the Flutter app's Firestore wire format EXACTLY.
 *
 * These are not a fresh design. Every field name, every enum string and every
 * date encoding is dictated by what `flutter_id_card` already reads and writes,
 * and by the deployed security rules that validate those writes. Changing a
 * name here without changing it there silently desynchronises the two clients.
 *
 * Source of truth, in the Flutter repo:
 *   lib/shared/models/student_entry.dart   (StudentEntry.toFirestoreMap)
 *   lib/shared/models/school_config.dart   (SchoolConfig.toFirestoreMap)
 *   lib/features/auth/domain/managed_user.dart
 *   lib/features/messaging/domain/chat_models.dart
 */

// ---------------------------------------------------------------------------
// Enums - the wire values are exact strings the Flutter enums serialise to.
// ---------------------------------------------------------------------------

/** `ApprovalStatus.name` in Dart. */
export type ApprovalStatus = 'pending' | 'approved' | 'rejected' | 'printed';

export const APPROVAL_STATUSES: ApprovalStatus[] = [
  'pending',
  'approved',
  'rejected',
  'printed',
];

export const APPROVAL_LABELS: Record<ApprovalStatus, string> = {
  pending: 'Pending review',
  approved: 'Approved',
  rejected: 'Rejected',
  printed: 'Printed',
};

/**
 * Only reviewed-and-signed-off work reaches a printer.
 *
 * `printed` stays printable on purpose: reprints are routine (a card is lost, a
 * sheet jams), and excluding them would mean never being able to re-run a batch
 * without flipping every entry back to approved. Mirrors
 * `ApprovalStatus.isPrintable` in Dart.
 */
export const isPrintable = (s: ApprovalStatus): boolean =>
  s === 'approved' || s === 'printed';

/** `UserRole.wireValue` in Dart - note the capitalisation, the rules match on it. */
export type UserRole = 'Admin' | 'Teacher' | 'School';

/** Anything that is not an Admin is an operator, scoped to one school. */
export const isOperator = (r: UserRole): boolean => r !== 'Admin';

export type ChatKind = 'direct' | 'broadcast';
export type MessageKind = 'text' | 'image' | 'document';

// ---------------------------------------------------------------------------
// Student entries
// ---------------------------------------------------------------------------

/**
 * One student's card data, at `schools/{schoolId}/entries/{entryId}`.
 *
 * Dates are ISO-8601 strings, not Firestore Timestamps. That is deliberate in
 * the Flutter app: `dob` is stored date-only so a card printed in one timezone
 * can never show a different birth date than the one that was typed.
 */
export interface StudentEntry {
  id: string;
  schoolId: string;

  name: string;
  fatherName: string;
  studentClass: string;
  division: string;
  /** School register number. Free text - "12/A" and "0034" are both real. */
  rollNumber: string;
  bloodGroup: string;
  /** `yyyy-MM-dd`, or null. */
  dob: string | null;
  mobile: string;
  address: string;

  /**
   * Firebase Storage download URL. Null until the photo uploads - which, until
   * Storage is provisioned on this project, is always. The entry still appears
   * in the review queue; it simply cannot be printed.
   */
  photoUrl: string | null;

  /**
   * Base64 JPEG thumbnail carried on the entry document itself.
   *
   * Cloud Storage is not provisioned on this Firebase project, so photos
   * travel inside Firestore instead: a thumbnail here, and the full frame in
   * `entries/{id}/media/photo`. The split matters because this panel lists
   * every submission across every school in one query - a full photo per row
   * would mean downloading tens of megabytes to render a table of names.
   *
   * Null on entries synced before inline photos landed, and on any entry whose
   * photo has not uploaded yet.
   */
  photoThumb: string | null;

  approvalStatus: ApprovalStatus;
  rejectionReason: string | null;
  reviewedBy: string | null;
  /** ISO-8601 UTC. */
  reviewedAt: string | null;
  createdAt: string | null;
  updatedAt: string | null;
}

export const hasPhoto = (e: StudentEntry): boolean =>
  (typeof e.photoUrl === 'string' && e.photoUrl.length > 0) ||
  (typeof e.photoThumb === 'string' && e.photoThumb.length > 0);

/**
 * An `<img src>` for the entry, or null if there is no picture to show.
 *
 * Prefers the Storage URL when one exists - it is the full frame and the
 * browser caches it - and falls back to the inline thumbnail. Callers that
 * need full resolution (the card preview, the print sheet) fetch the media
 * document instead; this is for avatars and list rows.
 */
export const photoSrc = (e: StudentEntry): string | null => {
  if (typeof e.photoUrl === 'string' && e.photoUrl.length > 0) return e.photoUrl;
  if (typeof e.photoThumb === 'string' && e.photoThumb.length > 0) {
    return `data:image/jpeg;base64,${e.photoThumb}`;
  }
  return null;
};

/** What the print path requires: signed off AND carrying a photo. */
export const isReadyToPrint = (e: StudentEntry): boolean =>
  isPrintable(e.approvalStatus) && hasPhoto(e);

// ---------------------------------------------------------------------------
// Schools
// ---------------------------------------------------------------------------

/**
 * Per-school configuration at `schools/{schoolId}`.
 *
 * Colours are stored as hex STRINGS (`#RRGGBB` or `AARRGGBB`) so they stay
 * legible and editable straight from the Firestore console.
 */
export interface SchoolConfig {
  id: string;
  name: string;
  addressLine: string;
  contactLine: string;
  logoUrl: string | null;
  principalSignatureUrl: string | null;

  cardSizeId: string;
  templateId: string;

  /** `StudentField.key` values that this school's form renders. */
  enabledFields: string[];
  classes: string[];
  divisions: string[];

  primaryColor: string;
  secondaryColor: string;
  headerColor: string;
  photoBackground: string;

  /** Division -> hex. Several schools issue one colour per division. */
  divisionColors: Record<string, string>;

  updatedAt: string | null;
}

export const CARD_SIZES: { id: string; label: string }[] = [
  { id: 'v52x84', label: '52 x 84 mm (Vertical)' },
  { id: 'v54x86', label: '54 x 86 mm (Vertical)' },
  { id: 'v56x88', label: '56 x 88 mm (Vertical)' },
  { id: 'h84x52', label: '84 x 52 mm (Horizontal)' },
  { id: 'h86x54', label: '86 x 54 mm (Horizontal)' },
  { id: 'h88x56', label: '88 x 56 mm (Horizontal)' },
];

export const TEMPLATES: { id: string; label: string; note?: string }[] = [
  { id: 'default_vertical', label: 'Default vertical' },
  { id: 'default_horizontal', label: 'Default horizontal' },
  { id: 'div_badge_vertical', label: 'Division badge vertical' },
  { id: 'side_panel_horizontal', label: 'Side panel horizontal' },
  { id: 'framed_vertical', label: 'Framed vertical' },
];

/**
 * Every field the card can carry, in print order.
 *
 * Mirrors the `StudentField` enum. `name` and `photo` are alwaysEnabled in
 * Dart - a card with neither is not an ID card - so they are not offered as
 * toggles here either.
 */
export const STUDENT_FIELDS: {
  key: keyof StudentEntry | 'photo';
  label: string;
  locked?: boolean;
}[] = [
  { key: 'name', label: 'Name', locked: true },
  { key: 'fatherName', label: "Father's Name" },
  { key: 'studentClass', label: 'Class' },
  { key: 'division', label: 'Div' },
  { key: 'rollNumber', label: 'Roll No' },
  { key: 'bloodGroup', label: 'Blood Group' },
  { key: 'dob', label: 'DOB' },
  { key: 'mobile', label: 'Mobile No' },
  { key: 'address', label: 'Address' },
  { key: 'photo', label: 'Photo', locked: true },
];

// ---------------------------------------------------------------------------
// Accounts
// ---------------------------------------------------------------------------

/**
 * `users/{uid}` - keyed by the Firebase Auth UID, never an auto-id.
 *
 * The security rules look users up by `request.auth.uid`. A document with any
 * other id cannot be found, and every request from that account is denied.
 */
export interface ManagedUser {
  uid: string;
  email: string;
  role: UserRole;
  schoolId: string | null;
  displayName: string;
  active: boolean;
  /** Firestore Timestamps here, unlike entries. */
  lastLoginDate: Timestamp | null;
  createdAt: Timestamp | null;
}

// ---------------------------------------------------------------------------
// Messaging
// ---------------------------------------------------------------------------

export interface Chat {
  id: string;
  title: string;
  /** Auth UIDs. The rules gate every read and write on membership. */
  members: string[];
  kind: ChatKind;
  schoolId: string | null;
  lastMessage: string;
  lastMessageAt: string | null;
  lastSenderId: string | null;
  /** UIDs that have not opened it. Shrinks as people read. */
  unreadFor: string[];
}

/**
 * Panel-wide settings, at `config/panel`.
 *
 * One document rather than a field on each school: whether this office prints
 * cards at all is a property of the installation, not of a school.
 */
export interface PanelConfig {
  /**
   * Whether the card-printing feature is part of this installation.
   *
   * Off hides the Print Center, the print-readiness tiles and every "cannot
   * be printed" warning - which are otherwise permanent alarms about a job
   * nobody is doing. Nothing is deleted: the sheet pipeline, the print batch
   * history and the underlying data are untouched, so turning it back on
   * restores the feature exactly as it was.
   *
   * Defaults to true, so an installation that never sets it behaves as it
   * always has.
   */
  printingEnabled: boolean;
}

export const DEFAULT_PANEL_CONFIG: PanelConfig = { printingEnabled: true };

export interface ChatMessage {
  id: string;
  chatId: string;
  senderId: string;
  senderName: string;
  sentAt: string | null;
  body: string;
  kind: MessageKind;
  attachmentUrl: string | null;
  attachmentName: string | null;

  /**
   * Base64 JPEG preview, carried on the message when the attachment travels
   * inside Firestore rather than through Cloud Storage - which on this
   * project is always, because the bucket has never existed. The full file
   * lives in the message's `media/file` document.
   */
  attachmentThumb: string | null;

  /** The attachment is in Firestore, not Storage. */
  attachmentInline: boolean;

  attachmentBytes: number | null;

  readBy: string[];
}

/** Whether there is anything attached, by either route. */
export const messageHasAttachment = (m: ChatMessage): boolean =>
  (typeof m.attachmentUrl === 'string' && m.attachmentUrl.length > 0) ||
  m.attachmentInline;

/**
 * An `<img src>` for the bubble preview, or null if there is nothing to draw.
 *
 * Prefers the Storage URL - it is the full frame and the browser caches it -
 * and falls back to the inline thumbnail.
 */
export const messagePreviewSource = (m: ChatMessage): string | null => {
  if (typeof m.attachmentUrl === 'string' && m.attachmentUrl.length > 0) {
    return m.attachmentUrl;
  }
  if (typeof m.attachmentThumb === 'string' && m.attachmentThumb.length > 0) {
    return `data:image/jpeg;base64,${m.attachmentThumb}`;
  }
  return null;
};

/** Recipients of a broadcast, excluding the admin who sent it. */
export const recipientCount = (c: Chat, senderUid: string): number =>
  c.members.filter((u) => u !== senderUid).length;

/**
 * How many recipients have opened an announcement.
 *
 * The only honest measure of "delivery" for a broadcast: writing it is one
 * atomic batch, so it lands for everyone or nobody and there is no
 * per-recipient send failure to count.
 */
export const readCount = (c: Chat, senderUid: string): number => {
  const total = recipientCount(c, senderUid);
  const unread = c.unreadFor.filter((u) => u !== senderUid).length;
  return Math.min(Math.max(total - unread, 0), total);
};
