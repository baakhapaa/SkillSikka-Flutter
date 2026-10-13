import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/events/data/event.dart';
import 'package:skillsikka/features/events/data/event_page.dart';
import 'package:skillsikka/features/home/presentation/home_page.dart';

import 'support/events_test_scope.dart';
import 'support/home_page_font_harness.dart';

/// The events rail card must fit the one height every card in the rail shares.
///
/// **Regression test for the 13px overflow reported on 2026-10-08.** The card
/// rendered a 92px cover, a two-line title, the host line, the date/place line
/// and the action row, and the action row was pushed 13px past the bottom of the
/// then-220px rail — which is what drew the black-and-yellow stripe.
///
/// It reproduced **only with real data**: the two hardcoded records the rail
/// replaced had a one-line title and no date line, so the height fitted. That is
/// why none of the existing home-page layout tests caught it, and why this test
/// pins the payload the backend actually returns.
///
/// **2026-10-10 — the rail is back to the design's 220.** The title is now
/// capped at a single ellipsized line, which is what made that possible: the
/// details half's content is a constant (106.6 in a 110 half) instead of growing
/// with the title. So the worst case is no longer a two-line title — it is a
/// one-line title *with* a host and a date/place line. The cap is asserted
/// below, so this test cannot start passing because a title stopped wrapping.
///
/// Deliberately does **not** drain overflows: a `RenderFlex` overflow in this
/// card *is* the defect, exactly as in `home_heading_alignment_360_test`.
void main() {
  installHomePageFontHarness();

  testWidgets('the events rail card fits its rail height at 360pt', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // The tallest card the backend can produce. The title is capped at one line
    // (asserted below), so the height comes from the lines that *can* still grow:
    // the host and the date/place line. A title long enough to be ellipsized is
    // still the right thing to use here, because that is what a real one is.
    final event = Event.tryParse(
      jsonDecode('''
{
  "id": 1,
  "title": "[Sample] Advanced Algebra & Calculus Masterclass",
  "description": "Dive deep into higher-level analytical calculus.",
  "highlights": ["Integration made practical"],
  "cover_image_url": null,
  "host": {
    "id": 3,
    "name": "Test Instructor",
    "role": "Mathematics Dept Head",
    "avatar_url": null
  },
  "start_at": "2026-10-13T04:15:00Z",
  "end_at": "2026-10-13T08:15:00Z",
  "format": "in_person",
  "venue_name": "Seminar Hall A, Tech Hub",
  "city": "Kathmandu, Nepal",
  "distance_km": 0.0,
  "attendee_count": 0,
  "attendee_avatars": [],
  "capacity": 200,
  "spots_left": 200,
  "my_status": "none",
  "is_saved": false,
  "rating": null,
  "is_published": true
}
'''),
    );
    expect(event, isNotNull);

    await tester.pumpWidget(
      eventsTestScope(
        page: EventPage(events: [event!], count: 1, nearScope: NearScope.gps),
        child: const MaterialApp(home: HomePage()),
      ),
    );
    // One frame to settle the provider's future, one to build the loaded rail.
    await tester.pump();
    await tester.pump();

    // Guard against a vacuous pass: if the rail had not rendered, the overflow
    // assertion below would hold for entirely the wrong reason.
    expect(find.text('Events near you'), findsOneWidget);
    expect(find.text('By Test Instructor'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);

    // The one-line cap is load-bearing — it is what keeps the card's height, and
    // so the gap above the action row, constant. Assert it rather than trusting
    // the arithmetic above to notice if the cap is ever raised back to two.
    final title = tester.widget<Text>(
      find.text('[Sample] Advanced Algebra & Calculus Masterclass'),
    );
    expect(title.maxLines, 1);

    expect(
      tester.takeException(),
      isNull,
      reason: 'the rail card must fit the height it shares with every card',
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
