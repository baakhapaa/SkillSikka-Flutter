import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/events/data/event.dart';
import 'package:skillsikka/features/events/data/event_page.dart';
import 'package:skillsikka/features/events/data/events_api.dart';
import 'package:skillsikka/features/events/data/events_providers.dart';
import 'package:skillsikka/features/events/presentation/event_details.dart';

import 'support/home_page_font_harness.dart';

/// The channel `geolocator` answers on.
///
/// **This constant existing at all is the fix for the 10-minute timeout.** See
/// [_allowDeniedLocation] for why the rail cannot resolve without it.
const _geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');

/// Makes `LocationService.hasPermission()` answer **immediately** with
/// "denied", which is the state this test wants anyway.
///
/// **Without this the rail's future never completes and the test hangs for
/// `defaultTestTimeout` (10 minutes) — that is the `TimeoutException after
/// 0:10:00.000000` this file used to produce, and it is not an environment
/// quirk.**
///
/// [nearbyEventsProvider] awaits [devicePositionProvider], which awaits
/// `detectBestEffortPosition` → `LocationService.hasPermission()` →
/// `Geolocator.checkPermission()`. That is a **MethodChannel** reply, delivered
/// as a real-async event. `testWidgets` runs the body in a `FakeAsync` zone that
/// neither drives the real event loop nor has a handler for this channel, so:
///
/// * the reply never arrives, so **the platform call never completes** — and
///   crucially it never *throws* either, so the `catch (_)` inside
///   `detectBestEffortPosition` never fires and the "null for every failure"
///   fallback its doc comment promises is never reached. The provider simply
///   stays `AsyncLoading` forever;
/// * the test body's `await container.read(nearbyEventsProvider.future)` then
///   never returns, and dies on `defaultTestTimeout` (`binding.dart:2240`).
///
/// Answering `denied` is *the same outcome the production code documents* for a
/// refused permission ("a refused permission costs the user distance ordering and
/// nothing else"), so this does not weaken the test: the rail still fetches, and
/// the assertion is still about whether `invalidate` caused a second fetch.
///
/// This mirrors `signup_location_prompt_test.dart`, which stubs the same channel
/// for the same reason.
void _allowDeniedLocation() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_geolocatorChannel, (call) async {
    // 0 == LocationPermission.denied in `geolocator`'s own enum encoding.
    if (call.method == 'checkPermission') return 0;
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(_geolocatorChannel, null),
  );
}

/// Registering must not leave the home rail's card showing a stale count.
///
/// **Regression test for the report "after registering the card still shows be
/// first to join".** The details screen updates its own copy of the event from
/// the response, but the rail renders a **cached** `nearbyEventsProvider` page —
/// so without an explicit invalidation the card behind the pushed route keeps
/// the `attendee_count` it was fetched with, which is 0 on a new event, which
/// renders as "Be the first to join".
///
/// The assertion is deliberately on the *number of times the list was fetched*
/// rather than on pixels: the bug is "the rail was never told to refetch", and
/// counting calls proves that directly instead of through a rendered string.
void main() {
  // The font harness is **hygiene, not the fix for the timeout** — see
  // [_allowDeniedLocation] for that. It is here only so this page's text does not
  // resolve through the real network path.
  //
  // `EventDetailsPage` calls `GoogleFonts.*`, and with no harness the resolve
  // walks the whole real chain in `google_fonts_base.dart:loadFontIfNecessary`:
  //
  //   1. the real `AssetManifest` — pubspec.yaml bundles only Roboto; no
  //      Manrope/Figtree/Inter, so there is no asset path to find;
  //   2. `loadFontFromDeviceFileSystem` — on Windows this is FFI, not a channel,
  //      so it does not throw: it reaches Win32 and does real `Directory.create`
  //      I/O in the fake-async zone;
  //   3. `_httpFetchFontAndSaveToDevice` — `allowRuntimeFetching` defaults to
  //      `true` (google_fonts_all_parts.g.dart:44), so a missed family opens a
  //      real HTTP request to `fonts.gstatic.com`.
  //
  // Steps 2 and 3 are real I/O driven by the real event loop, which the
  // `FakeAsync` zone does not pump. The harness closes step 1: its `aliases` set
  // covers Manrope/Figtree/Inter, which is *exactly* the three families this page
  // resolves, and serves all of them from one bundled Roboto face with
  // `allowRuntimeFetching = false`.
  //
  // **Do not mistake this for the timeout's cause.** `GoogleFonts.*` returns its
  // `TextStyle` synchronously and never awaits, and `GoogleFonts.pendingFonts()`
  // hands back the *cached* `loadingFuture` for an already-loaded family
  // (`google_fonts_base.dart:137`) rather than starting a new load — so no font
  // await was ever on this test's critical path.
  installHomePageFontHarness();

  testWidgets('registering invalidates the rail so its card is not stale', (
    tester,
  ) async {
    _allowDeniedLocation();

    final api = _FakeEventsApi();
    final container = ProviderContainer(
      overrides: [eventsApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    // A listener is what makes `invalidate` observable at all — with nothing
    // subscribed, the provider is only marked dirty and nothing recomputes.
    container.listen(nearbyEventsProvider, (_, _) {});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EventDetailsPage(eventId: 1)),
      ),
    );
    await tester.pump();

    await _settleRail(tester, container);
    final fetchesBeforeRegistering = api.listCalls;
    expect(
      fetchesBeforeRegistering,
      greaterThan(0),
      reason: 'the rail must have fetched once before the tap',
    );

    expect(
      find.text('Register Now'),
      findsOneWidget,
      reason: 'the fake event starts unregistered with seats free',
    );

    await tester.tap(find.text('Register Now'));
    await tester.pump();
    await tester.pump();

    expect(api.registerCalls, 1, reason: 'the tap must reach the API');

    await _settleRail(tester, container);

    expect(
      api.listCalls,
      greaterThan(fetchesBeforeRegistering),
      reason:
          'a successful registration must invalidate the rail, or its card '
          'keeps the attendee count it was fetched with',
    );
  });
}

/// Resolves [nearbyEventsProvider] and settles the frames it schedules.
///
/// Reading `.future` is what forces a recompute when the provider was
/// invalidated, and returns the cached value when it was not — so the caller's
/// assertion is exact either way. Plain `pump`s afterwards are what let the
/// refetch's own frames land; a single `pump` is not enough once a listener is
/// driving a rebuild.
///
/// **No `runAsync` and no `timeout`.** The channel reply is stubbed by
/// [_allowDeniedLocation], so this resolves entirely under the fake clock — which
/// is the point: `runAsync` would move it onto the real clock and make the
/// timeout a real-time bound.
Future<void> _settleRail(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await container.read(nearbyEventsProvider.future);
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
}

/// A hand-rolled double, because `EventsApi` is a concrete class with no
/// interface to implement against.
///
/// `implements` rather than `extends`: private members are not part of a class's
/// interface from another library, so the `ApiClient` field does not have to be
/// faked — only the public surface this test exercises.
class _FakeEventsApi implements EventsApi {
  int listCalls = 0;
  int registerCalls = 0;

  /// Unregistered, seats free — so the button reads "Register Now".
  Event get _base => Event(
    id: 1,
    title: 'Test event',
    attendeeCount: 0,
    capacity: 200,
    spotsLeft: 200,
    endAt: DateTime.now().toUtc().add(const Duration(days: 3)),
  );

  /// What the server returns from `register` — one more attendee, one fewer seat.
  Event get _registered => _base.copyWith(
    myStatus: EventRegistrationStatus.registered,
    attendeeCount: 1,
    spotsLeft: 199,
  );

  @override
  Future<EventPage> list({
    bool? near,
    double? lat,
    double? lng,
    double? radiusKm,
    bool? upcoming,
    String? format,
    int? district,
    int? municipality,
    String? search,
    String? ordering,
    int? page,
    int? pageSize,
  }) async {
    listCalls++;
    return EventPage.empty;
  }

  @override
  Future<EventPage> nextPage(String url) async => EventPage.empty;

  @override
  Future<EventPage> saved() async => EventPage.empty;

  @override
  Future<Event> detail(int id) async => _base;

  @override
  Future<Event?> register(int id) async {
    registerCalls++;
    return _registered;
  }

  @override
  Future<Event?> cancelRegistration(int id) async => _base;

  @override
  Future<bool?> save(int id) async => true;

  @override
  Future<bool?> unsave(int id) async => false;
}
