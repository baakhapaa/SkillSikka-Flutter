import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config_provider.dart';
import '../config/app_environment.dart';
import 'api_error.dart';

/// The bearer token for the signed-in user, or null when signed out.
///
/// In-memory only: a session does not survive a restart yet. Persisting it is
/// part of the session work, not the network layer.
final authTokenProvider = StateProvider<String?>((ref) => null);

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

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(authTokenProvider);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
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
    final form = FormData();
    form.fields.addAll(fields.entries);
    files.forEach((name, file) => form.files.add(MapEntry(name, file)));
    fileLists.forEach((name, list) {
      for (final file in list) {
        form.files.add(MapEntry(name, file));
      }
    });

    return _body(
      () => _dio.post<dynamic>(
        path,
        data: form,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      ),
    );
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
