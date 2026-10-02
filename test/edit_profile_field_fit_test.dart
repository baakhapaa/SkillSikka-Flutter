import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/profile/presentation/edit_profile_page.dart';

/// Guards the one layout rule this form depends on: a hint must never make its
/// own field taller than the fields around it.
///
/// `InputDecorator` sizes the field to `max(hintHeight, inputHeight)` and only
/// applies `TextOverflow.ellipsis` when `hintMaxLines` is set, so an unset
/// `hintMaxLines` lets a wide hint wrap onto a second line and stretch exactly
/// that one field. The two-up rows are where it bites: a 152pt field gives its
/// hint only 80pt of text slot once the 16pt content padding, two 4pt gaps and
/// the 48pt suffix `IconButton` are taken out.
void main() {
  testWidgets('the province, district and date hints stay on one line', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: EditProfilePage())),
    );
    await tester.pump();

    /// The field that owns [hint], measured from its own render box.
    double fieldHeight(String hint) => tester
        .getSize(
          find.ancestor(
            of: find.text(hint),
            matching: find.byType(TextFormField),
          ),
        )
        .height;

    // Full width, and its hint is short enough to fit in either font — so it
    // stays one line with or without the fix and is a fair baseline.
    final baseline = fieldHeight('+977 98XXXXXXXX');

    // Needs 82.9pt at 12pt in an 80pt slot, so it used to wrap.
    expect(fieldHeight('Select province'), baseline);
    // Needs 97.6pt at 11pt in the same 80pt slot — the worst of the three.
    expect(fieldHeight('Select province first'), baseline);
    // Same two-up row as Gender, same 80pt slot, 91.8pt of hint.
    expect(fieldHeight('DD / MM / YYYY'), baseline);

    // The full-width pickers were never affected: `Select your class` needs
    // 105.8pt and has 240pt to sit in. Asserted so a future change to the
    // padding or the suffix cannot quietly break them too.
    expect(fieldHeight('Select your class'), baseline);
  });
}
