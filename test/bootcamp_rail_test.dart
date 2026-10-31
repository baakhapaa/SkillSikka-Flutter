import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/bootcamp/data/bootcamp.dart';
import 'package:skillsikka/features/home/presentation/home_page.dart';

import 'support/events_test_scope.dart';
import 'support/home_page_font_harness.dart';

/// The ICT & AI Bootcamp rail's run picker and the slide it causes.
///
/// Two things this guards, both from 2026-10-31:
///
/// 1. The picker is **not** a `DropdownButton` any more. Material's menu is a
///    square grey slab with a cold highlight, and it looked like it belonged to
///    another app next to the cream section it opened from.
/// 2. Choosing a run **slides** the rail instead of reordering it. The old code
///    pulled the chosen card to the front, so the two cards swapped places under
///    the finger — a jump, not a transition.
void main() {
  installHomePageFontHarness();

  const sevenDay = BootcampCard(
    id: 1,
    title: 'ICT & AI BOOTCAMP at Palungtar',
    venueName: 'Palungtar',
    days: 7,
    studentsEnrolled: 0,
    viewCount: 0,
    image: '',
    qualityLabel: 'HD',
    status: 'upcoming',
  );
  const fourDay = BootcampCard(
    id: 2,
    title: 'ICT & AI BOOTCAMP at Sundarbazar',
    venueName: 'Sundarbazar',
    days: 4,
    studentsEnrolled: 1,
    viewCount: 0,
    image: '',
    qualityLabel: 'HD',
    status: 'completed',
  );

  Future<void> pumpHome(WidgetTester tester) async {
    // Tall enough that the rail is on screen without scrolling: the page is a
    // long column and `ensureVisible` alone left the pill under the bottom bar.
    await tester.binding.setSurfaceSize(const Size(360, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // The server's order: newest run first.
    await tester.pumpWidget(
      eventsTestScope(
        bootcamps: const [sevenDay, fourDay],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('ICT & AI Bootcamp'));
    await tester.pump();
    // `ensureVisible` parks the heading at the very top of the viewport, which
    // is exactly where the page's sticky header sits — the pill then has a
    // header over it and every tap misses. Push the rail down into the open
    // part of the screen first.
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 160));
    await tester.pump();
  }

  testWidgets('the run picker is the app\'s own card, not a Material menu', (
    tester,
  ) async {
    await pumpHome(tester);

    // The pill names the first card's run.
    expect(find.text('7 Days'), findsOneWidget);
    expect(find.byType(DropdownButton<int>), findsNothing);

    await tester.tap(find.text('7 Days'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    // Both runs are offered, and the current one carries the tick.
    expect(find.text('4 Days'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('picking a run slides the rail instead of reordering it', (
    tester,
  ) async {
    await pumpHome(tester);

    final fourDayCard = find.byKey(const ValueKey(2));
    final before = tester.getTopLeft(fourDayCard).dx;
    // It starts peeking in at the right edge — 311pt cards on a 360pt screen.
    expect(before, greaterThan(300));

    await tester.tap(find.text('7 Days'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    await tester.tap(find.text('4 Days'));
    // The route pops (170ms) and then the rail animates (360ms).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 400));

    // The card that was peeking is now the one at the left edge. Not exactly
    // 16: with only two cards the scroll clamps at its max extent before the
    // padding is used up.
    final after = tester.getTopLeft(fourDayCard).dx;
    expect(after, lessThan(60));
    expect(after, lessThan(before));
    // …and the pill followed it.
    expect(find.text('4 Days'), findsOneWidget);
    // The order never changed: the 7-day card is still first in the list.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey(1))).dx,
      lessThan(tester.getTopLeft(fourDayCard).dx),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
