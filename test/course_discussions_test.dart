import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/network/api_client.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/features/courses/data/course.dart';
import 'package:skillsikka/features/courses/data/course_adapter.dart';
import 'package:skillsikka/features/courses/data/course_api.dart';
import 'package:skillsikka/features/courses/data/course_discussions_api.dart';
import 'package:skillsikka/features/learning/data/enrollment.dart';
import 'package:skillsikka/features/learning/presentation/course_player_page.dart';
import 'package:skillsikka/features/quiz/data/quiz_api.dart';

import 'support/courses_test_scope.dart';
import 'support/home_page_font_harness.dart';

/// A stand-in for the discussion endpoints.
///
/// Same shape as [FakeCourseApi]: a subclass with a client that is never used,
/// because every method that would reach the network is overridden. `Dio()`
/// with no adapter answers 400 rather than throwing, so a forgotten override
/// fails a test instead of hanging one.
class FakeDiscussionsApi extends CourseDiscussionsApi {
  FakeDiscussionsApi({this.page, this.listFailure, this.postFailure})
    : super(ApiClient(Dio()));

  CourseThreadPage? page;
  ApiException? listFailure;
  ApiException? postFailure;

  final List<int> listCalls = <int>[];
  final List<({String body, int? parentId})> posts = [];
  final List<({int id, bool liked})> likes = [];
  final List<int> removed = <int>[];

  @override
  Future<CourseThreadPage> list(
    int courseId, {
    String ordering = '-created_at',
    int page = 1,
    int pageSize = 20,
  }) async {
    listCalls.add(courseId);
    if (listFailure case final failure?) throw failure;
    return this.page ??
        const CourseThreadPage(count: 0, threads: <CourseThread>[]);
  }

  @override
  Future<CourseThread> post(
    int courseId, {
    required String body,
    int? parentId,
  }) async {
    posts.add((body: body, parentId: parentId));
    if (postFailure case final failure?) throw failure;
    return CourseThread(
      id: 900 + posts.length,
      body: body,
      authorName: 'You',
      when: 'just now',
      parentId: parentId,
      isMine: true,
    );
  }

  @override
  Future<CourseLike> setLiked(
    int courseId,
    int threadId, {
    required bool liked,
  }) async {
    likes.add((id: threadId, liked: liked));
    return CourseLike(
      threadId: threadId,
      isLiked: liked,
      likesCount: liked ? 8 : 7,
    );
  }

  @override
  Future<void> remove(int courseId, int threadId) async {
    removed.add(threadId);
  }
}

/// An API-shaped course: `id` is set, so the player treats it as a server row.
CourseDetailData apiCourse({List<Map<String, dynamic>>? lessons}) {
  final rows =
      lessons ??
      <Map<String, dynamic>>[
        {
          'id': 501,
          'title': 'Reading light and shadow',
          'content_type': 'video',
          // Empty on purpose: a URL would make `_syncVideo` construct a
          // `video_player` controller, which has no platform implementation
          // under `flutter test`. The Q&A tab does not need a playable lesson.
          'content_url': '',
          'duration_seconds': 300,
          'order': 1,
          'section': 'Foundations',
          'is_preview': false,
        },
      ];
  return CourseMapper.detail(
    course: {
      'id': 99,
      'title': 'Drawing from Observation',
      'description': 'Learn by doing.',
      'course_type': 'skill',
      'skill_category': 13,
      'skill_category_name': 'Drawing',
      'is_paid': false,
      'price': null,
      'thumbnail_url': '',
      'is_published': true,
      'average_rating': null,
      'review_count': 0,
      'students_enrolled': 0,
      'lessons_count': rows.length,
      'total_duration_seconds': 300,
      'instructor': 4,
      'instructor_name': 'Test Instructor',
      'learning_outcomes': <String>[],
      'requirements': <String>[],
      'updated_at': '2026-10-27T06:04:13.639481Z',
    },
    lessons: rows,
  );
}

CourseThread thread({
  int id = 1,
  String body = 'How do I get the proportions right?',
  String author = 'Sita',
  String? role = 'Student',
  int likes = 4,
  bool isMine = false,
  bool isLiked = false,
  int replies = 0,
  List<CourseThread> replyRows = const <CourseThread>[],
}) => CourseThread(
  id: id,
  body: body,
  authorName: author,
  authorRole: role,
  when: '3h ago',
  likesCount: likes,
  isMine: isMine,
  isLiked: isLiked,
  repliesCount: replies,
  replies: replyRows,
);

void main() {
  installHomePageFontHarness();

  group('parsing', () {
    test('reads the serializer shape', () {
      final parsed = CourseThread.tryParse({
        'id': 12,
        'course': 99,
        'parent': null,
        'body': 'Which pencil?',
        'author': {
          'id': 3,
          'name': 'Sita',
          'profile_photo_url': null,
          'role_label': 'Grade 6 Student',
        },
        'likes_count': 5,
        'is_liked': true,
        'is_mine': true,
        'is_hidden': false,
        'created_at': '2026-10-29T08:00:00Z',
        'replies_count': 1,
        'replies': [
          {
            'id': 13,
            'parent': 12,
            'body': 'A 2B.',
            'author': {'id': 4, 'name': 'Ram', 'role_label': 'Instructor'},
            'likes_count': 0,
            'is_liked': false,
            'is_mine': false,
            'created_at': '2026-10-29T09:00:00Z',
          },
        ],
      })!;

      expect(parsed.id, 12);
      expect(parsed.parentId, isNull);
      expect(parsed.authorName, 'Sita');
      expect(parsed.authorRole, 'Grade 6 Student');
      expect(parsed.likesCount, 5);
      expect(parsed.isLiked, isTrue);
      expect(parsed.isMine, isTrue);
      expect(parsed.isStaff, isFalse);
      expect(parsed.repliesCount, 1);
      expect(parsed.replies.single.body, 'A 2B.');
      expect(parsed.replies.single.isStaff, isTrue);
    });

    test('a row without an id is not a thread', () {
      expect(CourseThread.tryParse({'body': 'no id'}), isNull);
      expect(CourseThread.tryParse(null), isNull);
      expect(CourseThread.tryParse('nope'), isNull);
    });

    test('the list is a paginated envelope', () {
      final page = CourseThreadPage.tryParse({
        'count': 34,
        'next': 'https://api.example.com/courses/99/discussions/?page=2',
        'previous': null,
        'results': [
          {
            'id': 1,
            'body': 'One',
            'author': {'name': 'A', 'role_label': 'Student'},
            'created_at': '2026-10-29T08:00:00Z',
          },
        ],
      })!;

      expect(page.count, 34);
      expect(page.next, endsWith('page=2'));
      expect(page.threads.single.body, 'One');
    });

    test('a bare array is not an envelope', () {
      // `/lessons/` and `/reviews/` answer bare arrays; this endpoint does not,
      // and a parser that accepted both would hide the difference.
      expect(CourseThreadPage.tryParse(<Object>[]), isNull);
    });

    test('relative time is finer than a day', () {
      final now = DateTime.utc(2026, 10, 29, 12);
      String at(Duration ago) =>
          relativeWhen(now.subtract(ago).toIso8601String(), now: now);

      expect(at(const Duration(seconds: 20)), 'just now');
      expect(at(const Duration(minutes: 12)), '12m ago');
      expect(at(const Duration(hours: 3)), '3h ago');
      expect(at(const Duration(days: 2)), '2d ago');
      expect(at(const Duration(days: 10)), '1w ago');
      expect(at(const Duration(days: 70)), '2mo ago');
      expect(at(const Duration(days: 800)), '2y ago');
      expect(relativeWhen(null), '');
      expect(relativeWhen('not a date'), '');
    });
  });

  group('the Q&A tab', () {
    Future<void> pump(
      WidgetTester tester, {
      required CourseDetailData course,
      required FakeDiscussionsApi discussions,
    }) async {
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          courseApiProvider.overrideWithValue(FakeCourseApi()),
          courseDiscussionsApiProvider.overrideWithValue(discussions),
          quizApiProvider.overrideWithValue(EmptyQuizApi()),
        ],
      );
      addTearDown(container.dispose);
      container.read(enrolledCoursesProvider.notifier).record(course);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: CoursePlayerPage(course: course)),
        ),
      );
      await tester.pump();
      drainUnrelatedOverflows(tester);
    }

    testWidgets('opens without fetching, and fetches when tapped', (
      tester,
    ) async {
      final discussions = FakeDiscussionsApi();
      await pump(tester, course: apiCourse(), discussions: discussions);

      expect(
        discussions.listCalls,
        isEmpty,
        reason: 'the player fetched the thread before anyone opened Q&A',
      );

      await tester.tap(find.text('Q&A'));
      await tester.pump();
      await tester.pump();
      drainUnrelatedOverflows(tester);

      expect(discussions.listCalls, [99]);
    });

    testWidgets('renders the loaded thread with its author and count', (
      tester,
    ) async {
      final discussions = FakeDiscussionsApi(
        page: CourseThreadPage(
          count: 1,
          threads: [thread(body: 'Which pencil should I buy?')],
        ),
      );
      await pump(tester, course: apiCourse(), discussions: discussions);

      await tester.tap(find.text('Q&A'));
      await tester.pump();
      await tester.pump();
      drainUnrelatedOverflows(tester);

      expect(find.text('Which pencil should I buy?'), findsOneWidget);
      expect(find.text('Sita'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('a failed first load offers a retry, not an empty thread', (
      tester,
    ) async {
      final discussions = FakeDiscussionsApi(
        listFailure: const ApiException(
          kind: ApiErrorKind.network,
          message: 'No connection.',
        ),
      );
      await pump(tester, course: apiCourse(), discussions: discussions);

      await tester.tap(find.text('Q&A'));
      await tester.pump();
      await tester.pump();
      drainUnrelatedOverflows(tester);

      expect(find.text('Could not load the discussion'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(
        find.text('No discussions yet'),
        findsNothing,
        reason: 'a failed request was reported as an empty thread',
      );

      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(discussions.listCalls, [99, 99]);
    });

    testWidgets('posting sends the text and inserts the returned row', (
      tester,
    ) async {
      final discussions = FakeDiscussionsApi(
        page: const CourseThreadPage(count: 0, threads: <CourseThread>[]),
      );
      await pump(tester, course: apiCourse(), discussions: discussions);

      await tester.tap(find.text('Q&A'));
      await tester.pump();
      await tester.pump();
      drainUnrelatedOverflows(tester);

      await tester.enterText(
        find.byType(TextField),
        'Is there a printable pack?',
      );
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump();
      drainUnrelatedOverflows(tester);

      expect(discussions.posts.single.body, 'Is there a printable pack?');
      expect(discussions.posts.single.parentId, isNull);
      expect(find.text('Is there a printable pack?'), findsOneWidget);
    });

    testWidgets('a reply is posted with its parent id', (tester) async {
      final discussions = FakeDiscussionsApi(
        page: CourseThreadPage(
          count: 1,
          threads: [thread(body: 'Where do I start?')],
        ),
      );
      await pump(tester, course: apiCourse(), discussions: discussions);

      await tester.tap(find.text('Q&A'));
      await tester.pump();
      await tester.pump();
      drainUnrelatedOverflows(tester);

      await tester.tap(find.text('Reply').first);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Start with boxes.');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump();
      drainUnrelatedOverflows(tester);

      expect(discussions.posts.single.parentId, 1);
      expect(find.text('Start with boxes.'), findsOneWidget);
    });

    testWidgets('reacting sends the like and shows the server count', (
      tester,
    ) async {
      final discussions = FakeDiscussionsApi(
        page: CourseThreadPage(count: 1, threads: [thread(likes: 4)]),
      );
      await pump(tester, course: apiCourse(), discussions: discussions);

      await tester.tap(find.text('Q&A'));
      await tester.pump();
      await tester.pump();
      drainUnrelatedOverflows(tester);

      expect(find.text('4'), findsOneWidget);
      await tester.tap(find.text('4'));
      await tester.pump();
      await tester.pump();

      expect(discussions.likes.single, (id: 1, liked: true));
      // 8, not 5: the server's answer replaces the optimistic guess.
      expect(find.text('8'), findsOneWidget);
      expect(find.text('5'), findsNothing);
    });

    testWidgets('a catalogue course never calls the endpoint', (tester) async {
      final discussions = FakeDiscussionsApi();
      await pump(tester, course: coursePool.first, discussions: discussions);

      await tester.tap(find.text('Q&A'));
      await tester.pump();
      await tester.pump();
      drainUnrelatedOverflows(tester);

      expect(discussions.listCalls, isEmpty);
      // It still renders the hardcoded thread it has always had.
      expect(
        find.text(coursePool.first.discussions.first.body),
        findsOneWidget,
      );
    });
  });
}
