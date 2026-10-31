import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/network/api_client.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/features/bootcamp/data/bootcamp.dart';
import 'package:skillsikka/features/bootcamp/data/bootcamp_api.dart';
import 'package:skillsikka/features/bootcamp/presentation/bootcamp_page.dart';
import 'package:skillsikka/features/courses/data/course_api.dart';
import 'package:skillsikka/features/courses/data/course_discussions_api.dart';

import 'support/courses_test_scope.dart';

/// The page, with the three providers it reads replaced.
///
/// Images are left blank on purpose: a real URL would put `Image.network` on the
/// test's HTTP client, which answers 400 and reports an image-loading error. An
/// empty path takes `CourseImage`'s asset fallback, which is the same branch the
/// design's bundled artwork uses.
BootcampDetail camp({List<BootcampDay>? days}) => BootcampDetail(
  id: 7,
  title: 'ICT & AI BOOTCAMP at Sundarbazar',
  description: 'Master the foundations of design strategy.',
  shortDescription: 'Four days of strategy, brand and delivery.',
  venueName: 'Sundarbazar',
  status: 'upcoming',
  heroVideoUrl: '',
  heroPosterUrl: '',
  image: '',
  qualityLabel: 'HD',
  level: 'beginner',
  language: 'English',
  durationDays: 4,
  studentsEnrolled: 12400,
  viewCount: 2500,
  startsOn: DateTime(2026, 11, 16),
  endsOn: DateTime(2026, 11, 19),
  instructorNames: const ['Shuvanga Karki', 'Amrit Bhandari'],
  days:
      days ??
      const [
        BootcampDay(1, [
          BootcampSection('Section 1: Research & Strategy Foundations', [
            BootcampLesson(
              number: 1,
              id: 11,
              title: 'Defining the Product Strategy Grid',
              duration: '18:45',
              dayNumber: 1,
              section: 'Section 1: Research & Strategy Foundations',
              kind: CourseLessonKind.video,
              isPreview: false,
              isCompleted: false,
              contentUrl: 'https://cdn.example.com/one.mp4',
            ),
          ]),
        ]),
        BootcampDay(2, [
          BootcampSection('Section 2: Design & Prototyping', [
            BootcampLesson(
              number: 2,
              id: 12,
              title: 'Wireframing for Mobile Interfaces',
              duration: '32:40',
              dayNumber: 2,
              section: 'Section 2: Design & Prototyping',
              kind: CourseLessonKind.video,
              isPreview: false,
              isCompleted: false,
              contentUrl: 'https://cdn.example.com/two.mp4',
            ),
          ]),
        ]),
      ],
  fileSections: const [
    BootcampFileSection('Section 1: Course Materials', [
      CourseResource(
        'Product Strategy Grid Template',
        CourseResourceType.pdf,
        id: 3,
        url: 'https://cdn.example.com/grid.pdf',
      ),
    ]),
  ],
  lessonCount: 2,
  episodeNo: 2,
);

class _FakeBootcampApi extends BootcampApi {
  _FakeBootcampApi({this.value, this.failure}) : super(ApiClient(Dio()));

  BootcampDetail? value;
  ApiException? failure;
  final List<int> calls = <int>[];

  @override
  Future<BootcampDetail> detail(int id) async {
    calls.add(id);
    final error = failure;
    if (error != null) throw error;
    return value!;
  }
}

class _FakeDiscussions extends CourseDiscussionsApi {
  _FakeDiscussions({this.page = const CourseThreadPage(count: 0, threads: [])})
    : super(ApiClient(Dio()));

  CourseThreadPage page;
  ApiException? failure;
  final List<String> posted = <String>[];
  int listCalls = 0;

  @override
  Future<CourseThreadPage> list(
    int courseId, {
    String ordering = '-created_at',
    int page = 1,
    int pageSize = 20,
  }) async {
    listCalls += 1;
    final error = failure;
    if (error != null) throw error;
    return this.page;
  }

  @override
  Future<CourseThread> post(
    int courseId, {
    required String body,
    int? parentId,
  }) async {
    posted.add(body);
    return CourseThread(
      id: 90 + posted.length,
      body: body,
      authorName: 'you',
      when: 'just now',
      isMine: true,
      parentId: parentId,
    );
  }

  @override
  Future<CourseLike> setLiked(
    int courseId,
    int threadId, {
    required bool liked,
  }) async =>
      CourseLike(threadId: threadId, isLiked: liked, likesCount: liked ? 1 : 0);
}

void main() {
  Widget app({
    BootcampDetail? detail,
    ApiException? failure,
    FakeCourseApi? courses,
    _FakeDiscussions? discussions,
  }) => ProviderScope(
    overrides: [
      bootcampApiProvider.overrideWithValue(
        _FakeBootcampApi(value: detail ?? camp(), failure: failure),
      ),
      courseApiProvider.overrideWithValue(courses ?? FakeCourseApi()),
      courseDiscussionsApiProvider.overrideWithValue(
        discussions ?? _FakeDiscussions(),
      ),
    ],
    child: const MaterialApp(home: IctBootcampPage(courseId: 7)),
  );

  testWidgets('renders the camp the admin created, and joins it first', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final courses = FakeCourseApi();
    await tester.pumpWidget(app(courses: courses));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('ICT & AI BOOTCAMP', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('12.4k students'), findsOneWidget);
    expect(find.text('HD'), findsOneWidget);
    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('Day 2'), findsOneWidget);
    expect(find.text('Defining the Product Strategy Grid'), findsOneWidget);

    // Enrolment is what unlocks the lesson URLs and the resource pack.
    expect(courses.enrollmentLookups, [7]);
    expect(courses.enrolCalls, [7]);
  });

  testWidgets('the day chips swap the curriculum', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Wireframing for Mobile Interfaces'), findsNothing);

    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();

    expect(find.text('Wireframing for Mobile Interfaces'), findsOneWidget);
    expect(find.text('Defining the Product Strategy Grid'), findsNothing);
  });

  testWidgets('the Resources tab lists the pack by section', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Resources'));
    await tester.pumpAndSettle();

    expect(find.text('Section 1: Course Materials'), findsOneWidget);
    expect(find.text('Product Strategy Grid Template'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
  });

  testWidgets('Q&A loads on demand, then posts a real thread', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final discussions = _FakeDiscussions(
      page: const CourseThreadPage(
        count: 1,
        threads: [
          CourseThread(
            id: 5,
            body: 'How can we check AI answers?',
            authorName: 'mira_sharma',
            when: '3h ago',
            authorRole: 'Student',
            likesCount: 2,
          ),
        ],
      ),
    );

    await tester.pumpWidget(app(discussions: discussions));
    await tester.pumpAndSettle();

    // Lazy: nothing is fetched until the tab is opened.
    expect(discussions.listCalls, 0);

    await tester.tap(find.text('Q&A'));
    await tester.pumpAndSettle();

    expect(discussions.listCalls, 1);
    expect(find.text('How can we check AI answers?'), findsOneWidget);
    expect(find.text('Episode 2'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Does the grid work?');
    await tester.tap(find.byIcon(Icons.send).first);
    await tester.pumpAndSettle();

    expect(discussions.posted, ['Does the grid work?']);
    expect(find.text('Does the grid work?'), findsOneWidget);
  });

  testWidgets('picking a lesson says what is playing, and ticks the one left', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final courses = FakeCourseApi();
    await tester.pumpWidget(app(courses: courses));
    await tester.pumpAndSettle();

    // Nothing is playing when the camp opens, so there is no now-playing row.
    expect(find.text('DAY 2'), findsNothing);

    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wireframing for Mobile Interfaces'));
    await tester.pumpAndSettle();

    // The strip names the lesson and the day it belongs to. `DAY 2` is the
    // strip's tag only — the Day chip prints `Day 2`, lower case.
    expect(find.text('DAY 2'), findsOneWidget);
    expect(find.text('Wireframing for Mobile Interfaces'), findsWidgets);
    // The first lesson was never opened, so nothing has been marked finished.
    expect(courses.completions, isEmpty);

    // Moving on finishes the lesson being left — the course player's rule.
    await tester.tap(find.text('Day 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Defining the Product Strategy Grid'));
    await tester.pumpAndSettle();

    expect(courses.completions, [12]);
    expect(find.text('DAY 1'), findsOneWidget);
  });

  testWidgets('Prev on the first lesson goes back to the trailer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Defining the Product Strategy Grid'));
    await tester.pumpAndSettle();
    expect(find.text('DAY 1'), findsOneWidget);

    await tester.tap(find.text('Prev'));
    await tester.pumpAndSettle();

    // Back on the camp's own poster: the strip collapses.
    expect(find.text('DAY 1'), findsNothing);
  });

  testWidgets('Next is dead on the last lesson, Prev is live', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wireframing for Mobile Interfaces'));
    await tester.pumpAndSettle();

    // Tapping Next at the end is a no-op rather than a wrap-around.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Wireframing for Mobile Interfaces'), findsWidgets);
    expect(find.text('DAY 2'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    await tester.pumpWidget(
      app(
        failure: const ApiException(
          kind: ApiErrorKind.unknown,
          message: 'That camp is gone.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('That camp is gone.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a camp with no lessons says so instead of showing a blank tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(detail: camp(days: const [])));
    await tester.pumpAndSettle();

    expect(
      find.text('The curriculum for this camp has not been published yet.'),
      findsOneWidget,
    );
  });
}
