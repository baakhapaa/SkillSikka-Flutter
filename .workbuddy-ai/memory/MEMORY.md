# SkillSikka — project notes

Flutter app, package name `skillsikka`. Figma-derived design system, Manrope
everywhere, `google_fonts` + `flutter_svg` + `go_router` + Riverpod.

## Running the tests (they DO work — see the 2026-09-18 correction)

```bash
cd C:/Users/Nitro/Desktop/SkillSikka-Flutter && \
  env "PROGRAMFILES(X86)=C:\\Program Files (x86)" \
  no_proxy="localhost,127.0.0.1,::1" NO_PROXY="localhost,127.0.0.1,::1" flutter test
```

Both env fixes are required. Without `no_proxy` every test dies with
`WebSocketException: Invalid WebSocket upgrade request`.

`flutter analyze` needs only the `PROGRAMFILES(X86)` fix.

### Known-bad test files on HEAD 486dc5d (measured, all pre-existing)

- `test/home_heading_alignment_test.dart` — **the second test in the file hangs
  forever** (the 360px case passes in ~1s, the 400px case never finishes). It is
  not width-dependent: any file with two `testWidgets` that each pump `HomePage`
  reproduces it. `HomePage.dispose()` is fine, so the leak is in the
  google_fonts test harness. **Keep to one HomePage-pumping test per file.**
  This is why a full `flutter test` looks like it died — run files individually
  with `timeout`.
- `test/widget_test.dart` — fails.
- `test/navigation_test.dart` — 2 failures (footer destinations, profile course
  tabs).

Use a throwaway `git worktree add /tmp/base HEAD` to prove a failure predates a
change instead of arguing about it.

### ⚠️ Do not use `git stash` in this repo

On 2026-09-21 a `git stash push -- lib/` was interrupted and afterwards
`.git/refs/` and `.git/objects/pack/*.pack` were gone. Git then silently
resolved to the repo at `C:\Users\Nitro` (a **parent** repo), so `git status`
still produced plausible-looking output for the wrong tree. History was
recovered with `git fetch origin --prune --tags`; the working tree was never
touched. See `2026-09-21.md` for the full recovery procedure.

To capture a pre-fix render, `cp` the file aside and edit in place. Get the
original with `git show HEAD:<path>`, which is safe.

## Design tokens (harvested from the signup screens)

| Token | Value |
|---|---|
| scaffold / surface | `#FAF9F6` / `#FFFFFF` |
| accent, primary buttons | `#E6B800` (fg `#111827`, `elevation: 4`, `shadowColor: #40E6B800`, `StadiumBorder`, height 52) |
| accent tint (badge bg) | `#FFF4CC` |
| cream card / info strip | `#FFFBF0`, brown ink `#2F2600` |
| ink / ink-soft / muted | `#111827` / `#4B5563` / `#9CA3AF` |
| border / field radius | `#E5E7EB` / 12 |
| success / danger | `#16A34A` / `#EF4444` |
| fonts | `GoogleFonts.manrope` |

`AppPalette` in `lib/core/widgets/location_prompt_dialog.dart` holds these — reuse
it rather than re-deriving colours in new screens.

## Layout conventions in this codebase

- Signup pages keep local private widgets at the bottom of the same file
  (`_Field`, `_FormField`, `_UploadCard`, `_Label`, `_Header`), with `_Field` on
  the student form and `_FormField` on the instructor form as near-duplicates.
  They are drifting; worth consolidating.
- Dropdown-style fields are `readOnly: onTap != null` with a chevron `trailing`.
  That idiom is reused by the location field to lock/unlock it.
- Screens that must be testable take injectable services via the constructor with
  a `const` default (see `SignupStudentFormPage.locationService`).
- **Section headings** use `const SectionBar()` + `SizedBox(width: 7)` +
  the title, never `Text('|')`. The glyph version put its ink wherever the 21pt
  line box landed (~3.5px above the heading's optical centre under
  `CrossAxisAlignment.end`). `SectionBar` lives in
  `lib/core/widgets/section_bar.dart`; pass `color:` if a screen needs its own
  tint (`recommended_course.dart` uses `0x1F111827`).
- Don't give a bar/glyph an alignment job that belongs to geometry: a `Text`'s
  line box is 1.37em for Manrope, so box-alignment and optical alignment are not
  the same thing. Compare *ink* centres when measuring, and prefer an explicit
  `Container` when a design says "aligned".
- Text stacks with `height: 1.0` carry descent space below the ink and only
  ~3px of air between two adjacent lines. If a label/value pair looks like it is
  colliding, add an explicit `SizedBox` rather than trusting the line boxes.
- **Never size a gap with a fixed `SizedBox(width:)` next to an `Expanded`
  text column.** The premium-course enrollment pill used `SizedBox(width: 69)`,
  which is fine on the 393pt canvas the design was drawn on and starves the
  label on a 360pt phone: the column got 52pt for `ENROLLMENT`, which needs
  72pt, so it wrapped and the row overflowed by 1px. Use a small minimum gap
  (`SizedBox(width: 12)`) and let `Expanded` absorb the slack.

## Device metrics

Target width is **360pt** (`360x800` logical at DPR 2 = 720x1600 px). The
premium-course enrollment pill is **298x60pt** and its fill is `#F2F1F7`.
Measured on a real device screenshot, the pill reads 296x60pt and the fill is
exactly `#F2F1F7` — so the code's values are right and the screenshot is 2 px/pt.
Useful calibration point: `ENROLLMENT` (Inter 10pt) has a 7.27pt cap height.

## Feature: location prompt on the signup forms

`lib/core/location/location_service.dart` (geolocator 14 + geocoding 5 wrapper) and
`lib/core/widgets/location_prompt_dialog.dart` (the popup). Popup opens from
`initState` on both signup forms; `showLocationPromptDialog` returns
`Future<DetectedLocation?>` (non-null = confirmed fix, `null` = dismissed).

**The Location field stays a normal editable input** — the popup only pre-fills
it. There is deliberately no "Enter Manually" button: the user removed it, and it
was only needed because the field used to be locked read-only. Don't reintroduce
the lock without also giving the user a way out.

`skipIntro` is `null` (decide from current permission), `true` (explicit user
request, jumps straight to detection), or `false` (always explain).
See `2026-09-21.md`.
