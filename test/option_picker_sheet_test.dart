import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/widgets/option_picker_sheet.dart';

/// The option counts the dev backend actually returns, read from
/// `GET /api/v1/grades/`, `/locations/provinces/` and `/locations/districts/`
/// on 2026-10-01: 12, 7 and 78.
///
/// They matter because the sheet used to be a non-scrolling `Column`: on a
/// 360x800 viewport `showModalBottomSheet` caps the sheet at 9/16 of the screen
/// (450pt), the header is 52.7pt and each `ListTile` 56pt, so a list needs
/// `52.7 + 56n + 8` and anything past seven options overflowed.
const _gradeCount = 12;
const _provinceCount = 7;
const _districtCount = 78;

void main() {
  /// Opens the sheet from a real tap so the modal route is fully wired, and
  /// hands whatever it pops with to [onResult].
  Future<void> openSheet(
    WidgetTester tester,
    List<String> options, {
    ValueChanged<String?>? onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  final chosen = await showOptionPickerSheet(
                    context,
                    title: 'district',
                    options: options,
                  );
                  onResult?.call(chosen);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // The regression was `RenderFlex overflowed` from the sheet's Column, and it
  // scaled with the list: 2.7px for the seven provinces, 283px for the twelve
  // grades, ~3979px for the 78 districts. Gender is the control — three options
  // always fitted, which is why this went unnoticed until the pickers were
  // pointed at the backend's reference data.
  for (final entry in const <String, int>{
    'gender (3 options)': 3,
    'provinces (7 options)': _provinceCount,
    'grades (12 options)': _gradeCount,
    'districts (78 options)': _districtCount,
  }.entries) {
    testWidgets('${entry.key} opens without overflowing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await openSheet(
        tester,
        List.generate(entry.value, (i) => 'Option ${i + 1}'),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ListTile), findsWidgets);
    });
  }

  testWidgets('a long list is capped, scrolls, and returns the choice', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? chosen;
    await openSheet(
      tester,
      List.generate(_districtCount, (i) => 'District ${i + 1}'),
      onResult: (value) => chosen = value,
    );

    // The cap is what gives the list a finite height to scroll inside; without
    // it the sheet would be as tall as all 78 rows.
    expect(
      tester.getSize(find.byType(ListView)).height,
      lessThanOrEqualTo(800 * 0.7),
    );

    // The far end of the list is off-screen until it is scrolled to — the
    // whole point, since a 78-row list is ~4.4k pt tall.
    expect(find.text('District 78'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('District 78'),
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );

    // `scrollUntilVisible` only guarantees the row exists in the tree; it can
    // still sit half under the sheet's edge, where a tap silently misses.
    // `ensureVisible` is the idiom this repo uses before tapping.
    await tester.ensureVisible(find.text('District 78'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('District 78'));
    await tester.pumpAndSettle();

    expect(chosen, 'District 78');
    expect(
      find.byType(ListView),
      findsNothing,
      reason: 'the sheet should close',
    );
  });
}
