import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import 'event.dart';
import 'event_page.dart';

/// Reads the events endpoints.
///
/// Every route is `jwtAuth`; the bearer token is attached by the interceptor on
/// [ApiClient]'s `Dio`, so nothing here deals with auth.
///
/// **The list endpoints answer with a paginated envelope**, not a bare array —
/// see [EventPage]. That is why `_page` asks for `Object?` rather than a list:
/// the body is a map, and asking for a list would make [ApiClient] throw its
/// "unexpected response" error on a perfectly good page.
class EventsApi {
  const EventsApi(this._client);

  final ApiClient _client;

  /// `GET /events/` — the rail (`near: true`) and the See All list.
  ///
  /// [lat] and [lng] must be sent **together or not at all**: the backend rejects
  /// a lone one. The caller is responsible for that; see
  /// `nearbyEventsProvider`, which only ever passes a complete pair.
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
  }) {
    return _page(
      '/events/',
      query: {
        // Null-aware entries: a null simply omits the parameter, which is what
        // the server treats as "not supplied". The `lat`/`lng` pair keeps an
        // explicit two-condition guard instead — see the note on this method.
        'near': ?near,
        if (lat != null && lng != null) 'lat': lat,
        if (lat != null && lng != null) 'lng': lng,
        'radius_km': ?radiusKm,
        'upcoming': ?upcoming,
        'format': ?format,
        'district': ?district,
        'municipality': ?municipality,
        if (search != null && search.isNotEmpty) 'search': search,
        'ordering': ?ordering,
        'page': ?page,
        'page_size': ?pageSize,
      },
    );
  }

  /// Fetches an absolute `next` URL exactly as the server sent it.
  ///
  /// The URL already carries every filter and the page number, so re-building it
  /// would be a second place for the two to disagree. dio treats an absolute URL
  /// as absolute and ignores `baseUrl`, and the interceptor still attaches the
  /// token — the URL is same-origin, so that is safe.
  Future<EventPage> nextPage(String url) => _page(url);

  /// `GET /events/{id}/` — one event.
  ///
  /// Throws [ApiException] with [ApiErrorKind.notFound] on a 404, which the
  /// details screen turns into a pop.
  Future<Event> detail(int id) async {
    final body = await _client.get<Map<String, dynamic>>('/events/$id/');
    final event = Event.tryParse(body);
    if (event == null) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'That event came back in an unexpected shape.',
      );
    }
    return event;
  }

  /// `GET /events/saved/` — the bookmarked events.
  Future<EventPage> saved() => _page('/events/saved/');

  /// `POST /events/{id}/register/` — register, or join the waitlist when full.
  ///
  /// The backend answers **201** for a new registration and **200** when the
  /// user was already on the list. Both carry the full event. A body is returned
  /// when there is one and `null` when there is not, so the caller can fall back
  /// to a local update instead of failing on a contract that has moved.
  Future<Event?> register(int id) async {
    final body = await _client.postOptionalBody('/events/$id/register/');
    return Event.tryParse(body);
  }

  /// `DELETE /events/{id}/register/` — cancel a registration or leave the
  /// waitlist.
  ///
  /// The brief says this answers `200` with the full event; the OpenAPI schema
  /// says `204` with nothing. Both are handled — see
  /// [ApiClient.deleteOptionalBody].
  Future<Event?> cancelRegistration(int id) async {
    final body = await _client.deleteOptionalBody('/events/$id/register/');
    return Event.tryParse(body);
  }

  /// `POST /events/{id}/save/` — bookmark on.
  ///
  /// Returns the server's `is_saved` when the body carries one, and `null` when
  /// it does not (the schema documents a bare `200`), so the caller keeps its
  /// optimistic value rather than flipping to a guess.
  Future<bool?> save(int id) async {
    final body = await _client.postOptionalBody('/events/$id/save/');
    return _isSaved(body);
  }

  /// `DELETE /events/{id}/save/` — bookmark off. Same contract as [save].
  Future<bool?> unsave(int id) async {
    final body = await _client.deleteOptionalBody('/events/$id/save/');
    return _isSaved(body);
  }

  /// Fetches a page from [path] or an absolute [url] and parses the envelope.
  Future<EventPage> _page(String path, {Map<String, dynamic>? query}) async {
    final body = await _client.get<Object?>(path, query: query);
    final page = EventPage.tryParse(body);
    if (page == null) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'The events list came back in an unexpected shape.',
      );
    }
    return page;
  }

  static bool? _isSaved(Object? body) {
    if (body is! Map) return null;
    final value = body['is_saved'];
    if (value is bool) return value;
    if (value is String) {
      final text = value.trim().toLowerCase();
      if (text == 'true') return true;
      if (text == 'false') return false;
    }
    return null;
  }
}

final eventsApiProvider = Provider<EventsApi>(
  (ref) => EventsApi(ref.watch(apiClientProvider)),
);
