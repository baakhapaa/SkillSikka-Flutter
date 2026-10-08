import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import 'event_page.dart';
import 'events_api.dart';

/// A device position, when one could be obtained.
typedef DevicePosition = ({double latitude, double longitude});

/// The device's position, or null for **every** failure.
///
/// Location services switched off, permission denied, denied forever, a lookup
/// that never arrived — all of them return null, deliberately. The rail must not
/// depend on a position: the backend falls back to the user's profile
/// municipality, then their district, then every upcoming event, and needs no
/// position at all to do any of it. So a refused permission costs the user
/// distance ordering and nothing else.
///
/// Permission is *checked* before it is requested, so this never raises the OS
/// prompt on its own. A prompt belongs to a moment the user chose — the signup
/// form, or a location button — not to the home screen scrolling past.
Future<DevicePosition?> detectBestEffortPosition(
  LocationService service,
) async {
  try {
    if (!await service.hasPermission()) return null;
    final location = await service.detectCurrentLocation();
    return (latitude: location.latitude, longitude: location.longitude);
  } catch (_) {
    // `LocationFailure` for the four documented cases, plus
    // `MissingPluginException` under a widget test. Both mean the same thing
    // here: no position, carry on without one.
    return null;
  }
}

/// The device's position, resolved once per session and cached.
///
/// **Split out of [nearbyEventsProvider] deliberately.** The rail's events are
/// invalidated after every registration — otherwise its card keeps showing "Be
/// the first to join" — and if the position lived inside that same provider,
/// every one of those invalidations would re-run the GPS lookup for a position
/// that cannot have changed in between. Kept apart, invalidating the events
/// reuses the cached position.
///
/// Invalidate *this* to re-resolve the position, e.g. after the user grants
/// permission from Settings.
final devicePositionProvider = FutureProvider<DevicePosition?>(
  (ref) => detectBestEffortPosition(ref.watch(locationServiceProvider)),
);

/// The home rail: events nearest-first, with the server's fallback chain.
///
/// `near=true` is what makes the server pick the scope and report it in
/// `near_scope`; the rail reads that back to label itself honestly. A position
/// is passed only when one was actually obtained, and never half of one — the
/// backend rejects `lat` without `lng`.
///
/// **Invalidate this after anything that changes a registration**, or the rail
/// keeps serving its cached page and the card's attendee count goes stale —
/// which is exactly the "still says Be the first to join" report.
final nearbyEventsProvider = FutureProvider<EventPage>((ref) async {
  final position = await ref.watch(devicePositionProvider.future);
  return ref
      .watch(eventsApiProvider)
      .list(
        near: true,
        lat: position?.latitude,
        lng: position?.longitude,
        pageSize: 10,
      );
});
