import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/premium_courses/presentation/premium_course_details_page.dart';

import 'support/courses_test_scope.dart';
import 'support/premium_course_rows.dart';

/// The premium course-detail screen.
///
/// **It could not be pumped before 2026-10-30.** The screen carried a bundled
/// trailer, and `CourseDetailView` builds a `VideoPlayerController` for one —
/// whose `initialize()` fails with a `MissingPluginException` under
/// `flutter test`, asynchronously and with no handler, failing the test
/// outright. Removing the trailer (premium now matches a skill course, which
/// shows its cover) is what makes these tests possible at all.
void main() {
  /// Roboto stands in for Manrope here, which wraps differently and overflows
  /// the sections this test does not own. Pre-existing.
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
        reason: 'unexpected exception on the premium detail: $text',
      );
    }
  }

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    FakeCourseApi? api,
  }) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      coursesTestScope(
        api: api ?? FakeCourseApi(),
        child: MaterialApp(home: child),
      ),
    );
    await tester.pump();
    drainUnrelatedOverflows(tester);
  }

  testWidgets('the demo screen renders without a video trailer', (
    tester,
  ) async {
    await pump(tester, const PremiumCourseDetailsPage());

    // The bundled course is still what an id-less route shows.
    expect(
      find.textContaining('DevSecOps & DevOps with Jenkins'),
      findsWidgets,
    );
    // The trailer is gone: nothing is loading a video, so there is no spinner
    // waiting on a plugin that does not exist here.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('it opens the course it was given, not the demo', (tester) async {
    final api = FakeCourseApi()
      ..detailValue = premiumCourse(id: 60, title: 'Premium DevOps');

    await pump(tester, const PremiumCourseDetailsPage(courseId: 60), api: api);
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);

    expect(find.textContaining('Premium DevOps'), findsWidgets);
    expect(
      find.textContaining('DevSecOps & DevOps with Jenkins'),
      findsNothing,
    );
  });

  testWidgets('a failed fetch offers a retry instead of a blank screen', (
    tester,
  ) async {
    // `FakeCourseApi` throws when no detail is scripted, which is the same shape
    // as a real 404 or a dropped connection.
    await pump(
      tester,
      const PremiumCourseDetailsPage(courseId: 60),
      api: FakeCourseApi(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);
  });
}
