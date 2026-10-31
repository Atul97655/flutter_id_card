import { createHash, randomBytes, randomInt, scryptSync, timingSafeEqual } from 'node:crypto';

/**
 * The rules an OTP lives by, written as plain functions over plain values.
 *
 * Everything here is deliberately free of Firebase. The policy - how long a
 * code lasts, how many guesses it survives, how often a new one may be asked
 * for - is the part that is easy to get subtly wrong and nearly impossible to
 * check by hand against a live project, so it is the part that has tests. The
 * Firestore and Auth plumbing lives in index.ts and does as little thinking as
 * it can.
 */

/** How long a code is good for. */
export const OTP_TTL_MS = 5 * 60 * 1000;

/**
 * Wrong guesses allowed before the code is burned.
 *
 * Five, against a six-digit space, leaves a one-in-two-hundred-thousand
 * chance of a blind hit per code. The cap is what makes a short code safe at
 * all: without it, a million guesses walks straight in.
 */
export const MAX_ATTEMPTS = 5;

/** Quiet period between sends to one address. */
export const RESEND_COOLDOWN_MS = 60 * 1000;

/** Sends allowed to one address per window, however patiently spaced. */
export const MAX_SENDS_PER_WINDOW = 5;
export const SEND_WINDOW_MS = 60 * 60 * 1000;

/** The stored side of an outstanding code. */
export interface OtpRecord {
  email: string;
  codeHash: string;
  salt: string;
  expiresAt: number;
  attempts: number;
  /** Sends inside the current window, including this one. */
  sendCount: number;
  /** When the window started, so it can roll rather than reset on every send. */
  windowStartedAt: number;
  lastSentAt: number;
  createdAt: number;
}

/**
 * Lower-cased and trimmed, which is how it is stored, hashed and looked up.
 *
 * Not full RFC-5321 normalisation - no dot-stripping, no plus-tag removal.
 * Those are provider-specific conventions, and treating `a.b@gmail.com` as
 * `ab@gmail.com` would silently merge two accounts that Firebase Auth itself
 * considers distinct.
 */
export function normaliseEmail(raw: string): string {
  return raw.trim().toLowerCase();
}

/**
 * Good enough to be worth sending to.
 *
 * Not an attempt at validating deliverability - nothing short of sending can
 * do that. It rejects the shapes that are certainly wrong so an obvious typo
 * fails fast instead of burning a send.
 */
export function looksLikeEmail(email: string): boolean {
  if (email.length < 6 || email.length > 254) return false;
  if (/\s/.test(email)) return false;
  return /^[^@]+@[^@.]+(\.[^@.]+)+$/.test(email);
}

/**
 * The Firestore document id for an address.
 *
 * Hashed, not the address itself. An email can contain characters Firestore
 * forbids in a document id, and a collection whose ids are readable addresses
 * is a mailing list for anyone who ever gets a listing of it.
 */
export function docIdFor(normalisedEmail: string): string {
  return createHash('sha256').update(normalisedEmail).digest('hex');
}

/** A fresh six-digit code, zero-padded, from the CSPRNG. */
export function generateCode(): string {
  return randomInt(0, 1_000_000).toString().padStart(6, '0');
}

/**
 * scrypt, not SHA-256.
 *
 * A six-digit code has a million possibilities, so a fast hash of one is
 * reversible on a laptop in under a second - the hash would be a formality.
 * scrypt makes each guess cost real time and memory, which is the only thing
 * standing between a leaked copy of this collection and every outstanding
 * code in it.
 */
export function hashCode(code: string, salt: string): string {
  return scryptSync(code, salt, 32).toString('hex');
}

export function newSalt(): string {
  return randomBytes(16).toString('hex');
}

/**
 * Constant-time comparison.
 *
 * `===` on the hex strings would leak, through timing, how many leading
 * characters of the hash a guess got right. That is a thin channel and a real
 * one, and avoiding it costs nothing.
 */
export function codeMatches(code: string, record: Pick<OtpRecord, 'codeHash' | 'salt'>): boolean {
  const candidate = Buffer.from(hashCode(code, record.salt), 'hex');
  const stored = Buffer.from(record.codeHash, 'hex');
  if (candidate.length !== stored.length) return false;
  return timingSafeEqual(candidate, stored);
}

/** Why a send was refused, or that it may go ahead. */
export type SendDecision =
  | { allowed: true; sendCount: number; windowStartedAt: number }
  | { allowed: false; reason: 'cooldown' | 'window'; retryAfterMs: number };

/**
 * Whether a new code may be sent to this address now.
 *
 * Two limits, because they stop different things. The cooldown stops the
 * impatient - a second tap on Resend, or a screen that retries on a dropped
 * response - from spending a send. The window stops a script from using the
 * address as an outbound mail relay all day, which costs real money and gets
 * the sending domain blocked for everybody.
 */
export function decideSend(existing: OtpRecord | null, now: number): SendDecision {
  if (existing === null) {
    return { allowed: true, sendCount: 1, windowStartedAt: now };
  }

  const sinceLast = now - existing.lastSentAt;
  if (sinceLast < RESEND_COOLDOWN_MS) {
    return {
      allowed: false,
      reason: 'cooldown',
      retryAfterMs: RESEND_COOLDOWN_MS - sinceLast,
    };
  }

  // A rolling window, not a fixed one. With a fixed window an attacker waits
  // for the boundary and gets two full allowances back to back.
  const windowAge = now - existing.windowStartedAt;
  if (windowAge >= SEND_WINDOW_MS) {
    return { allowed: true, sendCount: 1, windowStartedAt: now };
  }
  if (existing.sendCount >= MAX_SENDS_PER_WINDOW) {
    return {
      allowed: false,
      reason: 'window',
      retryAfterMs: SEND_WINDOW_MS - windowAge,
    };
  }
  return {
    allowed: true,
    sendCount: existing.sendCount + 1,
    windowStartedAt: existing.windowStartedAt,
  };
}

/** What a verification attempt amounts to. */
export type VerifyOutcome =
  | { status: 'ok' }
  | { status: 'expired' }
  | { status: 'locked' }
  | { status: 'wrong'; attemptsLeft: number };

/**
 * Judges one attempt against the stored record.
 *
 * Order matters and is not arbitrary: expiry is checked before the attempt
 * count so a code that timed out says so rather than quietly eating a guess,
 * and the attempt count is checked before the comparison so a locked record
 * cannot be brute-forced by ignoring the counter.
 */
export function judgeAttempt(
  record: OtpRecord,
  code: string,
  now: number,
): VerifyOutcome {
  if (now >= record.expiresAt) return { status: 'expired' };
  if (record.attempts >= MAX_ATTEMPTS) return { status: 'locked' };
  if (codeMatches(code, record)) return { status: 'ok' };

  const attemptsLeft = MAX_ATTEMPTS - (record.attempts + 1);
  return { status: 'wrong', attemptsLeft: Math.max(0, attemptsLeft) };
}

/** Builds the record to store for a freshly issued code. */
export function buildRecord(args: {
  email: string;
  code: string;
  now: number;
  sendCount: number;
  windowStartedAt: number;
}): OtpRecord {
  const salt = newSalt();
  return {
    email: args.email,
    codeHash: hashCode(args.code, salt),
    salt,
    expiresAt: args.now + OTP_TTL_MS,
    // A new code resets the guess budget. It is a different secret, and
    // carrying the old count over would let a failed guess on one code lock
    // out the next one the person asked for.
    attempts: 0,
    sendCount: args.sendCount,
    windowStartedAt: args.windowStartedAt,
    lastSentAt: args.now,
    createdAt: args.now,
  };
}
