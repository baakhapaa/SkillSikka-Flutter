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
import 'package:skillsikka/core/network/session.dart';
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
    session: scope.read(sessionProvider.notifier),
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
    session: scope.read(sessionProvider.notifier),
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
  confirmPassword: 'hunter2pass',
  gender: 'Female',
  dob: '2005-04-12',
  photo: _doc(_photoBytes, 'avatar.png'),
);

RegistrationRequest _instructorRequest() => RegistrationRequest.instructor(
  name: 'Bikash Rai',
  email: 'bikash@example.com',
  password: 'hunter2pass',
  confirmPassword: 'hunter2pass',
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
    test('is a multipart POST to the student endpoint', () async {
      await _withRepo(
        (_) => _json({
          'user': {'id': 'u1', 'email': 'sarah@example.com', 'role': 'student'},
        }),
        (repository, adapter, _) async {
          await repository.register(_studentRequest());

          final request = adapter.requests.single;
          expect(request.method, 'POST');
          expect(request.path, endsWith('/register/student/'));

          final form = request.data as FormData;
          final fields = {for (final e in form.fields) e.key: e.value};

          // The role selects the endpoint, so it is not a field. Sending one
          // would be harmless but it is not part of the contract.
          expect(fields.containsKey('role'), isFalse);
          expect(fields['name'], 'Sarah Sharma');
          expect(fields['email'], 'sarah@example.com');
          expect(fields['password'], 'hunter2pass');
          expect(fields['confirm_password'], 'hunter2pass');
          expect(fields['gender'], 'Female');
          expect(fields['dob'], '2005-04-12');
        },
      );
    });

    test('posts the instructor role to the instructor endpoint', () async {
      await _withRepo(
        (_) => _json({
          'user': {'id': 'u1', 'email': 'bikash@example.com'},
        }),
        (repository, adapter, _) async {
          await repository.register(_instructorRequest());

          // One endpoint per role, rather than a single endpoint taking a `role`
          // field — so the path is what tells the server which field set to
          // validate.
          expect(
            adapter.requests.single.path,
            endsWith('/register/instructor/'),
          );
        },
      );
    });

    test('sends confirm_password, which the backend requires', () async {
      await _withRepo(
        (_) => _json({
          'user': {'id': 'u1', 'email': 'sarah@example.com'},
        }),
        (repository, adapter, _) async {
          await repository.register(_studentRequest());

          final form = adapter.requests.single.data as FormData;
          final fields = {for (final e in form.fields) e.key: e.value};
          // We used to leave this out on the grounds that the form already
          // compares the two values. The backend requires the field and
          // validates the pair itself, so omitting it failed registration.
          expect(fields['confirm_password'], 'hunter2pass');
        },
      );
    });

    test(
      'sends the avatar as `profile_photo`, documents by slot name',
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
              containsAll(['profile_photo', 'cv_resume', 'certificates']),
            );
            // The slot names are already the multipart field names, so a rename
            // in the UI cannot silently change the wire contract.
            //
            // `certificates` is still off-contract: the backend expects
            // `certificates_and_recommendations`. Renaming the slot is
            // instructor-path work and is deliberately not done yet.
            expect(files['profile_photo']!.filename, 'avatar.png');
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

    test('reads tokens.access and verification_status', () async {
      await _withRepo(
        (_) => _json({
          'user': {
            // A Django AutoField arrives as a JSON number, not a string.
            'id': 42,
            'email': 'sarah@example.com',
            'name': 'Sarah Sharma',
            'role': 'student',
            'verification_status': 'pending',
          },
          'tokens': {'refresh': 'refresh-abc', 'access': 'access-abc'},
        }),
        (repository, _, _) async {
          final account = await repository.register(_studentRequest());

          // The token is nested under `tokens`. Reading only the top level was a
          // real bug: a *successful* registration parsed as "registered but not
          // signed in", so the user was left on the OTP step with no session.
          expect(account.accessToken, 'access-abc');
          expect(account.hasSession, isTrue);
          expect(account.userId, '42');
          expect(account.role, ProfileRole.student);
          // The field is `verification_status`; we were reading `status`, which
          // never arrives, so this was always null.
          expect(account.status, 'pending');
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

          expect(scope.read(sessionProvider)?.access, 'abc.def.ghi');
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
            expect(scope.read(sessionProvider), isNull);
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

          expect(scope.read(sessionProvider)?.access, 'from-otp');
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
        expect(scope.read(sessionProvider), isNull);
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

    // The three tests above all inspect the *returned account* and never supply a
    // session controller, so none of them could have caught the bug this group
    // exists for: `FakeAuthRepository` used to return a valid-looking account
    // without writing `sessionProvider`, which the interface explicitly promises
    // ("Signs in ... and adopts the session"). Every guarded screen then bounced
    // the user back to login with no error anywhere, while both the guard suite
    // (which sets the session directly) and these tests (which ignore it) passed.
    // It took `widget_test.dart` driving the real app to surface it.
    group('session adoption — the promise the double has to keep', () {
      test('logIn writes the session it returns', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final repository = FakeAuthRepository(
          session: container.read(sessionProvider.notifier),
        );

        final account = await repository.logIn(
          email: 'sita@example.com',
          password: 'Passw0rd',
        );

        expect(account.hasSession, isTrue);
        final session = container.read(sessionProvider);
        expect(session, isNotNull);
        // Both tokens, matching `DioAuthRepository._adopt`: an access-only
        // session is signed out half an hour in with no way to renew.
        expect(session!.access, account.accessToken);
        expect(session.refresh, account.refreshToken);
      });

      test('register adopts only when it actually returned a token', () async {
        final withToken = ProviderContainer();
        addTearDown(withToken.dispose);
        await FakeAuthRepository(
          tokenOnRegister: true,
          session: withToken.read(sessionProvider.notifier),
        ).register(_studentRequest());
        expect(withToken.read(sessionProvider), isNotNull);

        // The OTP-first model: no token, so no session. `_adopt` is a no-op
        // rather than storing a session with an empty access token.
        final withoutToken = ProviderContainer();
        addTearDown(withoutToken.dispose);
        await FakeAuthRepository(
          session: withoutToken.read(sessionProvider.notifier),
        ).register(_studentRequest());
        expect(withoutToken.read(sessionProvider), isNull);
      });

      test('logOut clears the session, like the real one', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final repository = FakeAuthRepository(
          session: container.read(sessionProvider.notifier),
        );
        await repository.logIn(email: 'sita@example.com', password: 'Passw0rd');
        expect(container.read(sessionProvider), isNotNull);

        await repository.logOut();

        expect(repository.logOuts, 1);
        expect(
          container.read(sessionProvider),
          isNull,
          reason:
              'a fake that leaves the session set makes every '
              '"logout returns you to login" test pass for the wrong reason',
        );
      });

      test('with no controller it records the call, adopts nothing', () async {
        // The documented escape hatch: legal for a test that only asserts on what
        // was *sent*. Pinned so it stays deliberate rather than becoming an
        // accidental default someone relies on.
        final repository = FakeAuthRepository();

        final account = await repository.logIn(
          email: 'sita@example.com',
          password: 'Passw0rd',
        );

        // The call was recorded and the account still carries a session — the
        // only omission is that nothing was written anywhere.
        expect(repository.logins, hasLength(1));
        expect(account.hasSession, isTrue);
      });
    });
  });

  group('AuthApi.logIn', () {
    test('posts email and password to /login/', () async {
      await _withRepo(
        (_) => _json({
          'user': {'id': 7, 'email': 'sita@example.com', 'role': 'student'},
          'tokens': {'access': 'access-abc', 'refresh': 'refresh-abc'},
        }),
        (repository, adapter, _) async {
          await repository.logIn(
            email: 'sita@example.com',
            password: 'Passw0rd',
          );

          final request = adapter.requests.single;
          expect(request.method, 'POST');
          expect(request.path, endsWith('/login/'));
          expect(request.data, {
            'email': 'sita@example.com',
            'password': 'Passw0rd',
          });
        },
      );
    });

    test('adopts the session the response carries', () async {
      await _withRepo(
        (_) => _json({
          'user': {'id': 7, 'email': 'sita@example.com', 'role': 'student'},
          'tokens': {'access': 'access-abc', 'refresh': 'refresh-abc'},
        }),
        (repository, _, scope) async {
          await repository.logIn(email: 'sita@example.com', password: 'p');

          // Both tokens: the access token alone dies after 30 minutes, so a
          // session without the refresh token cannot be renewed.
          expect(scope.read(sessionProvider)?.access, 'access-abc');
          expect(scope.read(sessionProvider)?.refresh, 'refresh-abc');
        },
      );
    });

    test('surfaces a bad-credentials 400 with the server wording', () async {
      final error = await _captureError(
        (repository) => repository.logIn(email: 'a@b.com', password: 'wrong'),
        handler: (_) => _json(
          {'detail': 'No active account found with the given credentials'},
          status: 400,
        ),
      );

      expect(error.statusCode, 400);
      expect(error.message, contains('No active account found'));
      // The backend does not say which of the two was wrong, which is why the
      // screen cannot highlight a field.
      expect(error.fieldErrors, isEmpty);
    });
  });

  group('DioAuthRepository.logOut', () {
    test('sends the refresh token so the server can blacklist it', () async {
      await _withRepo(
        (_) => _json({'detail': 'Logged out successfully.'}),
        (repository, adapter, scope) async {
          scope.read(sessionProvider.notifier).state = const Session(
            access: 'access-abc',
            refresh: 'refresh-abc',
          );

          await repository.logOut();

          expect(adapter.requests.single.path, endsWith('/logout/'));
          expect(adapter.requests.single.data, {'refresh': 'refresh-abc'});
          expect(scope.read(sessionProvider), isNull);
        },
      );
    });

    test('clears the session even when the call fails', () async {
      await _withRepo(
        (_) => _json({'detail': 'nope'}, status: 500),
        (repository, adapter, scope) async {
          scope.read(sessionProvider.notifier).state = const Session(
            access: 'access-abc',
            refresh: 'refresh-abc',
          );

          // Must not throw. The user asked to be signed out, so a server fault
          // cannot be allowed to leave them signed in on this device.
          await repository.logOut();

          expect(adapter.requests, hasLength(1));
          expect(scope.read(sessionProvider), isNull);
        },
      );
    });

    test('makes no call when there is no refresh token', () async {
      await _withRepo(
        (_) => _json({'detail': 'ok'}),
        (repository, adapter, scope) async {
          scope.read(sessionProvider.notifier).state = const Session(
            access: 'access-abc',
          );

          await repository.logOut();

          // Nothing to blacklist, so clearing locally is the whole job.
          expect(adapter.requests, isEmpty);
          expect(scope.read(sessionProvider), isNull);
        },
      );
    });
  });
}
