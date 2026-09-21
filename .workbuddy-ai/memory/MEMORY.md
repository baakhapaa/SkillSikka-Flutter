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

### Known-bad test files on HEAD 6072692 (measured, all pre-existing)

- `test/home_heading_alignment_test.dart` — **hangs forever**. This is why a full
  `flutter test` looks like it died. Run files individually with `timeout`.
- `test/widget_test.dart` — fails.
- `test/navigation_test.dart` — 2 failures (`Saved By Shorts` semantics label,
  `destination-*` keys).

Use a throwaway `git worktree add /tmp/base HEAD` to prove a failure predates a
change instead of arguing about it.

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
