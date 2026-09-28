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
import 'package:skillsikka/core/session_bootstrap.dart';
import 'package:skillsikka/features/auth/data/auth_repository.dart';
import 'package:skillsikka/features/auth/data/me_profile.dart';
import 'package:skillsikka/features/profile/data/profile_role.dart';
import 'package:skillsikka/features/profile/data/user_profile.dart';

/// A stand-in for the transport, copied in spirit from `api_client_test.dart`.
///
/// Duplicated rather than shared: both files need it, and a shared `test/support`
/// helper for a 25-line class would tie two unrelated suites together. The
/// alternative — one suite reaching into another's private helper — is worse.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) _handler;

  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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

/// The real `/me/` body, captured from the live backend on 2026-09-28.
///
/// Kept verbatim — including the string id and the flat shape — because the
/// point of this suite is that the real response parses. A hand-tidied fixture
/// would test the fixture.
const _liveMeBody = {
  'id': '12',
  'email': 'metest1790577752@example.com',
  'name': 'Me Probe',
  'role': 'student',
  'verification_status': 'not_applicable',
  'onboarding_completed': false,
  'is_active': true,
};

/// A container with the transport swapped out, like the app builds it.
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

void main() {
  group('MeProfile.tryParse', () {
    test('reads the live flat response', () {
      final profile = MeProfile.tryParse(_liveMeBody);

      expect(profile, isNotNull);
      expect(profile!.userId, '12', reason: 'a numeric id must stringify');
      expect(profile.email, 'metest1790577752@example.com');
      expect(profile.name, 'Me Probe');
      expect(profile.role, ProfileRole.student);
      expect(profile.verificationStatus, 'not_applicable');
      expect(profile.onboardingCompleted, isFalse);
      expect(profile.isActive, isTrue);
    });

    test('returns null when there is no identity in the body', () {
      // A 200 carrying something that is not a user must not be mistaken for
      // one, or the caller would overwrite a good profile with blanks.
      expect(MeProfile.tryParse({'detail': 'ok'}), isNull);
      expect(MeProfile.tryParse(const <String, dynamic>{}), isNull);
      expect(MeProfile.tryParse('not a map'), isNull);
      expect(MeProfile.tryParse(null), isNull);
    });

    test('reads a nested user object too', () {
      // `/me/` is flat, but the auth responses nest under `user`. One model
      // covering both is why this is accepted.
      final profile = MeProfile.tryParse({
        'user': {'id': 5, 'email': 'a@b.test', 'role': 'instructor'},
      });

      expect(profile, isNotNull);
      expect(profile!.userId, '5');
      expect(profile.role, ProfileRole.instructor);
    });

    test('leaves an unknown role null rather than coercing it', () {
      final profile = MeProfile.tryParse({
        'id': '1',
        'email': 'a@b.test',
        'role': 'super-admin',
      });

      expect(profile, isNotNull);
      expect(
        profile!.role,
        isNull,
        reason: 'an unrecognised role means the contract drifted',
      );
    });

    test('tolerates a wrong type in an optional flag', () {
      // A JSON `"false"` must not fail the whole parse — the identity is still
      // perfectly usable, and one bad optional field should not lose it.
      final profile = MeProfile.tryParse({
        'id': '1',
        'email': 'a@b.test',
        'is_active': 'false',
        'onboarding_completed': 0,
      });

      expect(profile, isNotNull);
      expect(profile!.isActive, isNull);
      expect(profile.onboardingCompleted, isNull);
    });

    test('profileValues omits blanks so a merge cannot erase', () {
      // The caller merges these over an existing profile. An empty string would
      // wipe a value the user typed.
      const profile = MeProfile(email: 'a@b.test');
      expect(profile.profileValues, {'email': 'a@b.test'});
      expect(profile.profileValues.containsKey('name'), isFalse);
    });
  });

  group('AuthRepository.fetchMe over HTTP', () {
    test('parses the live body and sends the path with its slash', () async {
      final adapter = _FakeAdapter((_) => _json(_liveMeBody));
      final scope = _scopeFor(adapter);
      addTearDown(scope.dispose);

      final repository = DioAuthRepository(
        client: scope.read(apiClientProvider),
        session: scope.read(sessionProvider.notifier),
      );

      final profile = await repository.fetchMe();

      expect(profile, isNotNull);
      expect(profile!.name, 'Me Probe');
      // The trailing slash is required: without it Django answers 301, which
      // dio does not silently follow. Asserted so a future "tidy-up" fails here
      // rather than in production.
      expect(adapter.requests.single.path, endsWith('/me/'));
    });

    test('throws ApiException on a 401, so the caller can decide', () async {
      // A 401 is the case the bootstrap has to survive. It must arrive as an
      // ApiException, not a DioException, or a screen would have to know what a
      // DioException is.
      final adapter = _FakeAdapter(
        (_) => _json({
          'detail': 'Authentication credentials were not provided.',
        }, status: 401),
      );
      final scope = _scopeFor(adapter);
      addTearDown(scope.dispose);

      final repository = DioAuthRepository(
        client: scope.read(apiClientProvider),
        session: scope.read(sessionProvider.notifier),
      );

      await expectLater(repository.fetchMe(), throwsA(isA<ApiException>()));
    });
  });

  group('SessionBootstrap', () {
    test('does nothing when there is no session', () async {
      final fake = FakeAuthRepository();
      final scope = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(scope.dispose);

      final loaded = await scope.read(sessionBootstrapProvider).loadProfile();

      expect(loaded, isFalse);
      expect(fake.meFetches, 0, reason: 'no session, no request');
    });

    test('fills the profile store from /me/', () async {
      final fake = FakeAuthRepository()
        ..me = const MeProfile(
          userId: '12',
          email: 'real@user.test',
          name: 'Real User',
          role: ProfileRole.instructor,
        );
      final scope = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(scope.dispose);

      scope.read(sessionProvider.notifier).state = const Session(
        access: 'access-abc',
        refresh: 'refresh-abc',
      );

      final loaded = await scope.read(sessionBootstrapProvider).loadProfile();

      expect(loaded, isTrue);
      final profile = scope.read(userProfileProvider);
      expect(profile.valueFor('name'), 'Real User');
      expect(profile.valueFor('email'), 'real@user.test');
      expect(profile.role, ProfileRole.instructor);
    });

    test('merges rather than replaces, keeping the photo', () async {
      // The store also holds the avatar, documents and the signup-detected
      // location. Filling in a name must not throw those away.
      final fake = FakeAuthRepository()
        ..me = const MeProfile(name: 'Real User', email: 'real@user.test');
      final scope = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(scope.dispose);

      scope.read(sessionProvider.notifier).state = const Session(access: 'a');
      scope.read(userProfileProvider.notifier).setLocation('Kathmandu');

      await scope.read(sessionBootstrapProvider).loadProfile();

      final profile = scope.read(userProfileProvider);
      expect(profile.valueFor('name'), 'Real User');
      expect(
        profile.valueFor('location'),
        'Kathmandu',
        reason: 'the merge must not drop what was already stored',
      );
    });

    test('survives a failed fetch without dropping the session', () async {
      // The important one: a dead /me/ endpoint must not sign the user out, and
      // must not throw into whoever triggered the load.
      final fake = FakeAuthRepository()
        ..meFailure = const ApiException(
          kind: ApiErrorKind.unauthorized,
          message: 'nope',
        );
      final scope = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(scope.dispose);

      scope.read(sessionProvider.notifier).state = const Session(
        access: 'access-abc',
      );

      final loaded = await scope.read(sessionBootstrapProvider).loadProfile();

      expect(loaded, isFalse);
      expect(
        scope.read(sessionProvider),
        isNotNull,
        reason: 'a failed profile fetch must not end the session',
      );
    });

    test('fetches once per session, not once per token rotation', () async {
      // The access token is replaced every 30 minutes. Only a *new session*
      // should cost a request, so the key is the refresh token.
      final fake = FakeAuthRepository()..me = const MeProfile(name: 'A');
      final scope = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(scope.dispose);

      final bootstrap = scope.read(sessionBootstrapProvider);
      scope.read(sessionProvider.notifier).state = const Session(
        access: 'a1',
        refresh: 'r1',
      );
      await bootstrap.loadProfile();
      expect(fake.meFetches, 1);

      // Same session — nothing to do.
      await bootstrap.loadProfile();
      expect(fake.meFetches, 1, reason: 'a repeat for the same session');

      // The **access** token rotated but the refresh token is unchanged, so this
      // is still the same session and must not refetch.
      scope.read(sessionProvider.notifier).state = const Session(
        access: 'a2',
        refresh: 'r1',
      );
      await bootstrap.loadProfile();
      expect(
        fake.meFetches,
        1,
        reason: 'a rotated access token is the same session',
      );

      // A different refresh token is a different session — someone else signed
      // in — and that does refetch.
      scope.read(sessionProvider.notifier).state = const Session(
        access: 'a3',
        refresh: 'r2',
      );
      await bootstrap.loadProfile();
      expect(
        fake.meFetches,
        2,
        reason: 'a new session must load its own profile',
      );
    });

    test('clears the profile when the session ends', () async {
      // Without this, signing out and back in as someone else would briefly show
      // the previous user's name.
      final fake = FakeAuthRepository();
      final scope = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(scope.dispose);

      // Watch it so the listener is attached, the way `app.dart` does.
      scope.listen(sessionProfileLoaderProvider, (_, _) {});

      scope.read(sessionProvider.notifier).state = const Session(access: 'a');
      scope.read(userProfileProvider.notifier).save({'name': 'Someone'});
      expect(scope.read(userProfileProvider).valueFor('name'), 'Someone');

      scope.read(sessionProvider.notifier).state = null;
      await Future<void>.delayed(Duration.zero);

      expect(
        scope.read(userProfileProvider).valueFor('name'),
        '',
        reason: 'the previous user\'s profile must not outlive their session',
      );
    });
  });
}
