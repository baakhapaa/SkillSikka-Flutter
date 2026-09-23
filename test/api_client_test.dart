import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/config/app_config_provider.dart';
import 'package:skillsikka/core/config/app_environment.dart';
import 'package:skillsikka/core/network/api_client.dart';
import 'package:skillsikka/core/network/api_error.dart';

/// A stand-in for the real transport.
///
/// `mockito` and `http_mock_adapter` are not dependencies of this project, and
/// adding one to test a class this thin would cost more than it saves — the
/// whole surface is "give me a status, a body and some headers".
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  /// Answers a single request. Throwing from here simulates a transport
  /// failure, which is the only way to reach the timeout and connection-error
  /// branches without a real socket.
  final FutureOr<ResponseBody> Function(RequestOptions options) _handler;

  /// Every request that reached the adapter, in order.
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    // Drain the body the way a real adapter would, so a malformed multipart
    // stream would surface here rather than being silently ignored.
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(
  Object? body, {
  int status = 200,
  Map<String, List<String>> headers = const {},
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...headers,
    },
  );
}

/// A `Dio` built the way the app builds it — same base options, same transformer,
/// same interceptors — with only the transport swapped out.
///
/// Going through the provider rather than hand-rolling a `Dio` matters: the
/// transformer is part of the app's configuration, and a harness that built its
/// own would quietly test a different client.
///
/// The config is overridden to production so the request-logging interceptor
/// stays out of the test output; the interceptor itself is covered in the last
/// group.
ProviderContainer _scopeFor(HttpClientAdapter adapter) {
  final scope = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          environment: AppEnvironment.production,
          apiBaseUrl: 'https://api.example.test',
        ),
      ),
    ],
  );
  scope.read(dioProvider).httpClientAdapter = adapter;
  return scope;
}

/// Runs [body] against an adapter that always answers the same way.
Future<void> _withResponse(
  FutureOr<ResponseBody> Function(RequestOptions options) handler,
  Future<void> Function(ApiClient client, _FakeAdapter adapter) body,
) async {
  final adapter = _FakeAdapter(handler);
  final scope = _scopeFor(adapter);
  addTearDown(scope.dispose);
  await body(scope.read(apiClientProvider), adapter);
}

/// The exception thrown by [body], or a failure if it threw nothing.
Future<ApiException> _captureError(
  Future<void> Function(ApiClient client) body, {
  required FutureOr<ResponseBody> Function(RequestOptions options) handler,
}) async {
  final adapter = _FakeAdapter(handler);
  final scope = _scopeFor(adapter);
  addTearDown(scope.dispose);
  try {
    await body(scope.read(apiClientProvider));
  } on ApiException catch (error) {
    return error;
  }
  fail('Expected an ApiException, but the request succeeded.');
}

void main() {
  group('success paths', () {
    test('post returns the decoded body', () async {
      await _withResponse((_) => _json({'id': 42, 'email': 'a@b.test'}), (
        client,
        _,
      ) async {
        final result = await client.post<Map<String, dynamic>>(
          '/auth/signup',
          data: {'email': 'a@b.test'},
        );
        expect(result['id'], 42);
      });
    });

    test('the caller-supplied body reaches the adapter untouched', () async {
      await _withResponse((_) => _json({'ok': true}), (client, adapter) async {
        await client.post<Map<String, dynamic>>(
          '/auth/signup',
          data: {'email': 'a@b.test', 'password': 'hunter2'},
        );

        final sent = adapter.requests.single.data as Map;
        expect(sent['email'], 'a@b.test');
        expect(sent['password'], 'hunter2');
        expect(adapter.requests.single.path, '/auth/signup');
      });
    });

    test('get forwards query parameters', () async {
      await _withResponse((_) => _json({'items': []}), (client, adapter) async {
        await client.get<Map<String, dynamic>>(
          '/courses',
          query: {'page': 2, 'q': 'physics'},
        );

        expect(adapter.requests.single.queryParameters, {
          'page': 2,
          'q': 'physics',
        });
      });
    });

    test('a 204 on delete completes without throwing', () async {
      await _withResponse((_) => ResponseBody.fromString('', 204), (
        client,
        _,
      ) async {
        await client.delete('/sessions/current');
      });
    });
  });

  group('every failure arrives as an ApiException, not a DioException', () {
    test('a 400 with field errors', () async {
      final error = await _captureError(
        (client) => client.post<void>('/auth/signup', data: const {}),
        handler: (_) => _json({
          'error': {
            'code': 'validation_error',
            'message': 'One or more fields are invalid.',
            'fields': {
              'email': 'This email is already registered.',
              'password': 'Use at least 8 characters.',
            },
          },
        }, status: 400),
      );

      expect(error.kind, ApiErrorKind.badRequest);
      expect(error.statusCode, 400);
      expect(error.hasFieldErrors, isTrue);
      expect(error.fieldError('email'), 'This email is already registered.');
      expect(error.fieldError('password'), 'Use at least 8 characters.');
    });

    test(
      'a 409 duplicate email is distinguishable from a generic 400',
      () async {
        final error = await _captureError(
          (client) => client.post<void>('/auth/signup', data: const {}),
          handler: (_) => _json({
            'error': {
              'code': 'email_taken',
              'message': 'Email already in use.',
            },
          }, status: 409),
        );

        expect(error.kind, ApiErrorKind.conflict);
        expect(error.code, 'email_taken');
        expect(error.isRetryable, isFalse);
      },
    );

    test('a 401 is flagged as an auth failure, not a retry', () async {
      final error = await _captureError(
        (client) => client.get<void>('/me'),
        handler: (_) => _json({
          'error': {'code': 'token_expired', 'message': 'Token expired.'},
        }, status: 401),
      );

      expect(error.kind, ApiErrorKind.unauthorized);
      expect(error.isAuthFailure, isTrue);
      expect(error.isRetryable, isFalse);
    });

    test('a 429 carries the Retry-After delay', () async {
      final error = await _captureError(
        (client) => client.post<void>('/auth/login', data: const {}),
        handler: (_) => _json(
          {
            'error': {'code': 'too_many_attempts'},
          },
          status: 429,
          headers: {
            'retry-after': ['30'],
          },
        ),
      );

      expect(error.kind, ApiErrorKind.rateLimited);
      expect(error.retryAfter, const Duration(seconds: 30));
      expect(error.isRetryable, isTrue);
    });

    test('a 500 is retryable and falls back to our own wording', () async {
      final error = await _captureError(
        (client) => client.get<void>('/courses'),
        handler: (_) =>
            _json({'message': 'Internal Server Error'}, status: 500),
      );

      expect(error.kind, ApiErrorKind.server);
      expect(error.isRetryable, isTrue);
      // The server sent no `error.message`, so the per-kind default is used
      // rather than the bare top-level string.
      expect(error.displayMessage, isNotEmpty);
    });

    test('a 404 on an unknown path', () async {
      final error = await _captureError(
        (client) => client.get<void>('/nope'),
        handler: (_) => _json({
          'error': {'code': 'not_found'},
        }, status: 404),
      );

      expect(error.kind, ApiErrorKind.notFound);
    });

    test(
      'an HTML error page from a proxy does not reach the user raw',
      () async {
        final error = await _captureError(
          (client) => client.get<void>('/courses'),
          handler: (_) => ResponseBody.fromString(
            '<html><body><h1>502 Bad Gateway</h1></body></html>',
            502,
            headers: {
              Headers.contentTypeHeader: ['text/html'],
            },
          ),
        );

        expect(error.kind, ApiErrorKind.server);
        expect(error.message, isNull);
        expect(error.displayMessage, isNot(contains('html')));
        expect(error.displayMessage, isNotEmpty);
      },
    );
  });

  group('transport failures', () {
    test(
      'a connection error is reported as unreachable, not as a server bug',
      () async {
        final error = await _captureError(
          (client) => client.get<void>('/courses'),
          handler: (options) => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        );

        expect(error.kind, ApiErrorKind.network);
        expect(error.statusCode, isNull);
        expect(error.isRetryable, isTrue);
        expect(error.isAuthFailure, isFalse);
      },
    );

    test('a receive timeout is reported as a timeout', () async {
      final error = await _captureError(
        (client) => client.get<void>('/courses'),
        handler: (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
      );

      expect(error.kind, ApiErrorKind.timeout);
      expect(error.isRetryable, isTrue);
    });
  });

  group('empty responses', () {
    test(
      'a 200 with no body is an explicit failure, not a silent null',
      () async {
        final error = await _captureError(
          (client) => client.post<Map<String, dynamic>>('/auth/signup'),
          handler: (_) => ResponseBody.fromString('', 200),
        );

        expect(error.kind, ApiErrorKind.unknown);
        expect(error.displayMessage, contains('empty'));
      },
    );

    test(
      'postOptionalBody accepts a body or none, where post demands one',
      () async {
        // The counterpart to the test above. Some POSTs legitimately answer with
        // nothing the caller needs — OTP verification may be a bare 204 — and the
        // caller only wants to know it succeeded.
        await _withResponse((_) => ResponseBody.fromString('', 204), (
          client,
          _,
        ) async {
          expect(await client.postOptionalBody('/auth/verify-otp'), isNull);
        });

        await _withResponse((_) => _json({'detail': 'verified'}), (
          client,
          _,
        ) async {
          expect(await client.postOptionalBody('/auth/verify-otp'), {
            'detail': 'verified',
          });
        });
      },
    );
  });

  group('multipart uploads', () {
    test(
      'fields and files are both attached, and the body comes back',
      () async {
        await _withResponse((_) => _json({'id': 'doc_1'}), (
          client,
          adapter,
        ) async {
          final result = await client.postMultipart<Map<String, dynamic>>(
            '/uploads',
            fields: {'slot': 'cv_resume', 'name': 'Ada'},
            files: {
              'file': filePart(
                bytes: Uint8List.fromList([1, 2, 3]),
                fileName: 'cv.pdf',
              ),
            },
          );

          expect(result['id'], 'doc_1');

          final form = adapter.requests.single.data as FormData;
          expect(
            form.fields.map((entry) => entry.key),
            containsAll(<String>['slot', 'name']),
          );
          expect(
            form.fields.firstWhere((entry) => entry.key == 'slot').value,
            'cv_resume',
          );
          expect(form.files.single.key, 'file');
          expect(form.files.single.value.filename, 'cv.pdf');
        });
      },
    );

    test('a repeated field name becomes one part per file', () async {
      await _withResponse((_) => _json({'ok': true}), (client, adapter) async {
        await client.postMultipart<Map<String, dynamic>>(
          '/uploads',
          fields: const {'slot': 'certificates'},
          fileLists: {
            'files': [
              filePart(bytes: Uint8List.fromList([1]), fileName: 'a.png'),
              filePart(bytes: Uint8List.fromList([2]), fileName: 'b.png'),
            ],
          },
        );

        final form = adapter.requests.single.data as FormData;
        expect(form.files.length, 2);
        expect(form.files.map((entry) => entry.value.filename), [
          'a.png',
          'b.png',
        ]);
      });
    });

    test('the part content type comes from dio, not from us', () {
      DioMediaType? typeOf(String fileName) => filePart(
        bytes: Uint8List.fromList([0]),
        fileName: fileName,
      ).contentType;

      // `MultipartFile` resolves these through `package:mime`, which is why
      // `filePart` does not carry its own extension map.
      expect(typeOf('cv.pdf').toString(), 'application/pdf');
      expect(typeOf('photo.JPG').toString(), 'image/jpeg');
      expect(typeOf('photo.jpeg').toString(), 'image/jpeg');
      expect(typeOf('id.png').toString(), 'image/png');
      expect(typeOf('cv.doc').toString(), 'application/msword');
      expect(typeOf('cv.docx').toString(), contains('wordprocessingml'));
      // Wider than any list we would have written by hand.
      expect(typeOf('scan.heic').toString(), 'image/heic');

      // An unknown or missing extension degrades to the safe default rather
      // than to no content type at all.
      expect(typeOf('README').toString(), 'application/octet-stream');
      expect(typeOf('archive.zzz').toString(), 'application/octet-stream');
    });
  });

  group('proxy-shaped failures', () {
    // The three ways a proxy in front of the API can mangle a response. All
    // three are plausible the first time this client is pointed at a real
    // environment, and all three must still produce a message a user can act on.
    test(
      'an HTML page served as JSON is a server fault, not a lost connection',
      () async {
        final error = await _captureError(
          (client) => client.get<Map<String, dynamic>>('/courses'),
          handler: (_) => ResponseBody.fromString(
            '<html><body><h1>502 Bad Gateway</h1></body></html>',
            502,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );

        expect(error.kind, ApiErrorKind.server);
        expect(error.statusCode, 502);
        expect(error.displayMessage, isNot(contains('html')));
      },
    );

    test('a body that is the wrong shape is reported as such, not as a bug in '
        'the connection', () async {
      // The backend answers a signup with a bare array, or a JSON string, where
      // the client asked for an object. This is the single most likely
      // integration mistake on day one, so it must not read as "check your wifi".
      final error = await _captureError(
        (client) =>
            client.post<Map<String, dynamic>>('/auth/signup', data: const {}),
        handler: (_) => _json(['unexpected', 'array']),
      );

      expect(error.kind, isNot(ApiErrorKind.network));
      expect(error.kind, isNot(ApiErrorKind.timeout));
      expect(error.displayMessage, isNotEmpty);
    });
  });

  group('the auth interceptor', () {
    test('attaches a bearer token when one is present', () async {
      final adapter = _FakeAdapter((_) => _json({'ok': true}));
      final scope = _scopeFor(adapter);
      addTearDown(scope.dispose);
      scope.read(authTokenProvider.notifier).state = 'token_abc';

      await scope.read(apiClientProvider).get<Map<String, dynamic>>('/me');

      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer token_abc',
      );
    });

    test('sends no Authorization header when signed out', () async {
      final adapter = _FakeAdapter((_) => _json({'ok': true}));
      final scope = _scopeFor(adapter);
      addTearDown(scope.dispose);

      await scope.read(apiClientProvider).get<Map<String, dynamic>>('/courses');

      expect(adapter.requests.single.headers, isNot(contains('Authorization')));
    });

    test('treats an empty token as signed out', () async {
      final adapter = _FakeAdapter((_) => _json({'ok': true}));
      final scope = _scopeFor(adapter);
      addTearDown(scope.dispose);
      scope.read(authTokenProvider.notifier).state = '';

      await scope.read(apiClientProvider).get<Map<String, dynamic>>('/courses');

      expect(adapter.requests.single.headers, isNot(contains('Authorization')));
    });
  });
}
