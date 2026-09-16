# ID entity — Admin panel

Web dashboard for the ID entity school ID card system. Reviews submissions,
records print runs, manages school configuration and accounts, and messages
the schools that submit cards.

It talks to the **same Firestore documents** as the Flutter mobile app. There
is no separate backend and no API layer between them: Firebase is the backend,
and the deployed security rules are what authorise every read and write.

## Running it

```bash
npm install
cp .env.example .env.local   # then fill in the Firebase web config
npm run dev
```

Sign in with an **admin** account. The panel reads `users/{uid}.role` from
Firestore to decide what to render; operators are told to use the mobile app
instead of being shown an empty dashboard.

`.env.local` holds the Firebase web config. Those keys are public by design —
they identify the project, they do not grant access. What protects the data is
`firebase/firestore.rules` in the Flutter repo.

## Stack

| | |
|---|---|
| Framework | Next.js 16 (App Router), React 19 |
| Styling | Tailwind CSS 4 |
| Data | Firebase Web SDK 12 — Firestore live subscriptions |
| Motion | Framer Motion |

## Layout

```
app/(dash)/        one folder per page, all behind the auth gate
components/ui/     shared primitives and the motion vocabulary
components/layout/ sidebar, topbar, auth gate
lib/types.ts       domain types mirroring the Dart wire format
lib/converters.ts  Firestore -> domain, defensively
lib/data.ts        all reads and writes
lib/store.tsx      one live mirror of the dataset, shared by every page
```

## Two things worth knowing before changing anything

**`lib/types.ts` is not a free design.** Every field name, enum string and
date encoding is dictated by what the Flutter app already writes and by the
rules that validate those writes. Renaming something here without renaming it
there silently desynchronises the two clients.

**Reads are deliberately defensive.** These documents are written by a
different client whose version may be older or newer than this panel. A
missing or misshapen field must render as empty, never crash the dashboard.
An unrecognised `approvalStatus` degrades to `pending`, an unrecognised role
to the lowest privilege, an unrecognised chat kind to `direct` — never to
anything privileged.

## Known limitation: photos

Cloud Storage is not provisioned on the Firebase project, so no student photo
has ever reached the server. The panel shows every submission and its details,
and flags approved cards that cannot be printed because they have no photo.

Enabling Storage (which needs the Blaze plan) clears this with no re-entry —
the mobile app has been holding each photo and retrying.

## What is deliberately not here

**Creating accounts.** It needs a Firebase Auth user *and* a matching
`users/{uid}` document keyed by that user's UID. The client SDK's
`createUser` signs the caller out of their own session, so doing it from a
browser would log the admin out. The mobile app already does it correctly.

**Generating print sheets.** The Flutter app owns the millimetre-accurate PDF
pipeline. A card specified as 54 × 86 mm has to measure 54 × 86 mm under a
ruler, and two implementations of that is one too many. This panel shows what
is ready and records that a batch was printed.
