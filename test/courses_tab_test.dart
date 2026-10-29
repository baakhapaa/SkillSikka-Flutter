import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/core/widgets/course_grid_card.dart';
import 'package:skillsikka/features/courses/data/course_adapter.dart';
import 'package:skillsikka/features/courses/data/course_api.dart';
import 'package:skillsikka/features/courses/presentation/course_details_page.dart';
import 'package:skillsikka/features/courses/presentation/courses.dart';

import 'support/courses_test_scope.dart';

/// A row shaped like `GET /courses/` — captured field names, not invented ones.
Map<String, dynamic> _row({
  int id = 15,
  String title = 'Drawing from Observation',
  int? grade = 7,
  String gradeName = 'Grade 7',
}) => {
  'id': id,
  'title': title,
  'description': 'Learn by doing.',
  'course_type': 'academic',
  'subject': 1,
  'subject_name': 'Mathematics',
  'grade': grade,
  'grade_name': gradeName,
  'skill_category': null,
  'skill_category_name': null,
  'is_paid': false,
  'price': null,
  'thumbnail_url': '',
  'is_published': true,
  'average_rating': 4.5,
  'review_count': 8,
  'students_enrolled': 120,
  'lessons_count': 9,
  'total_duration_seconds': 3600,
  'is_enrolled': false,
  'instructor': 4,
  'instructor_name': 'Test Instructor',
  'learning_outcomes': <String>[],
  'requirements': <String>[],
};

CoursePage _page(List<Map<String, dynamic>> rows) => CoursePage(
  count: rows.length,
  courses: [for (final row in rows) CourseMapper.summary(row)],
);

void main() {
  Widget app(FakeCourseApi api, {List<dynamic>? grades}) => coursesTestScope(
    api: api,
    grades: (grades ?? fakeGrades()).cast(),
    child: const MaterialApp(home: AllCoursesPage()),
  );

  testWidgets('renders the cards the API returned', (tester) async {
    final api = FakeCourseApi(
      catalogue: _page([
        _row(title: 'Fractions in Everyday Life'),
        _row(id: 16, title: 'Algebra Foundations'),
      ]),
    );

    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();

    expect(find.text('Fractions in Everyday Life'), findsOneWidget);
    expect(find.text('Algebra Foundations'), findsOneWidget);
    // The tab is the academic catalogue, so the request says so.
    expect(api.calls.single.courseType, 'academic');
  });

  testWidgets('an empty catalogue is an empty state, not an error', (
    tester,
  ) async {
    await tester.pumpWidget(app(FakeCourseApi()));
    await tester.pumpAndSettle();

    expect(find.text('No courses for this class yet.'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a class chip filters by grade id, never by its label', (
    tester,
  ) async {
    final api = FakeCourseApi(catalogue: _page([_row()]));
    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();

    // `All` sends no grade at all — it is the absence of a filter.
    expect(api.calls.single.grade, isNull);

    await tester.tap(find.text('Class 7'));
    await tester.pumpAndSettle();

    // 7, not 'Class 7'. An unknown query value is silently ignored by the
    // server, so the label would return the whole catalogue and look filtered.
    expect(api.calls.last.grade, 7);
  });

  testWidgets('a class with no grade behind it says so instead of showing all', (
    tester,
  ) async {
    final api = FakeCourseApi(catalogue: _page([_row()]));
    await tester.pumpWidget(app(api, grades: <dynamic>[]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Class 8'));
    await tester.pumpAndSettle();

    // No grade 8 in the list, so the chip cannot be honoured. Showing the
    // unfiltered catalogue under a `Class 8` heading would be a lie.
    expect(find.text('Class 8 has no courses yet.'), findsOneWidget);
    expect(api.calls, hasLength(1));
  });

  testWidgets('a failed load is an error state with a retry', (tester) async {
    final api = FakeCourseApi(
      failure: const ApiException(
        kind: ApiErrorKind.network,
        message: 'Cannot reach the server.',
      ),
    );

    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();

    expect(find.text('Cannot reach the server.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    // The retry re-requests rather than just re-rendering the error.
    expect(api.calls, hasLength(2));
  });

  testWidgets('a card carries the subject tag and rating, like the home rail', (
    tester,
  ) async {
    final api = FakeCourseApi(catalogue: _page([_row()]));
    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();

    // The home rail's card prints the subject in a tag and the rating beside a
    // star, above the title. The Courses grid used to print the title first and
    // leave the rating alone under it, which is what made the two screens look
    // like different apps. Both now draw `CourseGridCard`.
    expect(find.byType(CourseGridCard), findsOneWidget);
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
  });

  testWidgets('a course with no reviews shows no star, not a bare one', (
    tester,
  ) async {
    final row = _row()..['average_rating'] = null;
    final api = FakeCourseApi(catalogue: _page([row]));
    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();

    // `average_rating` is null until a course has a review. A star with an
    // empty label beside it reads as a rendering bug.
    expect(find.byType(CourseGridCard), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CourseGridCard),
        matching: find.byIcon(Icons.star),
      ),
      findsNothing,
    );
  });

  testWidgets('the grid holds at 360pt with two-line titles', (tester) async {
    // 360 is the narrowest phone the app targets, and the card is a fixed-height
    // image plus two text rows inside a fixed-aspect cell — the one place a
    // long title can overflow. A RenderFlex overflow throws here, so passing is
    // the assertion.
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final api = FakeCourseApi(
      catalogue: _page([
        _row(title: 'Grade 10: Reading and Writing with Confidence'),
        _row(id: 16, title: 'Matter and Chemical Reactions in Daily Life'),
        _row(id: 17, title: 'Short one'),
      ]),
    );

    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();

    expect(find.byType(CourseGridCard), findsNWidgets(3));

    // Uniform cells: the third card's top must line up with nothing in
    // particular, but the first two — same row — must share a height, which is
    // what the old hand-built rows could not promise.
    final cards = tester.widgetList(find.byType(CourseGridCard)).length;
    expect(cards, 3);
    final first = tester.getRect(find.byType(CourseGridCard).at(0));
    final second = tester.getRect(find.byType(CourseGridCard).at(1));
    expect(first.top, second.top);
    expect(first.height, second.height);
  });

  testWidgets('tapping a card opens the detail screen', (tester) async {
    final api = FakeCourseApi(catalogue: _page([_row()]));
    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Drawing from Observation'));
    await tester.pumpAndSettle();

    expect(find.byType(CourseDetailPage), findsOneWidget);
  });
}
