# The glassmorphic redesign

What was done, why it was done that way, and what is still open.

Implemented against `id_entity_ui_redesign_master_prompt.md` and the four
reference screens (Home, New ID Card, Chat, Profile). Ten commits,
`c6c0582` through `36e22c4`.

---

## 1. What shipped

| Phase | Commit | Scope |
|---|---|---|
| A | `c6c0582` | Design tokens — colour, gradient, shadow, spacing, typography |
| B | `c6c0582` | The glass component library |
| C | `fa5caaa` | Home dashboard + floating navigation (reference 1) |
| D | `dff80f8` | New ID Card form (reference 2) |
| E | `93f5b0a` | Chat thread and chat list (reference 3) |
| F | `1e25ecd` | Profile (reference 4) |
| G | `2f1fbf6` | Splash, login, and the joining flow (screens 15, 17, 18) |
| H | `0e762a2` | The admin section — ten screens |
| I | `fa74850` | The last eight screens + tests for the glass library |
| J | `36e22c4` | Placeholder screen and the 404 |

**29 of 32 screens** are on the new system. The three that are not are on
black on purpose — see §6.

73 files in `lib` changed (+6121 / −2869). No dependencies were added or
removed; `pubspec.yaml` is untouched.

---

## 2. New files

**Tokens** — `lib/shared/theme/`

| File | Holds |
|---|---|
| `app_colors.dart` | Brand, surface, glass, ink, status and messaging colours |
| `app_gradients.dart` | Page backdrops, the header block, action pills, the sheen |
| `app_shadows.dart` | `subtle` / `card` / `lifted` / `floating` / `glow(Color)` |
| `app_spacing.dart` | `AppRadius` and `AppSpacing` |
| `app_typography.dart` | The type scale, with on-dark variants |

**Components** — `lib/shared/widgets/glass/`

| File | Holds |
|---|---|
| `glass_surface.dart` | `GlassSurface`, `GlassDepth` — the one primitive |
| `glass_scaffold.dart` | `GlassScaffold`, `GlassBackdrop`, `GlassHeader`, `GlassIconButton` |
| `glass_controls.dart` | `GlassButton`, `GlassIconTile`, `GlassStatusBadge`, `GlassStat`, `GlassListRow` |
| `glass_text_field.dart` | `GlassFieldShell`, `GlassTextField`, `glassInputDecoration()` |
| `glass_bottom_nav.dart` | `GlassBottomNav`, `GlassNavItem` |
| `admin_page.dart` | `AdminPage` — the shared chrome for the admin section |

**Tests** — `test/glass_components_test.dart`, 17 tests.

---

## 3. The one decision everything else follows from

`GlassDepth` — declared on every surface, with three values.

Real glass in Flutter means `BackdropFilter`, and a `BackdropFilter` costs
the compositor a save-layer, a blur and a restore **once per filter, per
frame**. One on a header costs nothing anyone will notice. Twenty of them,
one per row of a scrolling list, is how a cheap Android tablet drops to
fifteen frames a second.

So:

- **`flat`** — a gradient, a hairline border and a tinted shadow. No blur.
  Visually indistinguishable from glass when what sits behind it is a
  smooth page gradient, which on every screen in this app it is. Used for
  everything that repeats: list rows, stat tiles, message bubbles, cards
  inside a scroll view.
- **`frosted`** — a real 14σ blur. Chrome that does not repeat and does
  overlap moving content: the bottom navigation bar, the chat header, the
  composer, the save bars.
- **`deep`** — a real 26σ blur. Sheets, where the content behind is meant
  to recede.

The clip sits **outside** the `BackdropFilter`, never inside. Inverted, a
`BackdropFilter` blurs the entire layer behind it rather than the area
under the widget — which shows up as the whole screen going soft the
moment one card appears. Three tests pin this.

Press feedback is a scale, not an ink ripple. An ink splash needs an
opaque `Material` to paint on; on a translucent surface it either
disappears or smears.

---

## 4. Architecture changes

Nothing about how the app works changed. Every provider read, route,
repository call, validator, security rule and sync path is as it was. The
phases are presentation-only, and the test suite is what holds that claim
up — the 15 tests written against the old form widget and the 9 written
against the old onboarding screens were left untouched and still pass.

Three structural things did change:

**The theme now draws Material surfaces as glass.** `Card` is translucent,
hairlined and lifted with a navy-tinted shadow; `ListTile`, `Chip`,
`Dialog`, `BottomSheet`, `PopupMenu`, `TabBar`, `FloatingActionButton`,
`SegmentedButton` and the progress indicators all consume the tokens. This
is what carried the redesign through the 6,786 lines of admin screens
without rewriting them by hand — they were already built from `Card`s and
`ListTile`s.

**`GlassFieldShell` was extracted from `GlassTextField`.** A dropdown and
a date picker need the identical frame around a completely different
input. Copying that frame into each of them is how a form ends up with
three fields that are each two pixels different from the others.

**`AdminPage`** holds the page gradient, the title block and the back
button for the admin section. Ten screens each building their own
`Scaffold` and `AppBar` is what made them look like ten different tools.

---

## 5. Where I departed from the references, and why

Each of these is a judgement call, not an oversight.

**The Profile reference's photographic backdrop became a gradient.** The
image is copyrighted, it would add weight to an APK that is already large,
and glass over arbitrary photography destroys text contrast in a way no
amount of tuning fixes.

**Typography stays on the platform font.** `google_fonts` fetches over the
network at first paint, and this is an offline-first app used in schools
with unreliable connections. Bundling Inter as an asset (~400 KB) is the
correct fix if the exact typeface matters; say so and it is a small change.
The bundled `Arial` is deliberately not used for UI — that is for the
printed card and has an open licensing question.

**The chat header says what the conversation is, not "Admin · Online".**
This app has no presence system. A green "Online" dot that is always lit
is a lie a user will eventually catch, and once they catch it they stop
trusting the rest of the indicators. It says "Announcement — admin office
only", or the participant count, instead.

**Three controls were cut rather than restyled.** The admin dashboard bar
carried four icon buttons, which at phone width left the title nowhere to
go — and Reports and the Audit log were already in the labelled quick
actions below. User Management offered "Add User" in the bar *and* "New
Account" as a floating button, both opening the same dialog. School detail
had four icons plus a back button plus a school name; Settings stayed in
the header and the other three moved into an overflow menu, where they
also get to carry their names.

---

## 6. The three screens still on black

Photo capture, the QR scanner, and the full-screen image viewer.

All three are camera or photography surfaces. The preview should be the
brightest thing on screen, and glass over a live camera feed is a
readability problem rather than a stylistic one. What *did* change on them
is the surfaces that float over the preview: the scan error is now
frosted, so it no longer reads as the camera having stopped, and the
join-confirmation sheet uses the deep blur so the preview recedes while
the question is being answered.

---

## 7. Two real bugs the tests caught

Worth recording, because both were found by a test rather than by reading
the code.

**A 57-pixel overflow in the school-detail overflow menu.** A
`PopupMenuItem` constrains its width, and "Export CSV & Reports" is longer
than a `Row` that sizes to its content. The label is now `Flexible`.

**The validation message was announced twice.** `GlassTextField` keeps the
`TextFormField`'s own error so the `Form` still knows validation failed,
suppressed to zero height, and renders a visible copy below the row.
Invisible — but both were live semantics nodes, so a screen reader read
the message twice. The visible copy is now wrapped in `ExcludeSemantics`.
I verified the assertion fails without the fix rather than passing either
way: two nodes before, one after.

One test was edited. `admin_screens_widget_test.dart` asserted on the
school-detail four-icon bar by tooltip; it now drives the overflow menu.
Same intent — both actions reachable, print history still opens its sheet.

---

## 8. Verification

Run at `36e22c4`:

```bash
flutter analyze                                    # clean, lib and test
flutter test                                       # 523 passing
flutter build apk --release                        # builds
cd firebase/rules-tests && npm test                # 104 + 12 passing
cd admin-web && npx vitest run                     # 43 passing
cd admin-web && npx tsc --noEmit && npm run build  # clean
```

The glass component tests pump at **320 logical pixels** — narrower than
any of the reference designs were drawn at. Flutter throws on a
`RenderFlex` overflow in debug, so "pumps without throwing" is a real
assertion about layout, not a smoke test that only proves the constructor
runs.

---

## 9. Outstanding

**APK size.** The fat release APK is 141.9 MB. Split per ABI it is 55.2 MB
for arm64-v8a and 45.4 MB for armeabi-v7a — a 61% reduction on the one
that matters, since every real device is arm64 (x86_64 is emulator-only).
The weight is native libraries, not assets: assets total 1.1 MB. If cards
are sideloaded onto tablets over a school connection, this is worth doing:

```bash
flutter build apk --release --split-per-abi
```

**Not a code change — a build-flag choice, so it is yours to make.**

**The Vercel deploy.** The admin panel deploys from a separate repository
via subtree split. That push is still yours to run:

```bash
git push website "$(git subtree split --prefix=admin-web)":main --force
```

**Authenticated panel verification.** I have not signed in to the panel.
Entering a password is something I will not do, whoever asks. If you sign
in yourself on the browser pane I can drive the authenticated session from
there without ever handling the credential. Separately: the password that
was pasted into a chat log earlier should be changed.

**The manager's branch** `feature/idcard-whatsapp-ui` has still never been
pushed.

**Inter.** Open, as above — bundle the TTFs or stay on the platform font.
