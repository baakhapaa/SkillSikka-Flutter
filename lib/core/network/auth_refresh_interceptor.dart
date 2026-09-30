import 'package:dio/dio.dart';

import 'session.dart';

/// The refresh endpoint, relative to the configured base URL.
const kRefreshPath = '/token/refresh/';

/// Set on a request that has already been replayed once after a refresh.
///
/// Without this a server that answers 401 to everything becomes an infinite
/// loop: refresh, replay, 401, refresh, replay…
const kAuthRetryKey = 'auth_retry_attempted';

/// Set on a request that must never trigger a refresh.
///
/// The refresh call itself carries it, so a 401 from `/token/refresh/` fails
/// immediately instead of recursing into another refresh.
const kSkipAuthRefreshKey = 'auth_skip_refresh';

/// What a refresh attempt produced.
enum _RefreshOutcome {
  /// A new access token was stored; the request can be replayed.
  renewed,

  /// The server rejected the refresh token. There is no way back in without a
  /// new sign-in, so the session should be dropped.
  rejected,

  /// The refresh could not be attempted — offline, timed out, 5xx. The session
  /// is probably still valid, so it is **kept**: clearing it here would sign a
  /// user out because their train went into a tunnel.
  unreachable,
}

/// Renews an expired access token and replays the request that failed.
///
/// Access tokens last 30 minutes (backend handoff §10) and the server answers an
/// expired one with **401** and the stable code `token_not_valid`. Without this
/// interceptor every session dies half an hour in, mid-screen, with nothing the
/// user can do about it.
///
/// Three failure modes it exists to avoid, all of which hang or loop:
///
/// * **Refreshing in a loop.** A replayed request that 401s again must not
///   refresh again. [kAuthRetryKey] is set on the replay and checked before
///   refreshing, so each request is refreshed at most once.
/// * **Refreshing concurrently.** Five requests failing together must not fire
///   five refreshes — the first rotates the token and the rest present a stale
///   one, which on a rotating-refresh backend signs the user out. Callers that
///   arrive while a refresh is running await the same future.
/// * **Refreshing the refresh.** The refresh request carries
///   [kSkipAuthRefreshKey], so its own 401 cannot recurse.
///
/// It does not navigate. A rejected refresh clears the session and returns the
/// original 401, which reaches the caller as an [ApiException] with
/// `isAuthFailure` true; deciding where to send the user is the router's job, not
/// the network layer's.
class AuthRefreshInterceptor extends Interceptor {
  AuthRefreshInterceptor({
    required Dio dio,
    required Session? Function() readSession,
    required void Function(Session?) writeSession,
  }) : _dio = dio,
       _readSession = readSession,
       _writeSession = writeSession;

  final Dio _dio;
  final Session? Function() _readSession;
  final void Function(Session?) _writeSession;

  /// The refresh currently in flight, or null. Shared by every caller that fails
  /// while it runs, which is what makes the refresh single-flight.
  Future<_RefreshOutcome>? _inFlight;

  /// Attaches the current access token, unless this is the refresh call — which
  /// needs no `Authorization` header, and would otherwise carry the expired token
  /// it is trying to replace.
  void attachToken(RequestOptions options) {
    if (options.extra[kSkipAuthRefreshKey] == true) return;
    final session = _readSession();
    if (session == null || session.access.isEmpty) return;
    options.headers['Authorization'] = 'Bearer ${session.access}';
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    attachToken(options);
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;

    final canRetry =
        err.response?.statusCode == 401 &&
        options.extra[kSkipAuthRefreshKey] != true &&
        options.extra[kAuthRetryKey] != true;
    if (!canRetry) {
      handler.next(err);
      return;
    }

    final session = _readSession();
    if (session == null || !session.canRefresh) {
      // Nothing to renew with — a session from a response that carried no
      // refresh token, or no session at all. Report the 401 rather than
      // pretending to have handled it.
      handler.next(err);
      return;
    }

    final outcome = await _refreshOnce(session);

    switch (outcome) {
      case _RefreshOutcome.renewed:
        try {
          handler.resolve(await _replay(options));
        } on DioException catch (error) {
          handler.next(error);
        }
        break;
      case _RefreshOutcome.rejected:
        _writeSession(null);
        handler.next(err);
        break;
      case _RefreshOutcome.unreachable:
        handler.next(err);
        break;
    }
  }

  /// Runs one refresh, or joins the one already running.
  Future<_RefreshOutcome> _refreshOnce(Session session) {
    final running = _inFlight;
    if (running != null) return running;

    final started = _refresh(session);
    _inFlight = started;
    // Cleared in a `whenComplete` so a throwing refresh cannot leave the slot
    // filled forever, which would make every later 401 await a dead future.
    return started.whenComplete(() => _inFlight = null);
  }

  Future<_RefreshOutcome> _refresh(Session session) async {
    try {
      final response = await _dio.post<dynamic>(
        kRefreshPath,
        data: {'refresh': session.refresh},
        options: Options(extra: {kSkipAuthRefreshKey: true}),
      );
      final access = _accessFrom(response.data);
      if (access == null) {
        // A 2xx whose body does not carry an access token is a contract
        // mismatch, not a transport problem. Treat it as rejected: there is
        // nothing to replay with, and retrying would not help.
        return _RefreshOutcome.rejected;
      }
      _writeSession(session.withAccess(access));
      return _RefreshOutcome.renewed;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      // 4xx means the refresh token itself is no good. Anything else — no
      // connection, a timeout, a 5xx — says nothing about the token, so the
      // session is left alone.
      //
      // This split is load-bearing, and the backend confirmed on 2026-09-30 that
      // it is safe: a dead refresh token is **structurally** always a 401.
      // `TokenRefreshView` raises `InvalidToken`, which is a DRF
      // `ValidationError` subclass, so it is mapped to 401 by design and no code
      // path turns it into a 5xx. A 5xx here therefore really does mean a server
      // fault unrelated to the token.
      //
      // Without that guarantee this branch would be a trap: a token that can
      // never succeed answering 5xx would leave the user holding a session they
      // can never use, with no way out.
      if (status != null && status >= 400 && status < 500) {
        return _RefreshOutcome.rejected;
      }
      return _RefreshOutcome.unreachable;
    }
  }

  /// Re-sends the failed request. The `Authorization` header is not set here:
  /// the replay goes back through [attachToken] on the way out, which reads the
  /// session the refresh just updated.
  Future<Response<dynamic>> _replay(RequestOptions options) {
    return _dio.request<dynamic>(
      options.path,
      data: _replayableBody(options.data),
      queryParameters: options.queryParameters,
      cancelToken: options.cancelToken,
      onSendProgress: options.onSendProgress,
      onReceiveProgress: options.onReceiveProgress,
      options: Options(
        method: options.method,
        headers: Map<String, dynamic>.from(options.headers),
        contentType: options.contentType,
        responseType: options.responseType,
        extra: {...options.extra, kAuthRetryKey: true},
        sendTimeout: options.sendTimeout,
        receiveTimeout: options.receiveTimeout,
      ),
    );
  }
}

/// The body to send on a replay.
///
/// dio finalises a [FormData] when it sends it, and a finalised one throws if it
/// is sent again — so a replayed multipart request needs a fresh copy built from
/// the same parts. Only byte-backed parts survive that; a
/// `MultipartFile.fromStream` holds a stream that has already been drained. Every
/// part this app creates comes from `filePart`, which uses `fromBytes`.
Object? _replayableBody(Object? data) {
  if (data is! FormData) return data;
  final copy = FormData();
  copy.fields.addAll(data.fields);
  copy.files.addAll(data.files);
  return copy;
}

/// The access token out of a refresh response.
///
/// **Flat, and only flat.** Confirmed by the backend on 2026-09-30:
/// `POST /token/refresh/` is SimpleJWT's unmodified `TokenRefreshView` with
/// `ROTATE_REFRESH_TOKENS` and `BLACKLIST_AFTER_ROTATION` both left at their
/// `False` defaults. So the body is always `{"access": "..."}` — never nested
/// under `tokens`, and never carrying a `refresh`.
///
/// This used to also accept `tokens.access`, because registration and login nest
/// their token that way and it was not known which shape this endpoint used. That
/// tolerance is deliberately gone. It was never exercised by a test, it cannot
/// occur, and a branch that cannot run only makes the parser look more forgiving
/// than the contract it is written against — the kind of thing that later reads as
/// evidence the endpoint is flexible when it is not.
///
/// **If the backend ever swaps this view out or turns rotation on, this is the
/// function that has to change**, along with `_refresh`'s write of the session.
String? _accessFrom(Object? body) {
  if (body is! Map) return null;
  final access = body.cast<String, dynamic>()['access'];
  if (access is String && access.trim().isNotEmpty) return access.trim();
  return null;
}
