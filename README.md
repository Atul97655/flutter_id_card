# School ID Card Management System

Offline-first Flutter app for capturing student details and photos, and
producing print-accurate ID cards.

The core requirement driving the architecture: **a card specified as 54 × 86 mm
must measure 54 × 86 mm under a ruler after printing.** Everything in the print
path is authored in millimetres and converted to PostScript points exactly once,
at the boundary with the `pdf` package. Screen pixels never enter it.

---

## Status

| Phase | Scope | State |
|---|---|---|
| 1 | Models, Drift local DB, dynamic form, uppercase + validation, auth, home, saved entries, sync status | **Done** |
| 2 | Camera capture, 4:5 guide overlay, on-device background removal, face-centred crop, brightness/contrast/saturation, 360×450 export | **Done** |
| 3 | `IdCardRenderer`, 5 JSON layout templates, per-division colours, true-size preview, single-card PDF at exact mm | **Done** |
| 4 | Firebase sync worker, admin dashboard, per-school settings UI, imposition sheets, folder output, printing | **Done** |
| 5 | In-app messaging — chat list, conversation, attachments, read receipts, broadcasts | **Done** |
| — | Admin approval workflow (approve / reject-with-reason / bulk approve), gating the print path | **Done** |

`flutter analyze` → 0 issues. `flutter test` → 191 passing. Debug APK builds.

### Known gaps

Real work that is deliberately **not** done, so nobody discovers it late:

- **Push notifications.** `firebase_messaging` is a dependency and the Firestore
  rules cover chat, but no FCM token registration or Cloud Function exists —
  messages arrive only while the app is open. Delivering them in the background
  needs a Cloud Function, which needs the Blaze (paid) plan.
- **Class/Div are free text, not dropdowns.** The roadmap asks for dropdowns;
  that needs a per-school list of valid classes and divisions in the admin
  panel, which does not exist yet.
- **Chat is online-only** — see "Why chat is not offline-first" below.
- **No app icon** (still the Flutter default) and no signed release build.
- **ML Kit background removal is still unverified against real captures.**

### Draft autosave

The form autosaves to `SharedPreferences` on a short debounce, and immediately
after a photo is captured — a photo is the costliest thing to lose, because it
means finding the student again. On reopening a blank form, a recovered draft
is offered once; drafts are scoped to the school and expire after 12 hours, so
one operator's half-typed student never surfaces under another school's login
or a day later.

It is deliberately **not** in the Drift database: a draft is scratch state, not
a record. Putting it in the entries table would surface half-typed rows in
Saved Entries and the sync queue, which is worse than losing them.

---

## Quick start

```bash
flutter pub get
```

```bash
dart run build_runner build
```

```bash
flutter run
```

Without `google-services.json` the app still runs: it detects the missing
Firebase config, shows a banner, and lets you use **Debug: continue without
Firebase** on the login screen to exercise the whole entry → photo → preview →
PDF pipeline offline. Entries made in that mode never sync.

### Generate sample cards to measure

```bash
flutter test test/sample_card_generation_test.dart
```

Writes 13 real PDFs to `build/sample_cards/` — one per template style, plus the
six division-colour variants. Print `vertical_54x86_typical.pdf` **at 100% scale
(not "fit to page")** and measure it — that is the acceptance test.

---

## Firebase setup

You already have the project. Remaining steps:

1. **Register the Android app.** In the Firebase console add an Android app with
   package name `com.example.flutter_id_card` (or change
   `applicationId` in `android/app/build.gradle.kts` first and use that).
   Download `google-services.json` into `android/app/`.

2. **Add the Google Services Gradle plugin.** In `android/settings.gradle.kts`:

   ```kotlin
   id("com.google.gms.google-services") version "4.4.2" apply false
   ```

   and in `android/app/build.gradle.kts` add `id("com.google.gms.google-services")`
   to the `plugins { }` block.

3. **Enable Email/Password** in Authentication → Sign-in method.

4. **Deploy the rules** in `firebase/`:

   ```bash
   firebase deploy --only firestore:rules,storage
   ```

5. **Create the first admin.** Add an Auth user, then a Firestore document at
   `users/{that user's UID}`:

   ```json
   {
     "email": "admin@yourorg.com",
     "role": "Admin",
     "active": true,
     "displayName": "Administrator"
   }
   ```

   > **Important:** the document ID must be the Auth UID, not an auto-generated
   > ID. The security rules look the user up by UID; an auto-ID document is
   > invisible to them and every request will be denied. (The app has a
   > temporary email-based fallback for sign-in so an existing hand-created
   > document keeps working, but the rules do not.)

6. **Create a school.** `schools/{schoolId}`:

   ```json
   {
     "name": "ST JOHN SAMARITAN SCHOOL",
     "addressLine": "ANAND NAGAR, HUBBALLI - 580025",
     "contactLine": "Office: 0836-2345678",
     "cardSizeId": "v54x86",
     "templateId": "default_vertical",
     "enabledFields": ["name","photo","fatherName","dob","mobile","address"],
     "primaryColor": "#D32F2F",
     "secondaryColor": "#1565C0",
     "headerColor": "#1565C0"
   }
   ```

7. **Create the school's operator login.** School operators sign in with a
   *school code*, which the app turns into an email:
   `stjohns` → `stjohns@schools.idcardx.app`. Create that Auth user, then
   `users/{uid}` with `role: "School"` and `schoolId` pointing at the school
   document. Change `kSchoolAuthDomain` in
   `lib/features/auth/data/auth_repository.dart` to your own domain first.

---

## Architecture

```
lib/
  features/
    auth/            login, session, roles
    data_entry/      dynamic form, saved entries, sync status
    photo_capture/   camera, segmentation, crop geometry, adjustments
    card_render/     IdCardRenderer, templates, preview, imposition
    admin/           dashboard, submissions/review, school settings, print
    messaging/       chat list, conversation, attachments
  shared/
    models/  print/  providers/  services/  utils/  widgets/  theme/  router/
assets/
  templates/         JSON card layouts
  fonts/             bundled Arial
firebase/            Firestore + Storage rules
```

**Layers.** Widgets never touch Drift or Firestore directly. Repositories own
persistence, Riverpod providers expose them, widgets consume providers.

**One renderer.** The on-screen preview does not re-implement the card layout in
Flutter widgets — it rasterises the *actual PDF* via `Printing.raster`. Two
renderers would drift apart and the operator would only find out after a 25-up
sheet had been printed.

**Offline-first.** Every entry is committed to local SQLite before any network
call. An operator can work a full day with no signal and lose nothing.

### The sync worker

`shared/services/firebase/sync_service.dart`. Runs while a real (non-debug)
session is active, started and stopped by `syncLifecycleProvider` in step with
the session — there is nothing to sync before login, and a debug offline
session must never push test data into the production project.

Each pass pulls the school's settings document down (so admin-side field
toggles reach the operator) then pushes queued entries up: photo to Storage
first, then the Firestore document. Design points worth knowing:

- **Idempotent.** The entry's own id is the Firestore document id, so replaying
  an interrupted run overwrites rather than creating a duplicate student — a
  duplicate would only be discovered at the printer.
- **Bounded retries.** Exponential backoff per row, capped, then parked as
  failed after 8 attempts so a permanently broken row (say a photo the OS
  deleted) stops burning quota. Manual retry from the Sync Status screen resets
  the counter.
- **Reconnect-triggered.** Coming back online drains the queue immediately
  rather than waiting out the poll interval.
- **Never throws into the UI.** Row failures are recorded on the row; pass
  failures become state, not exceptions.

### Why chat is *not* offline-first

The ID-card side mirrors everything into SQLite; messaging deliberately does
not, and reads Firestore directly. Card data must survive a day with no signal
because re-capturing it means physically revisiting the school. A chat message
that fails to send can be retyped in seconds. Building a second offline outbox
for that would double the sync machinery to maintain for a fraction of the
benefit. Firestore's own cache still covers short dropouts.

### The approval gate

Only entries an admin has **approved** can be printed. That invariant is
enforced inside `ImpositionService`, at the last point before bytes reach a
printer — not in the calling screens. Screens still filter for accurate counts,
but a mistake there cannot produce an unapproved printed card. `ApprovalStatus`
is separate from `SyncStatus` because they answer different questions
("reached the server?" vs "signed off?") and an entry is routinely one without
the other.

The Firestore rules enforce the same thing server-side: an operator may correct
a student's details but cannot touch `approvalStatus`, `rejectionReason`,
`reviewedBy` or `reviewedAt`, and cannot create an entry that is already
approved.

---

## Card layout templates

`assets/templates/*.json`. All coordinates in millimetres from the card's
top-left. Colours are `@primary` / `@secondary` / `@header` / `@divAccent`
tokens resolved against each school's palette, or a literal `#RRGGBB`.

Five templates ship, each modelled on a structure that appears in the reference
card set:

| Template | Size | Modelled on |
|---|---|---|
| `default_vertical` | 54×86 | Mother Teresa, JSS Gadag — header band, photo, rows, footer |
| `default_horizontal` | 86×54 | Tapasya — slim header, photo left, rows right |
| `div_badge_vertical` | 54×86 | Sacred Heart Convent — bold bands, dark photo panel, DIV badge |
| `side_panel_horizontal` | 86×54 | St John Samaritan — coloured ground, inset white body |
| `framed_vertical` | 54×86 | Pratibha Vikas — coloured frame, centred photo/name, signature line |

### Per-division colours

A school can set an accent colour per division (`divisionColors` on the school
document, keyed by uppercase division). When set, `@header` / `@divAccent`
resolve to that student's division colour instead of the school colour — so one
template produces the six-colour set Sacred Heart Convent issues, without six
templates. Leave the map empty and every card uses the school colour, exactly
as before.

```json
"divisionColors": { "A": "#E01B1B", "B": "#1A1AE0", "C": "#E0189C" }
```

Lookup ignores case and whitespace, because Div arrives from a free-text field.
An unlisted division falls back to the school colour.

### Text tokens

Static text supports `{schoolName}`, `{addressLine}`, `{contactLine}` and the
student tokens `{name}`, `{class}`, `{division}`, `{dob}`, `{mobile}`. Pair a
student token with `"requires": "<fieldKey>"` so the element disappears entirely
when that field is empty — that is what stops the DIV badge printing a bare
`DIV-` for a student with no division.

The `LABEL : VALUE` rows are **not** at fixed coordinates. A `fields` element
reserves a box and the renderer flows only the school's enabled, non-empty rows
into it, shrinking type if needed and reporting a warning when it does. Fixed
row positions would break the moment an admin switched a field off.

The 38.1 mm photo is the binding constraint on a vertical card — 44% of an 86 mm
height — which is why the header is a compact band rather than a deep masthead.

### Typography (fixed by spec)

| Field | Size | Weight | Colour |
|---|---|---|---|
| Name | 8 pt | Bold | primary |
| Father's Name | 7 pt | Regular | secondary |
| Class | 8 pt | Regular | primary |
| DOB | 7 pt | Regular | secondary |
| Mobile | 7 pt | Regular | primary |
| Address | 5 pt | Regular | primary, 2 lines |

Div (8 pt primary) and Blood Group (7 pt secondary) are not in the spec table
and were assigned to match the field they sit beside. See
`lib/features/card_render/domain/card_typography.dart`.

---

## Imposition

| Sheet | Size | Cards at 54×86 | Grid |
|---|---|---|---|
| 12 × 18 in | 304.8 × 457.2 mm | 25 | 5 × 5, margins 17.4 / 13.6 mm |
| A4 landscape | 297 × 210 mm | 10 | 5 × 2, margins 13.5 / 19 mm |
| Single | card size | 1 | reprints |

A4 is landscape because portrait genuinely cannot hold 10: 210 mm takes 3
columns and 297 mm takes 3 rows — nine cards. This is pinned by a test so nobody
"fixes" the orientation later.

The grid is computed from the selected card size. If a size cannot reach the
sheet's usual capacity the admin is warned rather than cards being silently
overlapped. Cards butt-cut by default (no gutter); pass a gutter only if each
card carries its own bleed, in which case it must be ≥ 2 × bleed.

Output tree:

```
Documents/Output/<SchoolName>/12x18_Sheets/sheet_001.pdf
                             /A4_Sheets/a4_001.pdf
                             /Single_Cards/STUDENTNAME_CLASS.pdf
```

---

## Things you need to decide or action

1. **Arial is not redistributable.** `assets/fonts/` currently holds Arial copied
   from Windows, which is a Monotype font licensed with the OS — shipping it in
   an APK is a licence violation. Replace both files with **Liberation Sans**
   (SIL OFL, metric-compatible, so the layout will not shift) before release, or
   buy an embedding licence. Keep the filenames.

2. **Application ID** is still `com.example.flutter_id_card`. Change it before
   any Play Store or MDM deployment, and register the new package in Firebase.

3. **Bulk print is desktop-only.** "Open folder" and "Print all" need a file
   manager and a default printer, neither of which Android provides. The
   `ExportService.canOpenFolder` / `canPrintDirectly` flags are false on Android
   and the UI must offer share / print-one instead. Plan the admin panel as a
   **Windows build** of this same codebase.

4. **Background-removal quality is unverified on real devices.** ML Kit selfie
   segmentation is wired up and the compositing uses a soft alpha ramp to avoid
   a hard halo around hair, but I have not been able to run it against real
   captures here. Test with 10–20 real student photos before rollout; if edges
   are poor, that is the point to reconsider a server-side fallback (flagged in
   the spec as a future improvement, deliberately not built).

5. **`compileSdk` is pinned to 37** and the root Gradle file adds
   `checker-qual` to every Android module — both were required to make the
   Firebase plugin set compile against Kotlin 2.4 / AGP 9.1. Comments explain
   why; do not remove them without re-testing the build.

---

## Testing

```bash
flutter test
```

| Suite | What it protects |
|---|---|
| `print_units_test` | mm ↔ pt ↔ px conversions, photo spec, card sizes |
| `card_render_test` | PDF MediaBox is exactly the card size; template bounds; row flow fits |
| `imposition_test` | 25-up and 10-up grids, margins, slot positions, capacity warnings |
| `photo_geometry_test` | 4:5 crop stays valid for every face position and size |
| `input_formatters_test` | uppercase enforcement, caret safety, digit-only |
| `validators_test` | 10-digit mobile, DOB range, blood group, address length |
| `school_config_test` | field toggles, colour parsing, Firestore round-trip |

Two real bugs were caught by these while building: row heights were being scaled
without scaling the gaps (rows overflowed the block), and `1080 * 0.8` floors to
863 in binary floating point (crops silently lost a pixel column).
