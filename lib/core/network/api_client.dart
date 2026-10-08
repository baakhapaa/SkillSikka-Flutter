import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config_provider.dart';
import '../config/app_environment.dart';
import 'api_error.dart';
import 'auth_refresh_interceptor.dart';
import 'session.dart';

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ),
  );

  // One interceptor owns the whole token lifecycle: it attaches the access token
  // to every request, and renews it once when the server says it has expired.
  // Keeping both halves together is what stops the header and the refresh from
  // disagreeing about where the token lives.
  dio.interceptors.add(
    AuthRefreshInterceptor(
      dio: dio,
      readSession: () => ref.read(sessionProvider),
      writeSession: (session) =>
          ref.read(sessionProvider.notifier).state = session,
    ),
  );

  dio.transformer = _tolerantTransformer();

  // Bodies and headers are deliberately NOT logged. Every request this app makes
  // carries either a password (signup, login, password reset) or a bearer token,
  // and a debug log is the easiest way for those to end up somewhere they should
  // not be — including in a bug report. Method, path, status and timing are
  // enough to spot a contract mismatch; if a body is genuinely needed, turn
  // `requestBody` on locally and take it back out before committing.
  if (config.environment != AppEnvironment.production) {
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: true,
        logPrint: (line) => debugPrint('$line'),
      ),
    );
  }

  return dio;
});

/// dio's default transformer, except that a body which claims to be JSON and is
/// not comes back as text instead of as an exception.
///
/// The failure this prevents is specific and likely. A proxy in front of the API
/// answers with an HTML error page while leaving the content type alone, dio's
/// default decoder throws a [FormatException] on it, and the throw **discards the
/// response** — so the status code is gone and a 502 arrives at [ApiException]
/// with nothing to classify, which makes a server outage read as "you are
/// offline". Decoding to text keeps the status, and `ApiException` already knows
/// to drop markup and fall back to a per-kind message.
BackgroundTransformer _tolerantTransformer() {
  final transformer = BackgroundTransformer();
  transformer.jsonDecodeCallback = (text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  };
  return transformer;
}

/// The typed request surface. Everything that talks to the API should go
/// through this rather than through Dio directly, so that every failure arrives
/// as an [ApiException] instead of a [DioException] each call site has to
/// remember to translate.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(dioProvider)),
);

class ApiClient {
  const ApiClient(this._dio);

  final Dio _dio;

  // Every verb asks dio for `dynamic` and casts in `_body` instead. Asking for
  // `Map<String, dynamic>` would make dio cast the body for us, and a body of the
  // wrong shape then fails *inside* dio — where the resulting exception has no
  // response attached and is indistinguishable from a dropped connection. A
  // mismatched payload is the likeliest thing to go wrong during integration, so
  // it has to arrive as its own error rather than as a network fault.

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) {
    return _body(
      () => _dio.get<dynamic>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) {
    return _body(
      () => _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: query,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<T> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) {
    return _body(
      () => _dio.patch<dynamic>(
        path,
        data: data,
        queryParameters: query,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<T> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) {
    return _body(
      () => _dio.put<dynamic>(
        path,
        data: data,
        queryParameters: query,
        cancelToken: cancelToken,
      ),
    );
  }

  /// For endpoints that legitimately answer with no body, such as a 204.
  Future<void> delete(
    String path, {
    Object? data,
    CancelToken? cancelToken,
  }) async {
    await _raw(
      () => _dio.delete<dynamic>(path, data: data, cancelToken: cancelToken),
    );
  }

  /// The response body of a `DELETE`, or null when the server sent none.
  ///
  /// The twin of [postOptionalBody], and it exists for the same reason: the
  /// events endpoints disagree with their own schema about whether a cancel
  /// answers with a body. `DELETE /events/{id}/register/` is documented as
  /// **200 + the full Event** in the backend's brief and as **204** in the
  /// generated OpenAPI schema, and `DELETE /events/{id}/save/` likewise (a JSON
  /// `is_saved` object versus 204). A caller cannot use [delete] — which returns
  /// `void` — without throwing away a body the brief says is there, and cannot
  /// use a typed call without breaking if the schema is right. This accepts
  /// either, so the call site reads the body when it arrives and falls back to
  /// its own optimistic state when it does not.
  Future<Object?> deleteOptionalBody(
    String path, {
    Object? data,
    CancelToken? cancelToken,
  }) async {
    final response = await _raw(
      () => _dio.delete<dynamic>(path, data: data, cancelToken: cancelToken),
    );
    final body = response.data;
    // Same normalisation as [postOptionalBody]: the tolerant transformer hands
    // back `''` for an empty body, and a caller checking for null should not have
    // to know that.
    if (body is String && body.isEmpty) return null;
    return body;
  }

  /// The response body, or null when the server sent none.
  ///
  /// For the rare endpoint whose body is genuinely optional. OTP verification is
  /// the case this exists for: depending on how the backend is built it may
  /// answer `204`, or `{"detail": "verified"}`, or a full session object, and
  /// the client has to accept all three. Prefer [post] everywhere else — it
  /// treats a missing or mis-shaped body as an error, which is what a caller
  /// that asked for a payload wants.
  Future<Object?> postOptionalBody(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    final response = await _raw(
      () => _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: query,
        cancelToken: cancelToken,
      ),
    );
    final body = response.data;
    // The tolerant transformer hands back raw text when a body is not JSON, so
    // an empty body arrives as '' rather than null. Normalise it: a caller
    // checking for null should not have to know that.
    if (body is String && body.isEmpty) return null;
    return body;
  }

  /// Sends [fields] and [files] as `multipart/form-data`.
  ///
  /// Split from [post] because uploads fail in ways a JSON body cannot — a file
  /// over the limit, a rejected type, a connection dropped mid-upload — and
  /// keeping them on one path makes it clear where the progress reporting will
  /// hook in later.
  Future<T> postMultipart<T>(
    String path, {
    required Map<String, String> fields,
    Map<String, MultipartFile> files = const {},
    Map<String, List<MultipartFile>> fileLists = const {},
    CancelToken? cancelToken,
    void Function(int sent, int total)? onSendProgress,
  }) {
    return _body(
      () => _dio.post<dynamic>(
        path,
        data: _formData(fields, files, fileLists),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      ),
    );
  }

  /// `multipart/form-data` on a `PATCH` — `PATCH /me/`, which carries the user's
  /// documents as well as their text fields.
  ///
  /// The body is assembled by the same [_formData] builder as [postMultipart],
  /// deliberately: the two requests differ **only** in the verb, and a second
  /// copy of this assembly would be a second place for the file-list flattening
  /// to drift.
  Future<T> patchMultipart<T>(
    String path, {
    required Map<String, String> fields,
    Map<String, MultipartFile> files = const {},
    Map<String, List<MultipartFile>> fileLists = const {},
    CancelToken? cancelToken,
    void Function(int sent, int total)? onSendProgress,
  }) {
    return _body(
      () => _dio.patch<dynamic>(
        path,
        data: _formData(fields, files, fileLists),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      ),
    );
  }

  /// One `FormData` for every multipart call, so the shape is defined once.
  ///
  /// [fileLists] exists because one slot on the wire takes **several** files
  /// under a repeated field name — `certificates_and_recommendations` is the
  /// only one, and DRF reads a repeated name as a list. Flattening it into
  /// [files] would not be possible: a `Map` holds one value per key, so a second
  /// certificate would silently replace the first.
  static FormData _formData(
    Map<String, String> fields,
    Map<String, MultipartFile> files,
    Map<String, List<MultipartFile>> fileLists,
  ) {
    final form = FormData();
    form.fields.addAll(fields.entries);
    files.forEach((name, file) => form.files.add(MapEntry(name, file)));
    fileLists.forEach((name, list) {
      for (final file in list) {
        form.files.add(MapEntry(name, file));
      }
    });
    return form;
  }

  /// Raw bytes from an authenticated URL — a document the server streams back.
  ///
  /// **The only method here that sets `responseType`.** Every other one goes
  /// through [_body], which throws when the body is not what the caller asked
  /// for — and an image is not JSON, so the default decoder would fail on
  /// perfectly good bytes. `_tolerantTransformer` only rescues a body that
  /// *claims* to be JSON; a PNG never does.
  ///
  /// [url] is absolute. `/me/` hands back full URLs, and re-joining one onto the
  /// configured host would be a second place for the two to disagree. Being
  /// absolute is also why this is safe to send the bearer token to: the backend
  /// states these are same-origin, so no third-party host ever sees it. **That is
  /// a property of the URLs, not of this method** — a caller handed a CDN link
  /// would leak the token, so the same-origin answer is load-bearing.
  Future<({Uint8List bytes, String? contentType})> getBytes(String url) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw ApiException(
          kind: ApiErrorKind.unknown,
          statusCode: response.statusCode,
          message: 'The server returned an empty file.',
        );
      }
      return (
        bytes: Uint8List.fromList(bytes),
        // Carried back so a caller can name the file. The store keeps a
        // filename beside every photo, and it is load-bearing — dio infers a
        // part's content type from the extension, so a JPEG stored as `.png`
        // re-uploads labelled `image/png`. A document URL is
        // `/me/documents/<id>/` and carries no extension of its own, so the
        // response's own content type is the only honest source.
        contentType: response.headers.value(Headers.contentTypeHeader),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Response<T>> _raw<T>(Future<Response<T>> Function() send) async {
    try {
      return await send();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<T> _body<T>(Future<Response<dynamic>> Function() send) async {
    final response = await _raw(send);
    final data = response.data;
    // An empty body is a failure rather than a null, because a caller that
    // expected a payload and got nothing has a bug to find, not a value to
    // handle. Asking dio for `dynamic` means normalising this here: dio does the
    // same for `T` other than `dynamic` or `String`.
    if (data == null || (data is String && data.isEmpty)) {
      throw ApiException(
        kind: ApiErrorKind.unknown,
        statusCode: response.statusCode,
        message: 'The server returned an empty response.',
      );
    }
    if (data is! T) {
      // Reached when the backend answers with a shape the call site did not ask
      // for — an array where an object was expected, or a body that claimed to be
      // JSON and was not. Deliberately not phrased as a connection problem.
      throw ApiException(
        kind: ApiErrorKind.unknown,
        statusCode: response.statusCode,
        message: 'The server returned an unexpected response.',
      );
    }
    return data;
  }
}

/// Wraps picked bytes as a multipart part.
///
/// The content type is deliberately not passed: `MultipartFile` already infers it
/// from the filename through `package:mime`, which knows far more extensions than
/// a hand-written map would (and falls back to `application/octet-stream`).
/// Spelling five of them out here would be duplication that goes stale.
///
/// Kept as a named helper so upload call sites read as intent rather than as
/// `MultipartFile.fromBytes(bytes, filename: name)` repeated in every form.
MultipartFile filePart({required Uint8List bytes, required String fileName}) {
  return MultipartFile.fromBytes(bytes, filename: fileName);
}
