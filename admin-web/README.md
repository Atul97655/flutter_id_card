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

**Student photos.** Cloud Storage is not provisioned on this Firebase project,
so photos travel inside Firestore: a ~4 KB base64 thumbnail on the entry
document, and the full frame in `entries/{id}/media/photo`. `EntryPhoto`
renders the thumbnail immediately everywhere, and fetches the full frame only
where one is actually needed (the review screen). List rows deliberately do
not — one extra read and tens of kilobytes per name, for a picture drawn at
36 px, is how you make a table of submissions expensive to open.

Entries submitted before this shipped have no photo on the server at all. They
are not lost and need no re-entry: the phone that captured each one sends its
photo up by itself on the next sync. Until then they show as "No photo yet".

**Generating print sheets.** The Flutter app owns the millimetre-accurate PDF
pipeline. A card specified as 54 × 86 mm has to measure 54 × 86 mm under a
ruler, and two implementations of that is one too many. This panel shows what
is ready and records that a batch was printed.

## Why this lives in the Flutter repo

This directory is the source of truth and is **also** published to a second
repository, `ID-entity-website`, which is what Vercel builds. That looked like
accidental duplication worth cleaning up; it is not, and deleting it here would
break deployment.

The two are kept in step with a subtree split, not a copy:

```bash
git subtree split --prefix=admin-web -b deploy
git push https://github.com/<owner>/ID-entity-website.git deploy:main
git branch -D deploy
```

The split rewrites this directory's history as if it were its own repository,
so the website repo gets real commits rather than a dump, and Vercel's Root
Directory stays `.`.

Keeping the source here is deliberate. The panel and the app share one wire
format - `lib/types.ts` mirrors `StudentEntry` in Dart field for field - and a
change to one that forgets the other is the single most likely way to break
this system. In one repository that is one commit and one review. Split across
two it is two, and nothing makes them happen together.

## Deployment

Hosted on Vercel as **`id-entity-admin`** under the `scorp-i-on` account,
connected to this repository so a push to `main` deploys by itself. Vercel's
Root Directory is `.` because the app sits at the root here.

Live: <https://id-entity-admin.vercel.app>

The six `NEXT_PUBLIC_FIREBASE_*` variables are already set on the project for
production, preview and development. They are public client identifiers, not
secrets — they name the Firebase project, they do not grant access to it. The
deployed Firestore and Storage rules are what protect the data.

To deploy by hand:

```bash
npx vercel deploy --prod
```

### Two settings that are not in this repo

**Deployment Protection.** New Vercel projects gate every URL behind a Vercel
login, so the panel is unreachable until it is turned off:
Vercel → the project → Settings → Deployment Protection → disable Vercel
Authentication. The panel has its own Firebase sign-in that only admits
admin accounts, verified server-side, so this second gate only blocks
legitimate use.

**Authorised domains.** Firebase rejects sign-in from a domain it does not
know. Add the deployment's hostname under Firebase Console → Authentication →
Settings → Authorised domains, or every login attempt fails with
`auth/unauthorized-domain`.
