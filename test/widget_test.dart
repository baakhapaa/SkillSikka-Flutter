// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillsikka/app.dart';

void main() {
  testWidgets('renders splash and opens login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SkillSikkaApp()));

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Already have an account? Log In'), findsNothing);
    expect(find.byType(Image), findsNWidgets(2));

    final loginRedirect = find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains('Log In'),
    );
    await tester.ensureVisible(loginRedirect);
    await tester.tap(loginRedirect);
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back!'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Get Started'), findsOneWidget);

    final loginRedirectAgain = find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains('Log In'),
    );
    await tester.ensureVisible(loginRedirectAgain);
    await tester.tap(loginRedirectAgain);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Learn. Practice. Grow.'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back!'), findsOneWidget);
  });
}
