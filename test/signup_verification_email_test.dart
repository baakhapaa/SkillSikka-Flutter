import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/features/auth/data/auth_repository.dart';
import 'package:skillsikka/features/profile/data/user_profile.dart';
import 'package:skillsikka/features/signup/presentation/signup_verification_page.dart';

/// Pumps the OTP screen with the network faked out, so the assertions are about
/// what the screen sends rather than about a transport error.
Future<FakeAuthRepository> _pumpVerify(
  WidgetTester tester, {
  String email = 'skill@email.com',
  List<String>? navigatedTo,
}) async {
  final router = GoRouter(
    initialLocation: '/signup/verify',
    routes: [
      GoRoute(
        path: '/signup/verify',
        builder: (_, _) => const SignupVerificationPage(),
      ),
      GoRoute(
        path: '/signup/interests',
        builder: (_, _) {
          navigatedTo?.add('/signup/interests');
          return const Scaffold(body: Text('interests step'));
        },
      ),
    ],
  );

  final auth = FakeAuthRepository();
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(auth)],
  );
  addTearDown(container.dispose);
  if (email.isNotEmpty) {
    container.read(userProfileProvider.notifier).save({'email': email});
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

/// Types [code] one digit at a time, the way a person does.
Future<void> _enterCode(WidgetTester tester, String code) async {
  final boxes = find.byType(TextField);
  expect(boxes, findsNWidgets(4), reason: 'the OTP boxes are gone');
  for (var index = 0; index < code.length; index++) {
    await tester.enterText(boxes.at(index), code[index]);
    await tester.pump();
  }
}

void main() {
  testWidgets('the code is sent to the address signup captured', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(userProfileProvider.notifier).save({
      'email': 'skill@email.com',
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SignupVerificationPage()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('skill@email.com'), findsOneWidget);
    expect(find.textContaining('sarah@email.com'), findsNothing);
  });

  testWidgets('falls back to the placeholder when signup captured nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SignupVerificationPage())),
    );
    await tester.pump();

    expect(find.textContaining('sarah@email.com'), findsOneWidget);
  });

  testWidgets('a full code is verified against the address signup captured', (
    tester,
  ) async {
    final navigated = <String>[];
    final auth = await _pumpVerify(tester, navigatedTo: navigated);

    await _enterCode(tester, '1234');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(auth.verifications, hasLength(1));
    expect(auth.verifications.single.email, 'skill@email.com');
    expect(auth.verifications.single.code, '1234');
    expect(navigated, ['/signup/interests']);
  });

  testWidgets('an incomplete code is refused without a request', (
    tester,
  ) async {
    final navigated = <String>[];
    final auth = await _pumpVerify(tester, navigatedTo: navigated);

    await _enterCode(tester, '12');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    // It used to push on any input at all, including none.
    expect(find.text('Enter the 4-digit code.'), findsOneWidget);
    expect(auth.verifications, isEmpty, reason: 'nothing to verify yet');
    expect(navigated, isEmpty);

    // Let the snack bar expire so no timer outlives the test.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a wrong code shows what the server said and stays put', (
    tester,
  ) async {
    final navigated = <String>[];
    final auth = await _pumpVerify(tester, navigatedTo: navigated);
    auth.failure = const ApiException(
      kind: ApiErrorKind.badRequest,
      statusCode: 400,
      // The field the server names is the OTP input itself. Worth pinning: the
      // parser used to drop a field error called `code` entirely, and this
      // screen has no other way to tell the user the code was wrong.
      fieldErrors: {'code': 'That code is not correct.'},
    );

    await _enterCode(tester, '0000');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(find.text('That code is not correct.'), findsOneWidget);
    expect(navigated, isEmpty, reason: 'a rejected code must not advance');

    await tester.pump(const Duration(seconds: 5));
  });
}
