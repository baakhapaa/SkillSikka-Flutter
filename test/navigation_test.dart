import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillsikka/features/navigation/presentation/app_shell.dart';
import 'package:skillsikka/features/profile/data/profile_role.dart';
import 'package:skillsikka/features/profile/data/user_profile.dart';
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

  testWidgets('profile course tabs switch content', (
    WidgetTester tester,
  ) async {
    // The My Courses grid and its dashed "Add New Course" tile are the
    // **instructor** profile, so the role has to be set for them to render at
    // all — a student's grid has a course card in that slot instead, because a
    // student cannot author a course (see `_buildCourseGrid`).
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(userProfileProvider.notifier)
        .setRole(ProfileRole.instructor);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ProfilePage())),
      ),
    );
    await tester.pump();

    // Tab 0 is the default, matching the design: the My Courses grid, with the
    // dashed "Add New Course" tile in the first slot.
    expect(find.text('My Courses'), findsOneWidget);
    expect(find.text('Add New Course'), findsOneWidget);
    expect(find.text('Saved Shorts'), findsNothing);
    expect(find.text('Saved Courses'), findsNothing);

    // The tabs are icon-only now — the design has no labels — so they are
    // addressed by glyph. `find.bySemanticsLabel` would need
    // `tester.ensureSemantics()`, which is why the old version of this test
    // could never resolve; the labels are still attached for a11y.
    //
    // Each section renders once now instead of twice: previously the tab bar
    // also drew the names as text and both panels were always mounted, so
    // 'Saved Shorts' matched twice. One panel at a time is the point of the
    // change.
    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await tester.pump();
    expect(find.text('Saved Shorts'), findsOneWidget);
    expect(find.text('My Courses'), findsNothing);

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();
    expect(find.text('Saved Courses'), findsOneWidget);
    expect(find.text('Saved Shorts'), findsNothing);

    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump();
    expect(find.text('My Courses'), findsOneWidget);
    expect(find.text('Add New Course'), findsOneWidget);
  });

  testWidgets('a student profile is not the instructor one', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(userProfileProvider.notifier).setRole(ProfileRole.student);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ProfilePage())),
      ),
    );
    await tester.pump();

    // A student cannot author a course, so the tile must not be offered — and
    // the slot holds a course card instead, so the grid keeps its shape.
    expect(find.text('Add New Course'), findsNothing);
    expect(find.text('Design Systems Fundamentals'), findsOneWidget);
    expect(find.text('My Courses'), findsOneWidget);

    // The header counts learner things, not teacher things.
    expect(find.text('Badges'), findsOneWidget);
    expect(find.text('Challenge'), findsOneWidget);
    expect(find.text('Students'), findsNothing);
    expect(find.text('Rating'), findsNothing);
  });

  testWidgets('a role that arrives after the first build still switches the '
      'profile', (WidgetTester tester) async {
    // Regression. The page read the store with `.read` and never subscribed, so
    // it worked out its role once, at first build, and kept that answer forever.
    // That is right when the role is already known — signup writes it before the
    // tab is ever built — and wrong after a sign-in, where the role lands a
    // moment later. The page then computed `effectiveRole` from a null role, got
    // the `student` fallback, and never rebuilt: an instructor saw the student
    // profile for the rest of the session.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ProfilePage())),
      ),
    );
    await tester.pump();

    // First build with no role yet: the fallback draws the student layout.
    expect(find.text('Add New Course'), findsNothing);
    expect(find.text('Badges'), findsOneWidget);
    expect(find.text('Students'), findsNothing);

    // The role arrives, exactly as it does when a sign-in response is adopted.
    container
        .read(userProfileProvider.notifier)
        .setRole(ProfileRole.instructor);
    await tester.pump();

    // Without a subscription nothing above would have rebuilt and every
    // assertion below would fail — which is the bug this test exists for.
    expect(find.text('Add New Course'), findsOneWidget);
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Rating'), findsOneWidget);
    expect(find.text('Badges'), findsNothing);
    expect(find.text('Challenge'), findsNothing);
  });
}
