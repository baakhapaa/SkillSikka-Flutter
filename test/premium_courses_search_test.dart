import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/premium_courses/presentation/premium_courses_page.dart';
import 'package:skillsikka/features/search/presentation/search_page.dart';

void main() {
  /// Drains layout exceptions raised by parts of these pages this test does not
  /// own. `flutter test` cannot fetch Manrope, so text is laid out with the
  /// Roboto stand-in, which wraps differently and overflows the course cards and
  /// the search page's rows — pre-existing, and unrelated to the search button.
  ///
  /// When several fire in one pump the framework collapses them into an
  /// aggregate message instead of the individual overflows, so both shapes are
  /// tolerated here. Anything else still fails the test.
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
        reason: 'unexpected exception on the premium courses page: $text',
      );
    }
  }

  testWidgets('the search button in the premium courses top bar opens search', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: PremiumCoursesPage()));
    await tester.pump();
    drainUnrelatedOverflows(tester);

    // The top bar's search affordance — the only search icon on the page.
    final searchButton = find.byIcon(Icons.search);
    expect(searchButton, findsOneWidget);

    await tester.tap(searchButton);
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);

    expect(
      find.byType(SearchPage),
      findsOneWidget,
      reason: 'tapping search should open the search page',
    );

    // The field takes focus on open (the page requests it in initState), which
    // is what makes the keyboard come up and the Cancel action appear.
    expect(
      find.text('Cancel'),
      findsOneWidget,
      reason: 'the search field should be focused as soon as the page opens',
    );
  });
}
