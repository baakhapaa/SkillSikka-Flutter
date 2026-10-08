import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/events/data/event.dart';
import 'package:skillsikka/features/events/data/event_page.dart';
import 'package:skillsikka/features/events/data/events_api.dart';
import 'package:skillsikka/features/events/data/events_providers.dart';
import 'package:skillsikka/features/events/presentation/event_details.dart';

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
  testWidgets('registering invalidates the rail so its card is not stale', (
    tester,
  ) async {
    final api = _FakeEventsApi();
    final container = ProviderContainer(
      overrides: [eventsApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    // A listener is what makes `invalidate` observable at all — with nothing
    // subscribed, the provider is only marked dirty and nothing recomputes.
    container.listen(nearbyEventsProvider, (_, _) {});
    await container.read(nearbyEventsProvider.future);
    final fetchesBeforeRegistering = api.listCalls;
    expect(
      fetchesBeforeRegistering,
      greaterThan(0),
      reason: 'the rail must have fetched once before the tap',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EventDetailsPage(eventId: 1)),
      ),
    );
    await tester.pump();

    expect(
      find.text('Register Now'),
      findsOneWidget,
      reason: 'the fake event starts unregistered with seats free',
    );

    await tester.tap(find.text('Register Now'));
    await tester.pump();
    await tester.pump();

    expect(api.registerCalls, 1, reason: 'the tap must reach the API');

    // Read forces a recompute if the provider was invalidated, and returns the
    // cached value if it was not — so this assertion is exact either way.
    await container.read(nearbyEventsProvider.future);

    expect(
      api.listCalls,
      greaterThan(fetchesBeforeRegistering),
      reason:
          'a successful registration must invalidate the rail, or its card '
          'keeps the attendee count it was fetched with',
    );
  });
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
