import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/events/data/event.dart';
import 'package:skillsikka/features/events/data/event_page.dart';

/// Parsing the events payload.
///
/// **The tolerance tested here is not hypothetical.** The backend's brief
/// (verified against the running server on 2026-10-08) shows `attendee_count: 0`
/// and `distance_km: 0.0` as numbers, while the generated OpenAPI schema types
/// every one of those fields as `string`, because they are DRF
/// `SerializerMethodField`s the schema generator cannot type. The client is
/// written to accept either, and these tests pin that down — a `String` where an
/// `int` is expected would throw inside the parser and take the whole list with
/// it, which is the single most likely way this integration breaks.
void main() {
  /// The payload from the brief's §3, verbatim.
  Map<String, dynamic> documentedPayload() =>
      jsonDecode('''
{
  "id": 1,
  "title": "Advanced Algebra & Calculus Masterclass",
  "description": "Dive deep into…",
  "highlights": ["Integration made practical", "Graphing techniques"],
  "cover_image_url": "http://192.168.1.68:8000/media/events/0028ee35.png",
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
  "province_id": 3,
  "district_id": 27,
  "municipality_id": 307,
  "latitude": 27.7172,
  "longitude": 85.324,
  "distance_km": 0.0,
  "attendee_count": 0,
  "attendee_avatars": [],
  "capacity": 200,
  "spots_left": 200,
  "my_status": "none",
  "is_saved": false,
  "rating": null,
  "is_published": true,
  "created_at": "2026-10-08T10:20:00Z",
  "updated_at": "2026-10-08T10:20:00Z"
}
''')
          as Map<String, dynamic>;

  group('Event.tryParse', () {
    test('reads the documented payload', () {
      final event = Event.tryParse(documentedPayload());

      expect(event, isNotNull);
      expect(event!.id, 1);
      expect(event.title, 'Advanced Algebra & Calculus Masterclass');
      expect(event.format, EventFormat.inPerson);
      expect(event.city, 'Kathmandu, Nepal');
      expect(event.venueName, 'Seminar Hall A, Tech Hub');
      expect(event.highlights, hasLength(2));
      expect(event.attendeeAvatars, isEmpty);
      expect(event.attendeeCount, 0);
      expect(event.capacity, 200);
      expect(event.spotsLeft, 200);
      expect(event.distanceKm, 0.0);
      expect(event.myStatus, EventRegistrationStatus.none);
      expect(event.isSaved, isFalse);
      expect(event.rating, isNull);
      expect(event.host!.name, 'Test Instructor');
      expect(event.host!.role, 'Mathematics Dept Head');
      expect(event.host!.avatarUrl, isNull);
    });

    test('accepts the string-typed numbers the OpenAPI schema describes', () {
      // Exactly the shape the schema would produce: every method field a string.
      final event = Event.tryParse({
        'id': '7',
        'title': 'String-typed',
        'distance_km': '3.4',
        'attendee_count': '12',
        'spots_left': '0',
        'is_saved': 'true',
        'rating': '4.5',
        'latitude': '27.7',
        'longitude': '85.3',
      });

      expect(event, isNotNull);
      expect(event!.id, 7);
      expect(event.distanceKm, 3.4);
      expect(event.attendeeCount, 12);
      expect(event.spotsLeft, 0);
      expect(event.isSaved, isTrue);
      expect(event.rating, 4.5);
      expect(event.latitude, 27.7);
      expect(event.longitude, 85.3);
      expect(event.isFull, isTrue, reason: 'spots_left 0 means full');
    });

    test('is dropped without an id, because it could not be opened', () {
      expect(Event.tryParse({'title': 'No id'}), isNull);
      expect(Event.tryParse({'id': null, 'title': 'Null id'}), isNull);
      expect(Event.tryParse('not a map'), isNull);
      expect(Event.tryParse(null), isNull);
    });

    test('keeps an event with no title rather than hiding it', () {
      final event = Event.tryParse({'id': 9});
      expect(event, isNotNull);
      expect(event!.title, 'Untitled event');
    });

    test('drops a host with no name instead of rendering a blank row', () {
      final nameless = Event.tryParse({
        'id': 2,
        'host': {'id': 3, 'name': '', 'role': 'Teacher'},
      });
      expect(nameless!.host, isNull);

      final absent = Event.tryParse({'id': 3, 'host': null});
      expect(absent!.host, isNull);
    });

    test('defaults a missing host role rather than showing an empty line', () {
      final event = Event.tryParse({
        'id': 4,
        'host': {'name': 'Someone'},
      });
      expect(event!.host!.role, 'Instructor');
    });

    test('treats empty strings as absent', () {
      // The brief says `description`, `venue_name` and `city` may be `''`.
      final event = Event.tryParse({
        'id': 5,
        'description': '',
        'venue_name': '',
        'city': '',
        'cover_image_url': '',
      });

      expect(event!.description, isEmpty);
      expect(event.venueName, isEmpty);
      expect(event.city, isEmpty);
      expect(event.coverImageUrl, isNull, reason: '"" is not a usable URL');
    });

    test('decodes highlights that arrive as a JSON-encoded string', () {
      // The schema types `highlights` as `string`; the brief shows a list.
      final event = Event.tryParse({'id': 6, 'highlights': '["One","Two"]'});
      expect(event!.highlights, ['One', 'Two']);

      final plain = Event.tryParse({'id': 7, 'highlights': 'Just one'});
      expect(plain!.highlights, ['Just one']);
    });

    test('normalises datetimes to UTC', () {
      final event = Event.tryParse({
        'id': 8,
        'start_at': '2026-10-13T04:15:00Z',
        'end_at': '2026-10-13T08:15:00Z',
      });

      expect(event!.startAt, DateTime.utc(2026, 10, 13, 4, 15));
      expect(event.startAt!.isUtc, isTrue);
      expect(event.endAt, DateTime.utc(2026, 10, 13, 8, 15));
    });

    test('reads an unknown format as unknown rather than guessing', () {
      expect(
        Event.tryParse({'id': 9, 'format': 'holographic'})!.format,
        EventFormat.unknown,
      );
      expect(EventFormat.unknown.label, isEmpty);
    });

    test('reads an unknown my_status without treating it as registered', () {
      final event = Event.tryParse({'id': 10, 'my_status': 'something-new'});
      expect(event!.myStatus, EventRegistrationStatus.unknown);
      expect(event.myStatus.isOnList, isFalse);
    });
  });

  group('Event.derived state', () {
    test('hasEnded compares in UTC, so the device offset cannot shift it', () {
      final past = Event(
        id: 1,
        title: 'Past',
        endAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      );
      final future = Event(
        id: 2,
        title: 'Future',
        endAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      final undated = Event(id: 3, title: 'No end');

      expect(past.hasEnded, isTrue);
      expect(future.hasEnded, isFalse);
      expect(
        undated.hasEnded,
        isFalse,
        reason: 'no end_at must not disable the button on a guess',
      );
    });

    test('isFull is false when seats are unlimited', () {
      expect(Event(id: 1, title: 'x', spotsLeft: null).isFull, isFalse);
      expect(Event(id: 1, title: 'x', spotsLeft: 3).isFull, isFalse);
      expect(Event(id: 1, title: 'x', spotsLeft: 0).isFull, isTrue);
    });

    test('withLocalRegistration adjusts the counts it can know', () {
      const base = Event(
        id: 1,
        title: 'x',
        attendeeCount: 10,
        spotsLeft: 5,
        myStatus: EventRegistrationStatus.none,
      );

      final registered = base.withLocalRegistration(
        EventRegistrationStatus.registered,
      );
      expect(registered.attendeeCount, 11);
      expect(registered.spotsLeft, 4);

      // The waitlist is not counted and does not consume a seat.
      final waitlisted = base.withLocalRegistration(
        EventRegistrationStatus.waitlisted,
      );
      expect(waitlisted.attendeeCount, 10);
      expect(waitlisted.spotsLeft, 5);

      final cancelled = registered.withLocalRegistration(
        EventRegistrationStatus.none,
      );
      expect(cancelled.attendeeCount, 10);
      expect(cancelled.spotsLeft, 5);

      // Cancelling a waitlist place changes neither count.
      final leftQueue = waitlisted.withLocalRegistration(
        EventRegistrationStatus.none,
      );
      expect(leftQueue.attendeeCount, 10);
      expect(leftQueue.spotsLeft, 5);
    });
  });

  group('EventPage.tryParse', () {
    test('reads the paginated envelope and its scope', () {
      final page = EventPage.tryParse({
        'count': 3,
        'next': 'http://192.168.1.68:8000/api/v1/events/?near=true&page=2',
        'previous': null,
        'near_scope': 'gps',
        'results': [documentedPayload()],
      });

      expect(page, isNotNull);
      expect(page!.count, 3);
      expect(page.events, hasLength(1));
      expect(page.hasMore, isTrue);
      expect(page.nearScope, NearScope.gps);
    });

    test('next is null on the last page', () {
      final page = EventPage.tryParse({
        'count': 1,
        'next': null,
        'previous': null,
        'results': [documentedPayload()],
      });
      expect(page!.hasMore, isFalse);
      expect(page.nextUrl, isNull);
    });

    test(
      'accepts a bare array, which is what the other list routes return',
      () {
        final page = EventPage.tryParse([documentedPayload()]);
        expect(page, isNotNull);
        expect(page!.events, hasLength(1));
        expect(page.count, 1);
        expect(page.nearScope, isNull);
      },
    );

    test('returns null when there is no results list', () {
      expect(EventPage.tryParse({'count': 0}), isNull);
      expect(EventPage.tryParse('nonsense'), isNull);
      expect(EventPage.tryParse(null), isNull);
    });

    test('skips one malformed record without losing the page', () {
      final page = EventPage.tryParse({
        'count': 3,
        'results': [
          documentedPayload(),
          {'title': 'no id'},
          {'id': 2, 'title': 'Fine'},
        ],
      });

      expect(page!.events, hasLength(2));
      expect(page.events.map((e) => e.id), [1, 2]);
    });

    test('an unknown near_scope does not claim the events are near', () {
      expect(NearScope.tryParse('somewhere-new'), NearScope.unknown);
      expect(NearScope.unknown.railTitle, 'Upcoming events');
      expect(NearScope.gps.railTitle, 'Events near you');
      expect(NearScope.municipality.railTitle, 'Events in your area');
      expect(NearScope.district.railTitle, 'Events in your district');
      expect(NearScope.all.railTitle, 'Upcoming events');
    });
  });
}
