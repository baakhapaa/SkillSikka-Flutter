import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Key on the sheet's heading text.
///
/// Exported so a test can read the heading directly: it cannot be found by
/// string alone, because a heading is often the same words as the hint of the
/// field that opened it — the Province picker's heading and the Province
/// field's hint are both "Select province".
const optionPickerSheetTitleKey = Key('optionPickerSheetTitle');

/// Bottom sheet used by the signup and edit-profile forms for their dropdown
/// fields (gender, class, province, …). Returns the chosen option, or `null`
/// when the user dismisses it.
///
/// The signup forms keep a private copy of this (`_pickOption`); new screens
/// should use this one.
///
/// **The option list scrolls, and the sheet is allowed to be taller than
/// `showModalBottomSheet`'s default.** It used to spread `options` straight
/// into a non-scrolling `Column`, which overflows the moment the list is
/// taller than the sheet's default cap of 9/16 of the screen — and every list
/// this sheet is given is long: `/grades/` returns 12, `/locations/provinces/`
/// 7 and `/locations/districts/` 78. Measured on a 360x800 viewport (cap 450pt,
/// header 52.7pt, 56pt per `ListTile`):
///
/// | list | needs | result |
/// |---|---|---|
/// | gender, 3 options | 228.7pt | fits — which is why this hid for so long |
/// | provinces, 7 | 452.7pt | `RenderFlex overflowed by 2.7 pixels` |
/// | grades, 12 | 732.7pt | `RenderFlex overflowed by 283 pixels` |
/// | districts, 78 | 4428.7pt | `RenderFlex overflowed by ~3979 pixels` |
///
/// Class, province and district are therefore the three fields that showed the
/// stripe on the student Edit Profile screen. The signup instructor form's
/// private picker already had the right shape (`isScrollControlled` plus a
/// bounded, scrollable list); this now matches it.
Future<String?> showOptionPickerSheet(
  BuildContext context, {
  required String title,
  required List<String> options,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    // Without this the sheet is capped at 9/16 of the screen and a long list
    // has nowhere to go.
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        // The cap is what makes the scroll below possible: it gives the list a
        // finite height to scroll inside.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                title,
                key: optionPickerSheetTitleKey,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(options[index]),
                  onTap: () => Navigator.pop(context, options[index]),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
