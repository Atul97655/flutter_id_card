import { describe, expect, it } from 'vitest';

import {
  buildRecord,
  codeMatches,
  decideSend,
  docIdFor,
  generateCode,
  hashCode,
  judgeAttempt,
  looksLikeEmail,
  MAX_ATTEMPTS,
  MAX_SENDS_PER_WINDOW,
  newSalt,
  normaliseEmail,
  OTP_TTL_MS,
  RESEND_COOLDOWN_MS,
  SEND_WINDOW_MS,
  type OtpRecord,
} from './otp';

/**
 * The OTP policy.
 *
 * This is the half of the feature that cannot be checked by looking at it.
 * A code that expires a minute late, a counter that resets when it should
 * not, a window an attacker can step over - none of those show up in a
 * manual test, and all of them are the difference between a six-digit secret
 * being safe and being a formality.
 */

const NOW = Date.UTC(2026, 9, 31, 12, 0, 0);

function record(overrides: Partial<OtpRecord> = {}): OtpRecord {
  const base = buildRecord({
    email: 'teacher@example.com',
    code: '123456',
    now: NOW,
    sendCount: 1,
    windowStartedAt: NOW,
  });
  return { ...base, ...overrides };
}

describe('normalising an address', () => {
  it('trims and lower-cases, because that is how it is looked up', () => {
    expect(normaliseEmail('  Teacher@Example.COM ')).toBe('teacher@example.com');
  });

  it('leaves dots and plus-tags alone', () => {
    // Firebase Auth treats a.b@gmail.com and ab@gmail.com as different
    // accounts. Folding them here would send one person's code to another
    // person's inbox.
    expect(normaliseEmail('a.b+school@gmail.com')).toBe('a.b+school@gmail.com');
  });
});

describe('the shape check', () => {
  it.each([
    'teacher@example.com',
    'a.b+tag@sub.example.co.in',
    'x@y.zz',
  ])('accepts %s', (email) => {
    expect(looksLikeEmail(email)).toBe(true);
  });

  it.each([
    ['no at sign', 'teacher.example.com'],
    ['no dot in the domain', 'teacher@example'],
    ['two at signs', 'a@b@example.com'],
    ['a space', 'teacher @example.com'],
    ['empty', ''],
    ['absurdly long', `${'a'.repeat(250)}@example.com`],
  ])('rejects %s', (_why, email) => {
    expect(looksLikeEmail(email)).toBe(false);
  });
});

describe('the document id', () => {
  it('is a hash, not the address', () => {
    const id = docIdFor('teacher@example.com');
    expect(id).toMatch(/^[0-9a-f]{64}$/);
    expect(id).not.toContain('teacher');
  });

  it('is stable, or nothing could ever be looked up again', () => {
    expect(docIdFor('teacher@example.com')).toBe(docIdFor('teacher@example.com'));
  });

  it('differs between addresses', () => {
    expect(docIdFor('a@example.com')).not.toBe(docIdFor('b@example.com'));
  });
});

describe('the code itself', () => {
  it('is always six digits, including when it is small', () => {
    // The zero-padding matters: 42 must be "000042", or a leading-zero code
    // typed exactly as it was emailed would fail to match.
    for (let i = 0; i < 300; i++) {
      expect(generateCode()).toMatch(/^\d{6}$/);
    }
  });

  it('is not the same code every time', () => {
    const seen = new Set(Array.from({ length: 200 }, () => generateCode()));
    expect(seen.size).toBeGreaterThan(150);
  });
});

describe('hashing', () => {
  it('does not store the code', () => {
    const r = record();
    expect(r.codeHash).not.toContain('123456');
    expect(JSON.stringify(r)).not.toContain('"123456"');
  });

  it('salts, so two identical codes do not share a hash', () => {
    const a = hashCode('123456', newSalt());
    const b = hashCode('123456', newSalt());
    expect(a).not.toBe(b);
  });

  it('matches the right code and rejects a near miss', () => {
    const r = record();
    expect(codeMatches('123456', r)).toBe(true);
    expect(codeMatches('123457', r)).toBe(false);
    expect(codeMatches('', r)).toBe(false);
    expect(codeMatches('1234567', r)).toBe(false);
  });
});

describe('deciding whether to send', () => {
  it('allows the first ever send', () => {
    const d = decideSend(null, NOW);
    expect(d).toEqual({ allowed: true, sendCount: 1, windowStartedAt: NOW });
  });

  it('refuses a second send inside the cooldown', () => {
    const d = decideSend(record(), NOW + 5_000);
    expect(d.allowed).toBe(false);
    if (d.allowed) return;
    expect(d.reason).toBe('cooldown');
    expect(d.retryAfterMs).toBe(RESEND_COOLDOWN_MS - 5_000);
  });

  it('allows one once the cooldown has passed', () => {
    const d = decideSend(record(), NOW + RESEND_COOLDOWN_MS);
    expect(d.allowed).toBe(true);
    if (!d.allowed) return;
    expect(d.sendCount).toBe(2);
  });

  it('refuses once the window allowance is spent', () => {
    const spent = record({
      sendCount: MAX_SENDS_PER_WINDOW,
      lastSentAt: NOW,
      windowStartedAt: NOW - 10 * 60_000,
    });
    const d = decideSend(spent, NOW + RESEND_COOLDOWN_MS);
    expect(d.allowed).toBe(false);
    if (d.allowed) return;
    expect(d.reason).toBe('window');
  });

  it('rolls the window rather than resetting it on a boundary', () => {
    // A fixed window lets somebody wait for the clock to tick over and spend
    // two full allowances back to back. The window has to be measured from
    // the first send in it, so these are set relative to the moment of the
    // check rather than to the last send.
    const checkedAt = NOW + RESEND_COOLDOWN_MS;

    const stillOpen = record({
      sendCount: MAX_SENDS_PER_WINDOW,
      lastSentAt: NOW,
      windowStartedAt: checkedAt - (SEND_WINDOW_MS - 1),
    });
    expect(decideSend(stillOpen, checkedAt).allowed).toBe(false);

    const elapsed = record({
      sendCount: MAX_SENDS_PER_WINDOW,
      lastSentAt: NOW,
      windowStartedAt: checkedAt - SEND_WINDOW_MS,
    });
    const d = decideSend(elapsed, checkedAt);
    expect(d.allowed).toBe(true);
    if (!d.allowed) return;
    expect(d.sendCount).toBe(1);
    expect(d.windowStartedAt).toBe(checkedAt);
  });

  it('keeps counting within a window that is still open', () => {
    const d = decideSend(
      record({ sendCount: 2, lastSentAt: NOW, windowStartedAt: NOW - 60_000 }),
      NOW + RESEND_COOLDOWN_MS,
    );
    expect(d.allowed).toBe(true);
    if (!d.allowed) return;
    expect(d.sendCount).toBe(3);
    expect(d.windowStartedAt).toBe(NOW - 60_000);
  });
});

describe('judging an attempt', () => {
  it('accepts the right code inside the window', () => {
    expect(judgeAttempt(record(), '123456', NOW + 1000)).toEqual({ status: 'ok' });
  });

  it('expires exactly at the deadline, not a tick after', () => {
    const r = record();
    expect(judgeAttempt(r, '123456', r.expiresAt - 1).status).toBe('ok');
    expect(judgeAttempt(r, '123456', r.expiresAt).status).toBe('expired');
  });

  it('expires five minutes out', () => {
    expect(record().expiresAt - NOW).toBe(OTP_TTL_MS);
  });

  it('reports expiry before spending a guess', () => {
    // Otherwise somebody who typed slowly loses an attempt to the clock and
    // is told the code was wrong, which it was not.
    const r = record({ attempts: 0 });
    expect(judgeAttempt(r, '999999', r.expiresAt + 1)).toEqual({
      status: 'expired',
    });
  });

  it('counts down the tries left', () => {
    expect(judgeAttempt(record({ attempts: 0 }), '999999', NOW)).toEqual({
      status: 'wrong',
      attemptsLeft: MAX_ATTEMPTS - 1,
    });
    expect(
      judgeAttempt(record({ attempts: MAX_ATTEMPTS - 1 }), '999999', NOW),
    ).toEqual({ status: 'wrong', attemptsLeft: 0 });
  });

  it('locks at the ceiling, and a correct code cannot unlock it', () => {
    // The guess budget is the whole defence. If the right code still worked
    // after the cap, an attacker would simply keep going.
    const burned = record({ attempts: MAX_ATTEMPTS });
    expect(judgeAttempt(burned, '999999', NOW).status).toBe('locked');
    expect(judgeAttempt(burned, '123456', NOW).status).toBe('locked');
  });
});

describe('a newly issued record', () => {
  it('starts with a clean guess budget', () => {
    // A new code is a different secret. Carrying the old count over would let
    // failed guesses against one code lock out the next one requested.
    const reissued = buildRecord({
      email: 'teacher@example.com',
      code: '654321',
      now: NOW,
      sendCount: 3,
      windowStartedAt: NOW - 120_000,
    });
    expect(reissued.attempts).toBe(0);
    expect(codeMatches('654321', reissued)).toBe(true);
  });

  it('remembers the window it belongs to', () => {
    const r = buildRecord({
      email: 'a@b.cc',
      code: '111111',
      now: NOW,
      sendCount: 3,
      windowStartedAt: NOW - 120_000,
    });
    expect(r.sendCount).toBe(3);
    expect(r.windowStartedAt).toBe(NOW - 120_000);
    expect(r.lastSentAt).toBe(NOW);
  });
});
