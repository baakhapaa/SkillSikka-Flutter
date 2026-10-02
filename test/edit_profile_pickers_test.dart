import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/widgets/option_picker_sheet.dart';
import 'package:skillsikka/features/profile/data/reference_data.dart';
import 'package:skillsikka/features/profile/presentation/edit_profile_page.dart';

/// The four pickers on the student Edit Profile screen, driven end to end:
/// every sheet must come up **with its heading** and **without overflowing**.
///
/// Two defects are pinned here, and they are unrelated:
///
/// 1. **The heading.** `_pickOption` was handed a finished heading by one call
///    site (Gender passed `'Select gender'`) and a bare noun by the rest (Class
///    passed `'class'`), and it rendered whatever it got. So the three pickers
///    read "class", "province" and "district" — labels, not prompts.
/// 2. **The overflow.** The sheet's option list was a non-scrolling `Column`,
///    capped by `showModalBottomSheet` at 9/16 of the screen. With the counts
///    the backend actually serves — 12 grades, 7 provinces, 78 districts —
///    every one of them overflowed, while Gender's 3 options always fitted.
const _gradeCount = 12;
const _provinceCount = 7;
const _districtCount = 78;

List<ReferenceItem> _items(String prefix, int count) => List.generate(
  count,
  (i) => ReferenceItem(id: '$prefix-${i + 1}', name: '$prefix ${i + 1}'),
);

void main() {
  /// This screen overflows in `flutter test` on its own — the test font stands
  /// in for Manrope, which cannot be fetched, and it is far wider. That is
  /// pre-existing and unrelated to the pickers, so drain it; anything that is
  /// not an overflow still fails.
  void drainKnownPageOverflow(WidgetTester tester) {
    for (
      var e = tester.takeException();
      e != null;
      e = tester.takeException()
    ) {
      final text = e.toString();
      expect(
        text.contains('overflowed') || text.contains('Multiple exceptions'),
        isTrue,
        reason: 'unexpected exception on the edit profile page: $text',
      );
    }
  }

  testWidgets('every picker opens with its heading and without overflowing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gradesProvider.overrideWith(
            (ref) async => _items('Grade', _gradeCount),
          ),
          provincesProvider.overrideWith(
            (ref) async => _items('Province', _provinceCount),
          ),
          districtsForProvinceProvider.overrideWith(
            (ref, province) async => _items('District', _districtCount),
          ),
        ],
        child: const MaterialApp(home: EditProfilePage()),
      ),
    );
    await tester.pump();
    drainKnownPageOverflow(tester);

    /// The field that owns [hint], tapped from a real gesture so the picker's
    /// own `onTap` runs.
    Finder fieldFor(String hint) => find.ancestor(
      of: find.text(hint),
      matching: find.byType(TextFormField),
    );

    /// Opens the picker for [hint] and asserts its sheet came up correct.
    Future<void> openPicker(
      String hint,
      String firstOption,
      String heading,
    ) async {
      final field = fieldFor(hint);
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      drainKnownPageOverflow(tester);

      await tester.tap(field);
      await tester.pumpAndSettle();

      // Guards against a vacuous pass: a missed tap only prints a warning, and
      // with no sheet open there is nothing to overflow or to read a heading
      // from.
      expect(
        find.text(firstOption),
        findsOneWidget,
        reason: 'the $hint picker did not open',
      );

      // Read through the key, not the string: for Province the heading and the
      // field's own hint are the same words.
      expect(
        tester.widget<Text>(find.byKey(optionPickerSheetTitleKey)).data,
        heading,
        reason: 'the $hint sheet heading',
      );

      // The regression: `RenderFlex overflowed` from the sheet's Column, thrown
      // during layout, so it has to be drained to be seen at all.
      expect(
        tester.takeException(),
        isNull,
        reason: 'the $hint picker overflowed',
      );
    }

    Future<void> choose(String option) async {
      await tester.tap(find.text(option));
      await tester.pumpAndSettle();
      // Choosing rebuilds the form — picking a province unlocks District — so
      // the page's own font-related overflow can come back here. Drain, do not
      // assert.
      drainKnownPageOverflow(tester);
    }

    // Gender — the control. Its heading was already right, which is what made
    // the other three look wrong, and its 3 options always fitted.
    await openPicker('Select gender', 'Female', 'Select gender');
    await choose('Female');

    // Class / Grade — 12 options.
    await openPicker('Select your class', 'Grade 1', 'Select class');
    await choose('Grade 1');

    // Province — 7 options, the marginal case: 452.7pt into a 450pt cap.
    await openPicker('Select province', 'Province 1', 'Select province');
    await choose('Province 1');

    // District is disabled until a province is chosen, so it is only reachable
    // after the step above. `TextFormField` does not expose `enabled` as a
    // field — it only forwards it — so read it off the `TextField` it builds.
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: fieldFor('Select province first'),
              matching: find.byType(TextField),
            ),
          )
          .enabled,
      isTrue,
      reason: 'choosing a province must unlock the district picker',
    );

    // District — 78 options, the worst case: ~4429pt into a 450pt cap.
    await openPicker('Select province first', 'District 1', 'Select district');
    await choose('District 1');

    expect(find.text('District 1'), findsWidgets);
  });
}
