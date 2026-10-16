import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/features/courses/data/course.dart';
import 'package:skillsikka/features/courses/presentation/course_details_page.dart';
import 'package:skillsikka/features/home/presentation/home_page.dart';
import 'package:skillsikka/features/skill_courses/data/skill_course.dart';
import 'package:skillsikka/features/skill_courses/presentation/skill_course_detail_page.dart';
import 'package:skillsikka/features/skill_courses/presentation/skill_courses.dart';

import 'support/events_test_scope.dart';
import 'support/home_page_font_harness.dart';

/// Titles used for whole-string assertions.
///
/// **Whole strings, never `textContaining`.** `coursePool` and `skillCoursePool`
/// deliberately share vocabulary — `Machine Learning`, the instructor
/// `Kelsey Hightower`, and the `skillcourse11.png` thumbnail all appear in both —
/// so a substring that looks distinctive is not. Only an exact title is.
const _pythonTitle = 'Python for Beginners: Complete Bootcamp 2024';
const _typescriptTitle = 'TypeScript Advanced Patterns';
const _sketchingTitle = 'Sketching Foundations: Line, Light & Form';
const _guitarTitle = 'Guitar for Absolute Beginners';

CourseDetailData _course(String title) =>
    skillCoursePool.firstWhere((c) => c.title == title);

/// Covers the Skill Courses tab's detail page and the shared `CourseDetailView`
/// it renders.
///
/// **Why nothing here pumps a course with a `bannerVideoAsset`.** That would
/// make `CourseDetailView.initState` construct a `VideoPlayerController`, and
/// `video_player` has no platform implementation under `flutter test` — the
/// failure arrives asynchronously as an uncatchable `MissingPluginException`.
/// Every entry in `skillCoursePool` has a null `bannerVideoAsset`, so the whole
/// feature is testable; the premium screen's video path is not, and is covered
/// by inspection (see `course_detail_page_test.dart`).
void main() {
  installHomePageFontHarness();

  Future<void> pumpAtPhoneSize(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(child);
    await tester.pump();
  }

  testWidgets('tapping a carousel card opens the detail page for it', (
    tester,
  ) async {
    await pumpAtPhoneSize(tester, const MaterialApp(home: SkillCoursesPage()));
    drainUnrelatedOverflows(tester);

    // `Coding` is selected by default and its first three lead the carousel, so
    // this title is on the page twice: once in the carousel and once in the list
    // below it. The carousel is built first, so `.first` is the carousel card.
    await tester.tap(find.text(_pythonTitle).first);
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);

    expect(
      find.byType(SkillCourseDetailPage),
      findsOneWidget,
      reason: "the carousel's View button used to be a no-op",
    );
    // The subtitle is detail-only, so it proves the push rendered *this* course
    // rather than the tap being swallowed.
    expect(find.text(_course(_pythonTitle).subtitle), findsOneWidget);
  });

  testWidgets('tapping a list card opens the detail page for it', (
    tester,
  ) async {
    await pumpAtPhoneSize(tester, const MaterialApp(home: SkillCoursesPage()));
    drainUnrelatedOverflows(tester);

    // TypeScript is not one of Coding's first three, so its title is unique to
    // the list — no `.first` disambiguation needed.
    final card = find.text(_typescriptTitle);
    expect(card, findsOneWidget);

    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);

    expect(find.byType(SkillCourseDetailPage), findsOneWidget);
    expect(find.text(_course(_typescriptTitle).subtitle), findsOneWidget);
  });

  testWidgets(
    'the detail page renders the course it was given, not a fixed one',
    (tester) async {
      // Not the pool's first entry, so an accidental `skillCoursePool.first`
      // hardcoding shows up here.
      final course = _course(_sketchingTitle);
      await pumpAtPhoneSize(
        tester,
        MaterialApp(home: SkillCourseDetailPage(course: course)),
      );
      drainUnrelatedOverflows(tester);

      expect(find.text(course.title), findsOneWidget);
      expect(find.text(course.subtitle), findsOneWidget);
      // A Coding course must not leak in — this is what proves the page is
      // parameterized rather than a static mirror.
      expect(find.text(_pythonTitle), findsNothing);
    },
  );

  testWidgets('a paid course leads the bottom bar with its price', (
    tester,
  ) async {
    final course = _course(_sketchingTitle);
    await pumpAtPhoneSize(
      tester,
      MaterialApp(home: SkillCourseDetailPage(course: course)),
    );
    drainUnrelatedOverflows(tester);

    expect(find.text('TOTAL PRICE'), findsOneWidget);
    expect(find.text(course.price), findsOneWidget);
    // A paid course does not also show the duration: the label and the value
    // always describe the same thing.
    expect(find.text('TOTAL TIME'), findsNothing);
    expect(find.text(course.totalTime), findsNothing);
  });

  testWidgets('a skill chip filters both the carousel and the list', (
    tester,
  ) async {
    await pumpAtPhoneSize(tester, const MaterialApp(home: SkillCoursesPage()));
    drainUnrelatedOverflows(tester);

    // Unfiltered (Coding), the Coding lead is on screen and the Drawing one is
    // not.
    expect(find.text(_pythonTitle), findsWidgets);
    expect(find.text(_sketchingTitle), findsNothing);

    // 'Drawing' is the second chip, so it is on screen without scrolling.
    await tester.tap(find.text('Drawing'));
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);

    expect(find.text(_sketchingTitle), findsWidgets);
    expect(
      find.text(_pythonTitle),
      findsNothing,
      reason: 'a Coding course survived a Drawing filter',
    );
  });

  testWidgets('the tab opens on the skill it was handed', (tester) async {
    // The home rail's skill cards push this page with a skill, so tapping
    // "Music" must land on Music rather than on the first chip.
    await pumpAtPhoneSize(
      tester,
      const MaterialApp(home: SkillCoursesPage(initialSkill: 'Music')),
    );
    await tester.pump();
    drainUnrelatedOverflows(tester);

    expect(find.text(_guitarTitle), findsWidgets);
    expect(find.text(_pythonTitle), findsNothing);

    // Music is the fourth chip and sits off screen at 360pt, so the row has to
    // scroll itself — otherwise the skill would be selected but invisible.
    final chip = tester.getRect(find.text('Music'));
    expect(chip.left, greaterThanOrEqualTo(0.0));
    expect(chip.right, lessThanOrEqualTo(360.0));
  });

  testWidgets('a home skill card opens the tab on that skill', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // HomePage's events rail reaches for `geolocator`, which neither completes
    // nor throws under `flutter test` — unstubbed it hangs the test rather than
    // failing it. See `eventsTestScope`.
    await tester.pumpWidget(
      eventsTestScope(child: const MaterialApp(home: HomePage())),
    );
    await tester.pump();
    drainUnrelatedOverflows(tester);

    // The rail sits below the fold. **Not `tester.ensureVisible`** — it
    // top-aligns, and HomePage's header is a `Stack` overlay, so the card would
    // land underneath it and the header would swallow the tap.
    final card = find.text('Drawing');
    await Scrollable.ensureVisible(tester.element(card), alignment: 0.5);
    await tester.pump();
    expect(
      tester.getRect(card).top,
      greaterThan(100),
      reason: 'the card is still under the fixed header',
    );

    await tester.tap(card);
    // **Not `pumpAndSettle`** — HomePage runs a `Timer.periodic(4s)` for the
    // promo banner, so time never runs out of scheduled frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    drainUnrelatedOverflows(tester);

    expect(find.byType(SkillCoursesPage), findsOneWidget);
    expect(find.text(_sketchingTitle), findsWidgets);
    expect(
      find.text(_pythonTitle),
      findsNothing,
      reason: 'the home card did not preselect its own skill',
    );

    // Dispose HomePage so its promo timer is cancelled — a timer still pending
    // when the test ends fails it.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a free course keeps TOTAL TIME and shows no price', (
    tester,
  ) async {
    // The shared model gained an optional price for the paid catalogues. This
    // guards the free one: the class catalogue sets none, so its bottom bar must
    // still lead with the duration.
    final course = coursePool.first;
    await pumpAtPhoneSize(
      tester,
      MaterialApp(home: CourseDetailPage(course: course)),
    );
    drainUnrelatedOverflows(tester);

    expect(find.textContaining('Rs.'), findsNothing);
    expect(find.text('TOTAL TIME'), findsOneWidget);
    expect(find.text('TOTAL PRICE'), findsNothing);
    expect(find.text(course.totalTime), findsOneWidget);
    expect(find.text('Enroll Now'), findsOneWidget);
  });

  group('skill catalogue invariants', () {
    const skills = ['Coding', 'Drawing', 'Public Speaking', 'Music'];

    test('every skill chip has at least three courses', () {
      // Three is what the carousel shows, so a skill below three would render a
      // short carousel and an empty-looking highlight.
      for (final skill in skills) {
        expect(
          skillCoursePool.where((c) => c.category == skill).length,
          greaterThanOrEqualTo(3),
          reason: 'the $skill chip would render an empty or short carousel',
        );
      }
    });

    test('every course is tagged with one of the four chip labels', () {
      // The chips filter on `category` by exact match, so a typo or a new skill
      // would silently empty a chip.
      for (final course in skillCoursePool) {
        expect(
          skills,
          contains(course.category),
          reason: '${course.title} is tagged ${course.category}',
        );
      }
    });

    test('no skill course carries a class level', () {
      // Skill courses are not part of the class-filtered catalogue; `classLevel`
      // is left empty on purpose.
      for (final course in skillCoursePool) {
        expect(course.classLevel, isEmpty, reason: course.title);
      }
    });

    test('every course summary agrees with its own modules', () {
      for (final course in skillCoursePool) {
        expect(
          course.modules,
          isNotEmpty,
          reason: '${course.title} has no curriculum',
        );

        final lectures = course.modules.fold<int>(
          0,
          (total, module) => total + module.lessons.length,
        );

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
  });
}
