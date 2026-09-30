import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/app.dart';
import 'package:skillsikka/core/network/session.dart';
import 'package:skillsikka/core/network/session_store.dart';
import 'package:skillsikka/features/auth/data/auth_repository.dart';

import 'support/home_page_font_harness.dart';

/// A session saved on a previous launch, and what the app does with it.
///
/// **Its own file, with one test in it, deliberately.** This pumps the real app, so
/// it builds `HomePage` — and a file containing a *second* `HomePage`-pumping test
/// is the shape that has hung this suite before; see the harness's note on
/// `pendingFontFutures`, where a stranded future makes the next test wait forever
/// and the run looks dead rather than failing. One test per file makes that
/// impossible instead of merely unlikely.
///
/// The harness is installed rather than working around the fonts, because this test
/// asserts on layout the same way the home-page suites do.
void main() {
  installHomePageFontHarness();

  testWidgets('opens straight into the app when a session was saved', (
    WidgetTester tester,
  ) async {
    // The payoff of persisting, and the one thing no other test covers: a
    // returning user never sees the welcome screen.
    //
    // `/splash` is the router's initial location and a *public* route, so a
    // signed-out user is left sitting on it. A session arriving from disk makes the
    // guard's `refreshListenable` fire, and the guard then moves the user to `/`
    // on its own. Nothing in this test navigates — that is the point.
    const stored = Session(access: 'access-abc', refresh: 'refresh-abc');
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith(
          (ref) =>
              FakeAuthRepository(session: ref.read(sessionProvider.notifier)),
        ),
        sessionStoreProvider.overrideWithValue(
          FakeSessionStore(stored: stored),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SkillSikkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    // `AppShell` mounts `ProfilePage`, which has a pre-existing RenderFlex
    // overflow unrelated to this test. Draining it keeps a known, older defect
    // from being reported as a failure here.
    drainUnrelatedOverflows(tester);

    expect(
      container.read(sessionProvider),
      stored,
      reason: 'the stored session must be restored into the app',
    );
    expect(
      find.byKey(const ValueKey('skill-sikka-footer')),
      findsOneWidget,
      reason: 'a restored session must land the user inside the app',
    );
    expect(
      find.text('Get Started'),
      findsNothing,
      reason: 'a returning user must not be left on the welcome screen',
    );
  });
}
