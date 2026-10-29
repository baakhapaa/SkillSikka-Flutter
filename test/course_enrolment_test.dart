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
import 'support/payment_test_scope.dart';

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
          'title': type == 'academic'
              ? 'Newton law'
              : 'Drawing from Observation',
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
    FakePaymentApi? payments,
    List<Uri>? opened,
  }) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final payment = paymentOverrides(api: payments, opened: opened);
    addTearDown(payment.links.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseApiProvider.overrideWithValue(api),
          ...payment.overrides,
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
          home: CourseDetailPage(
            course: apiCourse(type: type, paid: paid),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps the bottom bar's call to action.
  ///
  /// The label is not a constant any more: a paid course says `Buy Rs. 1,299`
  /// until an enrolment exists and `Continue payment` once one is
  /// `pending_payment`, and an enrolled course says `Continue Learning`. A test
  /// that hardcoded `Enroll Now` would pass only on the free, unenrolled path.
  Future<void> tapCta(WidgetTester tester, String label) async {
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
    await tapCta(tester, 'Enroll Now');

    expect(api.enrolCalls, [99]);
    expect(find.byType(CoursePlayerPage), findsOneWidget);
  });

  testWidgets('an unpaid enrolment opens checkout, not the player', (
    tester,
  ) async {
    // `pending_payment` grants no lesson access, so the player must stay shut —
    // but the tap is no longer a dead end. It opens the sheet that can turn the
    // row into an `active` one.
    final api = FakeCourseApi()
      ..enrollResult = const CourseEnrollment(
        id: 2,
        courseId: 99,
        status: 'pending_payment',
      );

    await pumpDetail(tester, api, paid: true);
    await tapCta(tester, 'Buy Rs. 1,299');

    expect(api.enrolCalls, [99]);
    expect(find.byType(CoursePlayerPage), findsNothing);
    expect(find.text('Complete your purchase'), findsOneWidget);
    expect(find.text('Pay Rs. 1,299'), findsOneWidget);
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

    await tapCta(tester, 'Start Learning');

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
    await tapCta(tester, 'Enroll Now');

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
      //
      // The bar now reads `Continue payment` from the server's own row, and the
      // tap opens checkout rather than a dead-end toast.
      final api = FakeCourseApi()
        ..enrollFailure = alreadyEnrolled()
        ..existingEnrollment = const CourseEnrollment(
          id: 2,
          courseId: 99,
          status: 'pending_payment',
        );

      await pumpDetail(tester, api, paid: true);
      await tapCta(tester, 'Continue payment');

      expect(api.enrollmentLookups, contains(99));
      expect(find.byType(CoursePlayerPage), findsNothing);
      expect(find.text('Complete your purchase'), findsOneWidget);
    });

    testWidgets('a paid-for row opens the player straight away', (
      tester,
    ) async {
      // The other half: refusing every paid course would lock out the students
      // who did pay. Only the status may decide — and an `active` row means the
      // bar offers `Continue Learning` without asking the server to enrol again.
      final api = FakeCourseApi()
        ..enrollFailure = alreadyEnrolled()
        ..existingEnrollment = const CourseEnrollment(
          id: 3,
          courseId: 99,
          status: 'active',
        );

      await pumpDetail(tester, api, paid: true);
      await tapCta(tester, 'Continue Learning');

      expect(api.enrolCalls, isEmpty);
      expect(find.byType(CoursePlayerPage), findsOneWidget);
    });

    testWidgets('an unconfirmable enrolment on a paid course refuses', (
      tester,
    ) async {
      // The server says "already enrolled", then says there is no row. On a paid
      // course that contradiction must not be resolved in the student's favour.
      final api = FakeCourseApi()..enrollFailure = alreadyEnrolled();

      await pumpDetail(tester, api, paid: true);
      await tapCta(tester, 'Buy Rs. 1,299');

      expect(find.byType(CoursePlayerPage), findsNothing);
      expect(
        find.text('We could not confirm your enrolment. Try again.'),
        findsOneWidget,
      );
    });

    testWidgets('paying in the sheet opens the player', (tester) async {
      // The whole point of the flow: the app never decides that a payment
      // succeeded. It starts one, sends the browser to the gateway, and waits
      // for the server to say `successful` — which is also the moment the
      // enrolment is `active`, so the player can open.
      final api = FakeCourseApi()
        ..enrollResult = const CourseEnrollment(
          id: 2,
          courseId: 99,
          status: 'pending_payment',
        );
      final payments = FakePaymentApi()
        ..statusResults = [
          payment(status: 'initiated'),
          payment(status: 'successful'),
        ];
      final opened = <Uri>[];

      await pumpDetail(
        tester,
        api,
        paid: true,
        payments: payments,
        opened: opened,
      );
      await tapCta(tester, 'Buy Rs. 1,299');

      await tester.tap(find.text('Pay Rs. 1,299'));
      await tester.pump();
      await tester.pump();

      expect(payments.initiateCalls, [99]);
      expect(opened.single.toString(), contains('esewa'));
      expect(find.text('Waiting for eSewa to confirm…'), findsOneWidget);

      // The poll leaves the gateway alone for six seconds, then asks every two.
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(find.text('Payment successful'), findsNothing);

      // Second answer: confirmed. The sheet closes itself and the player opens.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('Payment successful'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
      expect(find.byType(CoursePlayerPage), findsOneWidget);
    });

    testWidgets('a cancelled payment leaves the user on the detail page', (
      tester,
    ) async {
      // The other half of the gate: `failed`/`cancelled` must never open the
      // player, and must not be reported as a success that later 403s.
      final api = FakeCourseApi()
        ..enrollResult = const CourseEnrollment(
          id: 2,
          courseId: 99,
          status: 'pending_payment',
        );
      final payments = FakePaymentApi()
        ..statusResults = [payment(status: 'cancelled')];

      await pumpDetail(tester, api, paid: true, payments: payments);
      await tapCta(tester, 'Buy Rs. 1,299');

      await tester.tap(find.text('Pay Rs. 1,299'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      expect(
        find.text('The payment was cancelled. Nothing has been charged.'),
        findsOneWidget,
      );
      expect(find.byType(CoursePlayerPage), findsNothing);
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
    await tapCta(tester, 'Enroll Now');

    expect(find.byType(CoursePlayerPage), findsNothing);
    expect(
      find.text('This course is not available for enrollment.'),
      findsOneWidget,
    );
  });
}
