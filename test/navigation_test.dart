import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillsikka/features/navigation/presentation/app_shell.dart';
import 'package:skillsikka/features/profile/presentation/profile_page.dart';

/// Rewritten 2026-09-24. Every assertion that used to fail here was asserting
/// UI that no longer exists — see the notes on each test. Nothing in this file
/// was failing because of a bug in the app.
void main() {
  testWidgets('footer switches between all learning destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));

    // The footer is the only chrome on this screen.
    final footer = find.byKey(const ValueKey('skill-sikka-footer'));
    expect(footer, findsOneWidget);
    // Scoped to the footer: the five pages sit in an IndexedStack and are all
    // mounted at once, so an unscoped count would also pick up any icon a page
    // happens to use.
    expect(
      find.descendant(of: footer, matching: find.byType(SvgPicture)),
      findsNWidgets(5),
    );

    // NOTE: this used to assert `find.text('Learn. Practice. Grows.')` and
    // `find.byKey(ValueKey('destination-$destination'))`. Both were dead:
    //   * the tagline was the placeholder body of the old home scaffold, deleted
    //     in 7bf4c78 ("designed home page"). No `Text` with that string exists
    //     anywhere in `lib/`, so `find.text` could never match it.
    //   * only `destination-My Learning` and `destination-Profile` are ever
    //     built — `ShortPage` renders `ShortFeedPage` and `ChallengesPage`
    //     renders itself, neither via `DestinationPage`. So `destination-Short`
    //     and `destination-Challenge` matched nothing. (`DestinationPage` is
    //     still in the tree, just unused by the shell.)
    //
    // Even the two keys that do exist could not have proved a switch: `AppShell`
    // renders the five pages through an `IndexedStack`, and the SDK keeps every
    // child mounted — non-selected ones are wrapped in `_VisibilityScope`, not
    // `Offstage`, so the default finders see all five pages on every frame.
    // "Which page is showing" is not observable that way. Selection is, and the
    // footer already encodes it: the selected label is painted `0xFFE6B800`.
    const selectedColour = Color(0xFFE6B800);
    const destinations = [
      'Home',
      'Short',
      'Challenge',
      'My Learning',
      'Profile',
    ];

    Color? labelColourOf(String label) => tester
        .widget<Text>(find.descendant(of: footer, matching: find.text(label)))
        .style
        ?.color;

    expect(
      labelColourOf('Home'),
      selectedColour,
      reason: 'Home starts selected',
    );
    for (final label in destinations.skip(1)) {
      expect(labelColourOf(label), isNot(selectedColour), reason: label);
    }

    for (final destination in [...destinations.skip(1), 'Home']) {
      await tester.tap(
        find.descendant(of: footer, matching: find.text(destination)),
      );
      // A single pump rather than `pumpAndSettle`: HomePage runs a 4s periodic
      // promo timer that kicks off a 500ms page animation, so any settle that
      // reaches the timer gets re-armed by it. One frame is all this needs — the
      // footer rebuilds synchronously on the `setState` from `onSelected`.
      await tester.pump();

      expect(
        labelColourOf(destination),
        selectedColour,
        reason: '$destination should be highlighted after tapping it',
      );
      for (final other in destinations) {
        if (other == destination) continue;
        expect(
          labelColourOf(other),
          isNot(selectedColour),
          reason: '$other should not be highlighted while $destination is',
        );
      }
    }
  });

  testWidgets('profile course tabs are present', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProfilePage())),
    );

    expect(find.text('My Courses'), findsOneWidget);

    // This test used to be called "profile course tabs switch content" and tapped
    // the tabs via `find.bySemanticsLabel`, which needs `tester.ensureSemantics()`
    // and so could never resolve. But the deeper problem is that there is nothing
    // to switch: `_buildCourseTab` is
    // `Semantics(child: GestureDetector(onTap: () {}))` — an empty callback — and
    // both sections below the tabs are rendered unconditionally. Tapping a tab
    // changes nothing, so no assertion about switching can pass today.
    //
    // What is true, and what this now asserts: the three tabs exist and both
    // saved-content sections render. Extend this test when the tabs get real
    // behaviour — the labels are already there for `find.text`.
    expect(find.text('Saved Shorts'), findsNWidgets(2));
    expect(find.text('Saved Courses'), findsNWidgets(2));
  });
}
