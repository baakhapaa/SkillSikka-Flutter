import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/home/presentation/home_page.dart';

import 'support/events_test_scope.dart';
import 'support/home_page_font_harness.dart';

/// Section headings must line up with the content under them at 360pt, the
/// narrowest phone the app targets.
///
/// Split out of `home_heading_alignment_test.dart` on 2026-09-24 so that each
/// width gets its own file. See `home_page_font_harness.dart` for why pumping
/// HomePage twice in one file used to hang — the harness now clears the global
/// that caused it, so this split is belt-and-braces rather than load-bearing.
///
/// Deliberately does NOT call `drainUnrelatedOverflows`: a RenderFlex overflow
/// at a given width is itself a layout defect at that width, and this test is
/// the regression guard for the fixed `Start Learning` button overflow.
void main() {
  installHomePageFontHarness();

  testWidgets('home headings align with their section content at 360', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
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
