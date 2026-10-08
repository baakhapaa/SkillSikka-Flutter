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
/// Deliberately does **not** drain overflows: a `RenderFlex` overflow in this
/// card *is* the defect, exactly as in `home_heading_alignment_360_test`.
void main() {
  installHomePageFontHarness();

  testWidgets('the events rail card fits its rail height at 360pt', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // The longest card the backend can produce: a title that wraps to two lines
    // plus a host and a date/place line. Every text is capped by `maxLines`, so
    // this is the worst case, not one sample of many.
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

    expect(
      tester.takeException(),
      isNull,
      reason: 'the rail card must fit the height it shares with every card',
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
