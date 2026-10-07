import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:skillsikka/core/network/session.dart';
import 'package:skillsikka/core/routing/app_router.dart';
import 'package:skillsikka/features/auth/data/auth_repository.dart';

import 'support/home_page_font_harness.dart';

/// The routing guard: who is allowed where.
///
/// These drive the **real** router from [appRouterProvider] rather than a
/// hand-built `GoRouter`. A test that constructs its own routes tests nothing
/// about the guard — the guard lives in the provider's `redirect`, so the
/// provider is what has to be under test.
///
/// Three tests in this suite already build their own routers for other reasons
/// (`logout_clears_session_test`, `signup_form_validation_test`,
/// `signup_verification_email_test`). They are deliberately left alone here: they
/// are testing their own screens, and this file is where the guard is tested.
void main() {
  // Every screen these routes resolve to uses `GoogleFonts.*`, and a widget test
  // fetches nothing. Without this the first test passes and the *second* one
  // hangs — see the harness's own comment on `pendingFontFutures`. It is not
  // optional here for the same reason it is not optional on HomePage.
  installHomePageFontHarness();

  /// A signed-in session, with a refresh token so it is a realistic one.
  const signedIn = Session(access: 'access-abc', refresh: 'refresh-abc');

  /// The router, plus the container behind it, so a test can change the session
  /// and watch the guard re-evaluate.
  ///
  /// **[startAt] is navigated to after the router is built, not used as an
  /// initial location.** The first version of this took an `initialLocation` and
  /// ignored it — `appRouterProvider` hardcodes `initialLocation: '/splash'`, so
  /// every test started at the splash screen regardless of what it asked for, and
  /// eleven of them failed with `Expected: '/login-screen' Actual: '/splash'`.
  /// The guard was correct the whole time; the harness was lying about where it
  /// started.
  ///
  /// Navigating with `go` rather than rebuilding the router is also the more
  /// honest test: it exercises `redirect` as a *navigation*, which is how a user
  /// reaches these routes.
  ({GoRouter router, ProviderContainer container}) routerFor({
    Session? session,
    String? startAt,
  }) {
    final container = ProviderContainer(
      overrides: [
        // The screens reachable in these tests never make a request, but
        // installing the fake means a mistake in a route under test cannot turn
        // into real HTTP inside a widget test.
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    if (session != null) {
      container.read(sessionProvider.notifier).state = session;
    }

    // Built through the provider so the guard, its `refreshListenable` and its
    // route table are all the real ones.
    final router = container.read(appRouterProvider);

    if (startAt != null && startAt != '/splash') router.go(startAt);

    return (router: router, container: container);
  }

  /// Pumps the router into the tree and settles it.
  ///
  /// The container has to be threaded in and installed as an
  /// `UncontrolledProviderScope`, because a `ProviderContainer` on its own is
  /// **not** how a widget finds providers — the widget tree needs a scope
  /// ancestor. Without one, any route under test whose screen reads a provider
  /// throws `Bad state: No ProviderScope found`.
  ///
  /// That is exactly what happened here: `/onboarding` and `/login-screen` do
  /// not read providers and rendered fine, so the harness looked correct, while
  /// `/signup/student` reads one and blew up. Only the route that actually
  /// touched a provider surfaced the missing scope.
  ///
  /// `UncontrolledProviderScope` rather than `ProviderScope` because the
  /// container is already built in [routerFor] — the same instance the test
  /// mutates to drive the session-change cases. A fresh `ProviderScope` would
  /// silently construct a *second* container and the setters would write to the
  /// wrong one.
  Future<void> pumpRouter(
    WidgetTester tester,
    GoRouter router,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The path the router settled on.
  String currentPath(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  group('isPublicRoute', () {
    test('allows each route a signed-out user legitimately needs', () {
      for (final path in [
        '/splash',
        '/onboarding',
        '/login-screen',
        '/forgot-password',
      ]) {
        expect(isPublicRoute(path), isTrue, reason: '$path should be public');
      }
    });

    test('covers the whole signup family by prefix', () {
      // One entry per family, so adding a signup step does not mean remembering
      // to add it here as well.
      for (final path in [
        '/signup',
        '/signup/role',
        '/signup/student',
        '/signup/instructor',
        '/signup/interests',
        '/signup/verify',
      ]) {
        expect(isPublicRoute(path), isTrue, reason: '$path should be public');
      }
    });

    test('protects everything else', () {
      for (final path in ['/', '/short', '/short/for-you', '/profile']) {
        expect(isPublicRoute(path), isFalse, reason: '$path must be protected');
      }
    });

    test('is not fooled by a path that merely starts with a public one', () {
      // `startsWith('$route/')`, not a bare `startsWith`. Without the separator
      // `/splash-of-something` would be treated as public.
      expect(isPublicRoute('/splash/extra'), isTrue);
      expect(isPublicRoute('/splashy'), isFalse);
      expect(isPublicRoute('/login-screen-fake'), isFalse);
    });
  });

  group('signed out', () {
    testWidgets('is sent to the login screen from a protected route', (
      tester,
    ) async {
      final (:router, :container) = routerFor(startAt: '/');

      await pumpRouter(tester, router, container);

      expect(
        currentPath(router),
        '/login-screen',
        reason: 'the home route must not be reachable with no session',
      );
      expect(container.read(sessionProvider), isNull);
    });

    testWidgets('keeps every public route reachable', (tester) async {
      for (final path in [
        '/onboarding',
        '/login-screen',
        '/forgot-password',
        '/signup/role',
        '/signup/student',
      ]) {
        final (:router, :container) = routerFor(startAt: path);

        await pumpRouter(tester, router, container);

        expect(
          currentPath(router),
          path,
          reason: '$path is public and must not be redirected',
        );
      }
    });

    testWidgets('stays put on the start-up route', (tester) async {
      // `/splash` is the `initialLocation` and must not be redirected away from,
      // or the app could never settle on a screen for a returning user.
      final (:router, :container) = routerFor();

      await pumpRouter(tester, router, container);

      expect(currentPath(router), '/splash');
    });

    testWidgets('is not redirected merely for starting up signed out', (
      tester,
    ) async {
      // The start-up state is "no session", and no *transition* has happened.
      // A guard that reacted to the state rather than a change would bounce
      // every cold start off the splash screen and onto login, which is what
      // this pins.
      final (:router, :container) = routerFor(startAt: '/splash');

      await pumpRouter(tester, router, container);

      expect(currentPath(router), '/splash');
    });
  });

  group('signed in', () {
    testWidgets('is allowed through to a protected route', (tester) async {
      final (:router, :container) = routerFor(session: signedIn, startAt: '/');

      await pumpRouter(tester, router, container);

      expect(currentPath(router), '/');
    });

    testWidgets('is moved off the splash screen', (tester) async {
      final (:router, :container) = routerFor(session: signedIn);

      await pumpRouter(tester, router, container);

      expect(currentPath(router), '/');
    });

    testWidgets('is moved off login, onboarding and password recovery', (
      tester,
    ) async {
      for (final path in ['/login-screen', '/onboarding', '/forgot-password']) {
        final (:router, :container) = routerFor(
          session: signedIn,
          startAt: path,
        );

        await pumpRouter(tester, router, container);

        expect(
          currentPath(router),
          '/',
          reason: 'a signed-in user has nothing to do on $path',
        );
      }
    });

    testWidgets('is left on the verify step, which is live again', (
      tester,
    ) async {
      // This used to assert the opposite. Registration handed back a session and
      // the step's endpoint did not exist, so a signed-in user on it was sent
      // home. Both halves are now wrong: the backend withholds the session until
      // the emailed code is confirmed (2026-10-07), and the step posts to a real
      // endpoint.
      //
      // Leaving it reachable is also what stops the interests step being
      // skipped. The session appears *while the user is on this screen*, so a
      // rule that redirected a signed-in user away would fire mid-verification
      // and jump straight to home.
      final (:router, :container) = routerFor(
        session: signedIn,
        startAt: '/signup/verify',
      );

      await pumpRouter(tester, router, container);

      expect(currentPath(router), '/signup/verify');
    });
  });

  group('the guard re-evaluates when the session changes', () {
    testWidgets('moves to login when the session is lost', (tester) async {
      // The involuntary sign-out: the server rejected the refresh token. Without
      // `refreshListenable` the guard would have been evaluated once and gone
      // stale, leaving the user on a screen that can no longer load anything.
      final (:router, :container) = routerFor(session: signedIn, startAt: '/');
      await pumpRouter(tester, router, container);
      expect(currentPath(router), '/');

      container.read(sessionProvider.notifier).state = null;
      await tester.pumpAndSettle();

      expect(currentPath(router), '/login-screen');
    });

    testWidgets('unlocks the app when a session is adopted', (tester) async {
      // The signup path: the user registers, a session is adopted, and the
      // routes they are now entitled to must open without a manual navigation.
      final (:router, :container) = routerFor(startAt: '/login-screen');
      await pumpRouter(tester, router, container);
      expect(currentPath(router), '/login-screen');

      container.read(sessionProvider.notifier).state = signedIn;
      await tester.pumpAndSettle();

      expect(currentPath(router), '/');
    });

    testWidgets('does not churn on a token rotation', (tester) async {
      // The access token is replaced every 30 minutes. Only the *presence* of a
      // session should re-run the guard; a same-presence change must not, or
      // every refresh would re-evaluate the whole route table mid-request.
      final (:router, :container) = routerFor(
        session: signedIn,
        startAt: '/short',
      );
      await pumpRouter(tester, router, container);
      expect(currentPath(router), '/short');

      container.read(sessionProvider.notifier).state = const Session(
        access: 'rotated-access',
        refresh: 'refresh-abc',
      );
      await tester.pumpAndSettle();

      expect(
        currentPath(router),
        '/short',
        reason: 'a rotated token must not move the user',
      );
    });
  });

  group('the guard does not loop', () {
    testWidgets('a denied route settles rather than oscillating', (
      tester,
    ) async {
      // The classic failure: `redirect` returns a path that itself redirects, and
      // the router spins. go_router throws on a redirect loop rather than hanging,
      // so reaching the assertion at all is most of the test — but the settled
      // path is asserted too, because a guard that lands somewhere unexpected is
      // its own bug.
      final (:router, :container) = routerFor(startAt: '/short');

      await pumpRouter(tester, router, container);

      expect(currentPath(router), '/login-screen');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a signed-in user sent home from login settles on home', (
      tester,
    ) async {
      // The other direction, and the one that loops if `/` were ever treated as
      // needing a session it can then lose.
      final (:router, :container) = routerFor(
        session: signedIn,
        startAt: '/login-screen',
      );

      await pumpRouter(tester, router, container);

      expect(currentPath(router), '/');
      expect(tester.takeException(), isNull);
    });
  });
}
