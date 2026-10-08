import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/events/data/event.dart';
import 'package:skillsikka/features/events/presentation/event_format.dart';

/// Formatting the events payload for the screen.
///
/// **Timezone note.** `flutter test` runs in the machine's own zone, so an
/// assertion like "`04:15:00Z` renders as 10:00 AM" would only hold in Nepal
/// (UTC+05:45) and would fail on a UTC CI box. Every case below therefore builds
/// its input as a **local** `DateTime` and converts it to UTC, which makes the
/// expected output identical in every zone while still exercising the conversion
/// path. The one test that uses a raw UTC instant asserts agreement with its own
/// local equivalent rather than a hardcoded clock time, for the same reason.
void main() {
  /// A wall-clock local time, expressed as the UTC instant the API would send.
  DateTime asWire(int year, int month, int day, int hour, int minute) =>
      DateTime(year, month, day, hour, minute).toUtc();

  group('eventDateLabel', () {
    test('names the weekday and the month', () {
      // 13 October 2026 is a Tuesday.
      expect(
        eventDateLabel(asWire(2026, 10, 13, 10, 0)),
        'Tuesday, October 13',
      );
    });

    test('is null when there is no date', () {
      expect(eventDateLabel(null), isNull);
    });

    test('handles the first and last month of the year', () {
      expect(eventDateLabel(asWire(2026, 1, 1, 9, 0)), 'Thursday, January 1');
      expect(
        eventDateLabel(asWire(2026, 12, 31, 9, 0)),
        'Thursday, December 31',
      );
    });
  });

  group('eventTimeLabel', () {
    test('renders a range with an en dash', () {
      expect(
        eventTimeLabel(
          asWire(2026, 10, 13, 10, 0),
          asWire(2026, 10, 13, 14, 0),
        ),
        '10:00 AM \u2013 2:00 PM',
      );
    });

    test('maps midnight and noon to 12 rather than 0', () {
      // `hour % 12` alone gives 0 for both, which is the classic bug here.
      expect(eventTimeLabel(asWire(2026, 10, 13, 0, 0), null), '12:00 AM');
      expect(eventTimeLabel(asWire(2026, 10, 13, 12, 0), null), '12:00 PM');
    });

    test('pads the minute and drops the leading zero on the hour', () {
      expect(eventTimeLabel(asWire(2026, 10, 13, 13, 5), null), '1:05 PM');
      expect(eventTimeLabel(asWire(2026, 10, 13, 9, 30), null), '9:30 AM');
    });

    test('falls back to a single time when there is no end', () {
      expect(eventTimeLabel(asWire(2026, 10, 13, 10, 0), null), '10:00 AM');
    });

    test('is null when there is no start, even if an end exists', () {
      expect(eventTimeLabel(null, asWire(2026, 10, 13, 14, 0)), isNull);
    });

    test('converts a UTC instant to the device local time', () {
      // Passing the same instant already expressed locally must render the same
      // wall clock — which is only true if the UTC input is being converted.
      final utc = DateTime.utc(2026, 10, 13, 4, 15);
      expect(eventTimeLabel(utc, null), eventTimeLabel(utc.toLocal(), null));
    });
  });

  group('eventPlaceLabel', () {
    test('joins the city and the format', () {
      expect(
        eventPlaceLabel(city: 'Kathmandu, Nepal', format: EventFormat.inPerson),
        'Kathmandu, Nepal (In-Person)',
      );
      expect(
        eventPlaceLabel(city: 'Bhaktapur', format: EventFormat.hybrid),
        'Bhaktapur (Hybrid)',
      );
    });

    test('collapses to the bare label for an online event with no city', () {
      // The brief calls this out: "For online with empty city, show just
      // Online" — otherwise it renders as a stray " (Online)".
      expect(eventPlaceLabel(city: '', format: EventFormat.online), 'Online');
    });

    test('shows the city alone when the format is unknown', () {
      expect(
        eventPlaceLabel(city: 'Pokhara', format: EventFormat.unknown),
        'Pokhara',
      );
    });

    test('is empty when there is neither', () {
      expect(eventPlaceLabel(city: '', format: EventFormat.unknown), isEmpty);
    });
  });

  group('distanceLabel', () {
    test('rounds to one decimal place and says how far', () {
      expect(distanceLabel(3.44), '3.4 km away');
      expect(distanceLabel(6.5), '6.5 km away');
      expect(distanceLabel(0.0), '0.0 km away');
    });

    test('is null when the server sent no distance', () {
      // The normal case when the client had no position to send.
      expect(distanceLabel(null), isNull);
    });

    test('is null for a non-finite value rather than printing NaN', () {
      expect(distanceLabel(double.nan), isNull);
      expect(distanceLabel(double.infinity), isNull);
    });
  });

  group('attendingLabel', () {
    test('frames an empty event as an invitation, not a warning', () {
      expect(attendingLabel(0), 'Be the first to join');
    });

    test('counts attendance with a plus', () {
      expect(attendingLabel(1), '1+ attending');
      expect(attendingLabel(120), '120+ attending');
    });
  });

  group('spotsLabel', () {
    test('is null when seats are unlimited or unknown', () {
      expect(spotsLabel(null), isNull);
    });

    test('offers the waitlist when full', () {
      expect(spotsLabel(0), 'Waitlist open');
    });

    test('is singular for one seat', () {
      expect(spotsLabel(1), '1 spot left');
    });

    test('counts the remaining seats', () {
      expect(spotsLabel(200), '200 spots left');
    });
  });

  group('ratingLabel', () {
    test('is one decimal place', () {
      expect(ratingLabel(4.5), '4.5');
      expect(ratingLabel(5), '5.0');
    });
  });
}
