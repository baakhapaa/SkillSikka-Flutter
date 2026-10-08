import 'dart:convert';

import 'package:flutter/foundation.dart';

/// How an event is attended.
///
/// The wire values are the backend's `FormatEnum` (`in_person`, `online`,
/// `hybrid`), read off the live OpenAPI schema on 2026-10-08.
enum EventFormat {
  inPerson('in_person'),
  online('online'),
  hybrid('hybrid'),

  /// A value the client does not know. Kept rather than thrown so a new format
  /// added on the server costs the user a label, not the whole event.
  unknown('');

  const EventFormat(this.wire);

  final String wire;

  static EventFormat tryParse(Object? value) {
    if (value is! String) return EventFormat.unknown;
    final needle = value.trim().toLowerCase();
    for (final format in EventFormat.values) {
      if (format != EventFormat.unknown && format.wire == needle) return format;
    }
    return EventFormat.unknown;
  }

  /// The human label, or `''` when the format is unknown — the caller decides
  /// what to show instead of being handed a guess.
  String get label => switch (this) {
    EventFormat.inPerson => 'In-Person',
    EventFormat.online => 'Online',
    EventFormat.hybrid => 'Hybrid',
    EventFormat.unknown => '',
  };
}

/// Where the signed-in user stands on an event.
///
/// Wire values are `none` / `registered` / `waitlisted`.
enum EventRegistrationStatus {
  none('none'),
  registered('registered'),
  waitlisted('waitlisted'),
  unknown('');

  const EventRegistrationStatus(this.wire);

  final String wire;

  static EventRegistrationStatus tryParse(Object? value) {
    if (value is! String) return EventRegistrationStatus.unknown;
    final needle = value.trim().toLowerCase();
    for (final status in EventRegistrationStatus.values) {
      if (status != EventRegistrationStatus.unknown && status.wire == needle) {
        return status;
      }
    }
    return EventRegistrationStatus.unknown;
  }

  /// True when the user is on the list in either capacity, so the action on the
  /// button is a cancel rather than a join.
  bool get isOnList =>
      this == EventRegistrationStatus.registered ||
      this == EventRegistrationStatus.waitlisted;
}

/// The instructor an event belongs to.
///
/// Nested in the event payload. Nullable as a whole: an event with no host hides
/// the host row rather than showing a blank name.
@immutable
class EventHost {
  const EventHost({
    this.id,
    required this.name,
    this.role = 'Instructor',
    this.avatarUrl,
  });

  final int? id;
  final String name;

  /// Never empty on the wire — the backend defaults it to `"Instructor"` — but
  /// defaulted here too so a missing key cannot produce an empty subtitle.
  final String role;

  final String? avatarUrl;

  /// Parses a host, or null when there is nothing usable to show.
  ///
  /// A host with no name is treated as absent: the row's whole content is the
  /// name, so an anonymous host would render as a blank line under an avatar.
  static EventHost? tryParse(Object? body) {
    if (body is! Map) return null;
    final json = body.cast<Object?, Object?>();
    final name = _asString(json['name']);
    if (name.isEmpty) return null;
    final role = _asString(json['role']);
    return EventHost(
      id: _asInt(json['id']),
      name: name,
      role: role.isEmpty ? 'Instructor' : role,
      avatarUrl: _asUrl(json['avatar_url']),
    );
  }

  /// The first letter of the name, for the avatar placeholder.
  ///
  /// `substring(0, 1)` rather than `name[0]` so the result is always a `String`
  /// — indexing a `String` yields a UTF-16 code unit, which is not a `String` and
  /// mis-renders any name starting outside the BMP.
  String get initial => name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

  @override
  String toString() => 'EventHost($id, $name)';
}

/// One event, as `GET /api/v1/events/` and `GET /api/v1/events/{id}/` return it.
///
/// **Parsing is deliberately tolerant about scalar types.** The backend's brief
/// (verified against the running server, 2026-10-08) shows `attendee_count: 0`,
/// `distance_km: 0.0`, `spots_left: 200`, `is_saved: false` and `rating: null`,
/// but the generated OpenAPI schema types every one of those as `string`,
/// because they are DRF `SerializerMethodField`s and the schema generator cannot
/// infer a type for them. Whichever is right, the client must not care: the
/// helpers below accept a `num`, a numeric `String` and a `bool`/`"true"` alike.
/// Getting this wrong is not cosmetic — a `String` where an `int` is expected
/// throws inside the parser and takes the whole list down with it.
///
/// Every field that can legitimately be absent is nullable or an empty list, and
/// the UI hides the corresponding row rather than rendering a blank one.
@immutable
class Event {
  const Event({
    required this.id,
    required this.title,
    this.description = '',
    this.highlights = const [],
    this.coverImageUrl,
    this.host,
    this.startAt,
    this.endAt,
    this.format = EventFormat.unknown,
    this.venueName = '',
    this.city = '',
    this.provinceId,
    this.districtId,
    this.municipalityId,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.attendeeCount = 0,
    this.attendeeAvatars = const [],
    this.capacity,
    this.spotsLeft,
    this.myStatus = EventRegistrationStatus.none,
    this.isSaved = false,
    this.rating,
    this.isPublished = false,
  });

  final int id;
  final String title;
  final String description;

  /// The "What you'll learn" bullets. Empty means hide the section.
  final List<String> highlights;

  final String? coverImageUrl;
  final EventHost? host;

  /// **UTC.** The backend sends ISO 8601 with a `Z`; convert with
  /// [DateTime.toLocal] before formatting — see `event_format.dart`.
  final DateTime? startAt;
  final DateTime? endAt;

  final EventFormat format;
  final String venueName;
  final String city;

  final int? provinceId;
  final int? districtId;
  final int? municipalityId;

  final double? latitude;
  final double? longitude;

  /// Server-computed distance from the position the client sent, or null when
  /// the client sent no position or the event has no coordinates.
  final double? distanceKm;

  /// Registered people only — the waitlist is not counted.
  final int attendeeCount;

  /// Up to four avatar URLs for the stack. Empty means hide the stack.
  final List<String> attendeeAvatars;

  /// `null` means unlimited, not zero.
  final int? capacity;
  final int? spotsLeft;

  final EventRegistrationStatus myStatus;
  final bool isSaved;

  /// Always `null` today — the backend has no ratings yet, so the UI hides the
  /// stars. Modelled rather than dropped so the day it appears it just shows.
  final double? rating;

  final bool isPublished;

  /// True when the event has already finished, from the device clock.
  ///
  /// `end_at` is UTC and so is `DateTime.now().toUtc()`, so the comparison is
  /// offset-free. An event with no `end_at` is never treated as ended — the
  /// button stays usable rather than being disabled on a guess.
  bool get hasEnded {
    final end = endAt;
    if (end == null) return false;
    return end.isBefore(DateTime.now().toUtc());
  }

  /// True when the event has no seats left. Unlimited events are never full.
  bool get isFull => spotsLeft != null && spotsLeft! <= 0;

  /// True when the event carries a position, so a distance can be shown.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Parses one event, or null when it cannot be shown or routed to.
  ///
  /// An event with no usable `id` is dropped: the id is the only thing that
  /// makes the card tappable, so keeping it would produce a card that opens
  /// nothing. A missing `title` is tolerated with a placeholder — the event is
  /// still openable, and hiding it would be worse.
  static Event? tryParse(Object? body) {
    if (body is! Map) return null;
    final json = body.cast<Object?, Object?>();

    final id = _asInt(json['id']);
    if (id == null) return null;

    final title = _asString(json['title']);

    return Event(
      id: id,
      title: title.isEmpty ? 'Untitled event' : title,
      description: _asString(json['description']),
      highlights: _asStringList(json['highlights']),
      coverImageUrl: _asUrl(json['cover_image_url']),
      host: EventHost.tryParse(json['host']),
      startAt: _asDateTime(json['start_at']),
      endAt: _asDateTime(json['end_at']),
      format: EventFormat.tryParse(json['format']),
      venueName: _asString(json['venue_name']),
      city: _asString(json['city']),
      provinceId: _asInt(json['province_id']),
      districtId: _asInt(json['district_id']),
      municipalityId: _asInt(json['municipality_id']),
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      distanceKm: _asDouble(json['distance_km']),
      attendeeCount: _asInt(json['attendee_count']) ?? 0,
      attendeeAvatars: _asStringList(json['attendee_avatars']),
      capacity: _asInt(json['capacity']),
      spotsLeft: _asInt(json['spots_left']),
      myStatus: EventRegistrationStatus.tryParse(json['my_status']),
      isSaved: _asBool(json['is_saved']) ?? false,
      rating: _asDouble(json['rating']),
      isPublished: _asBool(json['is_published']) ?? false,
    );
  }

  /// A copy with individual fields replaced.
  ///
  /// Needed for the two places the client updates without a server round-trip:
  /// the optimistic bookmark flip, and the fallback after a cancel that answers
  /// with no body.
  Event copyWith({
    EventRegistrationStatus? myStatus,
    bool? isSaved,
    int? attendeeCount,
    int? spotsLeft,
  }) {
    return Event(
      id: id,
      title: title,
      description: description,
      highlights: highlights,
      coverImageUrl: coverImageUrl,
      host: host,
      startAt: startAt,
      endAt: endAt,
      format: format,
      venueName: venueName,
      city: city,
      provinceId: provinceId,
      districtId: districtId,
      municipalityId: municipalityId,
      latitude: latitude,
      longitude: longitude,
      distanceKm: distanceKm,
      attendeeCount: attendeeCount ?? this.attendeeCount,
      attendeeAvatars: attendeeAvatars,
      capacity: capacity,
      spotsLeft: spotsLeft ?? this.spotsLeft,
      myStatus: myStatus ?? this.myStatus,
      isSaved: isSaved ?? this.isSaved,
      rating: rating,
      isPublished: isPublished,
    );
  }

  /// The best-effort local state after a registration change, used **only** when
  /// the server answers without an event body.
  ///
  /// The brief says the mutation returns the full event and the caller should
  /// use it; the schema says `DELETE` answers `204`. So this exists for the
  /// schema's case and is explicitly an approximation: a cancel promotes the
  /// first waitlisted person server-side, which the client cannot see, so the
  /// counts it computes can be off by one until the next fetch. The status is
  /// the part that must be right, and it is.
  Event withLocalRegistration(EventRegistrationStatus status) {
    switch (status) {
      case EventRegistrationStatus.registered:
        return copyWith(
          myStatus: status,
          attendeeCount: attendeeCount + 1,
          // Written out rather than `clamp`ed: `num.clamp` is declared to return
          // `num`, and whether the analyzer narrows it back to `int` for an
          // `int` receiver is not worth depending on in a file this central.
          spotsLeft: spotsLeft == null
              ? null
              : (spotsLeft! > 0 ? spotsLeft! - 1 : 0),
        );
      case EventRegistrationStatus.waitlisted:
        // The waitlist is not counted in `attendee_count` and does not consume a
        // seat.
        return copyWith(myStatus: status);
      case EventRegistrationStatus.none:
        final wasRegistered = myStatus == EventRegistrationStatus.registered;
        return copyWith(
          myStatus: status,
          attendeeCount: wasRegistered
              ? (attendeeCount > 0 ? attendeeCount - 1 : 0)
              : attendeeCount,
          spotsLeft: wasRegistered && spotsLeft != null
              ? spotsLeft! + 1
              : spotsLeft,
        );
      case EventRegistrationStatus.unknown:
        return this;
    }
  }

  @override
  String toString() => 'Event($id, "$title")';
}

/// Reads an integer from a `num` or a numeric string.
///
/// The string branch is not defensive padding — see the note on [Event]: the
/// schema types these fields as `string`.
int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text) ?? double.tryParse(text)?.toInt();
  }
  return null;
}

/// Reads a double from a `num` or a numeric string.
double? _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }
  return null;
}

/// Reads a bool from a real bool, a `"true"`/`"false"` string, or 0/1.
bool? _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final text = value.trim().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
  }
  return null;
}

/// A trimmed string, or `''`.
String _asString(Object? value) {
  if (value is String) return value.trim();
  if (value is num) return value.toString();
  return '';
}

/// A trimmed string that is present and non-empty, or null.
///
/// Empty strings are treated as absent: the brief says `description`,
/// `venue_name` and `city` "may be `''`", and an empty string and a null are the
/// same thing to the UI — a row with nothing in it.
String? _asUrl(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

/// A list of non-empty strings.
///
/// Accepts a real `List`, a JSON-encoded array string, or a bare string. The
/// string branches exist because `highlights` and `attendee_avatars` are
/// `SerializerMethodField`s, and the schema types them as plain `string` — so a
/// JSON-encoded array is a real possibility rather than a hypothetical one.
List<String> _asStringList(Object? value) {
  if (value is List) {
    final result = <String>[];
    for (final entry in value) {
      if (entry is String) {
        final text = entry.trim();
        if (text.isNotEmpty) result.add(text);
      } else if (entry is Map) {
        // A future shape that nests each item (e.g. `{url: ...}`) should not
        // lose the value.
        final nested = _asString(entry['url'] ?? entry['value']);
        if (nested.isNotEmpty) result.add(nested);
      }
    }
    return List.unmodifiable(result);
  }

  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return const [];
    if (text.startsWith('[')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) return _asStringList(decoded);
      } on FormatException {
        // Not JSON after all — fall through and treat it as one plain string.
      }
    }
    return List.unmodifiable([text]);
  }

  return const [];
}

/// Reads an ISO 8601 datetime and normalises it to **UTC**.
///
/// A trailing `Z` (or offset) parses as that instant; a naive string parses as
/// local time, which is the only sensible reading if the backend ever drops the
/// offset. Normalising here means every formatter can assume UTC and convert
/// once, instead of each one guessing.
DateTime? _asDateTime(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  return parsed?.toUtc();
}
