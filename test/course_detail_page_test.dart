import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/features/courses/data/course.dart';
import 'package:skillsikka/features/courses/data/course_adapter.dart';
import 'package:skillsikka/features/courses/data/course_api.dart';
import 'package:skillsikka/features/courses/presentation/course_details_page.dart';
import 'package:skillsikka/features/courses/presentation/courses.dart';
import 'package:skillsikka/features/courses/presentation/widgets/review_sheet.dart';
import 'package:skillsikka/features/home/presentation/home_page.dart';
import 'package:skillsikka/features/learning/presentation/course_player_page.dart';
import 'package:skillsikka/features/profile/data/profile_completeness.dart';

import 'support/courses_test_scope.dart';
import 'support/events_test_scope.dart';
import 'support/home_page_font_harness.dart';

/// A `GET /courses/` row, in the field names the server actually sends.
Map<String, dynamic> tabRow({
  required int id,
  required String title,
  required int grade,
}) => {
  'id': id,
  'title': title,
  'description': 'Learn by doing.',
  'course_type': 'academic',
  'level': 'intermediate',
  'language': 'English',
  'subject': 1,
  'subject_name': 'Mathematics',
  'grade': grade,
  'grade_name': 'Grade $grade',
  'is_paid': false,
  'price': null,
  'thumbnail_url': '',
  'is_published': true,
  'average_rating': 4.5,
  'review_count': 8,
  'students_enrolled': 120,
  'lessons_count': 9,
  'total_duration_seconds': 3600,
  'instructor': 4,
  'instructor_name': 'Test Instructor',
  'learning_outcomes': <String>[],
  'requirements': <String>[],
};

/// Covers the course-detail screen and the shared `CourseDetailView` it renders,
/// from both entry points that reach it: the Courses tab's grid and the home
/// screen's "Courses" rail.
///
/// **`PremiumCourseDetailsPage` is no longer excluded.** It used to carry a
/// `bannerVideoAsset`, so `CourseDetailView.initState` built a
/// `VideoPlayerController` whose `initialize()` fails with a
/// `MissingPluginException` under `flutter test` — an async failure with no
/// handler, which fails the test outright. The trailer was removed on
/// 2026-10-30 (premium now matches a skill course, which shows its cover), so
/// the premium screen renders without the video plugin and is pumped in
/// `premium_detail_page_test.dart`.
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
    final course = CourseMapper.summary(
      tabRow(id: 1, title: 'Class Six Maths', grade: 6),
    );
    final api = FakeCourseApi(
      catalogue: CoursePage(count: 1, courses: [course]),
    );

    await pumpAtPhoneSize(
      tester,
      coursesTestScope(
        api: api,
        grades: fakeGrades(),
        child: const MaterialApp(home: AllCoursesPage()),
      ),
    );
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);

    final card = find.text('Class Six Maths').first;
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
      // `coursesTestScope` too: the card carries a real course id, so tapping it
      // makes the detail page fetch `/courses/{id}/`. Without a stub that is a
      // real HTTP call, which `flutter test` answers 400 — the page would still
      // render the row it was given, but the test would be relying on a
      // production fallback and printing a Dio dump.
      coursesTestScope(
        api: FakeCourseApi(),
        child: eventsTestScope(
          academic: [coursePool.first],
          child: const MaterialApp(home: HomePage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    // The rail slides the cards in. A tap during that slide hits the position
    // the card is leaving, not the card.
    await tester.pump(const Duration(milliseconds: 400));
    drainUnrelatedOverflows(tester);

    // The rail shows the academic courses it was given. This test supplies the
    // catalogue's first course, which is what the card must open.
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

  testWidgets('the Description section is a changelog, not the description', (
    tester,
  ) async {
    // The description belongs in the lede under the title, and the Description
    // section carries `Course Updates:` — the shape every catalogue entry and
    // the premium screen have. Swapping them put a marketing blurb under a
    // changelog heading.
    final course = CourseMapper.summary({
      ...tabRow(id: 1, title: 'Class Six Maths', grade: 6),
      // No id ⇒ the page paints this summary and fetches nothing.
      'id': null,
      'created_at': '2026-10-27T06:04:13Z',
      'updated_at': '2026-10-27T06:04:13Z',
    });

    await pumpAtPhoneSize(
      tester,
      ProviderScope(
        child: MaterialApp(home: CourseDetailPage(course: course)),
      ),
    );
    drainUnrelatedOverflows(tester);

    expect(find.text('Learn by doing.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Learn by doing.')).dy,
      lessThan(tester.getTopLeft(find.text("What you'll learn")).dy),
      reason: 'the description is the lede, above the first section',
    );

    expect(find.text('Course Updates:'), findsOneWidget);
    expect(find.text('v 1.0 - October 2026'), findsOneWidget);
    expect(find.text('First release.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Course Updates:')).dy,
      greaterThan(tester.getTopLeft(find.text('Description')).dy),
      reason: 'the changelog is inside the Description section',
    );

    // One block and no more to reveal, so the toggle would open onto nothing.
    expect(find.text('Show more'), findsNothing);
  });

  testWidgets('"This course includes" is filled from the course', (
    tester,
  ) async {
    // It used to be a heading over an empty white block on every API course:
    // the adapter mapped `includes` to `const []` because the backend has no
    // column for it.
    final course = CourseMapper.detail(
      course: {
        ...tabRow(id: 1, title: 'Class Six Maths', grade: 6),
        'id': null,
        'total_duration_seconds': 600,
        'created_at': '2026-10-27T06:04:13Z',
        'updated_at': '2026-10-27T06:04:13Z',
      },
      lessons: [
        {
          'id': 1,
          'section': 'Foundations',
          'title': 'First marks',
          'content_type': 'video',
          'duration_seconds': 600,
          'order': 1,
        },
      ],
    );

    await pumpAtPhoneSize(
      tester,
      ProviderScope(
        child: MaterialApp(home: CourseDetailPage(course: course)),
      ),
    );
    drainUnrelatedOverflows(tester);

    expect(find.text('This course includes'), findsOneWidget);
    expect(find.text('10min of on-demand video'), findsOneWidget);
    expect(find.text('Full lifetime access'), findsOneWidget);
    expect(find.text('Certificate of completion'), findsOneWidget);
    // A lesson is always a video; PDFs are resources, so no lesson may ever
    // produce a document or written row.
    expect(find.textContaining('document'), findsNothing);
    expect(find.textContaining('written'), findsNothing);
  });

  testWidgets('an API course shows level and language under the update date', (
    tester,
  ) async {
    // Both rows are authored in the course builder and stored on `Course`, so an
    // API course fills the same rows the bundled catalogue does. There is no
    // subtitle row any more — it was removed on 2026-10-30.
    final course = CourseMapper.summary({
      ...tabRow(id: 1, title: 'Class Six Maths', grade: 6),
      'id': null,
      'created_at': '2026-10-27T06:04:13Z',
      'updated_at': '2026-10-27T06:04:13Z',
    });

    await pumpAtPhoneSize(
      tester,
      ProviderScope(
        child: MaterialApp(home: CourseDetailPage(course: course)),
      ),
    );
    drainUnrelatedOverflows(tester);

    expect(find.text('Intermediate'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Intermediate')).dy,
      greaterThan(tester.getTopLeft(find.text('Last updated 10/2026')).dy),
      reason: 'the level sits under the update date, as in the design',
    );
    expect(
      tester.getTopLeft(find.text('English')).dy,
      greaterThan(tester.getTopLeft(find.text('Intermediate')).dy),
      reason: 'level then language, in the order `courseMetaRows` builds them',
    );
    // No CC/subtitle row at all, for either data source. It was removed on
    // 2026-10-30; the adapter-level assertion lives in `course_adapter_test.dart`.
    expect(find.textContaining('Subtitles'), findsNothing);
    expect(find.textContaining('CC English'), findsNothing);
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
    final six = CourseMapper.summary(
      tabRow(id: 1, title: 'Class Six Maths', grade: 6),
    );
    final ten = CourseMapper.summary(
      tabRow(id: 2, title: 'Class Ten Maths', grade: 10),
    );
    final api = FakeCourseApi(
      catalogue: CoursePage(count: 2, courses: [six, ten]),
    );

    await pumpAtPhoneSize(
      tester,
      coursesTestScope(
        api: api,
        grades: fakeGrades(),
        child: const MaterialApp(home: AllCoursesPage()),
      ),
    );
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);

    // Unfiltered, both classes are on screen.
    expect(find.text('Class Six Maths'), findsWidgets);
    expect(find.text('Class Ten Maths'), findsWidgets);

    // 'Class 6' is the second chip, so it is on screen without scrolling the
    // chip row — the last chip is not, at 360pt.
    await tester.tap(find.text('Class 6'));
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);

    expect(find.text('Class Six Maths'), findsWidgets);
    expect(
      find.text('Class Ten Maths'),
      findsNothing,
      reason: 'a Class 10 course survived a Class 6 filter',
    );
    // The chip sent the grade id, which is what the server filters on.
    expect(api.lastGradeId, 6);
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

  group('student feedback', () {
    /// An API course nobody has reviewed — the state the screenshot showed as a
    /// blank block with a stranded `course rating` label.
    CourseDetailData unreviewed({int id = 99}) => CourseMapper.detail(
      course: {
        ...tabRow(id: id, title: 'Fresh Course', grade: 6),
        'average_rating': null,
        'review_count': 0,
        'students_enrolled': 0,
      },
      lessons: const [],
    );

    /// Scrolls [finder] into the middle of the viewport before tapping.
    ///
    /// `tester.ensureVisible` top-aligns, which puts a target near the bottom of
    /// this page underneath the sticky enrol bar — the tap then misses and only
    /// prints a warning.
    Future<void> reveal(WidgetTester tester, Finder finder) async {
      await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
      await tester.pumpAndSettle();
    }

    testWidgets('no reviews renders an empty state, not a blank block', (
      tester,
    ) async {
      await pumpAtPhoneSize(
        tester,
        MaterialApp(
          home: CourseDetailView(data: unreviewed(), onEnrol: () async {}),
        ),
      );
      drainUnrelatedOverflows(tester);

      expect(find.text('No reviews yet'), findsOneWidget);
      // The summary that used to render as `''` over this label is gone
      // entirely — a lone "course rating" under a blank space is the bug.
      expect(find.text('course rating'), findsNothing);
      // …and the header meta row says so instead of drawing a star over nothing.
      expect(find.text('No ratings yet'), findsOneWidget);
      // Nothing to rate with: the catalogue/premium path has no endpoint.
      expect(find.text('Write a review'), findsNothing);
    });

    testWidgets('an enrolled student can rate the course and submit it', (
      tester,
    ) async {
      final api = FakeCourseApi();
      await pumpAtPhoneSize(
        tester,
        MaterialApp(
          home: Builder(
            builder: (context) => CourseDetailView(
              data: unreviewed(),
              onEnrol: () async {},
              onWriteReview: () =>
                  openCourseReview(context, api: api, courseId: 99),
            ),
          ),
        ),
      );
      drainUnrelatedOverflows(tester);

      await reveal(tester, find.text('Write a review'));
      await tester.tap(find.text('Write a review'));
      await tester.pumpAndSettle();

      expect(find.text('Rate this course'), findsOneWidget);
      expect(find.text('Tap a star to rate'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('review-star-4')));
      await tester.pump();
      expect(find.text('Very good'), findsOneWidget);

      await tester.tap(find.text('Submit review'));
      await tester.pumpAndSettle();

      expect(api.submitted.single.courseId, 99);
      expect(api.submitted.single.rating, 4);
      expect(api.updated, isEmpty);
    });

    testWidgets('an existing review opens prefilled and updates instead', (
      tester,
    ) async {
      final api = FakeCourseApi()
        ..myReviewValue = {'id': 1, 'rating': 5, 'review': 'Loved it'};
      await pumpAtPhoneSize(
        tester,
        MaterialApp(
          home: Builder(
            builder: (context) => CourseDetailView(
              data: unreviewed(),
              onEnrol: () async {},
              hasReviewed: true,
              onWriteReview: () =>
                  openCourseReview(context, api: api, courseId: 99),
            ),
          ),
        ),
      );
      drainUnrelatedOverflows(tester);

      await reveal(tester, find.text('Edit your review'));
      await tester.tap(find.text('Edit your review'));
      await tester.pumpAndSettle();

      // Prefilled from `GET /courses/{id}/reviews/me/`, and the submit is a
      // PATCH rather than a POST that would answer REVIEW_EXISTS.
      expect(find.text('Loved it'), findsOneWidget);
      expect(find.text('Update review'), findsOneWidget);

      await tester.tap(find.text('Update review'));
      await tester.pumpAndSettle();

      expect(api.updated.single.rating, 5);
      expect(api.updated.single.review, 'Loved it');
      expect(api.submitted, isEmpty);
    });

    testWidgets('the real page probes progress and offers the review control', (
      tester,
    ) async {
      // The in-session enrolment store is empty on a cold start, so the page
      // asks `GET /courses/{id}/progress/` — the same enrolment rule the review
      // endpoint enforces — rather than hiding the control from a student who
      // enrolled yesterday.
      final api = FakeCourseApi()..detailValue = unreviewed();
      await pumpAtPhoneSize(
        tester,
        coursesTestScope(
          api: api,
          child: MaterialApp(
            home: CourseDetailPage(
              course: CourseMapper.summary(
                tabRow(id: 99, title: 'Fresh Course', grade: 6),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      drainUnrelatedOverflows(tester);

      expect(find.text('Write a review'), findsOneWidget);
    });

    testWidgets('the instructor stats are bare numbers, as the design draws '
        'them', (tester) async {
      // The adapter used to hand the card `19 courses`, so the card printed the
      // unit twice and the value wrapped onto two lines at 360pt.
      final course = CourseMapper.detail(
        course: tabRow(id: 7, title: 'Stats Course', grade: 6),
        lessons: const [],
        instructor: {
          'id': 4,
          'name': 'Test Instructor',
          'profile_photo_url': null,
          'qualification': 'MSc Computer Science',
          'subject_expertise': 'Python, Django',
          'average_rating': 1.5,
          'review_count': 2,
          'total_students': 2,
          'total_courses': 19,
        },
      );

      await pumpAtPhoneSize(
        tester,
        MaterialApp(
          home: CourseDetailView(data: course, onEnrol: () async {}),
        ),
      );
      drainUnrelatedOverflows(tester);

      expect(find.text('19'), findsOneWidget);
      expect(find.text('Courses'), findsOneWidget);
      expect(find.text('19 courses'), findsNothing);
      expect(find.text('2 reviews'), findsNothing);
    });
  });
}
