import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/profile/data/user_profile.dart';
import 'package:skillsikka/features/signup/presentation/signup_verification_page.dart';

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
}
