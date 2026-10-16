import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/courses/data/course.dart';
import 'package:skillsikka/features/courses/presentation/course_details_page.dart';
import 'package:skillsikka/features/courses/presentation/courses.dart';
import 'package:skillsikka/features/home/presentation/home_page.dart';
import 'package:skillsikka/features/learning/presentation/course_player_page.dart';
import 'package:skillsikka/features/profile/data/profile_completeness.dart';

import 'support/events_test_scope.dart';
import 'support/home_page_font_harness.dart';

/// Covers the course-detail screen and the shared `CourseDetailView` it renders,
/// from both entry points that reach it: the Courses tab's grid and the home
/// screen's "Courses" rail.
///
/// **Why nothing here pumps `PremiumCourseDetailsPage`.** That screen's data
/// carries a `bannerVideoAsset`, so `CourseDetailView.initState` constructs a
/// `VideoPlayerController` and calls `initialize()`. `video_player` has no
/// platform implementation under `flutter test`, so that future fails
/// asynchronously with a `MissingPluginException` and no handler attached —
/// which fails the test rather than surfacing as a catchable exception. It is
/// the same wall that kept the premium screen untested before this refactor
/// (`2026-09-22.md`, `spacing_audit_2026-09-22.md`). Covering it needs a fake
/// `VideoPlayerPlatform.instance`; until then the premium path is verified by
/// inspection, and the *shared* view is covered here through the video-less
/// catalogue courses — which is the point of the extraction anyway.
void main() {
  installHomePageFontHarness();

  Future<void> pumpAtPhoneSize(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(child);
    await tester.pump();
  }

  testWidgets('tapping a course card opens the detail page for it', (
    tester,
  ) async {
    await pumpAtPhoneSize(tester, const MaterialApp(home: AllCoursesPage()));
    drainUnrelatedOverflows(tester);

    // The catalogue tiles its six courses to eighteen cards, so this title
    // appears three times — take the first, which is the one on screen.
    final card = find.text(coursePool.first.title).first;
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);

    expect(
      find.byType(CourseDetailPage),
      findsOneWidget,
      reason: 'the card used to dead-end on a SnackBar',
    );
    // A heading that exists only on the detail screen, so this proves the push
    // actually rendered rather than the tap being swallowed.
    expect(find.text('Curriculum'), findsOneWidget);
  });

  testWidgets('a home course card opens the same detail page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // HomePage's events rail reaches for `geolocator`, which has no
    // implementation under `flutter test` — the call neither completes nor
    // throws, so an unstubbed rail hangs the test rather than failing it.
    // `eventsTestScope` overrides the one provider the rail reads, which removes
    // both the network request and the plugin. See its own doc comment.
    await tester.pumpWidget(
      eventsTestScope(child: const MaterialApp(home: HomePage())),
    );
    await tester.pump();
    drainUnrelatedOverflows(tester);

    // The rail samples the same catalogue the Courses tab filters, so `All`
    // shows the catalogue's first four — and this title leads it.
    final card = find.text(coursePool.first.title);
    // **Not `tester.ensureVisible`.** That aligns the target to the viewport's
    // *top edge*, and HomePage's header is a `Stack` overlay rather than part of
    // the scroll (`home_page.dart:280` — hence the `SizedBox(height: 80)` spacer
    // at the top of the scroll content). Top-aligning puts the card underneath
    // the header, which then swallows the tap: `tap()` warns that the derived
    // offset "would not hit test on the specified widget" and the push never
    // happens. Centre it so it clears the header on both edges.
    await Scrollable.ensureVisible(tester.element(card), alignment: 0.5);
    await tester.pump();

    // Turn a confusing "tap would not hit test" warning into a clear failure.
    expect(
      tester.getRect(card).top,
      greaterThan(100),
      reason: 'the card is still under the fixed header',
    );

    await tester.tap(card);
    // **Not `pumpAndSettle`.** HomePage runs a `Timer.periodic(4s)` to advance
    // the promo banner, so time never runs out of scheduled frames and settling
    // would time out. Two pumps are enough: the pushed route builds its page
    // immediately, well before the transition finishes.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    drainUnrelatedOverflows(tester);

    expect(find.byType(CourseDetailPage), findsOneWidget);
    expect(find.text('Curriculum'), findsOneWidget);

    // Dispose HomePage so its promo timer is cancelled — a timer still pending
    // when the test ends fails it, and the failure reads as unrelated noise.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the detail page renders the course it was given', (
    tester,
  ) async {
    // JavaScript Masterclass — not the first entry, so an accidental hardcoding
    // of `coursePool.first` would show up here.
    final course = coursePool[1];
    await pumpAtPhoneSize(
      tester,
      MaterialApp(home: CourseDetailPage(course: course)),
    );
    drainUnrelatedOverflows(tester);

    expect(find.text(course.title), findsOneWidget);
    expect(find.text(course.totalTime), findsOneWidget);

    // The premium screen's copy must not leak in: this is what proves the page
    // is parameterized rather than a static mirror.
    //
    // Assert on the premium course's **exact title and instructor**, never on a
    // shared word. The first version of this test used
    // `find.textContaining('DevSecOps')` and failed — the catalogue's own Amrit
    // Poudel is an "App Security | DevSecOps | Automation" instructor, so that
    // substring is legitimately on this page. The word is shared vocabulary;
    // only the premium *values* are the tell.
    expect(
      find.text('DevSecOps & DevOps with Jenkins, Kubernetes, Terraform & AWS'),
      findsNothing,
    );
    expect(find.textContaining('Baakhapaa'), findsNothing);
  });

  testWidgets('the shared view renders every section from the data', (
    tester,
  ) async {
    final course = coursePool.first;
    await pumpAtPhoneSize(
      tester,
      MaterialApp(home: CourseDetailPage(course: course)),
    );
    drainUnrelatedOverflows(tester);

    for (final heading in [
      "What you'll learn",
      'Curriculum',
      'This course includes',
      'Requirements',
      'Description',
      'Instructors',
      'Student feedback',
    ]) {
      expect(
        find.text(heading),
        findsOneWidget,
        reason: 'section missing after the extraction: $heading',
      );
    }

    expect(find.text(course.learningOutcomes.first), findsOneWidget);
    expect(find.text(course.modules.first.title), findsOneWidget);
    expect(find.text(course.includes.first.label), findsOneWidget);
    expect(find.text(course.requirements.first), findsOneWidget);
    // **Not `instructors.first.name`.** That string is legitimately on this page
    // twice: the "Created by" row in the core details carries the course's
    // `instructorName`, and the instructor card further down carries the same
    // person's `name`. For most catalogue entries those are the same string, so
    // `findsOneWidget` was wrong. The instructor's own title appears only in the
    // card, which is what this assertion is actually about.
    expect(find.text(course.instructors.first.title), findsOneWidget);
    expect(find.text(course.reviews.first.name), findsOneWidget);
    expect(find.text('Show more'), findsOneWidget);
    expect(find.text('TOTAL TIME'), findsOneWidget);
    expect(find.text('Enroll Now'), findsOneWidget);
  });

  testWidgets('the enrol button runs the profile gate and opens the player', (
    tester,
  ) async {
    await pumpAtPhoneSize(
      tester,
      ProviderScope(
        overrides: [
          // A complete profile, so the gate short-circuits and no dialog or
          // Edit Profile navigation is involved.
          profileCompletenessProvider.overrideWithValue(
            const ProfileCompleteness(
              fields: <ProfileField>[],
              missing: <ProfileField>[],
            ),
          ),
        ],
        child: MaterialApp(home: CourseDetailPage(course: coursePool.first)),
      ),
    );
    drainUnrelatedOverflows(tester);

    await tester.tap(find.text('Enroll Now'));
    // The flow pushes a route now, so the two bare `pump`s this test used are
    // not enough — the transition has to finish before the player is on screen.
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);

    expect(
      find.byType(CoursePlayerPage),
      findsOneWidget,
      reason: 'enrolling used to stop at a SnackBar on the detail page',
    );
  });

  testWidgets('a class chip filters the Courses tab to that class', (
    tester,
  ) async {
    final classSix = coursePool.firstWhere((c) => c.classLevel == 'Class 6');
    final classTen = coursePool.firstWhere((c) => c.classLevel == 'Class 10');

    await pumpAtPhoneSize(tester, const MaterialApp(home: AllCoursesPage()));
    drainUnrelatedOverflows(tester);

    // Unfiltered, both classes are on screen.
    expect(find.text(classSix.title), findsWidgets);
    expect(find.text(classTen.title), findsWidgets);

    // 'Class 6' is the second chip, so it is on screen without scrolling the
    // chip row — the last chip is not, at 360pt.
    await tester.tap(find.text('Class 6'));
    await tester.pump();
    drainUnrelatedOverflows(tester);

    expect(find.text(classSix.title), findsWidgets);
    expect(
      find.text(classTen.title),
      findsNothing,
      reason: 'a Class 10 course survived a Class 6 filter',
    );
    // The header names the filter, so a filtered grid cannot read as the whole
    // catalogue.
    expect(find.text('Class 6 Courses'), findsOneWidget);
  });

  testWidgets('a curriculum section expands to reveal its lessons', (
    tester,
  ) async {
    final course = coursePool.first;
    final module = course.modules.first;
    final lesson = module.lessons.first;

    await pumpAtPhoneSize(
      tester,
      MaterialApp(home: CourseDetailPage(course: course)),
    );
    drainUnrelatedOverflows(tester);

    // Collapsed: the section is there, its lectures are not.
    expect(find.text(module.title), findsOneWidget);
    expect(find.text(lesson.title), findsNothing);

    // Centre it before tapping — the section sits below the fold, and the
    // screen's sticky bottom bar would swallow a tap at the viewport's edge.
    await Scrollable.ensureVisible(
      tester.element(find.text(module.title)),
      alignment: 0.5,
    );
    await tester.pump();

    await tester.tap(find.text(module.title));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    drainUnrelatedOverflows(tester);

    expect(
      find.text(lesson.title),
      findsOneWidget,
      reason: 'tapping the section should reveal its first lecture',
    );

    // Tapping again collapses it.
    await tester.tap(find.text(module.title));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    drainUnrelatedOverflows(tester);

    expect(find.text(lesson.title), findsNothing);
  });

  group('catalogue invariants', () {
    test('every course summary agrees with its own modules', () {
      for (final course in coursePool) {
        expect(
          course.modules,
          isNotEmpty,
          reason: '${course.title} has no curriculum',
        );

        final lectures = course.modules.fold<int>(
          0,
          (total, module) => total + module.lessons.length,
        );

        // The summary is authored copy, so it can drift from the data. These
        // two assertions are what stop it: the curriculum section derives its
        // counts from `modules`, so a stale summary would visibly contradict
        // the sections right beneath it.
        expect(
          course.curriculumSummary,
          contains('${course.modules.length} sections'),
          reason: '${course.title}: summary disagrees with module count',
        );
        expect(
          course.curriculumSummary,
          contains('$lectures lectures'),
          reason: '${course.title}: summary disagrees with lecture count',
        );

        for (final module in course.modules) {
          expect(
            module.lessons,
            isNotEmpty,
            reason: '${course.title} / ${module.title} would expand to nothing',
          );
        }
      }
    });

    test('every class chip has at least one course', () {
      // A chip that filters to nothing renders an empty state, which is
      // correct behaviour but looks broken as a shipped catalogue.
      for (final klass in [
        'Class 6',
        'Class 7',
        'Class 8',
        'Class 9',
        'Class 10',
      ]) {
        expect(
          coursePool.where((c) => c.classLevel == klass),
          isNotEmpty,
          reason: 'the $klass chip would render an empty grid',
        );
      }
    });
  });
}
