import 'package:flutter/foundation.dart';

import 'event.dart';

/// Which fallback step the server used to answer a `near=true` request.
///
/// The backend reports this in `near_scope` and **only when `near=true`** is
/// sent. It exists so the rail can say what it is actually showing: an event
/// 300 km away is not "near you", and labelling it that way is worse than a
/// duller heading.
enum NearScope {
  /// Events with coordinates within `radius_km` of the device position.
  gps('gps'),

  /// No GPS match (or none sent): the user's profile municipality.
  municipality('municipality'),

  /// Nothing in the municipality: the user's profile district.
  district('district'),

  /// Nothing nearby: every upcoming event, by date.
  all('all'),

  /// Not reported, or a value this client does not know.
  unknown('');

  const NearScope(this.wire);

  final String wire;

  static NearScope tryParse(Object? value) {
    if (value is! String) return NearScope.unknown;
    final needle = value.trim().toLowerCase();
    for (final scope in NearScope.values) {
      if (scope != NearScope.unknown && scope.wire == needle) return scope;
    }
    return NearScope.unknown;
  }

  /// The rail heading for this scope.
  ///
  /// [unknown] falls back to the plainest of the four rather than to "near you":
  /// claiming proximity is the one thing that would be wrong if the server
  /// stopped reporting the scope.
  String get railTitle => switch (this) {
    NearScope.gps => 'Events near you',
    NearScope.municipality => 'Events in your area',
    NearScope.district => 'Events in your district',
    NearScope.all => 'Upcoming events',
    NearScope.unknown => 'Upcoming events',
  };
}

/// One page of events, as the list endpoints return them.
///
/// **This is a paginated envelope, not a bare array** — `{count, next,
/// previous, near_scope, results}`. The client's existing list-returning `get`
/// cannot read it, which is why the events API parses a map and takes `results`.
@immutable
class EventPage {
  const EventPage({
    this.events = const [],
    this.nextUrl,
    this.count = 0,
    this.nearScope,
  });

  final List<Event> events;

  /// The absolute URL of the next page, or null on the last page.
  ///
  /// Kept as the server sent it and fetched as-is — re-building it from the
  /// original query would be a second place for the filters to disagree.
  final String? nextUrl;

  /// Total matching records across all pages, as the server counts them.
  final int count;

  /// Present only when the request carried `near=true`.
  final NearScope? nearScope;

  bool get hasMore => nextUrl != null;

  bool get isEmpty => events.isEmpty;

  static const EventPage empty = EventPage();

  /// Parses the envelope, or null when the body is not one.
  ///
  /// Also accepts a **bare array**, because that is what every other list
  /// endpoint in this API returns (`/ebooks/`, `/courses/`, `/subjects/`), and a
  /// list that silently came back in the older shape should render rather than
  /// fail. A bare array is treated as a single page with no `next`.
  static EventPage? tryParse(Object? body) {
    if (body is List) {
      return EventPage(events: _parseEvents(body), count: body.length);
    }
    if (body is! Map) return null;

    final json = body.cast<Object?, Object?>();
    final results = json['results'];
    if (results is! List) return null;

    final events = _parseEvents(results);
    return EventPage(
      events: events,
      nextUrl: _nonEmptyString(json['next']),
      // `count` is the server's total; when it is absent, the page length is the
      // only honest number available.
      count: _asInt(json['count']) ?? events.length,
      nearScope: NearScope.tryParse(json['near_scope']),
    );
  }

  static List<Event> _parseEvents(List<Object?> raw) {
    final result = <Event>[];
    for (final entry in raw) {
      final event = Event.tryParse(entry);
      // One malformed record costs the user that record, not the whole page.
      if (event != null) result.add(event);
    }
    return List.unmodifiable(result);
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}
