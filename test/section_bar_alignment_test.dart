import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/widgets/section_bar.dart';
import 'package:skillsikka/features/home/presentation/home_page.dart';

import 'support/events_test_scope.dart';
import 'support/home_page_font_harness.dart';

void main() {
  installHomePageFontHarness();

  Future<void> pumpHome(WidgetTester tester, double width) async {
    await tester.binding.setSurfaceSize(Size(width, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // The events rail is provider-driven; the scope stubs it so this test stays
    // a layout measurement.
    await tester.pumpWidget(
      eventsTestScope(child: const MaterialApp(home: HomePage())),
    );
    await tester.pump();
  }

  testWidgets('home section headings and enrollment block are aligned', (
    tester,
  ) async {
    // 360x800 is the phone the enrollment bug was reported on.
    await pumpHome(tester, 360);

    for (final title in ['Explore our Top instructors', 'Get Premium Courses']) {
      final row = find
          .ancestor(of: find.text(title), matching: find.byType(Row))
          .first;
      final bar = find.descendant(of: row, matching: find.byType(SectionBar));
      expect(bar, findsOneWidget, reason: title);

      final barRect = tester.getRect(bar);
      final titleRect = tester.getRect(find.text(title));
      // For Manrope/Roboto the line-box centre sits within ~0.25px of the
      // heading's cap-height centre, so this is the optical centre too.
      // The old `Text('|')` version was ~3.5px above it.
      expect(
        barRect.center.dy,
        closeTo(titleRect.center.dy, 0.5),
        reason: '$title: accent bar is not vertically centred on the heading',
      );
    }

    final label = find.text('ENROLLMENT').first;
    final price = find.text('Rs.24.99').first;
    final pill = find
        .ancestor(of: label, matching: find.byType(Container))
        .first;
    final stack = find.ancestor(of: label, matching: find.byType(Column)).first;

    expect(
      tester.getRect(stack).center.dy,
      closeTo(tester.getRect(pill).center.dy, 0.5),
      reason: 'enrollment stack is not vertically centred in the pill',
    );
    // The two 1.0-height line boxes only leave ~3px of air on their own, which
    // reads as the price colliding with the label.
    expect(
      tester.getRect(price).top - tester.getRect(label).bottom,
      greaterThanOrEqualTo(5),
      reason: 'price is crowding the ENROLLMENT label',
    );

    // The label and the price must each render on ONE line, and the stack must
    // fit inside the pill. A fixed 69pt spacer used to starve the column: on a
    // 360pt device only 52pt was left for 'ENROLLMENT', which needs 72pt, so
    // the pill rendered "ENROLLM / ENT" and "Rs.24. / 99" and overflowed by 1px.
    for (final (finder, text, lineHeight) in [
      (label, 'ENROLLMENT', 10.0),
      (price, 'Rs.24.99', 17.0),
    ]) {
      final rect = tester.getRect(finder);
      expect(
        rect.height,
        lessThan(lineHeight * 1.5),
        reason: '$text wrapped onto a second line at 360pt',
      );
      // Also prove nothing was ellipsised: a truncated run would be clamped to
      // the available width, i.e. narrower than the unconstrained string.
      final style = tester.widget<Text>(finder).style!;
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(
        rect.width,
        greaterThanOrEqualTo(painter.width - 1.0),
        reason: '$text was truncated at 360pt',
      );
    }
    expect(
      tester.getRect(stack).height,
      lessThanOrEqualTo(tester.getRect(pill).height),
      reason: 'the enrollment stack does not fit inside the pill',
    );

    drainUnrelatedOverflows(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
