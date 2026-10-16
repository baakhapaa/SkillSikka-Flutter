import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/features/courses/data/course.dart';
import 'package:skillsikka/features/courses/presentation/course_details_page.dart';
import 'package:skillsikka/features/learning/data/enrollment.dart';
import 'package:skillsikka/features/learning/presentation/course_player_page.dart';
import 'package:skillsikka/features/skill_courses/data/skill_course.dart';

import 'support/home_page_font_harness.dart';

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
/// branch is the one every test below exercises.
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
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer();
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
    expect(store.of(geometry)?.completed, contains(0));
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

      store.markComplete(geometry, 0);
      store.markComplete(geometry, 0); // idempotent
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
}
