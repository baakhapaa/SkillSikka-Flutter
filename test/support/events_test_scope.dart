import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillsikka/features/bootcamp/data/bootcamp.dart';
import 'package:skillsikka/features/bootcamp/data/bootcamp_api.dart';
import 'package:skillsikka/features/events/data/event_page.dart';
import 'package:skillsikka/features/events/data/events_providers.dart';

/// Wraps [child] in a `ProviderScope` whose home-page network rails are stubbed.
///
/// **Two rails, one scope.** `Event near you` is provider-driven as of
/// 2026-10-08 and `ICT & AI Bootcamp` as of 2026-10-31. Both fetch on their
/// first build, and a test that disposes the tree mid-request fails on the
/// *next* assertion with `A Timer is still pending` — dio's 15s timeout outlives
/// the widget. Overriding the providers themselves removes the request (and, for
/// the events rail, the `geolocator` call, which throws `MissingPluginException`
/// under `flutter test`).
///
/// **Overriding the provider, not the API**, is deliberate: it is the single
/// seam each rail reads, so one override removes the network, the location call
/// and the timer together.
///
/// Both defaults are **empty**, which makes each rail render nothing. That keeps
/// a layout test measuring the sections it actually asserts on, instead of a
/// rail whose height depends on whether a mocked request has landed yet.
///
/// The name predates the second rail and is kept so seven suites do not churn
/// over a rename; it is a home-page scope, not an events-only one.
Widget eventsTestScope({
  required Widget child,
  EventPage? page,
  List<BootcampCard> bootcamps = const <BootcampCard>[],
}) {
  return ProviderScope(
    overrides: [
      nearbyEventsProvider.overrideWith((ref) async => page ?? EventPage.empty),
      bootcampsProvider.overrideWith((ref) async => bootcamps),
    ],
    child: child,
  );
}
