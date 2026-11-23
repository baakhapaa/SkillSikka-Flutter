import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/features/auth/data/auth_repository.dart';
import 'package:skillsikka/features/bootcamp/data/bootcamp_api.dart';
import 'package:skillsikka/features/bootcamp/presentation/bootcamp_page.dart';
import 'package:skillsikka/features/courses/data/course_api.dart';
import 'package:skillsikka/features/quiz/data/quiz_api.dart';
import 'package:skillsikka/features/learning/presentation/course_player_page.dart';
import 'package:skillsikka/features/learning/data/learning_api.dart';
import 'package:skillsikka/features/learning/data/my_learning.dart';
import 'package:skillsikka/features/learning/presentation/my_learning_page.dart';
import 'package:skillsikka/features/payment/data/payment_api.dart';

import 'support/bootcamp_fixtures.dart';
import 'support/courses_test_scope.dart';
import 'support/learning_test_scope.dart';
import 'support/payment_test_scope.dart';

/// A row shaped like `/my-learning/` — captured from the running backend on
/// 2026-10-27, field names included.
Map<String, dynamic> course([int id = 16]) => {
  'id': id,
  'title': 'Grade 9: Matter and Chemical Reactions',
  'description': '',
  'course_type': 'academic',
  'subject': 2,
  'subject_name': 'Science',
  'grade': 9,
  'grade_name': 'Grade 9',
  'skill_category': null,
  'skill_category_name': null,
  'is_paid': false,
  'price': null,
  'thumbnail_url': '',
  'is_published': true,
  'average_rating': null,
  'review_count': 0,
  'students_enrolled': 1,
  'lessons_count': 9,
  'total_duration_seconds': 3645,
  'is_enrolled': true,
  'instructor': 4,
  'instructor_name': 'Test Instructor',
  'learning_outcomes': <String>[],
  'requirements': <String>[],
  'updated_at': '2026-10-27T06:04:13.639481Z',
};

Map<String, dynamic> learningRow({
  int courseId = 16,
  double percentage = 33.33,
  int completed = 3,
  int total = 9,
  int? nextLessonId = 83,
  int? nextLessonNumber = 4,
  bool isCompleted = false,
  String? completedAt,
}) => {
  'enrollment_id': 2,
  'enrollment_status': isCompleted ? 'completed' : 'active',
  'enrolled_at': '2026-10-01T05:00:00Z',
  'completed_at': completedAt,
  'course': course(courseId),
  'progress_percentage': percentage,
  'completed_lessons': completed,
  'total_lessons': total,
  'is_completed': isCompleted,
  'next_lesson': nextLessonId == null
      ? null
      : {
          'id': nextLessonId,
          'title': 'Guided Practice: Activity 1',
          'content_type': 'video',
          'order': nextLessonNumber ?? 1,
          'lesson_number': nextLessonNumber ?? 1,
        },
  'resume_url': 'http://127.0.0.1:8000/api/v1/lessons/83/',
  'last_learning_activity': '2026-10-25T18:04:00Z',
};

Map<String, dynamic> payload({
  Map<String, dynamic>? hero,
  List<Map<String, dynamic>> courses = const [],
  List<Map<String, dynamic>> completed = const [],
  List<Map<String, dynamic>> pending = const [],
  Map<String, dynamic>? stats,
  List<Map<String, dynamic>> certificates = const [],
}) => {
  'continue_learning': hero,
  'courses': courses,
  'completed_courses': completed,
  'pending_payment': pending,
  'stats':
      stats ?? {'courses_completed': 0, 'day_streak': 0, 'hours_learned': null},
  'certificates': certificates,
};

/// A `pending_payment` row, as the endpoint now returns it: the same card plus
/// the payment to re-ask about, and nothing to resume.
Map<String, dynamic> pendingRow({
  int courseId = 21,
  int enrollmentId = 9,
  int? paymentId = 44,
  String? paymentStatus = 'initiated',
}) => {
  'enrollment_id': enrollmentId,
  'enrollment_status': 'pending_payment',
  'enrolled_at': '2026-10-30T06:00:00Z',
  'completed_at': null,
  'course': course(courseId),
  'progress_percentage': 0.0,
  'completed_lessons': 0,
  'total_lessons': 9,
  'is_completed': false,
  'next_lesson': null,
  'resume_url': null,
  'last_learning_activity': null,
  'latest_payment_id': paymentId,
  'latest_payment_status': paymentStatus,
};

void main() {
  group('MyLearning.tryParse', () {
    test('reads the hero, the stats and an empty account', () {
      final learning = MyLearning.tryParse(
        payload(
          hero: learningRow(),
          stats: {
            'courses_completed': 1,
            'day_streak': 4,
            'hours_learned': null,
          },
        ),
      );

      expect(learning, isNotNull);
      expect(learning!.continueLearning?.course.title, contains('Matter'));
      expect(learning.continueLearning?.percentage, 33.33);
      expect(learning.stats.coursesCompleted, 1);
      expect(learning.stats.dayStreak, 4);
      // The endpoint always sends null; the screen must not invent a number.
      expect(learning.stats.hoursLearned, isNull);
      expect(learning.isEmpty, isFalse);
    });

    test('the hero is not repeated in the list', () {
      // The server pulls the resumable course out of `courses` and returns it
      // separately, so `all` has to add it back exactly once.
      final learning = MyLearning.tryParse(
        payload(hero: learningRow(), courses: [learningRow(courseId: 17)]),
      );

      expect(learning!.courses, hasLength(1));
      expect(learning.all, hasLength(2));
      expect(learning.all.first.course.id, 16);
    });

    test('an empty payload is an empty dashboard, not a null', () {
      final learning = MyLearning.tryParse(payload());

      expect(learning, isNotNull);
      expect(learning!.continueLearning, isNull);
      expect(learning.isEmpty, isTrue);
    });

    test('a body that is not an object is rejected', () {
      expect(MyLearning.tryParse(const []), isNull);
      expect(MyLearning.tryParse(null), isNull);
    });

    group('pending_payment', () {
      test('is parsed into its own list, never into the learning ones', () {
        // The whole point of the section: an unpaid course is visible without
        // being counted as something the student is learning.
        final learning = MyLearning.tryParse(
          payload(hero: learningRow(), pending: [pendingRow()]),
        );

        expect(learning!.pending, hasLength(1));
        expect(learning.pending.single.course.id, 21);
        expect(learning.pending.single.paymentId, 44);
        expect(learning.pending.single.paymentStatus, 'initiated');
        expect(learning.all, hasLength(1), reason: 'hero only');
        expect(learning.courses, isEmpty);
        expect(learning.completed, isEmpty);
      });

      test('a student whose only course is unpaid is not "empty"', () {
        // The empty state says "Enrol in a course" — showing it beside a pending
        // card would contradict the card.
        final learning = MyLearning.tryParse(payload(pending: [pendingRow()]));

        expect(learning!.pending, hasLength(1));
        expect(learning.isEmpty, isFalse);
      });

      test(
        'only a failed, cancelled or absent payment offers checkout again',
        () {
          PendingEnrolment parse(String? status, int? id) =>
              PendingEnrolment.tryParse(
                pendingRow(paymentId: id, paymentStatus: status),
              )!;

          expect(parse('failed', 44).needsNewPayment, isTrue);
          expect(parse('cancelled', 44).needsNewPayment, isTrue);
          expect(parse(null, null).needsNewPayment, isTrue);
          // The gateway may already hold the money in both of these, so starting a
          // second payment is how a student pays twice.
          expect(parse('initiated', 44).needsNewPayment, isFalse);
          expect(parse('successful', 44).needsNewPayment, isFalse);
        },
      );

      test('the status line never claims more than the server said', () {
        expect(
          PendingEnrolment.tryParse(
            pendingRow(paymentStatus: 'initiated'),
          )!.statusLabel,
          contains('Confirming'),
        );
        expect(
          PendingEnrolment.tryParse(
            pendingRow(paymentId: null, paymentStatus: null),
          )!.statusLabel,
          contains('did not complete'),
        );
      });

      test('a row without a course is dropped rather than rendered blank', () {
        final learning = MyLearning.tryParse(
          payload(
            pending: [
              pendingRow(),
              {'enrollment_id': 3},
            ],
          ),
        );

        expect(learning!.pending, hasLength(1));
      });
    });

    test('certificates take their title from the right field', () {
      final learning = MyLearning.tryParse(
        payload(
          certificates: [
            {
              'id': 1,
              'certificate_type': 'course',
              'course': 15,
              'course_title': 'Drawing from Observation',
              'grade': null,
              'grade_name': null,
              'issued_at': '2026-10-27T06:30:00Z',
            },
            {
              'id': 2,
              'certificate_type': 'grade',
              'course': null,
              'course_title': null,
              'grade': 9,
              'grade_name': 'Grade 9',
              'issued_at': '2026-10-27T06:30:00Z',
            },
          ],
        ),
      );

      expect(learning!.certificates, hasLength(2));
      expect(learning.certificates.first.title, 'Drawing from Observation');
      // A grade certificate has no course title at all.
      expect(learning.certificates.last.title, 'Grade 9');
    });
  });

  group('LearningCourse', () {
    LearningCourse parse(Map<String, dynamic> row) =>
        MyLearning.tryParse(payload(hero: row))!.continueLearning!;

    test('position comes from the server, not from arithmetic', () {
      final learning = parse(learningRow());

      expect(learning.positionLabel, 'Lesson 4 of 9');
      expect(learning.percentLabel, '33%');
      expect(learning.progress, closeTo(0.3333, 0.001));
    });

    test('a finished course has no next lesson and says so', () {
      final learning = parse(
        learningRow(
          percentage: 100,
          completed: 9,
          nextLessonId: null,
          nextLessonNumber: null,
          isCompleted: true,
          completedAt: '2026-10-27T07:14:54Z',
        ),
      );

      expect(learning.positionLabel, 'All 9 lessons');
      expect(learning.resumeIndex, 0);
      expect(learning.isCompleted, isTrue);
    });

    test('resumeIndex finds the next lesson among the modules', () {
      // The course payload here carries no lessons (a list row has none), so
      // there is nothing to find and the player opens at the top — it re-seeds
      // from the server on open anyway.
      expect(parse(learningRow()).resumeIndex, 0);
    });
  });

  group('MyLearningPage', () {
    Future<void> pump(WidgetTester tester, MyLearning learning) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        learningTestScope(
          learning: learning,
          child: const MaterialApp(home: MyLearningPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the hero shows the real progress and resume point', (
      tester,
    ) async {
      await pump(tester, MyLearning.tryParse(payload(hero: learningRow()))!);

      expect(find.text('Continue Learning'), findsOneWidget);
      expect(
        find.textContaining('Matter and Chemical Reactions'),
        findsWidgets,
      );
      expect(find.text('33% Complete'), findsOneWidget);
      expect(find.text('Lesson 4 of 9'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
    });

    testWidgets('an empty dashboard says so instead of showing a fake card', (
      tester,
    ) async {
      await pump(tester, const MyLearning());

      expect(find.text('Nothing in progress yet'), findsOneWidget);
      expect(find.text('No certificates yet'), findsOneWidget);
      // Completed Courses is omitted entirely rather than rendered empty.
      expect(find.text('Completed Courses'), findsNothing);
    });

    testWidgets('hours learned prints a dash, never a made-up number', (
      tester,
    ) async {
      await pump(tester, MyLearning.tryParse(payload(hero: learningRow()))!);

      expect(find.text('HOURS LEARNED'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('an unpaid course has its own section and its own action', (
      tester,
    ) async {
      // Before 2026-10-30 this row did not exist at all: the endpoint filtered
      // `pending_payment` out, so a student whose app died during checkout saw
      // nothing for a course the gateway may already have charged them for.
      await pump(
        tester,
        MyLearning.tryParse(
          payload(hero: learningRow(), pending: [pendingRow()]),
        )!,
      );

      expect(find.text('PAYMENT PENDING'), findsOneWidget);
      expect(find.text('Check payment'), findsOneWidget);
      // Never a Resume: an unpaid course has no lesson to open. The hero above
      // it still has one.
      expect(find.text('Resume'), findsOneWidget);
      expect(find.textContaining('Confirming your payment'), findsOneWidget);
    });

    testWidgets('a payment the gateway refused offers checkout again', (
      tester,
    ) async {
      await pump(
        tester,
        MyLearning.tryParse(
          payload(
            pending: [pendingRow(paymentStatus: 'failed', paymentId: 44)],
          ),
        )!,
      );

      expect(find.text('Complete payment'), findsOneWidget);
      expect(find.text('Check payment'), findsNothing);
      expect(find.textContaining('Nothing was charged'), findsOneWidget);
    });

    testWidgets('"Check payment" re-asks the gateway instead of paying again', (
      tester,
    ) async {
      // **The double-charge guard.** An `initiated` payment may already have
      // taken the student's money; starting a second one is how they pay twice.
      // So the button must call `GET /payments/{id}/` — which is what refreshes
      // the row — and never `initiate`.
      final api = FakePaymentApi()
        ..statusResults = [payment(id: 44, status: 'successful')];
      final learning = MyLearning.tryParse(
        payload(pending: [pendingRow(paymentId: 44)]),
      )!;

      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myLearningProvider.overrideWith((ref) async => learning),
            paymentApiProvider.overrideWithValue(api),
          ],
          // A Scaffold, because the card reports its answer in a SnackBar and
          // `ScaffoldMessenger` has nothing to present to without one. In the
          // app this page lives inside `AppShell`, which owns the Scaffold.
          child: const MaterialApp(home: Scaffold(body: MyLearningPage())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check payment'));
      await tester.pumpAndSettle();

      expect(api.statusCalls, [44]);
      expect(
        api.initiateCalls,
        isEmpty,
        reason: 'a second payment must never be created from this card',
      );
    });

    testWidgets('a completed course lists with its completion month', (
      tester,
    ) async {
      await pump(
        tester,
        MyLearning.tryParse(
          payload(
            completed: [
              learningRow(
                courseId: 15,
                percentage: 100,
                completed: 9,
                nextLessonId: null,
                nextLessonNumber: null,
                isCompleted: true,
                completedAt: '2026-10-27T07:14:54Z',
              ),
            ],
            stats: {
              'courses_completed': 1,
              'day_streak': 0,
              'hours_learned': null,
            },
          ),
        )!,
      );

      expect(find.text('Completed Courses'), findsOneWidget);
      expect(find.textContaining('Completed Oct 2026'), findsOneWidget);
      expect(find.text('Certificate Issued'), findsOneWidget);
    });
  });

  group('myLearningFailureCopy', () {
    // The three answers `/my-learning/` actually gives, measured against the
    // dev backend on 2026-10-28. Only one of them is a connectivity problem, and
    // the screen used to say "Check your connection" for all three.
    test(
      'an expired token says the session ended, not that you are offline',
      () {
        final copy = myLearningFailureCopy(
          const ApiException(
            kind: ApiErrorKind.unauthorized,
            statusCode: 401,
            // DRF's wording for an expired access token — developer prose that
            // must not be shown.
            message: 'Given token not valid for any token type',
            code: ApiErrorCode.tokenNotValid,
          ),
        );

        expect(copy.title, 'Your session has ended.');
        expect(copy.body, 'Sign in again to see your courses.');
        expect(copy.signInAgain, isTrue);
        expect(copy.actionLabel, 'Sign in again');
      },
    );

    test(
      'an unverified account quotes the server, which is the useful part',
      () {
        final copy = myLearningFailureCopy(
          const ApiException(
            kind: ApiErrorKind.unauthorized,
            statusCode: 401,
            message: 'Verify your email before signing in.',
          ),
        );

        expect(copy.title, 'Your session has ended.');
        expect(copy.body, 'Verify your email before signing in.');
        expect(copy.signInAgain, isTrue);
        expect(copy.actionLabel, 'Sign in again');
      },
    );

    test('an instructor is told the screen is not for them', () {
      // 403 with `Only active students can access My Learning.` — retrying this
      // can never succeed, so the button must not offer it.
      final copy = myLearningFailureCopy(
        const ApiException(
          kind: ApiErrorKind.forbidden,
          statusCode: 403,
          message: 'Only active students can access My Learning.',
        ),
      );

      expect(copy.title, 'My Learning is not available for this account.');
      expect(copy.body, 'Only active students can access My Learning.');
      expect(copy.signInAgain, isTrue);
      // The session is valid — signing the same account in again would land
      // straight back here, so the label names the action that can help.
      expect(copy.actionLabel, 'Switch account');
    });

    test('a real connection failure still offers a retry', () {
      final copy = myLearningFailureCopy(
        const ApiException(kind: ApiErrorKind.network),
      );

      expect(copy.title, 'We could not load your courses.');
      expect(copy.body, contains('Check your connection'));
      expect(copy.signInAgain, isFalse);
      expect(copy.actionLabel, 'Try again');
    });

    test('a non-API throw is not reported as a network fault', () {
      // The provider is not obliged to throw an `ApiException`, and a parse
      // failure must not be dressed up as "you are offline".
      final copy = myLearningFailureCopy(const FormatException('bad json'));

      expect(copy.title, 'We could not load your courses.');
      expect(copy.body, 'Something went wrong. Please try again.');
      expect(copy.signInAgain, isFalse);
      expect(copy.actionLabel, 'Try again');
    });
  });

  group('the failure screen', () {
    Future<void> pumpFailure(
      WidgetTester tester,
      Object error, {
      FakeAuthRepository? auth,
    }) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        learningTestScope(
          failure: error,
          auth: auth,
          child: const MaterialApp(home: MyLearningPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'a 403 offers switching account, not a retry that cannot work',
      (tester) async {
        await pumpFailure(
          tester,
          const ApiException(
            kind: ApiErrorKind.forbidden,
            statusCode: 403,
            message: 'Only active students can access My Learning.',
          ),
        );

        expect(
          find.text('My Learning is not available for this account.'),
          findsOneWidget,
        );
        // Not "Sign in again": the session is valid, so that would loop.
        expect(find.text('Switch account'), findsOneWidget);
        expect(find.text('Sign in again'), findsNothing);
        // The old screen showed this for a 403 and reproduced the failure.
        expect(find.text('Try again'), findsNothing);
      },
    );

    testWidgets('an offline failure still offers a retry', (tester) async {
      await pumpFailure(tester, const ApiException(kind: ApiErrorKind.network));

      expect(find.text('We could not load your courses.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Sign in again'), findsNothing);
    });

    testWidgets('"Sign in again" ends the session instead of re-requesting', (
      tester,
    ) async {
      // A button that only looked like a logout would leave the dead session in
      // place and land the user back on this screen.
      final auth = FakeAuthRepository();
      await pumpFailure(
        tester,
        const ApiException(kind: ApiErrorKind.unauthorized, statusCode: 401),
        auth: auth,
      );

      await tester.tap(find.text('Sign in again'));
      await tester.pumpAndSettle();

      expect(auth.logOuts, 1);
    });
  });

  group('opening a course', () {
    /// A bootcamp row, exactly as `/my-learning/` returns one: the course is a
    /// `bootcamp` and the card carries its progress like any other.
    MyLearning bootcamp() {
      final row = learningRow(courseId: 78, completed: 2, total: 20);
      row['course'] = {
        ...course(78),
        'title': 'ICT & AI BOOTCAMP at Sundarbazar',
        'course_type': 'bootcamp',
        'lessons_count': 20,
      };
      return MyLearning.tryParse(payload(hero: row))!;
    }

    testWidgets('a bootcamp opens the bootcamp player, not the course player', (
      tester,
    ) async {
      // The regression: `continueCourse` pushed `CoursePlayerPage` for every
      // course. A bootcamp summary carries no modules, so that screen opened
      // with **no lessons at all** — a blank player.
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final api = FakeBootcampApi(value: camp());
      await tester.pumpWidget(
        learningTestScope(
          learning: bootcamp(),
          child: ProviderScope(
            overrides: [
              bootcampApiProvider.overrideWithValue(api),
              courseApiProvider.overrideWithValue(FakeCourseApi()),
              quizApiProvider.overrideWithValue(EmptyQuizApi()),
            ],
            child: const MaterialApp(home: MyLearningPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();

      expect(find.byType(IctBootcampPage), findsOneWidget);
      expect(find.byType(CoursePlayerPage), findsNothing);
      // It opened *this* camp, not some other id.
      expect(api.calls, [78]);
    });
  });
}
