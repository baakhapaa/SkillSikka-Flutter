import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/features/auth/data/auth_repository.dart';
import 'package:skillsikka/features/login_screen/presentation/forgot_password_page.dart';

/// Pumps the reset flow with the network faked out, so the assertions are about
/// what the screen sends rather than about a transport error.
///
/// Returns the fake so a test can make a step fail, or assert on what went out.
Future<FakeAuthRepository> _pumpForgot(
  WidgetTester tester, {
  List<String>? navigatedTo,
}) async {
  // The screen is taller than the 800x600 default surface, which would put the
  // buttons out of reach of a tap.
  await tester.binding.setSurfaceSize(const Size(360, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final router = GoRouter(
    initialLocation: '/forgot-password',
    routes: [
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/login-screen',
        builder: (_, _) {
          navigatedTo?.add('/login-screen');
          return const Scaffold(body: Text('login step'));
        },
      ),
    ],
  );

  final auth = FakeAuthRepository();
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(auth)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  return auth;
}

/// Pumps enough frames for a stubbed request to finish and the UI to catch up.
///
/// Deliberately not [WidgetTester.pumpAndSettle]: the resend countdown schedules
/// a frame every second, so "no frames scheduled" is not a state this screen
/// reaches until the cooldown expires.
Future<void> _settleRequest(WidgetTester tester) async {
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pumps a snack bar fully out of the overlay.
///
/// Three pumps, because the dismissal is a chain and each pump moves one link:
/// the entrance animation finishing is what *starts* the four-second dismissal
/// timer, and the exit animation only plays on frames pumped after the timer
/// fires. One long pump fires no timer at all (the entrance is still short of
/// done), so the bar stays up — sitting exactly on the bottom bar's button, and
/// the next tap silently misses it.
Future<void> _drainSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Walks steps 1 and 2 with valid input, leaving the screen on step 3.
Future<void> _reachPasswordStep(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField), 'asha@example.com');
  await tester.tap(find.text('Send Reset Code'));
  await _settleRequest(tester);
  // The send confirmation sits over the bottom bar for four seconds; the Verify
  // Code tap underneath silently misses while it is up.
  await _drainSnackBar(tester);

  for (var index = 0; index < 4; index++) {
    await tester.enterText(find.byType(TextField).at(index), '1234'[index]);
    await tester.pump();
  }
  await tester.tap(find.text('Verify Code'));
  await _settleRequest(tester);
}

void main() {
  testWidgets(
    'an email is sent to the reset endpoint and advances to the code',
    (tester) async {
      final auth = await _pumpForgot(tester);

      await tester.enterText(find.byType(TextFormField), 'asha@example.com');
      await tester.tap(find.text('Send Reset Code'));
      await _settleRequest(tester);

      expect(auth.resetRequests, ['asha@example.com']);
      // The step advanced, which is the whole point: the endpoint answers 200
      // whether or not the address exists, so there is nothing to branch on.
      expect(find.text('Enter the Code'), findsOneWidget);
      expect(find.textContaining('asha@example.com'), findsOneWidget);

      await _drainSnackBar(tester);
    },
  );

  testWidgets('a malformed email is refused without a request', (tester) async {
    final auth = await _pumpForgot(tester);

    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.text('Send Reset Code'));
    await _settleRequest(tester);

    expect(find.textContaining('Enter a valid email address'), findsOneWidget);
    expect(auth.resetRequests, isEmpty, reason: 'nothing to send yet');
    // Still on step 1.
    expect(find.text('Forgot Password?'), findsOneWidget);

    await _drainSnackBar(tester);
  });

  testWidgets(
    'the code is exchanged for a token and advances to the password',
    (tester) async {
      final auth = await _pumpForgot(tester);
      await _reachPasswordStep(tester);

      expect(auth.resetVerifications, hasLength(1));
      expect(auth.resetVerifications.single.email, 'asha@example.com');
      expect(auth.resetVerifications.single.code, '1234');
      expect(find.text('Set a New Password'), findsOneWidget);

      await _drainSnackBar(tester);
    },
  );

  testWidgets('an incomplete code is refused without a request', (
    tester,
  ) async {
    final auth = await _pumpForgot(tester);

    await tester.enterText(find.byType(TextFormField), 'asha@example.com');
    await tester.tap(find.text('Send Reset Code'));
    await _settleRequest(tester);
    await _drainSnackBar(tester);

    // Two digits only.
    await tester.enterText(find.byType(TextField).at(0), '1');
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), '2');
    await tester.pump();

    await tester.tap(find.text('Verify Code'));
    await _settleRequest(tester);

    expect(find.text('Enter the 4-digit code.'), findsOneWidget);
    expect(auth.resetVerifications, isEmpty);
    expect(find.text('Set a New Password'), findsNothing);

    await _drainSnackBar(tester);
  });

  testWidgets('a rejected code shows what the server said and stays put', (
    tester,
  ) async {
    final auth = await _pumpForgot(tester);

    await tester.enterText(find.byType(TextFormField), 'asha@example.com');
    await tester.tap(find.text('Send Reset Code'));
    await _settleRequest(tester);
    await _drainSnackBar(tester);

    // The live shape, measured 2026-10-07: a *list* on this endpoint, unlike
    // signup's plain string. Both must render.
    auth.failure = const ApiException(
      kind: ApiErrorKind.badRequest,
      statusCode: 400,
      message: 'Invalid or expired OTP.',
    );

    for (var index = 0; index < 4; index++) {
      await tester.enterText(find.byType(TextField).at(index), '0000'[index]);
      await tester.pump();
    }
    await tester.tap(find.text('Verify Code'));
    await _settleRequest(tester);

    expect(find.text('Invalid or expired OTP.'), findsOneWidget);
    expect(find.text('Set a New Password'), findsNothing);

    await _drainSnackBar(tester);
  });

  testWidgets('a new password is sent with the token and lands on login', (
    tester,
  ) async {
    final navigated = <String>[];
    final auth = await _pumpForgot(tester, navigatedTo: navigated);
    await _reachPasswordStep(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'NewPass123');
    await tester.enterText(fields.at(1), 'NewPass123');
    await tester.tap(find.text('Reset Password'));
    await _settleRequest(tester);

    expect(auth.passwordResets, hasLength(1));
    final sent = auth.passwordResets.single;
    // The token from step 2 must be carried through — a null here would reach the
    // server as a dead token.
    expect(sent.resetToken, 'fake-reset-token');
    expect(sent.newPassword, 'NewPass123');
    expect(sent.confirmPassword, 'NewPass123');

    // The backend returns no tokens and signs every session out, so the flow ends
    // on the login screen rather than in the app.
    expect(navigated, ['/login-screen']);

    await _drainSnackBar(tester);
  });

  testWidgets('mismatched passwords are refused without a request', (
    tester,
  ) async {
    final auth = await _pumpForgot(tester);
    await _reachPasswordStep(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'NewPass123');
    await tester.enterText(fields.at(1), 'Different123');
    await tester.tap(find.text('Reset Password'));
    await _settleRequest(tester);

    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(auth.passwordResets, isEmpty);
    expect(find.text('Set a New Password'), findsOneWidget);

    await _drainSnackBar(tester);
  });

  testWidgets('a dead reset token sends the user back to the start', (
    tester,
  ) async {
    final auth = await _pumpForgot(tester);
    await _reachPasswordStep(tester);

    // The guide's shape for a used, expired or tampered-with token: a `detail`
    // with **no field errors**. That absence is what the screen branches on.
    auth.resetFailure = const ApiException(
      kind: ApiErrorKind.badRequest,
      statusCode: 400,
      message: 'Invalid or expired reset token.',
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'NewPass123');
    await tester.enterText(fields.at(1), 'NewPass123');
    await tester.tap(find.text('Reset Password'));
    await _settleRequest(tester);

    // Back to step 1, because the only recovery is a fresh code.
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Set a New Password'), findsNothing);
    expect(find.text('Invalid or expired reset token.'), findsOneWidget);

    await _drainSnackBar(tester);
  });

  testWidgets('password field errors stay on the step, on the field', (
    tester,
  ) async {
    final auth = await _pumpForgot(tester);
    await _reachPasswordStep(tester);

    // A password-rule failure, which *does* carry field errors — the opposite
    // signal from the dead-token case above.
    auth.resetFailure = const ApiException(
      kind: ApiErrorKind.badRequest,
      statusCode: 400,
      fieldErrors: {'new_password': 'This password is too common.'},
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'NewPass123');
    await tester.enterText(fields.at(1), 'NewPass123');
    await tester.tap(find.text('Reset Password'));
    await _settleRequest(tester);

    // The user can fix this in place, so they must not be thrown back to step 1.
    expect(find.text('Set a New Password'), findsOneWidget);
    expect(find.text('This password is too common.'), findsOneWidget);

    await _drainSnackBar(tester);
  });

  testWidgets('a code that comes back without a token does not advance', (
    tester,
  ) async {
    final auth = await _pumpForgot(tester);

    await tester.enterText(find.byType(TextFormField), 'asha@example.com');
    await tester.tap(find.text('Send Reset Code'));
    await _settleRequest(tester);
    await _drainSnackBar(tester);

    // A 2xx with no `reset_token`. Nothing can authorise step 3 without one, so
    // treating this as success would strand the user on a screen whose only
    // button fails.
    auth.resetToken = null;

    for (var index = 0; index < 4; index++) {
      await tester.enterText(find.byType(TextField).at(index), '1234'[index]);
      await tester.pump();
    }
    await tester.tap(find.text('Verify Code'));
    await _settleRequest(tester);

    expect(find.text('Set a New Password'), findsNothing);
    expect(find.text('Enter the Code'), findsOneWidget);

    await _drainSnackBar(tester);
  });

  testWidgets('resending is locked for the cooldown, then available', (
    tester,
  ) async {
    final auth = await _pumpForgot(tester);

    await tester.enterText(find.byType(TextFormField), 'asha@example.com');
    await tester.tap(find.text('Send Reset Code'));
    await _settleRequest(tester);

    // The label is `mm:ss`, so 60 seconds reads as `01:00`, not `00:60`.
    expect(find.textContaining('Send a new code in 01:00'), findsOneWidget);
    expect(find.text('Send a new code'), findsNothing);

    // One second at a time, so the tick is exercised the way it runs.
    for (var second = 0; second < 61; second++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(find.textContaining('Send a new code in'), findsNothing);
    expect(find.text('Send a new code'), findsOneWidget);

    await tester.tap(find.text('Send a new code'));
    await _settleRequest(tester);

    expect(auth.resetRequests, ['asha@example.com', 'asha@example.com']);

    await _drainSnackBar(tester);
  });

  testWidgets('the countdown is cancelled when the screen goes away', (
    tester,
  ) async {
    await _pumpForgot(tester);

    await tester.enterText(find.byType(TextFormField), 'asha@example.com');
    await tester.tap(find.text('Send Reset Code'));
    await _settleRequest(tester);

    // Replace the screen, which disposes the State while its periodic timer is
    // still running. Without the cancel in dispose, the next tick calls setState
    // on a dead State and this test fails on that exception.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(seconds: 90));

    expect(tester.takeException(), isNull);
  });
}
