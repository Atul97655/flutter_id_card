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

Expected: **29 Firestore + 12 Storage tests passing.**

| File | Covers |
|---|---|
| `firestore.test.js` | Cross-teacher isolation, hub-and-spoke messaging, the review workflow, privilege escalation |
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

## 2. Deploying

Also **free** — publishing rules is a Spark-plan operation.

```bash
cd firebase && npx firebase login && npx firebase deploy --only firestore:rules,storage --project <your-project-id>
```

Use the project id of the **ID CardX** Firebase project. Run `npm test` first:
deploying rules that fail the suite means shipping a hole.

> The emulator also validates syntax. An earlier draft of the Storage rules had
> an invalid escape in a regex and would not compile — the emulator caught it
> before it ever reached a deploy.

---

## 3. What the rules guarantee

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

## 4. Two bugs this suite caught

Worth recording, because both were invisible while the rules sat undeployed.

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

Both are covered by regression tests: *"a teacher CAN send a message in their
own conversation"* and *"a non-member CANNOT read another conversation
attachments"*.

---

## 5. Keeping client and rules in step

The Storage rules allowlist attachment MIME types. `ChatRepository.contentTypeFor`
maps a filename to the type the client declares on upload, and the chat screen
refuses unsupported files before uploading so the user sees a plain message
instead of a raw permission error.

**Adding a file type means changing three places:** the allowlist in
`storage.rules`, the map in `chat_repository.dart`, and a test in
`storage.test.js`.
