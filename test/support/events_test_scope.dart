import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillsikka/features/events/data/event_page.dart';
import 'package:skillsikka/features/events/data/events_providers.dart';

/// Wraps [child] in a `ProviderScope` whose events rail is stubbed.
///
/// **Why this exists.** The home page's "Event near you" rail is provider-driven
/// as of 2026-10-08. Four suites pump `HomePage` — or `AppShell`, which mounts it
/// — with no scope at all, because they measure layout and nothing else. Without
/// a scope the rail throws `ProviderScope not found` on its first build.
///
/// Overriding [nearbyEventsProvider] itself, rather than the API or the location
/// service, is deliberate: it is the single seam the rail reads, so one override
/// removes **both** the network request and the `geolocator` call — and
/// `geolocator` has no implementation under `flutter test`, where every method
/// throws `MissingPluginException`.
///
/// The default is an **empty** page, which makes the rail render nothing. That
/// keeps a layout test measuring the sections it actually asserts on, instead of
/// a rail whose height depends on whether a mocked request has landed yet.
Widget eventsTestScope({required Widget child, EventPage? page}) {
  return ProviderScope(
    overrides: [
      nearbyEventsProvider.overrideWith((ref) async => page ?? EventPage.empty),
    ],
    child: child,
  );
}
