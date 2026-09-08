import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillsikka/features/navigation/presentation/app_shell.dart';
import 'package:skillsikka/features/profile/presentation/profile_page.dart';

void main() {
  testWidgets('footer switches between all learning destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));

    expect(find.text('Learn. Practice. Grows.'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNWidgets(5));

    for (final destination in [
      'Short',
      'Challenge',
      'My Learning',
      'Profile',
      'Home',
    ]) {
      await tester.tap(find.text(destination).last);
      await tester.pump();
      if (destination == 'Home') {
        expect(find.text('Learn. Practice. Grows.'), findsOneWidget);
      } else {
        expect(
          find.byKey(ValueKey('destination-$destination')),
          findsOneWidget,
        );
      }
    }
  });

  testWidgets('profile course tabs switch content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProfilePage())),
    );

    expect(find.text('My Courses'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Saved Shorts'));
    await tester.pump();
    expect(find.text('Saved Shorts'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Saved Courses'));
    await tester.pump();
    expect(find.text('Saved Courses'), findsOneWidget);
  });
}
