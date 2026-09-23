import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// What went wrong, at the level of detail the UI actually branches on.
///
/// Deliberately not one variant per HTTP status: a screen almost never needs to
/// tell 402 from 404, but it does need to tell "you are offline" from "your
/// password is wrong" from "that email is taken".
enum ApiErrorKind {
  /// The device could not reach the server at all.
  network,

  /// The server did not answer in time.
  timeout,

  /// The request was cancelled — usually because the screen went away.
  cancelled,

  /// 400. Malformed, or a validation failure the server did not itemise.
  badRequest,

  /// 401. Missing or expired credentials.
  unauthorized,

  /// 403. Authenticated, but not allowed.
  forbidden,

  /// 404.
  notFound,

  /// 409. A duplicate — for signup, almost always the email.
  conflict,

  /// 422. A validation failure; expect [ApiException.fieldErrors].
  validation,

  /// 429. Too many attempts; see [ApiException.retryAfter].
  rateLimited,

  /// 5xx.
  server,

  /// Anything unclassified.
  unknown,
}

/// A failed request, in a form the UI can render without knowing about Dio.
///
/// The backend's error shape is not confirmed yet (see
/// `.workbuddy-ai/docs/backend-api-requirements.md`, section 6), so parsing is
/// deliberately tolerant: it accepts the envelope we asked for and several
/// plausible neighbours, and always degrades to something showable rather than
/// throwing while handling a throw.
@immutable
class ApiException implements Exception {
  const ApiException({
    required this.kind,
    this.statusCode,
    this.code,
    this.message,
    this.fieldErrors = const {},
    this.retryAfter,
    this.cause,
  });

  final ApiErrorKind kind;

  /// The HTTP status, when there was one. Null for a transport failure.
  final int? statusCode;

  /// The server's machine-readable code, when it sent one.
  ///
  /// This is what the UI should branch on once the backend confirms its codes —
  /// not [message], which is copy and will change.
  final String? code;

  /// The server's message, if it sent one that is safe to show.
  final String? message;

  /// Per-field messages, keyed the way the *server* names the field.
  ///
  /// Callers mapping these onto form inputs must translate to their own keys;
  /// the server has no reason to know what the client calls a controller.
  final Map<String, String> fieldErrors;

  /// From `Retry-After`, for [ApiErrorKind.rateLimited].
  final Duration? retryAfter;

  /// The original error, kept for logging. Never shown to a user.
  final Object? cause;

  /// True when the fix is to sign in again rather than to retry.
  bool get isAuthFailure =>
      kind == ApiErrorKind.unauthorized || kind == ApiErrorKind.forbidden;

  /// True when trying the same request again could plausibly succeed.
  ///
  /// A validation failure is not retryable — the same body will fail the same
  /// way — but a dropped connection or a 503 is.
  bool get isRetryable =>
      kind == ApiErrorKind.network ||
      kind == ApiErrorKind.timeout ||
      kind == ApiErrorKind.server ||
      kind == ApiErrorKind.rateLimited;

  bool get hasFieldErrors => fieldErrors.isNotEmpty;

  /// The message for a specific input, or null when the server said nothing
  /// about it.
  String? fieldError(String field) => fieldErrors[field];

  /// Something safe to put in front of a user.
  ///
  /// Prefers the server's own wording, because only it knows whether the email
  /// is taken or the password is too short — but falls back to a per-kind
  /// default so a bare 500 does not surface as an empty snackbar.
  String get displayMessage {
    final own = message?.trim();
    if (own != null && own.isNotEmpty) return own;
    return _defaultMessage(kind);
  }

  /// Builds from a response without a [DioException], so the parsing can be
  /// tested directly.
  factory ApiException.fromResponseBody({
    required int? statusCode,
    Object? body,
    Duration? retryAfter,
    Object? cause,
  }) {
    final parsed = _parseBody(body);
    return ApiException(
      kind: _kindForStatus(statusCode),
      statusCode: statusCode,
      code: parsed.code,
      message: parsed.message,
      fieldErrors: parsed.fieldErrors,
      retryAfter: retryAfter,
      cause: cause,
    );
  }

  /// Normalises a Dio failure.
  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    final status = response?.statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      // A timeout during response transformation is still the server taking too
      // long from the user's point of view.
      case DioExceptionType.transformTimeout:
        return ApiException(
          kind: ApiErrorKind.timeout,
          statusCode: status,
          cause: error,
        );
      case DioExceptionType.cancel:
        return ApiException(
          kind: ApiErrorKind.cancelled,
          statusCode: status,
          cause: error,
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.connectionError:
        return ApiException(
          kind: ApiErrorKind.network,
          statusCode: status,
          cause: error,
        );
      case DioExceptionType.badResponse:
        return ApiException.fromResponseBody(
          statusCode: status,
          body: response?.data,
          retryAfter: _parseRetryAfter(response?.headers),
          cause: error,
        );
      case DioExceptionType.unknown:
        // A browser `XMLHttpRequest` failure arrives as `unknown` with no
        // response at all. That is connectivity, not a server fault — and
        // calling it "unknown" would send the user to a support form for a
        // problem that is usually their wifi.
        return ApiException(
          kind: response == null ? ApiErrorKind.network : ApiErrorKind.unknown,
          statusCode: status,
          message: error.message,
          cause: error,
        );
    }
  }

  static ApiErrorKind _kindForStatus(int? status) {
    return switch (status) {
      400 => ApiErrorKind.badRequest,
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      422 => ApiErrorKind.validation,
      429 => ApiErrorKind.rateLimited,
      final s? when s >= 500 => ApiErrorKind.server,
      _ => ApiErrorKind.unknown,
    };
  }

  static String _defaultMessage(ApiErrorKind kind) {
    return switch (kind) {
      ApiErrorKind.network =>
        'Could not reach the server. Check your connection and try again.',
      ApiErrorKind.timeout => 'The server took too long to respond. Try again.',
      ApiErrorKind.cancelled => 'The request was cancelled.',
      ApiErrorKind.badRequest => 'That request was not accepted.',
      ApiErrorKind.unauthorized => 'Your session has expired. Please log in.',
      ApiErrorKind.forbidden => 'You do not have access to that.',
      ApiErrorKind.notFound => 'We could not find what you asked for.',
      ApiErrorKind.conflict => 'That is already in use.',
      ApiErrorKind.validation => 'Please check the highlighted fields.',
      ApiErrorKind.rateLimited =>
        'Too many attempts. Please wait a moment and try again.',
      ApiErrorKind.server => 'Something went wrong on our side. Try again.',
      ApiErrorKind.unknown => 'Something went wrong. Please try again.',
    };
  }

  @override
  String toString() {
    final parts = <String>[
      'ApiException(${kind.name}',
      if (statusCode != null) ', status: $statusCode',
      if (code != null) ', code: $code',
      if (fieldErrors.isNotEmpty) ', fields: ${fieldErrors.keys.join(',')}',
      ')',
    ];
    return parts.join();
  }
}

/// The message cap. A misconfigured proxy can return a whole HTML error page as
/// the body, and none of it belongs in a snackbar — see [_isMarkup] for the part
/// that drops it outright, and this for the part that keeps a long *message*
/// from filling the screen.
const int _maxMessageLength = 300;

class _ParsedBody {
  const _ParsedBody({this.code, this.message, this.fieldErrors = const {}});

  final String? code;
  final String? message;
  final Map<String, String> fieldErrors;
}

/// Keys that describe the error as a whole rather than one input.
///
/// Needed because a body with no explicit field map has its top level read as
/// field errors, and a form has no input called `detail` or `title`.
const _envelopeKeys = <String>{
  'code',
  'error_code',
  'errorCode',
  'type',
  'message',
  'detail',
  'error_description',
  'title',
  'msg',
  'fields',
  'errors',
  'field_errors',
  'validation',
};

/// Django REST Framework's object-level errors: about the request as a whole,
/// not about one input. There is nothing to highlight in a form for these.
const _objectLevelKeys = <String>{
  'non_field_errors',
  'nonFieldErrors',
  '__all__',
};

/// Pulls a code, a message and per-field errors out of a response body.
///
/// Tolerant on purpose. The contract we asked for is
/// `{"error": {"code", "message", "fields"}}`, but the backend is Django REST
/// Framework, so the bodies that actually arrive are DRF's own defaults:
/// a bare `{field: [messages]}` map for a 400, `{"detail": ...}` for the
/// exceptions DRF raises itself, and `non_field_errors` for object-level
/// validation. All three are handled here, which means the backend team does not
/// have to re-wrap every serializer error to make the UI work.
_ParsedBody _parseBody(Object? body) {
  if (body == null) return const _ParsedBody();

  if (body is String) {
    final text = _cleanMessage(body);
    return text == null ? const _ParsedBody() : _ParsedBody(message: text);
  }

  if (body is! Map) return const _ParsedBody();

  final map = body.cast<Object?, Object?>();
  final nested = map['error'];

  // The shape we asked for: everything under `error`. DRF without a custom
  // exception handler sends everything at the top level, so the map is its own
  // envelope.
  final envelope = nested is Map ? nested.cast<Object?, Object?>() : map;

  final code = _firstString([
    envelope['code'],
    envelope['error_code'],
    envelope['errorCode'],
    envelope['type'],
  ]);

  // `detail` is DRF's own wording; `title` covers RFC 7807 problem+json.
  final message = _firstString([
    envelope['message'],
    envelope['detail'],
    envelope['error_description'],
    envelope['title'],
    envelope['msg'],
    // A bare string under `error` is a message, not an envelope.
    nested is String ? nested : null,
  ]);

  final declared = _parseDeclaredFieldErrors(envelope);

  // Falls back to reading the top level as field errors when no explicit map was
  // given, which is what makes a stock DRF 400 useful.
  final fieldErrors = declared.isNotEmpty
      ? declared
      : _fieldErrorsFromTopLevel(envelope);

  return _ParsedBody(
    code: code,
    // Object-level errors become the banner message rather than a field named
    // `non_field_errors` that no form can match.
    message:
        message ??
        _firstString([
          for (final key in _objectLevelKeys) envelope[key],
          _objectLevelMessage(envelope['errors']),
        ]),
    fieldErrors: fieldErrors,
  );
}

/// Field errors under an explicit key, in whichever shape the backend uses.
///
/// `drf-standardized-errors` — the package the DRF docs point at for a uniform
/// error format — puts a *list* of `{attr, detail, code}` objects under `errors`,
/// not a map. Read as a map that becomes a single field named `errors` whose value
/// is the first message, which no form can match and which hides the real errors.
Map<String, String> _parseDeclaredFieldErrors(Map<Object?, Object?> envelope) {
  final errors = envelope['errors'];
  if (errors is List) return _fieldErrorsFromList(errors);

  return _parseFieldErrors(
    envelope['fields'] ??
        errors ??
        envelope['field_errors'] ??
        envelope['validation'],
  );
}

/// Reads `errors: [{attr, detail, code}]`.
///
/// Entries with no `attr` describe the request rather than an input, and are
/// promoted to the banner by [_objectLevelMessage] instead of becoming fields.
Map<String, String> _fieldErrorsFromList(List<Object?> entries) {
  final result = <String, String>{};
  for (final entry in entries) {
    if (entry is! Map) continue;
    final map = entry.cast<Object?, Object?>();
    final field = map['attr'] ?? map['field'] ?? map['source'];
    if (field is! String || field.isEmpty) continue;
    final detail = _firstString([map['detail'], map['message'], map['msg']]);
    if (detail != null) result[field] = detail;
  }
  return result;
}

/// The message from a standardized-errors entry that names no field.
String? _objectLevelMessage(Object? errors) {
  if (errors is! List) return null;
  for (final entry in errors) {
    if (entry is! Map) continue;
    final map = entry.cast<Object?, Object?>();
    if (map['attr'] != null) continue;
    final detail = _firstString([map['detail'], map['message'], map['msg']]);
    if (detail != null) return detail;
  }
  return null;
}

/// Reads `{field: [messages]}` — the default body of a DRF serializer error.
///
/// Keys that describe the error as a whole are skipped: `{"code": "email_taken"}`
/// must not produce a field called `code`, and `non_field_errors` has already been
/// promoted to the message by [_parseBody].
Map<String, String> _fieldErrorsFromTopLevel(Map<Object?, Object?> envelope) {
  final result = <String, String>{};
  for (final entry in envelope.entries) {
    final key = entry.key;
    if (key is! String) continue;
    if (_envelopeKeys.contains(key) || _objectLevelKeys.contains(key)) continue;
    final value = _firstString([entry.value]);
    if (value != null) result[key] = value;
  }
  return result;
}

/// Field errors turn up in at least four shapes in the wild.
///
/// `{"email": "taken"}`, `{"email": ["taken"]}`, `{"email": {"message": "..."}}`
/// and `{"email": [{"message": "..."}]}` all mean the same thing to a form.
Map<String, String> _parseFieldErrors(Object? raw) {
  if (raw is! Map) return const {};

  final result = <String, String>{};
  for (final entry in raw.cast<Object?, Object?>().entries) {
    final key = entry.key;
    if (key is! String) continue;
    final value = _firstString([
      entry.value,
      entry.value is Map ? (entry.value as Map)['message'] : null,
    ]);
    if (value != null) result[key] = value;
  }
  return result;
}

/// The first value that is, or contains, a non-empty string.
///
/// Recurses one level so a list or a `{message: ...}` wrapper still yields text.
String? _firstString(List<Object?> candidates) {
  for (final candidate in candidates) {
    if (candidate == null) continue;
    if (candidate is String) {
      final cleaned = _cleanMessage(candidate);
      if (cleaned != null) return cleaned;
      continue;
    }
    if (candidate is List) {
      final nested = _firstString(candidate);
      if (nested != null) return nested;
      continue;
    }
    if (candidate is Map) {
      final nested = _firstString([
        candidate['message'],
        candidate['detail'],
        candidate['msg'],
      ]);
      if (nested != null) return nested;
    }
  }
  return null;
}

String? _cleanMessage(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  if (_isMarkup(text)) return null;
  if (text.length <= _maxMessageLength) return text;
  return '${text.substring(0, _maxMessageLength)}...';
}

/// True for a body that is a document rather than a message.
///
/// dio hands back anything that is not JSON as a plain string, and a proxy in
/// front of the API answers with an HTML error page — so the body of a 502 can
/// arrive here as `<html><body><h1>502 Bad Gateway</h1>`. Putting that in a
/// snackbar is worse than saying nothing, so it is dropped and the caller falls
/// back to the per-kind default.
///
/// The test is "starts with a tag", not "contains one": a legitimate message may
/// well contain `<`, as in "Password must be < 8 characters".
bool _isMarkup(String text) => text.startsWith('<') && text.contains('>');

/// `Retry-After` is either a number of seconds or an HTTP date. Only the first
/// is handled: a date would need the local clock to be trustworthy, and a wrong
/// countdown is worse than none.
Duration? _parseRetryAfter(Headers? headers) {
  final raw = headers?.value('retry-after');
  if (raw == null) return null;
  final seconds = int.tryParse(raw.trim());
  if (seconds == null || seconds < 0) return null;
  return Duration(seconds: seconds);
}
