import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/features/courses/data/course_adapter.dart';
import 'package:skillsikka/features/courses/data/course_api.dart';
import 'package:skillsikka/features/courses/presentation/course_details_page.dart';
import 'package:skillsikka/features/learning/presentation/course_player_page.dart';
import 'package:skillsikka/features/profile/data/profile_completeness.dart';

import 'support/courses_test_scope.dart';
import 'support/home_page_font_harness.dart';

/// The enrolment flow — the one place a course can refuse to open.
///
/// `startCourse` is the only path into the player, so these tests drive it the
/// way a user does: tap `Enroll Now` on the detail page and see whether the
/// player appears.
void main() {
  installHomePageFontHarness();

  /// A course shaped like `GET /courses/99/`, with one text lesson so the player
  /// never constructs a `video_player` controller.
  CourseDetailData apiCourse({String type = 'skill', bool paid = false}) =>
      CourseMapper.detail(
        course: {
          'id': 99,
          'title': type == 'academic' ? 'Newton law' : 'Drawing from Observation',
          'description': 'Learn by doing.',
          'course_type': type,
          'skill_category': type == 'skill' ? 13 : null,
          'skill_category_name': type == 'skill' ? 'Drawing' : null,
          'grade_name': type == 'academic' ? 'Grade 10' : null,
          'subject_name': type == 'academic' ? 'Science' : null,
          'is_paid': paid,
          'price': paid ? '1299.00' : null,
          'thumbnail_url': '',
          'is_published': true,
          'average_rating': null,
          'review_count': 0,
          'students_enrolled': 0,
          'lessons_count': 1,
          'total_duration_seconds': 300,
          'instructor': 4,
          'instructor_name': 'Test Instructor',
          'learning_outcomes': <String>[],
          'requirements': <String>[],
          'updated_at': '2026-10-27T06:04:13.639481Z',
        },
        lessons: [
          {
            'id': 1,
            'title': 'Reading',
            'content_type': 'text',
            'content_url': '',
            'content_text': 'Body',
            'section': 'Foundations',
            'duration_seconds': 300,
            'is_preview': false,
            'order': 1,
          },
        ],
      );

  Future<void> pumpDetail(
    WidgetTester tester,
    FakeCourseApi api, {
    String type = 'skill',
    bool paid = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseApiProvider.overrideWithValue(api),
          // The profile gate is not what these tests are about; a complete
          // profile is the state a real user reaches before enrolling.
          profileCompletenessProvider.overrideWithValue(
            const ProfileCompleteness(
              fields: <ProfileField>[],
              missing: <ProfileField>[],
            ),
          ),
        ],
        child: MaterialApp(
          home: CourseDetailPage(course: apiCourse(type: type, paid: paid)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapEnrol(WidgetTester tester, {String label = 'Enroll Now'}) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('a successful enrolment opens the player', (tester) async {
    final api = FakeCourseApi()
      ..enrollResult = const CourseEnrollment(
        id: 1,
        courseId: 99,
        status: 'active',
      );

    await pumpDetail(tester, api);
    await tapEnrol(tester);

    expect(api.enrolCalls, [99]);
    expect(find.byType(CoursePlayerPage), findsOneWidget);
  });

  testWidgets('an unpaid course enrols but does not open the player', (
    tester,
  ) async {
    // `pending_payment` grants no lesson access. Opening the player here would
    // show a screen full of locks the user has no way to clear.
    final api = FakeCourseApi()
      ..enrollResult = const CourseEnrollment(
        id: 2,
        courseId: 99,
        status: 'pending_payment',
      );

    await pumpDetail(tester, api);
    await tapEnrol(tester);

    expect(api.enrolCalls, [99]);
    expect(find.byType(CoursePlayerPage), findsNothing);
    expect(
      find.text('This course needs payment before you can start it.'),
      findsOneWidget,
    );
  });

  testWidgets('an academic course opens without enrolling at all', (
    tester,
  ) async {
    // `POST /courses/{id}/enroll/` answers 400 COURSE_NOT_ENROLLABLE for every
    // non-skill course: a school course is opened by grade, and no enrolment
    // row is involved. So the CTA must not call it — the old flow called it for
    // every course with an id and put "Only skill development courses require
    // enrollment." over the detail page.
    final api = FakeCourseApi();

    await pumpDetail(tester, api, type: 'academic');
    expect(find.text('Enroll Now'), findsNothing);

    await tapEnrol(tester, label: 'Start Learning');

    expect(api.enrolCalls, isEmpty);
    expect(find.byType(CoursePlayerPage), findsOneWidget);
  });

  testWidgets('already enrolled is success, not an error', (tester) async {
    // The user's intent is "take me into the course"; the server saying they are
    // already in is the outcome they asked for. The lookup is consulted anyway —
    // the status is what separates "in" from "started paying and stopped" — and
    // this free course's row is missing, which is the old behaviour, not a
    // reason to lock someone out of something free.
    final api = FakeCourseApi()
      ..enrollFailure = const ApiException(
        kind: ApiErrorKind.badRequest,
        statusCode: 400,
        code: 'ALREADY_ENROLLED',
        message: 'You are already enrolled in this course.',
      );

    await pumpDetail(tester, api);
    await tapEnrol(tester);

    expect(find.byType(CoursePlayerPage), findsOneWidget);
  });

  group('a paid course cannot be entered without paying', () {
    ApiException alreadyEnrolled() => const ApiException(
      kind: ApiErrorKind.badRequest,
      statusCode: 400,
      code: 'ALREADY_ENROLLED',
      message: 'You are already enrolled in this course.',
    );

    testWidgets('ALREADY_ENROLLED on an unpaid row keeps the player shut', (
      tester,
    ) async {
      // The bug this covers: `ALREADY_ENROLLED` was read as "you are in", so the
      // *second* tap on Start opened the player for a course the student had
      // never paid for, and every lesson inside then answered
      // `403 NOT_ENROLLED`. The first tap was guarded; the second was not.
      final api = FakeCourseApi()
        ..enrollFailure = alreadyEnrolled()
        ..existingEnrollment = const CourseEnrollment(
          id: 2,
          courseId: 99,
          status: 'pending_payment',
        );

      await pumpDetail(tester, api, paid: true);
      await tapEnrol(tester);

      expect(api.enrollmentLookups, [99]);
      expect(find.byType(CoursePlayerPage), findsNothing);
      expect(
        find.text(
          'This course costs Rs. 1,299 and needs payment before you can start it.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('ALREADY_ENROLLED on a paid-for row opens the player', (
      tester,
    ) async {
      // The other half: refusing every paid course would lock out the students
      // who did pay. Only the status may decide.
      final api = FakeCourseApi()
        ..enrollFailure = alreadyEnrolled()
        ..existingEnrollment = const CourseEnrollment(
          id: 3,
          courseId: 99,
          status: 'active',
        );

      await pumpDetail(tester, api, paid: true);
      await tapEnrol(tester);

      expect(find.byType(CoursePlayerPage), findsOneWidget);
    });

    testWidgets('an unconfirmable enrolment on a paid course refuses', (
      tester,
    ) async {
      // The server says "already enrolled", then says there is no row. On a paid
      // course that contradiction must not be resolved in the student's favour.
      final api = FakeCourseApi()..enrollFailure = alreadyEnrolled();

      await pumpDetail(tester, api, paid: true);
      await tapEnrol(tester);

      expect(find.byType(CoursePlayerPage), findsNothing);
      expect(
        find.text('We could not confirm your enrolment. Try again.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('a real refusal keeps the user on the detail page', (
    tester,
  ) async {
    final api = FakeCourseApi()
      ..enrollFailure = const ApiException(
        kind: ApiErrorKind.badRequest,
        statusCode: 400,
        code: 'COURSE_NOT_PUBLISHED',
        message: 'This course is not available for enrollment.',
      );

    await pumpDetail(tester, api);
    await tapEnrol(tester);

    expect(find.byType(CoursePlayerPage), findsNothing);
    expect(
      find.text('This course is not available for enrollment.'),
      findsOneWidget,
    );
  });
}
