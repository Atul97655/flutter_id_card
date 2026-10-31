import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineSecret, defineString } from 'firebase-functions/params';
import { logger } from 'firebase-functions';

import { buildOtpEmail, EmailSendError, sendViaResend } from './email';
import {
  buildRecord,
  decideSend,
  docIdFor,
  generateCode,
  judgeAttempt,
  looksLikeEmail,
  MAX_ATTEMPTS,
  normaliseEmail,
  OTP_TTL_MS,
  type OtpRecord,
} from './otp';

initializeApp();

/**
 * Email one-time-code sign-in.
 *
 * Two callables. `sendOtp` issues a code and mails it; `verifyOtp` checks one
 * and hands back a Firebase custom token the app exchanges for a session.
 *
 * ## Why this is on the server at all
 *
 * Every part of it has to be somewhere the phone cannot reach. The code is
 * stored hashed, the attempt counter has to be unforgeable, the rate limit
 * has to hold across devices, and minting a credential is by definition
 * privileged. A client-side version of this is not a weaker version of the
 * same thing - it is not the same thing.
 *
 * ## What it will not tell you
 *
 * Neither function ever reveals whether an address has an account. `sendOtp`
 * writes the record and returns the same shape either way, and only actually
 * mails a code if there is somebody to mail it to; `verifyOtp` answers a
 * correct code for a non-existent account exactly as it answers a wrong one.
 * Otherwise this pair is an oracle for "does this person use the app", which
 * is not ours to publish.
 *
 * ## Sign-in, not sign-up
 *
 * A code only ever signs in an account that already exists. Registration has
 * its own flows, with their own rules about what a new account may write onto
 * itself, and quietly creating accounts here would route around all of it.
 */

/** Resend's API key. Set with: firebase functions:secrets:set RESEND_API_KEY */
const resendApiKey = defineSecret('RESEND_API_KEY');

/** Must be on a domain verified in Resend. */
const mailFrom = defineString('MAIL_FROM', {
  default: 'ID entity <noreply@example.com>',
});

const appName = defineString('APP_NAME', { default: 'ID entity' });

/**
 * Mumbai. The schools are in India, and the default (us-central1) puts an
 * avoidable third of a second of round trip in front of somebody standing in
 * a school office waiting to sign in.
 */
const REGION = 'asia-south1';

const OTP_COLLECTION = 'otps';

export const sendOtp = onCall(
  { region: REGION, secrets: [resendApiKey], cors: false },
  async (request) => {
    const rawEmail = (request.data as { email?: unknown } | null)?.email;
    if (typeof rawEmail !== 'string') {
      throw new HttpsError('invalid-argument', 'An email address is required.');
    }

    const email = normaliseEmail(rawEmail);
    if (!looksLikeEmail(email)) {
      throw new HttpsError(
        'invalid-argument',
        'That does not look like an email address.',
      );
    }

    const db = getFirestore();
    const ref = db.collection(OTP_COLLECTION).doc(docIdFor(email));
    const now = Date.now();

    // The read, the decision and the write are one transaction. Two taps on
    // Resend arriving together would otherwise both read the old record, both
    // decide they are allowed, and both send - which is exactly the thing the
    // cooldown exists to prevent.
    const issued = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const existing = snap.exists ? (snap.data() as OtpRecord) : null;

      const decision = decideSend(existing, now);
      if (!decision.allowed) {
        return { sent: false as const, decision };
      }

      const code = generateCode();
      const record = buildRecord({
        email,
        code,
        now,
        sendCount: decision.sendCount,
        windowStartedAt: decision.windowStartedAt,
      });
      tx.set(ref, record);
      return { sent: true as const, code };
    });

    if (!issued.sent) {
      const seconds = Math.ceil(issued.decision.retryAfterMs / 1000);
      throw new HttpsError(
        'resource-exhausted',
        issued.decision.reason === 'cooldown'
          ? `Wait ${seconds} seconds before asking for another code.`
          : 'Too many codes requested for this address. Try again later.',
        { retryAfterSeconds: seconds },
      );
    }

    // Only now do we look the account up, and the answer never leaves the
    // server. A missing account means no email goes out; the caller sees the
    // same response either way.
    const recipientExists = await userExists(email);
    if (recipientExists) {
      const message = buildOtpEmail({
        code: issued.code,
        appName: appName.value(),
        ttlMinutes: Math.round(OTP_TTL_MS / 60000),
      });
      try {
        await sendViaResend({
          config: {
            apiKey: resendApiKey.value(),
            from: mailFrom.value(),
            appName: appName.value(),
          },
          to: email,
          ...message,
        });
      } catch (error) {
        // The record is rolled back. Leaving it would hold the address in
        // cooldown for a code that is sitting in a database and nowhere else
        // - the person would be locked out for a minute by our failure.
        await ref.delete().catch(() => undefined);
        const status = error instanceof EmailSendError ? error.status : 0;
        logger.error('OTP email failed', { status });
        throw new HttpsError(
          'unavailable',
          'Could not send the code just now. Try again in a moment.',
        );
      }
    } else {
      logger.info('OTP requested for an address with no account');
    }

    return {
      sent: true,
      expiresInSeconds: Math.round(OTP_TTL_MS / 1000),
      resendInSeconds: 60,
    };
  },
);

export const verifyOtp = onCall(
  { region: REGION, cors: false },
  async (request) => {
    const data = request.data as { email?: unknown; code?: unknown } | null;
    if (typeof data?.email !== 'string' || typeof data?.code !== 'string') {
      throw new HttpsError(
        'invalid-argument',
        'An email address and a code are required.',
      );
    }

    const email = normaliseEmail(data.email);
    const code = data.code.trim();
    if (!looksLikeEmail(email) || !/^\d{6}$/.test(code)) {
      throw new HttpsError('invalid-argument', 'That code is not valid.');
    }

    const db = getFirestore();
    const ref = db.collection(OTP_COLLECTION).doc(docIdFor(email));
    const now = Date.now();

    // Transactional for the same reason as the send, and one more: the
    // attempt counter is the only thing making a six-digit secret safe. Two
    // guesses racing each other outside a transaction would each read the
    // same count and each write count+1, so the budget never moves.
    const outcome = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return { status: 'missing' as const };

      const record = snap.data() as OtpRecord;
      const verdict = judgeAttempt(record, code, now);

      if (verdict.status === 'ok' || verdict.status === 'expired' || verdict.status === 'locked') {
        // Burned either way. A correct code is single-use; an expired or
        // exhausted one has nothing left to offer and should not sit around.
        tx.delete(ref);
      } else {
        tx.update(ref, { attempts: record.attempts + 1 });
      }
      return verdict;
    });

    switch (outcome.status) {
      case 'missing':
        throw new HttpsError(
          'not-found',
          'That code has expired. Ask for a new one.',
        );
      case 'expired':
        throw new HttpsError(
          'deadline-exceeded',
          'That code has expired. Ask for a new one.',
        );
      case 'locked':
        throw new HttpsError(
          'resource-exhausted',
          `Too many wrong attempts. Ask for a new code.`,
        );
      case 'wrong':
        throw new HttpsError(
          'permission-denied',
          outcome.attemptsLeft > 0
            ? `That code is not right. ${outcome.attemptsLeft} ${
                outcome.attemptsLeft === 1 ? 'try' : 'tries'
              } left.`
            : 'Too many wrong attempts. Ask for a new code.',
          { attemptsLeft: outcome.attemptsLeft, maxAttempts: MAX_ATTEMPTS },
        );
      case 'ok':
        break;
    }

    const uid = await uidFor(email);
    if (uid === null) {
      // Correct code, no account. Answered exactly as a wrong code is, so
      // the pair cannot be used to test which addresses are registered.
      throw new HttpsError(
        'permission-denied',
        'That code is not right. Ask for a new one.',
      );
    }

    const token = await getAuth().createCustomToken(uid, { signIn: 'otp' });
    return { token };
  },
);

async function userExists(email: string): Promise<boolean> {
  return (await uidFor(email)) !== null;
}

async function uidFor(email: string): Promise<string | null> {
  try {
    return (await getAuth().getUserByEmail(email)).uid;
  } catch {
    return null;
  }
}
