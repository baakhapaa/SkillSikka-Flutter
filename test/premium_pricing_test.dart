import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/features/courses/data/course_adapter.dart';
import 'package:skillsikka/features/courses/data/course_api.dart';
import 'package:skillsikka/features/premium_courses/presentation/premium_courses_page.dart';

import 'support/courses_test_scope.dart';
import 'support/premium_course_rows.dart';

/// The premium catalogue, read from `GET /courses/?course_type=premium`.
///
/// **The regression this guards:** the page was twelve hardcoded cards, so a
/// premium course created in the builder existed on the server and appeared
/// nowhere in the app. The cards keep their design; only their source changed.
///
/// **Premium is paid, always** (product rule, 2026-10-30): no card may print
/// "Free" — or "Paid", which is a word where a price belongs.
void main() {
  /// Roboto stands in for Manrope under `flutter test`, which wraps differently
  /// and overflows the premium cards. Pre-existing and unrelated to pricing.
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
        reason: 'unexpected exception on the premium catalogue: $text',
      );
    }
  }

  Future<FakeCourseApi> pump(
    WidgetTester tester, {
    List<CourseDetailData> courses = const [],
    bool fail = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeCourseApi(
      catalogue: CoursePage(count: courses.length, courses: courses),
      failure: fail
          ? const ApiException(kind: ApiErrorKind.network, message: 'offline')
          : null,
    );
    await tester.pumpWidget(
      coursesTestScope(
        api: api,
        child: const MaterialApp(home: PremiumCoursesPage()),
      ),
    );
    await tester.pump();
    drainUnrelatedOverflows(tester);
    return api;
  }

  testWidgets('a course added in the builder appears in the premium section', (
    tester,
  ) async {
    // The whole point: neither of these was in the app before it was fetched.
    final api = await pump(
      tester,
      courses: [
        premiumCourse(id: 60, title: 'Premium DevOps'),
        premiumCourse(
          id: 61,
          title: 'Premium Design Systems',
          category: 'Design',
        ),
      ],
    );

    expect(api.calls.single.courseType, 'premium');
    expect(find.text('Premium DevOps'), findsOneWidget);
    expect(find.text('Premium Design Systems'), findsOneWidget);
  });

  testWidgets('the cards keep their price and rating slots', (tester) async {
    // Four, because the shelf splits: the carousel takes three and the list
    // takes the rest — and the two cards print different slots.
    await pump(
      tester,
      courses: [
        premiumCourse(),
        premiumCourse(id: 61, title: 'Second'),
        premiumCourse(id: 62, title: 'Third'),
        premiumCourse(id: 63, title: 'Fourth'),
      ],
    );

    // `price` from the wire, in the card's own format.
    expect(find.text('Rs. 2,499'), findsWidgets);
    expect(find.text('4.7'), findsWidgets);
    // The carousel's meta row keeps the design's short student form.
    expect(find.text('4,195 students'), findsWidgets);
    // The list card's slot keeps the design's `(214)` shape, with the real count.
    expect(find.text('(12)'), findsOneWidget);
  });

  test('a premium row takes its category from premium_category_name', () {
    // The chips print 'Design' too, so a widget finder cannot tell the card's
    // category line from the chip — this is the invariant, checked where it
    // lives. `skill_category_name` is null on a premium row, so a mapper that
    // read only that field left the line blank.
    expect(CourseMapper.summary(premiumCourseRow()).category, 'Design');

    final skill = CourseMapper.summary({
      ...premiumCourseRow(),
      'course_type': 'skill',
      'premium_category': null,
      'premium_category_name': null,
      'skill_category': 3,
      'skill_category_name': 'Coding',
    });
    expect(skill.category, 'Coding');
  });

  testWidgets('no premium card is free', (tester) async {
    await pump(tester, courses: [premiumCourse()]);

    final shown = [
      for (final widget in tester.widgetList<Text>(find.byType(Text)))
        if (widget.data != null) widget.data!,
    ];
    expect(
      shown.where((t) => t == 'Free' || t == 'Paid'),
      isEmpty,
      reason: 'a premium card must never carry a pricing status word',
    );
  });

  testWidgets('an empty catalogue says so instead of showing demo cards', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('No premium courses yet.'), findsOneWidget);
    // The old hardcoded twelve are gone, not merely hidden.
    expect(
      find.text('Illustrator CC: The Complete Problem Solving Guide'),
      findsNothing,
    );
  });

  testWidgets('a failed fetch offers a retry, not an empty shelf', (
    tester,
  ) async {
    await pump(tester, fail: true);

    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('No premium courses yet.'), findsNothing);
  });

  testWidgets('the category chips filter what is shown', (tester) async {
    await pump(
      tester,
      courses: [
        premiumCourse(id: 60, title: 'Premium DevOps', category: 'Design'),
        premiumCourse(id: 61, title: 'Premium Physics', category: 'Physics'),
      ],
    );

    expect(find.text('Premium Physics'), findsOneWidget);

    await tester.tap(find.text('Design'));
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);

    expect(find.text('Premium DevOps'), findsOneWidget);
    expect(find.text('Premium Physics'), findsNothing);
  });
}
