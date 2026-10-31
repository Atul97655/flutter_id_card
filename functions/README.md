# Email OTP sign-in

Two callable Cloud Functions behind "Sign in with a code instead" on the login
screen.

| | |
|---|---|
| `sendOtp` | Issues a six-digit code, stores it hashed, emails it via Resend |
| `verifyOtp` | Checks a code and returns a Firebase **custom token** |

Region: **asia-south1** (Mumbai). It is pinned in two places and they must
agree — `REGION` in `src/index.ts` and `OtpRepository.region` in the Flutter
app. A mismatch does not fail loudly: the client resolves a URL that does not
exist and times out, which looks exactly like a dead connection.

## The policy

| Rule | Value | Where |
|---|---|---|
| Code lifetime | 5 minutes | `OTP_TTL_MS` |
| Wrong guesses allowed | 5, then the code is burned | `MAX_ATTEMPTS` |
| Gap between sends | 60 seconds | `RESEND_COOLDOWN_MS` |
| Sends per address | 5 per rolling hour | `MAX_SENDS_PER_WINDOW` |

All four live in `src/otp.ts` as plain functions over plain values, with
tests in `src/otp.test.ts`. That is deliberate: the policy is the part that
is easy to get subtly wrong and impossible to check by hand against a live
project.

Codes are hashed with **scrypt** and a per-record salt, never stored in the
clear. A six-digit code has a million possibilities, so a fast hash of one is
reversible on a laptop in under a second — the hash would be a formality.

## What it will not tell you

Neither function reveals whether an address has an account. `sendOtp` writes
its record and returns the same response either way, and only actually mails
a code if there is somebody to mail it to. `verifyOtp` answers a correct code
for a non-existent account exactly as it answers a wrong one. Otherwise the
pair is an oracle for "does this person use the app".

Codes **sign in**, they do not sign up. Registration has its own flows with
their own rules about what a new account may write onto itself; creating
accounts here would route around all of it.

## Storage

One collection, `otps`, keyed by `sha256(normalised email)` — hashed because
an email can contain characters Firestore forbids in a document id, and a
collection whose ids are readable addresses is a mailing list for anyone who
gets a listing of it.

`firestore.rules` denies **all** client access to it, including admins. The
functions use the Admin SDK and bypass rules, so denying everything costs the
feature nothing and is the whole of its storage security. A readable hash
turns a six-digit secret into an offline crack; a writable attempt counter
turns the five-guess cap into a suggestion.

## Setup before this can be deployed

Three things, none of which can be done from the repository:

**1. The project must be on the Blaze plan.** Cloud Functions cannot be
deployed on Spark at all. This is the blocker — everything else is minutes.
Blaze is pay-as-you-go with a free tier that this workload sits inside; it
needs a billing account on the Firebase console.

**2. A Resend account with a verified sending domain.** A key alone is not
enough: Resend rejects every message whose `from` is not on a domain you have
verified, and the rejection arrives as a 403 at send time, not at deploy time.

```bash
# The API key, stored as a secret - never in the repository
firebase functions:secrets:set RESEND_API_KEY --project id-cardx

# The sending address, on the verified domain
firebase functions:config:set  # not used - see below
```

`MAIL_FROM` and `APP_NAME` are `defineString` params, so the CLI prompts for
them on first deploy and remembers the answers in `.env.<project>`. The
default `noreply@example.com` will not send anything.

**3. Deploy.**

```bash
firebase deploy --only functions --project id-cardx
```

The rules change ships separately and is needed too:

```bash
firebase deploy --only firestore:rules --project id-cardx
```

## Working on it

```bash
npm install
npm test          # the policy tests - no emulator, no network
npm run typecheck
npm run build
npm run serve     # functions emulator
```

The tests are pure and fast on purpose; there is nothing to start and nothing
to clean up. What they cannot cover is the Firestore transaction and the
Resend call, which is why both are kept as thin as they are in `index.ts`.
