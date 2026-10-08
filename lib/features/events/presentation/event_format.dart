import '../data/event.dart';

/// Text formatting for the events screens.
///
/// **Hand-rolled rather than `intl`.** This project has no `intl` dependency,
/// and adding one for four short labels would pull in a locale database the app
/// does not otherwise use. The cost is that these are English-only and
/// hardcoded to the Gregorian calendar — fine for the one market the app ships
/// in, and the place to look when it is not.
///
/// **Every function takes UTC and converts once**, because that is what the
/// backend sends (`start_at: "2026-10-13T04:15:00Z"`). Nepal is **UTC+05:45** —
/// a 45-minute offset, so getting this wrong moves the time by 45 minutes even
/// when the date is right. Converting in exactly one place is what keeps the
/// date and the time from disagreeing.

const _weekdays = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _months = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// `"Tuesday, October 13"`, in the device's local time, or null when there is
/// no date to show.
///
/// Null rather than a placeholder so the caller decides whether to drop the row
/// or draw it differently — the details screen hides the whole date card.
String? eventDateLabel(DateTime? startUtc) {
  if (startUtc == null) return null;
  final local = startUtc.toLocal();
  final weekday = _weekdays[local.weekday - 1];
  final month = _months[local.month - 1];
  return '$weekday, $month ${local.day}';
}

/// `"10:00 AM – 2:00 PM"` in local time.
///
/// Falls back to a single time when there is no end, and to null when there is
/// no start. The separator is an en dash, matching the design.
String? eventTimeLabel(DateTime? startUtc, DateTime? endUtc) {
  final start = _clockTime(startUtc);
  if (start == null) return null;
  final end = _clockTime(endUtc);
  if (end == null) return start;
  return '$start \u2013 $end';
}

/// `"10:00 AM"` from a UTC instant, or null.
String? _clockTime(DateTime? utc) {
  if (utc == null) return null;
  final local = utc.toLocal();
  final hour24 = local.hour;
  // 0 -> 12 AM, 12 -> 12 PM, 13 -> 1 PM. `% 12` alone gives 0 for both midnight
  // and noon, which is why the hour is mapped explicitly.
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = hour24 < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}

/// `"Kathmandu, Nepal (In-Person)"`, `"Online"`, or `''`.
///
/// The design puts the city and the format on one line. An online event has no
/// city, and " (Online)" on its own reads as a stray bracket, so that case
/// collapses to the bare label. An unknown format with a city shows just the
/// city rather than a guessed label.
String eventPlaceLabel({required String city, required EventFormat format}) {
  final place = city.trim();
  final label = format.label;

  if (place.isEmpty) return label;
  if (label.isEmpty) return place;
  return '$place ($label)';
}

/// `"3.4 km away"`, or null when there is no distance to show.
///
/// One decimal place, as the brief specifies. Null — rather than "0.0 km" — when
/// the server sent no distance, which is the normal case when the client had no
/// position to send.
String? distanceLabel(double? distanceKm) {
  if (distanceKm == null || distanceKm.isNaN || distanceKm.isInfinite) {
    return null;
  }
  return '${distanceKm.toStringAsFixed(1)} km away';
}

/// `"120+ attending"`, or a nudge when nobody has registered yet.
///
/// The nudge is the brief's: a bare "0 attending" reads as a warning, and an
/// empty-looking event is the one most in need of the opposite framing.
String attendingLabel(int count) {
  if (count <= 0) return 'Be the first to join';
  return '$count+ attending';
}

/// `"4.9"` — one decimal place. The caller hides the stars entirely while
/// [Event.rating] is null, so this is only reached when there is a rating.
String ratingLabel(double rating) => rating.toStringAsFixed(1);

/// `"12 spots left"`, or null when seats are unlimited or unknown.
///
/// A full event reads as the waitlist rather than "0 spots left".
String? spotsLabel(int? spotsLeft) {
  if (spotsLeft == null) return null;
  if (spotsLeft <= 0) return 'Waitlist open';
  if (spotsLeft == 1) return '1 spot left';
  return '$spotsLeft spots left';
}
