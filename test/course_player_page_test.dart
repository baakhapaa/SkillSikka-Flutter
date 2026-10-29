import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/features/courses/data/course.dart';
import 'package:skillsikka/features/courses/data/course_adapter.dart';
import 'package:skillsikka/features/courses/data/course_api.dart';
import 'package:skillsikka/features/courses/data/course_resources_api.dart';
import 'package:skillsikka/features/courses/presentation/course_details_page.dart';
import 'package:skillsikka/features/learning/data/enrollment.dart';
import 'package:skillsikka/features/learning/presentation/course_player_page.dart';
import 'package:skillsikka/features/learning/presentation/widgets/video_transport_controls.dart';
import 'package:skillsikka/features/skill_courses/data/skill_course.dart';

import 'support/courses_test_scope.dart';
import 'support/home_page_font_harness.dart';

/// An icon inside the player's top stage only.
///
/// The lesson rows below draw the same play/lock glyphs, so an unscoped
/// `find.byIcon` matches the list as well as the stage and cannot tell them
/// apart.
Finder _stageIcon(IconData icon) => find.descendant(
  of: find.byKey(CoursePlayerPage.stageKey),
  matching: find.byIcon(icon),
);

/// Covers the screen a course opens into after enrolling, and the detail page's
/// two bottom-bar states that lead into it.
///
/// **Every assertion here is scoped to what a 360x800 viewport actually builds.**
/// The lecture list and the discussion thread are `ListView`s, so an off-screen
/// row is not merely invisible — it does not exist, and `find.text` cannot match
/// it. Where a test needs the whole list, it pumps a taller surface instead of
/// scrolling and hoping.
///
/// **No lecture in the catalogue has a video** (`CourseLesson.videoAsset` is null
/// on all 297 of them), which is what keeps `video_player` — no platform
/// implementation under `flutter test` — off this file entirely. The still-image
/// branch is the one every catalogue test below exercises.
///
/// The `stage` group at the end uses **API-shaped** courses instead, built
/// through `CourseMapper`, to cover the three new stage branches. None of them
/// carries a playable video either — a text lesson renders its body, a gated
/// lesson has no URL, and a PDF renders a document card — so `_syncVideo` returns
/// before it ever constructs a controller.
void main() {
  installHomePageFontHarness();

  final geometry = coursePool.first;
  final algebra = coursePool.firstWhere(
    (c) => c.title == 'Mathematics: Algebra Foundations',
  );

  /// Pumps the player for [course] inside its own container.
  ///
  /// Returns the container so a test can read the enrolment store back — which
  /// is how the Prev/Next tests assert, rather than counting rendered strings
  /// that appear in two places at once.
  Future<ProviderContainer> pumpPlayer(
    WidgetTester tester,
    CourseDetailData course, {
    bool enrolled = true,
    int startIndex = 0,
    Size size = const Size(360, 800),
    FakeCourseApi? api,
    FakeCourseResourcesApi? resources,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // An API course makes the player fetch its progress on open, and tapping
    // Resources makes it fetch the pack. Every test that passes one hands over a
    // fake, so no suite reaches the network — dio would answer 400 under
    // `flutter test`, which looks like a product bug.
    final container = ProviderContainer(
      overrides: [
        if (api != null) courseApiProvider.overrideWithValue(api),
        courseResourcesApiProvider.overrideWithValue(
          resources ?? FakeCourseResourcesApi(),
        ),
      ],
    );
    addTearDown(container.dispose);
    if (enrolled) {
      container
          .read(enrolledCoursesProvider.notifier)
          .record(course, startIndex: startIndex);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: CoursePlayerPage(course: course, startIndex: startIndex),
        ),
      ),
    );
    await tester.pump();
    drainUnrelatedOverflows(tester);
    return container;
  }

  testWidgets('the player opens on the course it was handed', (tester) async {
    await pumpPlayer(tester, geometry);

    expect(find.text(geometry.modules.first.title), findsOneWidget);
    // The current lecture is named twice — once over the still, once in its row
    // — so this is `findsWidgets`, not `findsOneWidget`. Asserting the exact
    // count here would be asserting the video overlay, which is not the point.
    expect(find.text(geometry.modules.first.lessons.first.title), findsWidgets);
  });

  testWidgets('the player renders the course it was handed, not another', (
    tester,
  ) async {
    await pumpPlayer(tester, geometry);

    expect(
      find.text(algebra.modules.first.title),
      findsNothing,
      reason: 'the player is showing a course it was not given',
    );
    // And the negative above is only meaningful beside the positive: an empty
    // screen would satisfy "the other course is absent" too.
    expect(find.text(geometry.modules.first.title), findsOneWidget);
  });

  testWidgets('a section header counts its own lectures, not the course total', (
    tester,
  ) async {
    await pumpPlayer(tester, geometry);

    final firstModule = geometry.modules.first;
    expect(
      find.text('${firstModule.lessons.length} lessons'),
      findsWidgets,
      reason: 'the header must count the list beneath it',
    );
    // The course has nine lectures across three sections. A header reading
    // `9 lessons` would be the whole-course total — the hardcoded-count defect
    // the curriculum accordion already had once.
    final total = geometry.modules.fold<int>(
      0,
      (sum, module) => sum + module.lessons.length,
    );
    expect(total, greaterThan(firstModule.lessons.length));
    expect(find.text('$total lessons'), findsNothing);
  });

  testWidgets('Next advances the lecture and remembers where you were', (
    tester,
  ) async {
    final container = await pumpPlayer(tester, geometry);
    final store = container.read(enrolledCoursesProvider.notifier);

    expect(store.of(geometry)?.lastIndex, 0);

    await tester.tap(find.text('Next'));
    await tester.pump();
    drainUnrelatedOverflows(tester);

    expect(store.of(geometry)?.lastIndex, 1);
    // Leaving a lecture is this demo's stand-in for finishing it — there is no
    // playback-completed event without a video. Without this the progress on the
    // My Learning tab could never leave zero.
    //
    // The stored key is the lesson's **id**, or a negative position for a
    // catalogue lesson that has none — not the index it used to be.
    expect(
      store.of(geometry)?.completed,
      contains(lessonProgressKey(geometry.modules.first.lessons.first, 0)),
    );
  });

  testWidgets('Prev is disabled on the first lecture rather than wrapping', (
    tester,
  ) async {
    final container = await pumpPlayer(tester, geometry);
    final store = container.read(enrolledCoursesProvider.notifier);

    await tester.tap(find.text('Prev'));
    await tester.pump();
    drainUnrelatedOverflows(tester);

    expect(
      store.of(geometry)?.lastIndex,
      0,
      reason: 'Prev at the start of a course must not move anywhere',
    );
  });

  testWidgets('the Resources tab lists the pack and counts it', (tester) async {
    final course = geometry;
    await pumpPlayer(tester, course);

    await tester.tap(find.text('Resources'));
    await tester.pump();
    drainUnrelatedOverflows(tester);

    expect(find.text('${course.resources.length} files'), findsOneWidget);
    expect(find.text(course.resources.first.title), findsOneWidget);
    // The header names the episode, built from the lecture that is playing —
    // it is not an authored string.
    expect(
      find.text('EP. 1 ${course.modules.first.lessons.first.title}'),
      findsOneWidget,
    );
  });

  testWidgets('the Q&A tab shows the thread and View more reveals the rest', (
    tester,
  ) async {
    final course = geometry;
    // Tall enough that the whole thread builds: a ListView does not create rows
    // outside its viewport, so at 800pt the last comment would not exist to be
    // found and the failure would look like a missing comment.
    await pumpPlayer(tester, course, size: const Size(360, 1400));

    await tester.tap(find.text('Q&A'));
    await tester.pump();
    drainUnrelatedOverflows(tester);

    expect(find.text('Discussions'), findsOneWidget);
    expect(find.text(course.discussions.first.author), findsOneWidget);

    // Four are authored, three are shown, so the control has something behind
    // it — a `View more` that expands to nothing is a dead control.
    expect(course.discussions.length, greaterThan(3));
    final hidden = course.discussions.last.author;
    expect(find.text(hidden), findsNothing);
    expect(find.text('View more'), findsOneWidget);

    await tester.tap(find.text('View more'));
    await tester.pump();
    drainUnrelatedOverflows(tester);

    expect(find.text(hidden), findsOneWidget);
    expect(find.text('View more'), findsNothing);
  });

  testWidgets('replying nests the answer under its message', (tester) async {
    final course = geometry;
    // The whole thread has to be built: posting a reply opens the thread, so
    // the assertion below needs the second card to exist to be compared with.
    await pumpPlayer(tester, course, size: const Size(360, 1400));

    await tester.tap(find.text('Q&A'));
    await tester.pump();
    drainUnrelatedOverflows(tester);

    final parent = course.discussions.first;
    final next = course.discussions[1];

    // The first `Reply` in the tree is the first card's.
    await tester.tap(find.text('Reply').first);
    await tester.pump();

    // The composer says what it is about to do — otherwise a reply and a new
    // discussion look identical while you are typing.
    expect(find.text('Replying to ${parent.author}'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'Which construction should I redo first?',
    );
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    drainUnrelatedOverflows(tester);

    final reply = find.text('Which construction should I redo first?');
    expect(reply, findsOneWidget);

    // Under the message it answers, and above the next card — not at the top
    // of the list, which is where a new discussion goes.
    final replyY = tester.getTopLeft(reply).dy;
    expect(
      replyY,
      greaterThan(tester.getTopLeft(find.text(parent.body)).dy),
      reason: 'the reply rendered above the message it answers',
    );
    expect(
      replyY,
      lessThan(tester.getTopLeft(find.text(next.body)).dy),
      reason: 'the reply became a new message in the thread',
    );

    // And indented, so the nesting is visible rather than implied by order.
    expect(
      tester.getTopLeft(reply).dx,
      greaterThan(tester.getTopLeft(find.text(parent.body)).dx),
      reason: 'the reply is flush with its parent, so it reads as a sibling',
    );

    // A reply is part of a discussion, not a new one.
    expect(find.text('${course.discussions.length}'), findsOneWidget);
  });

  testWidgets('posting with no reply target still starts a new discussion', (
    tester,
  ) async {
    final course = geometry;
    await pumpPlayer(tester, course, size: const Size(360, 1400));

    await tester.tap(find.text('Q&A'));
    await tester.pump();
    drainUnrelatedOverflows(tester);

    await tester.enterText(find.byType(TextField), 'Is the pack printable?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    drainUnrelatedOverflows(tester);

    final comment = find.text('Is the pack printable?');
    expect(comment, findsOneWidget);

    // Above the first authored card, because a new discussion sorts to the top
    // — the opposite of where a reply goes.
    expect(
      tester.getTopLeft(comment).dy,
      lessThan(tester.getTopLeft(find.text(course.discussions.first.body)).dy),
    );
    expect(find.text('${course.discussions.length + 1}'), findsOneWidget);
  });

  testWidgets('the bottom bar offers Enroll, then Continue Learning', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> pumpDetail({required bool enrolled}) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      if (enrolled) {
        container.read(enrolledCoursesProvider.notifier).record(geometry);
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: CourseDetailPage(course: geometry)),
        ),
      );
      await tester.pump();
      drainUnrelatedOverflows(tester);
    }

    await pumpDetail(enrolled: false);
    expect(find.text('Enroll Now'), findsOneWidget);
    expect(find.text('Continue Learning'), findsNothing);

    await pumpDetail(enrolled: true);
    expect(
      find.text('Continue Learning'),
      findsOneWidget,
      reason: 'an enrolled course must not still be selling itself',
    );
    expect(find.text('Enroll Now'), findsNothing);
  });

  group('the enrolment store', () {
    test('records a course once, however many times it is asked', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final store = container.read(enrolledCoursesProvider.notifier);

      expect(store.isEnrolled(geometry), isFalse);
      store.record(geometry);
      store.record(geometry);

      expect(store.isEnrolled(geometry), isTrue);
      expect(container.read(enrolledCoursesProvider), hasLength(1));
    });

    test('derives progress from the course, not from a stored count', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final store = container.read(enrolledCoursesProvider.notifier);
      store.record(geometry);

      final lessons = geometry.modules.fold<int>(
        0,
        (sum, module) => sum + module.lessons.length,
      );
      expect(store.of(geometry)?.total, lessons);
      expect(store.of(geometry)?.progress, 0);

      final first = geometry.modules.first.lessons.first;
      store.markComplete(geometry, first, 0);
      store.markComplete(geometry, first, 0); // idempotent
      expect(store.of(geometry)?.done, 1);
      expect(store.of(geometry)?.percentLabel, '${(100 / lessons).round()}%');
    });

    test('every catalogue course carries a resource pack and a thread', () {
      // Authored content, so it can drift from the model silently. Both pools
      // are checked: the player renders an empty state for a course without
      // them, and an empty state is the wrong thing to ship for a whole pool.
      for (final course in [...coursePool, ...skillCoursePool]) {
        expect(
          course.resources,
          isNotEmpty,
          reason: '${course.title} has no resources',
        );
        expect(
          course.discussions,
          isNotEmpty,
          reason: '${course.title} has no discussions',
        );
      }
    });
  });

  group('stage', () {
    /// A course shaped like `GET /courses/{id}/` + its lessons.
    ///
    /// Built through [CourseMapper] rather than by hand so these tests exercise
    /// the real wire-to-view mapping: `content_type` becomes a
    /// [CourseLessonKind], and a null `content_url` stays null so the paywall
    /// branch can see it.
    CourseDetailData apiCourse(List<Map<String, dynamic>> lessons) {
      final course = CourseMapper.detail(
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
          'lessons_count': lessons.length,
          'total_duration_seconds': 900,
          'instructor': 4,
          'instructor_name': 'Test Instructor',
          'learning_outcomes': <String>[],
          'requirements': <String>[],
          'updated_at': '2026-10-27T06:04:13.639481Z',
        },
        lessons: lessons,
      );
      // `CourseMapper` leaves `id` from the payload, so the player knows this is
      // an API course and that a null URL means gated.
      return course;
    }

    Map<String, dynamic> lesson(
      int id,
      String kind, {
      String? url,
      String? text,
      String? section = 'Foundations',
    }) => {
      'id': id,
      'title': 'Lesson $id',
      'content_type': kind,
      'content_url': url,
      'content_text': text,
      'section': section,
      'duration_seconds': 300,
      'is_preview': false,
      'order': id,
    };

    testWidgets('a text lesson renders its body instead of a player', (
      tester,
    ) async {
      await pumpPlayer(
        tester,
        apiCourse([
          lesson(
            1,
            'text',
            text: 'Work through the example and explain your reasoning.',
          ),
        ]),
        api: FakeCourseApi(),
      );

      expect(
        find.text('Work through the example and explain your reasoning.'),
        findsOneWidget,
      );
      expect(
        _stageIcon(Icons.play_circle_outline),
        findsNothing,
        reason: 'a reading lesson is not a video',
      );
    });

    testWidgets('a gated video lesson shows a lock, not a play button', (
      tester,
    ) async {
      // `content_url: null` is what the paywall returns for a student who is not
      // enrolled. Rendering a play button over the still would promise a video
      // that cannot start.
      await pumpPlayer(
        tester,
        apiCourse([lesson(1, 'video')]),
        api: FakeCourseApi(),
      );

      expect(find.text('Enrol to watch this lesson'), findsOneWidget);
      expect(_stageIcon(Icons.lock_outline), findsOneWidget);
      expect(_stageIcon(Icons.play_circle_outline), findsNothing);
      // And no transport bar: there is no controller behind a gated lesson, so
      // a play/pause or a seek bar over the lock would be a control that
      // cannot act.
      expect(find.byType(VideoTransportControls), findsNothing);
    });

    testWidgets('a pdf lesson is a resource, so it never reaches the stage', (
      tester,
    ) async {
      // **A PDF is a resource, not a lecture** — `CourseMapper._resources` lifts
      // those rows out of the curriculum. So there is no pdf stage to draw: the
      // lecture list holds the one lecture and the file is in Resources.
      final course = apiCourse([
        lesson(1, 'text', text: 'Body one'),
        lesson(2, 'pdf', url: 'https://example.com/worksheet.pdf'),
      ]);
      await pumpPlayer(tester, course, api: FakeCourseApi());

      expect(find.text('Lesson 1'), findsWidgets);
      expect(
        find.text('Lesson 2'),
        findsNothing,
        reason: 'a pdf must not be listed as a lecture',
      );

      await tester.tap(find.text('Resources'));
      await tester.pump();
      drainUnrelatedOverflows(tester);

      expect(find.text('1 file'), findsOneWidget);
      expect(find.text('Lesson 2'), findsOneWidget);
    });
  });

  group('progress', () {
    /// The same API-shaped course the `stage` group builds, kept local so the
    /// two groups can drift independently.
    CourseDetailData apiCourse(List<Map<String, dynamic>> lessons) =>
        CourseMapper.detail(
          course: {
            'id': 99,
            'title': 'Drawing from Observation',
            'description': '',
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
            'lessons_count': lessons.length,
            'total_duration_seconds': 900,
            'instructor': 4,
            'instructor_name': 'Test Instructor',
            'learning_outcomes': <String>[],
            'requirements': <String>[],
            'updated_at': '2026-10-27T06:04:13.639481Z',
          },
          lessons: lessons,
        );

    Map<String, dynamic> textLesson(int id) => {
      'id': id,
      'title': 'Lesson $id',
      'content_type': 'text',
      'content_url': '',
      'content_text': 'Body $id',
      'section': 'Foundations',
      'duration_seconds': 300,
      'is_preview': false,
      'order': id,
    };

    testWidgets('the server decides which lecture to resume on', (
      tester,
    ) async {
      final course = apiCourse([
        for (var id = 1; id <= 3; id++) textLesson(id),
      ]);
      final api = FakeCourseApi()
        ..nextLesson = 3
        ..progressValue = const CourseProgress(
          courseId: 99,
          totalLessons: 3,
          completedLessons: 2,
          percentage: 66.67,
          isCompleted: false,
        );

      final container = await pumpPlayer(tester, course, api: api);
      await tester.pumpAndSettle();

      final enrollment = container
          .read(enrolledCoursesProvider.notifier)
          .of(course);

      // Lesson 3 is the first incomplete one, so 1 and 2 are complete — the
      // server's own definition of `next_lesson` makes that exact, not a guess.
      expect(enrollment?.lastIndex, 2);
      expect(enrollment?.done, 2);
      expect(enrollment?.completed, containsAll(<int>[1, 2]));
    });

    testWidgets('an explicit startIndex is not overridden by the server', (
      tester,
    ) async {
      final course = apiCourse([
        for (var id = 1; id <= 3; id++) textLesson(id),
      ]);
      final api = FakeCourseApi()
        ..nextLesson = 3
        ..progressValue = const CourseProgress(
          courseId: 99,
          totalLessons: 3,
          completedLessons: 2,
          percentage: 66.67,
          isCompleted: false,
        );

      // The user tapped a specific lecture; resuming elsewhere would be rude.
      await pumpPlayer(tester, course, api: api, startIndex: 1);
      await tester.pumpAndSettle();

      expect(find.text('Body 2'), findsOneWidget);
    });

    testWidgets('advancing posts the completion for that lesson', (
      tester,
    ) async {
      final course = apiCourse([textLesson(1), textLesson(2)]);
      final api = FakeCourseApi();

      await pumpPlayer(tester, course, api: api);
      await tester.pumpAndSettle();
      expect(api.completions, isEmpty);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // The lesson's server id, not its position.
      expect(api.completions, [1]);
    });

    testWidgets('a catalogue course never calls the API', (tester) async {
      // Catalogue lessons have no ids, so there is nothing to post and nothing
      // to fetch — the store stays the only source.
      final api = FakeCourseApi();
      await pumpPlayer(tester, geometry, api: api);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(api.completions, isEmpty);
    });
  });

  group('completing a course', () {
    /// One API-backed course with [count] text lectures.
    CourseDetailData course(int count) => CourseMapper.detail(
      course: {
        'id': 99,
        'title': 'Drawing from Observation',
        'description': '',
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
        'lessons_count': count,
        'total_duration_seconds': count * 300,
        'instructor': 4,
        'instructor_name': 'Test Instructor',
        'learning_outcomes': <String>[],
        'requirements': <String>[],
        'updated_at': '2026-10-27T06:04:13.639481Z',
      },
      lessons: [
        for (var id = 1; id <= count; id++)
          {
            'id': id,
            'title': 'Lesson $id',
            'content_type': 'text',
            'content_url': '',
            'content_text': 'Body $id',
            'section': 'Foundations',
            'duration_seconds': 300,
            'is_preview': false,
            'order': id,
          },
      ],
    );

    testWidgets('the last lecture can be finished from its own row', (
      tester,
    ) async {
      // **The gap this closes:** `_select` only ticks the lecture being *left*,
      // so the final lecture — which has no Next — could never be completed and
      // the course could never reach 100%.
      final api = FakeCourseApi();
      await pumpPlayer(tester, course(1), api: api);
      await tester.pumpAndSettle();

      expect(find.text('Mark complete'), findsOneWidget);
      await tester.tap(find.text('Mark complete'));
      await tester.pumpAndSettle();

      expect(api.completions, [1]);
      expect(find.text('Mark complete'), findsNothing);
    });

    testWidgets('finishing the course offers a review that really submits', (
      tester,
    ) async {
      final api = FakeCourseApi();
      await pumpPlayer(tester, course(1), api: api);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mark complete'));
      await tester.pumpAndSettle();

      expect(find.text('You finished this course'), findsOneWidget);

      await tester.tap(find.text('Write a review'));
      await tester.pumpAndSettle();
      expect(find.text('Rate this course'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('review-star-5')));
      await tester.pump();
      await tester.tap(find.text('Submit review'));
      await tester.pumpAndSettle();

      expect(api.submitted.single.courseId, 99);
      expect(api.submitted.single.rating, 5);
    });

    testWidgets('an unfinished course offers no review card', (tester) async {
      final api = FakeCourseApi();
      await pumpPlayer(tester, course(2), api: api);
      await tester.pumpAndSettle();

      expect(find.text('You finished this course'), findsNothing);
    });
  });

  /// The Resources tab, which fetches `GET /courses/{id}/resources/` the first
  /// time it is opened — the same lazy contract the Q&A tab has.
  group('resources', () {
    CourseDetailData apiCourse(List<Map<String, dynamic>> lessons) =>
        CourseMapper.detail(
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
            'lessons_count': lessons.length,
            'total_duration_seconds': 900,
            'instructor': 4,
            'instructor_name': 'Test Instructor',
            'learning_outcomes': <String>[],
            'requirements': <String>[],
            'updated_at': '2026-10-27T06:04:13.639481Z',
          },
          lessons: lessons,
        );

    Map<String, dynamic> lesson(int id, {String kind = 'video'}) => {
      'id': id,
      'title': 'Lesson $id',
      'content_type': kind,
      'content_url': 'https://example.com/$id.mp4',
      'content_text': null,
      'section': 'Foundations',
      'duration_seconds': 300,
      'is_preview': false,
      'order': id,
    };

    CourseResource file(
      String title, {
      int? lessonId,
      String format = 'pdf',
      int? sizeBytes,
      String? url = 'https://example.com/file.pdf',
    }) => CourseResource(
      title,
      CourseResourceType.fromFormat(format),
      id: title.hashCode.abs(),
      url: url,
      lessonId: lessonId,
      sizeBytes: sizeBytes,
    );

    testWidgets('the tab fetches once, and only when it is opened', (
      tester,
    ) async {
      final resources = FakeCourseResourcesApi();
      await pumpPlayer(
        tester,
        apiCourse([lesson(1)]),
        api: FakeCourseApi(),
        resources: resources,
      );
      await tester.pumpAndSettle();

      expect(
        resources.calls,
        isEmpty,
        reason:
            'a player opened to watch a lecture must not fetch a tab nobody '
            'looked at',
      );

      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();
      expect(resources.calls, [99]);

      // Leaving and coming back must not spend a second request.
      await tester.tap(find.text('Lessons'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();
      expect(resources.calls, [99]);
    });

    testWidgets('a lesson shows its own files and the course-wide ones', (
      tester,
    ) async {
      final resources = FakeCourseResourcesApi(
        rows: [
          file('This lesson worksheet', lessonId: 1),
          file('Course-wide template'),
          file('Next lesson handout', lessonId: 2),
        ],
      );
      await pumpPlayer(
        tester,
        apiCourse([lesson(1), lesson(2)]),
        api: FakeCourseApi(),
        resources: resources,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();

      expect(find.text('This lesson worksheet'), findsOneWidget);
      expect(
        find.text('Course-wide template'),
        findsOneWidget,
        reason:
            'a row with no lesson is course-wide — every bootcamp pack is '
            'shaped that way and must stay visible',
      );
      expect(
        find.text('Next lesson handout'),
        findsNothing,
        reason: 'another lesson’s file is not this lesson’s file',
      );
      expect(find.text('2 files'), findsOneWidget);
    });

    testWidgets('a server pack replaces the pdf-lesson fallback', (
      tester,
    ) async {
      // The course carries a `pdf` lesson, which the adapter lifts into a
      // fallback resource. Once the server answers real rows, those win.
      final course = apiCourse([lesson(1), lesson(2, kind: 'pdf')]);
      expect(course.resources, hasLength(1));

      await pumpPlayer(
        tester,
        course,
        api: FakeCourseApi(),
        resources: FakeCourseResourcesApi(
          rows: [file('Workbook', lessonId: 1, format: 'xlsx')],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();

      expect(find.text('Workbook'), findsOneWidget);
      expect(find.text('1 file'), findsOneWidget);
      expect(
        find.text('Lesson 2'),
        findsNothing,
        reason: 'the fallback list is only for a course with no rows',
      );
    });

    testWidgets(
      'a refused load says so instead of claiming there are no files',
      (tester) async {
        final resources = FakeCourseResourcesApi(
          failure: const ApiException(
            kind: ApiErrorKind.forbidden,
            statusCode: 403,
            message: 'You must be enrolled in this course to access it.',
          ),
        );
        await pumpPlayer(
          tester,
          apiCourse([lesson(1)]),
          api: FakeCourseApi(),
          resources: resources,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Resources'));
        await tester.pumpAndSettle();

        expect(find.text('Could not load the files'), findsOneWidget);
        expect(
          find.text('No files for this lesson'),
          findsNothing,
          reason: 'a 403 is not an empty pack',
        );
        expect(find.text('Try again'), findsOneWidget);
      },
    );
  });
}
