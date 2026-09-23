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
import 'package:skillsikka/features/auth/data/auth_repository.dart';
import 'package:skillsikka/features/auth/data/registration_request.dart';
import 'package:skillsikka/features/profile/data/profile_role.dart';
import 'package:skillsikka/features/profile/data/user_profile.dart';

/// A stand-in for the real transport — the same one `api_client_test.dart` uses.
/// `mockito` and `http_mock_adapter` are not dependencies of this project.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

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
    // stream surfaces here rather than being silently ignored.
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object? body, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// A `Dio` built the way the app builds it — same base options, same tolerant
/// transformer, same interceptors — with only the transport swapped out.
///
/// Overridden to production so the request-logging interceptor stays out of the
/// test output.
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

/// Runs [body] against the real repository talking to a fake transport.
Future<void> _withRepo(
  FutureOr<ResponseBody> Function(RequestOptions options) handler,
  Future<void> Function(
    AuthRepository repository,
    _FakeAdapter adapter,
    ProviderContainer scope,
  )
  body,
) async {
  final adapter = _FakeAdapter(handler);
  final scope = _scopeFor(adapter);
  addTearDown(scope.dispose);

  final repository = DioAuthRepository(
    client: scope.read(apiClientProvider),
    authToken: scope.read(authTokenProvider.notifier),
  );
  await body(repository, adapter, scope);
}

/// The exception thrown by [body], or a failure if it threw nothing.
Future<ApiException> _captureError(
  Future<void> Function(AuthRepository repository) body, {
  required FutureOr<ResponseBody> Function(RequestOptions options) handler,
}) async {
  final adapter = _FakeAdapter(handler);
  final scope = _scopeFor(adapter);
  addTearDown(scope.dispose);
  final repository = DioAuthRepository(
    client: scope.read(apiClientProvider),
    authToken: scope.read(authTokenProvider.notifier),
  );

  try {
    await body(repository);
  } on ApiException catch (error) {
    return error;
  }
  fail('expected an ApiException, but the call succeeded');
}

final _photoBytes = Uint8List.fromList([1, 2, 3, 4]);
final _cvBytes = Uint8List.fromList([5, 6, 7, 8]);
final _certBytes = Uint8List.fromList([9, 10]);

PickedDocument _doc(Uint8List bytes, String name) =>
    PickedDocument(bytes: bytes, fileName: name);

RegistrationRequest _studentRequest() => RegistrationRequest.student(
  name: 'Sarah Sharma',
  email: 'sarah@example.com',
  password: 'hunter2pass',
  gender: 'Female',
  dob: '2005-04-12',
  photo: _doc(_photoBytes, 'avatar.png'),
);

RegistrationRequest _instructorRequest() => RegistrationRequest.instructor(
  name: 'Bikash Rai',
  email: 'bikash@example.com',
  password: 'hunter2pass',
  gender: 'Male',
  dob: '1990-01-20',
  phone: '9812345678',
  location: 'Baneshwor, Kathmandu',
  qualification: 'Master of Computer Applications',
  expertise: 'Physics, Fullstack Web Dev',
  experience: '5',
  photo: _doc(_photoBytes, 'avatar.png'),
  cv: _doc(_cvBytes, 'cv.pdf'),
  certificates: _doc(_certBytes, 'cert.png'),
);

void main() {
  group('AuthApi.register — the request', () {
    test('is a multipart POST carrying the role and every text field', () async {
      await _withRepo(
        (_) => _json({
          'user': {'id': 'u1', 'email': 'sarah@example.com', 'role': 'student'},
        }),
        (repository, adapter, _) async {
          await repository.register(_studentRequest());

          final request = adapter.requests.single;
          expect(request.method, 'POST');
          expect(request.path, endsWith('/auth/register'));

          final form = request.data as FormData;
          final fields = {for (final e in form.fields) e.key: e.value};

          // The role rides with the fields rather than in the path: it decides
          // which field set the server validates.
          expect(fields['role'], 'student');
          expect(fields['name'], 'Sarah Sharma');
          expect(fields['email'], 'sarah@example.com');
          expect(fields['password'], 'hunter2pass');
          expect(fields['gender'], 'Female');
          expect(fields['dob'], '2005-04-12');
        },
      );
    });

    test('never sends confirm_password', () async {
      await _withRepo(
        (_) => _json({
          'user': {'id': 'u1', 'email': 'sarah@example.com'},
        }),
        (repository, adapter, _) async {
          await repository.register(_studentRequest());

          final form = adapter.requests.single.data as FormData;
          // It is a client-side check only. Sending it would put the same
          // secret on the wire twice.
          expect(
            form.fields.map((e) => e.key),
            isNot(contains('confirm_password')),
          );
        },
      );
    });

    test(
      'sends the avatar as `photo` and documents under their slot names',
      () async {
        await _withRepo(
          (_) => _json({
            'user': {'id': 'u1', 'email': 'bikash@example.com'},
          }),
          (repository, adapter, _) async {
            await repository.register(_instructorRequest());

            final form = adapter.requests.single.data as FormData;
            final files = {for (final e in form.files) e.key: e.value};

            expect(
              files.keys,
              containsAll(['photo', 'cv_resume', 'certificates']),
            );
            // The slot names are already the multipart field names, so a rename
            // in the UI cannot silently change the wire contract.
            expect(files['photo']!.filename, 'avatar.png');
            expect(files['cv_resume']!.filename, 'cv.pdf');
            expect(files['certificates']!.filename, 'cert.png');
          },
        );
      },
    );
  });

  group('AuthApi.register — the response', () {
    test('reads a nested user object with no token', () async {
      await _withRepo(
        (_) => _json({
          'user': {
            'id': 'u1',
            'email': 'sarah@example.com',
            'role': 'student',
            'status': 'pending',
          },
        }),
        (repository, _, _) async {
          final account = await repository.register(_studentRequest());

          expect(account.email, 'sarah@example.com');
          expect(account.userId, 'u1');
          expect(account.role, ProfileRole.student);
          expect(account.status, 'pending');
          expect(account.hasSession, isFalse);
        },
      );
    });

    test('reads a token alongside the user', () async {
      await _withRepo(
        (_) => _json({
          'user': {'id': 'u1', 'email': 'sarah@example.com', 'role': 'student'},
          'access_token': 'abc.def.ghi',
          'refresh_token': 'zzz',
          'expires_in': 3600,
        }),
        (repository, _, _) async {
          final account = await repository.register(_studentRequest());

          expect(account.accessToken, 'abc.def.ghi');
          expect(account.hasSession, isTrue);
        },
      );
    });

    test('reads a flat body where the user fields are top level', () async {
      await _withRepo(
        (_) => _json({
          'id': 'u9',
          'email': 'bikash@example.com',
          'role': 'instructor',
          'token': 'flat-token',
        }),
        (repository, _, _) async {
          final account = await repository.register(_instructorRequest());

          expect(account.userId, 'u9');
          expect(account.role, ProfileRole.instructor);
          expect(account.accessToken, 'flat-token');
        },
      );
    });

    test(
      'leaves an unrecognised role null rather than guessing student',
      () async {
        await _withRepo(
          (_) => _json({
            'user': {'id': 'u1', 'email': 'x@example.com', 'role': 'moderator'},
          }),
          (repository, _, _) async {
            final account = await repository.register(_studentRequest());

            // Coercing to student would show a student's field set to someone who
            // is not one, hiding the contract drift instead of surfacing it.
            expect(account.role, isNull);
            expect(account.email, 'x@example.com');
          },
        );
      },
    );

    test('treats a blank token as no session', () async {
      await _withRepo(
        (_) => _json({
          'user': {'id': 'u1', 'email': 'sarah@example.com'},
          'access_token': '   ',
        }),
        (repository, _, _) async {
          final account = await repository.register(_studentRequest());
          expect(account.hasSession, isFalse);
        },
      );
    });

    test('a 2xx that does not describe an account is an error', () async {
      final error = await _captureError(
        (repository) => repository.register(_studentRequest()),
        // A body with no identity and no token. Accepting it would let the flow
        // continue with an empty email and fail somewhere less obvious.
        handler: (_) => _json({'detail': 'ok'}),
      );

      expect(error.kind, ApiErrorKind.unknown);
      expect(error.message, contains('did not contain an account'));
    });
  });

  group('AuthApi — errors reach the caller as ApiException', () {
    test('a DRF field-error 400 keeps its per-field messages', () async {
      final error = await _captureError(
        (repository) => repository.register(_studentRequest()),
        handler: (_) => _json({
          'email': ['This email is already registered.'],
          'password': ['This password is too short.'],
        }, status: 400),
      );

      expect(error.kind, ApiErrorKind.badRequest);
      expect(error.statusCode, 400);
      expect(error.fieldError('email'), 'This email is already registered.');
      expect(error.fieldError('password'), 'This password is too short.');
      // DRF sends a serializer error as 400, so the kind is `badRequest` — but
      // the user still needs to be pointed at the fields, not told the request
      // "was not accepted".
      expect(error.displayMessage, contains('highlighted fields'));
    });

    test(
      'a 500 arrives as a server error, not as a connection problem',
      () async {
        final error = await _captureError(
          (repository) => repository.register(_studentRequest()),
          handler: (_) =>
              _json({'detail': 'Internal server error'}, status: 500),
        );

        expect(error.kind, ApiErrorKind.server);
        expect(error.isRetryable, isTrue);
      },
    );
  });

  group('DioAuthRepository — session adoption', () {
    test('keeps the token registration returned', () async {
      await _withRepo(
        (_) => _json({
          'user': {'id': 'u1', 'email': 'sarah@example.com', 'role': 'student'},
          'access_token': 'abc.def.ghi',
        }),
        (repository, _, scope) async {
          await repository.register(_studentRequest());

          expect(scope.read(authTokenProvider), 'abc.def.ghi');
        },
      );
    });

    test(
      'leaves the session alone when registration returned no token',
      () async {
        await _withRepo(
          (_) => _json({
            'user': {
              'id': 'u1',
              'email': 'sarah@example.com',
              'role': 'student',
            },
          }),
          (repository, _, scope) async {
            await repository.register(_studentRequest());

            // The OTP-first backend model. Adopting nothing is correct here; the
            // flow continues to verification.
            expect(scope.read(authTokenProvider), isNull);
          },
        );
      },
    );

    test('adopts the token when verification is what issues it', () async {
      await _withRepo(
        (_) => _json({
          'user': {'id': 'u1', 'email': 'sarah@example.com'},
          'access_token': 'from-otp',
        }),
        (repository, _, scope) async {
          await repository.verifyOtp(email: 'sarah@example.com', code: '1234');

          expect(scope.read(authTokenProvider), 'from-otp');
        },
      );
    });

    test('verifyOtp tolerates a response that carries no account', () async {
      await _withRepo((_) => _json({'detail': 'Email verified.'}), (
        repository,
        adapter,
        scope,
      ) async {
        final account = await repository.verifyOtp(
          email: 'sarah@example.com',
          code: '1234',
        );

        expect(account, isNull);
        expect(scope.read(authTokenProvider), isNull);
        // …and the code really was sent.
        final sent = adapter.requests.single.data as Map<String, dynamic>;
        expect(sent['email'], 'sarah@example.com');
        expect(sent['code'], '1234');
      });
    });

    test('verifyOtp tolerates an empty 204 body', () async {
      await _withRepo(
        // Empty body: dio hands back '' and the tolerant transformer keeps it a
        // string rather than throwing away the response.
        (_) => ResponseBody.fromString('', 204),
        (repository, _, _) async {
          final account = await repository.verifyOtp(
            email: 'sarah@example.com',
            code: '1234',
          );

          // A 204 is a success, so this must not throw.
          expect(account, isNull);
        },
      );
    });

    test('a wrong code surfaces the server message', () async {
      final error = await _captureError(
        (repository) =>
            repository.verifyOtp(email: 'sarah@example.com', code: '0000'),
        handler: (_) => _json({
          'code': ['That code is not correct.'],
        }, status: 400),
      );

      expect(error.kind, ApiErrorKind.badRequest);
      expect(error.fieldError('code'), 'That code is not correct.');
    });

    test('resendOtp posts the email and ignores the body', () async {
      await _withRepo((_) => _json({'detail': 'Sent.'}), (
        repository,
        adapter,
        _,
      ) async {
        await repository.resendOtp(email: 'sarah@example.com');

        final request = adapter.requests.single;
        expect(request.path, endsWith('/auth/resend-otp'));
        expect(
          (request.data as Map<String, dynamic>)['email'],
          'sarah@example.com',
        );
      });
    });
  });

  group('FakeAuthRepository', () {
    test('records what it was sent and honours tokenOnRegister', () async {
      final repository = FakeAuthRepository(tokenOnRegister: true);

      final account = await repository.register(_studentRequest());

      expect(repository.registrations, hasLength(1));
      expect(
        repository.registrations.single.fields['email'],
        'sarah@example.com',
      );
      expect(account.hasSession, isTrue);
      expect(account.role, ProfileRole.student);
    });

    test('without tokenOnRegister it mimics the OTP-first backend', () async {
      final repository = FakeAuthRepository();

      final account = await repository.register(_studentRequest());

      expect(account.hasSession, isFalse);
    });

    test(
      'failure makes every call throw, so a screen error path can be driven',
      () async {
        final repository = FakeAuthRepository()
          ..failure = const ApiException(
            kind: ApiErrorKind.network,
            message: 'No connection.',
          );

        expect(
          () => repository.register(_studentRequest()),
          throwsA(isA<ApiException>()),
        );
        expect(
          () => repository.verifyOtp(email: 'a@b.com', code: '1234'),
          throwsA(isA<ApiException>()),
        );
        // Nothing was recorded as a success.
        expect(repository.registrations, isEmpty);
        expect(repository.verifications, isEmpty);
      },
    );
  });
}
