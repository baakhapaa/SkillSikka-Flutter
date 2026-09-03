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
  testWidgets('renders the login screen route', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SkillSikkaApp()));

    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Learn. Practice. Grow.'), findsOneWidget);
  });
}
