import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/home/presentation/home_page.dart';

import 'support/events_test_scope.dart';
import 'support/home_page_font_harness.dart';

/// Same assertions as the 360pt file, at 400pt. Kept in a separate file for the
/// same reason — see `home_page_font_harness.dart`.
///
/// The width matters: the home page mixes fixed-width pills and `Expanded`
/// children, so an alignment defect can show at one width and not the other.
/// The `Start Learning` overflow that was fixed in `home_page.dart` only ever
/// reproduced at 360pt.
void main() {
  installHomePageFontHarness();

  testWidgets('home headings align with their section content at 400', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // The events rail is provider-driven; the scope stubs it so this test stays
    // a layout measurement.
    await tester.pumpWidget(
      eventsTestScope(child: const MaterialApp(home: HomePage())),
    );
    await tester.pump();

    for (final title in ['Get Premium Courses', 'Recommended Books']) {
      final heading = find.text(title);
      final row = find.ancestor(of: heading, matching: find.byType(Row)).first;
      final section = find
          .ancestor(of: heading, matching: find.byType(Column))
          .first;
      final rowRect = tester.getRect(row);
      final sectionRect = tester.getRect(section);
      expect(rowRect.left, sectionRect.left, reason: title);
      expect(rowRect.right, sectionRect.right, reason: title);
      final seeAll = find.descendant(of: row, matching: find.text('See All'));
      expect(tester.getRect(seeAll).right, sectionRect.right, reason: title);
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
