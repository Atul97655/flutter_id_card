# Security Rules — Testing and Deployment

The rules in `firebase/firestore.rules` and `firebase/storage.rules` are what
actually protect the data. The role checks inside the Flutter app are a UI
convenience: anyone with a stolen ID token and `curl` bypasses them entirely.

The Plan of Action calls one test non-negotiable:

> Log in as Teacher A and deliberately try to read Teacher B's messages and card
> requests through the API. The database must reject it. If it succeeds, the
> system is not ready.

That test is now automated and runs locally against the Firebase emulator.

---

## 1. Running the tests

**Free.** No Blaze plan, no billing, no network Firebase project — the emulator
runs entirely on this machine. Needs Node and Java, both already installed here.

```bash
cd firebase/rules-tests && npm install && npm test
```

Expected: **31 Firestore + 12 Storage tests passing.**

| File | Covers |
|---|---|
| `firestore.test.js` | Cross-teacher isolation, hub-and-spoke messaging, the review workflow, the login write, privilege escalation |
| `storage.test.js` | Student photos per school, chat attachment membership, file-type allowlist |

The suite runs the two files as **separate mocha processes** on purpose. Mocha
applies root-level `before`/`beforeEach` hooks from every loaded file to every
test, so sharing one process let the Storage fixture wipe the Firestore fixture
out from under the Firestore tests.

If a run fails to start with *"Port 8080 is not open"*, the previous emulator
left its rules runtime holding the port (a known shutdown NPE in the emulator,
harmless). `npm test` frees the ports automatically via `pretest`; to do it by
hand, run `bash free-ports.sh`.

---

## 2. Deployment status

**Firestore rules: DEPLOYED to `id-cardx` on 2026-09-10.** Tenant isolation,
hub-and-spoke messaging and the review gate are live and enforced server-side.

Verified before deploying that both real accounts are keyed by their Auth UID —
the rules look users up by `request.auth.uid`, and a document with any other ID
would have locked that account out of everything.

**Storage rules: NOT deployed — Cloud Storage is not provisioned on the
project.** The deploy fails with *"Firebase Storage has not been set up on
project id-cardx"*.

This matters well beyond the rules. `google-services.json` names a bucket
(`id-cardx.firebasestorage.app`) that does not exist, so **student photo upload
and chat attachments have never worked against this project.**

Provisioning Storage on a project this recent requires the **Blaze** plan,
because it creates a Google Cloud Storage bucket. Blaze has a free tier (5 GB
stored, 1 GB/day downloaded) that a few hundred 300 KB photos sits well inside,
but it does require a card on the account. Until then the app degrades on
purpose — see below.

The Storage rules are written and tested (12 passing); they deploy in one
command the moment the bucket exists:

```bash
cd firebase/rules-tests && npx firebase deploy --only storage --config ../firebase.json --project id-cardx
```

### How the app behaves without Storage

A photo upload failure does **not** block the student record any more. Before
this change a failed photo aborted the whole row, which meant that with no
bucket **not one submission reached the office** — the review queue stayed
empty and an operator's day of work looked lost, when only the picture was
missing.

Now the details still reach Firestore with a null `photoUrl`, the entry appears
in the admin review queue, and the row stays queued so the photo is retried by
itself once the bucket exists. The operator is told plainly that the details
uploaded and **not** to retake the photo.

The print path already excludes approved entries that have no photo and reports
the count, so a card can never be printed with an empty photo box.

Covered by `test/sync_photo_degradation_test.dart`.

---

## 3. Deploying

Publishing rules is **free** — a Spark-plan operation.

```bash
cd firebase/rules-tests && npx firebase deploy --only firestore:rules --config ../firebase.json --project id-cardx
```

`firebase-tools` is installed under `firebase/rules-tests/node_modules`, which
is why the command runs from there and points at `../firebase.json`.

Run `npm test` first: deploying rules that fail the suite means shipping a hole.

> The emulator also validates syntax. An earlier draft of the Storage rules had
> an invalid escape in a regex and would not compile — the emulator caught it
> before it ever reached a deploy.

---

## 4. What the rules guarantee

**Tenant isolation** — a teacher reads and writes only their own school's
students, settings and photos. Another school's data is rejected at the
database, not hidden in the UI.

**Hub and spoke** — only an admin can create a conversation, so teacher-to-teacher
messaging is impossible by construction. A teacher can send messages and clear
their own unread badge in their own conversation, and nothing else — they cannot
rename it, change its kind, or add themselves to someone else's.

**Broadcasts are announcements** — only the admin can post into a
`kind: 'broadcast'` conversation. The chat screen also hides the composer, but
that is decoration; the rule is the control.

**Review is the admin's alone** — an operator cannot set `approvalStatus`,
`rejectionReason`, `reviewedBy` or `reviewedAt`, cannot create an entry that is
already approved, and cannot delete a synced record.

**No privilege escalation** — a user may update only their own `lastLoginDate`.
They cannot grant themselves `role: "Admin"`, move themselves to another school,
create accounts, or read anyone else's profile. A deactivated account keeps its
credentials but loses all access.

**Storage** — student photos are scoped per school and must be images under 3 MB.
Chat attachments require membership of that conversation, checked against the
`members` array in Firestore, and are limited to images, PDF, text, Word and
Excel under 10 MB.

---

## 5. Bugs this suite caught

Worth recording, because all of these were invisible while the rules sat
undeployed.

**Chat attachments were world-readable.** The old rule was
`allow read: if isActive()` with a comment saying it "relies on unguessable
paths". Chat ids are visible to every member and stored in plain text in
Firestore, so any teacher could read — and write — any other school's chat
files. Now checked against `members`.

**The rules would have broken teacher messaging on deploy.** `/chats/{chatId}`
allowed `update` only for admins, but both `sendMessage` and `markRead` perform
a batched write that updates the chat document (`lastMessage`, `lastMessageAt`,
`lastSenderId`, `unreadFor`). Deploying as-is would have made it impossible for
any teacher to send a message or clear an unread badge — the whole
teacher→admin direction the plan requires. Members may now write exactly those
four fields and nothing else.

**The login write needed checking too.** `/users/{uid}` lets a user change only
their own `lastLoginDate`, and the login path writes it with `set(merge:true)`,
which Firestore evaluates as an update. It passes — but that was reasoning, and
reasoning is exactly what missed the chat document. Now proven by a test.

---

## 6. A known edge case

Editing an entry resets it to "pending review". If the office has already
approved that card but the operator's device has not synced the approval yet,
their edit is refused by `reviewFieldsUnchanged()` and the row parks as failed.

The UI blocks editing once a card is *known* to be approved, so this needs the
approval to be in flight. `SyncService._describe` names the likely cause in the
error rather than blaming account access, which is what it used to say.

A full fix would have the sync reconcile that entry against the server copy
instead of parking it. Not done — it needs a decision about which side wins.

---

## 7. Keeping client and rules in step

The Storage rules allowlist attachment MIME types. `ChatRepository.contentTypeFor`
maps a filename to the type the client declares on upload, and the chat screen
refuses unsupported files before uploading so the user sees a plain message
instead of a raw permission error.

**Adding a file type means changing three places:** the allowlist in
`storage.rules`, the map in `chat_repository.dart`, and a test in
`storage.test.js`.
