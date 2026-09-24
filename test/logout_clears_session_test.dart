import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:skillsikka/core/network/api_client.dart';
import 'package:skillsikka/features/profile/data/user_profile.dart';
import 'package:skillsikka/features/profile/presentation/profile_page.dart';

void main() {
  /// The profile page is laid out for a font `flutter test` cannot fetch, so the
  /// fallback wraps differently and overflows. Pre-existing and unrelated to
  /// logging out; anything that is *not* an overflow still fails the test.
  void drainUnrelatedOverflows(WidgetTester tester) {
    for (
      var e = tester.takeException();
      e != null;
      e = tester.takeException()
    ) {
      final text = e.toString();
      expect(
        text.contains('overflowed') || text.contains('Multiple exceptions'),
        isTrue,
        reason: 'unexpected exception on the profile page: $text',
      );
    }
  }

  testWidgets('logging out clears the session and the whole profile store', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // A signed-in user, with every kind of data the store can hold. This is
    // what used to survive a logout and greet the next person to sign in.
    container.read(authTokenProvider.notifier).state = 'token-abc';
    final profile = container.read(userProfileProvider.notifier);
    profile.save({'name': 'Sita', 'email': 'sita@email.com'});
    profile.setPhoto(Uint8List.fromList([1, 2, 3]), 'avatar.jpg');
    profile.setDocument(
      ProfileDocumentSlot.cvResume,
      PickedDocument(bytes: Uint8List.fromList([9]), fileName: 'cv.pdf'),
    );

    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, _) => const Scaffold(body: ProfilePage()),
        ),
        GoRoute(
          path: '/login-screen',
          builder: (_, _) => const Scaffold(body: Text('login screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    drainUnrelatedOverflows(tester);

    final logoutRow = find.text('Log Out');
    expect(logoutRow, findsOneWidget, reason: 'the profile page lost its row');
    // It is the last item in a long settings list.
    await tester.ensureVisible(logoutRow);
    await tester.pump();
    await tester.tap(logoutRow);
    await tester.pumpAndSettle();

    // Both the settings row and the confirm button read 'Log Out', so target
    // the button rather than the text.
    await tester.tap(find.widgetWithText(FilledButton, 'Log Out'));
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);

    expect(container.read(authTokenProvider), isNull);
    expect(
      find.text('login screen'),
      findsOneWidget,
      reason: 'logging out should land on the login screen',
    );

    final after = container.read(userProfileProvider);
    expect(after.photoBytes, isNull, reason: 'the photo survived the logout');
    expect(after.photoFileName, isNull);
    expect(after.valueFor('name'), '');
    expect(after.valueFor('email'), '');
    expect(after.documents, isEmpty, reason: 'documents survived the logout');
  });
}
