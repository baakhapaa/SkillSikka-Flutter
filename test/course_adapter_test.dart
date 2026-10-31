import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/features/courses/data/course.dart';
import 'package:skillsikka/features/courses/data/course_adapter.dart';
import 'package:skillsikka/features/courses/data/course_api.dart';

/// Fixtures below are **captured from the running backend** on 2026-10-27
/// (`GET /courses/15/`, `GET /lessons/?course=15`, `GET /courses/14/reviews/`),
/// not written by hand — a fixture invented from the schema would have the
/// schema's mistakes baked in. Notably `average_rating` really is `null` here,
/// and `CourseReview.student` really is an object where the schema says string.
Map<String, dynamic> _course() => {
  'id': 15,
  'title': 'Drawing from Observation',
  'description': 'Learn drawing with practical activities.',
  'course_type': 'skill',
  'level': 'beginner',
  'language': 'English',
  'skill_category': 13,
  'skill_category_name': 'Drawing',
  'subject': null,
  'subject_name': null,
  'grade': null,
  'grade_name': null,
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
  'learning_outcomes': [
    'Explain the key ideas in Drawing from Observation.',
    'Apply the concepts in a guided practical activity.',
  ],
  'requirements': ['A notebook and a willingness to practice.'],
  'created_at': '2026-10-27T06:04:13.639471Z',
  'updated_at': '2026-10-27T06:04:13.639481Z',
};

Map<String, dynamic> _lesson(
  int id,
  String? section,
  int order, {
  String kind = 'video',
  bool preview = false,
}) => {
  'id': id,
  'section': section,
  'duration_seconds': 180 + order * 45,
  'is_preview': preview,
  'course': 15,
  'title': '$section: Activity $order',
  'content_type': kind,
  'content_url': kind == 'text' ? '' : 'https://example.com/$id.mp4',
  'content_text': kind == 'text' ? 'Do the thing.' : '',
  'order': order,
};

/// The seeded shape: three sections of three, ordered 1–9.
List<Map<String, dynamic>> _nineLessons() => [
  for (var order = 1; order <= 9; order++)
    _lesson(
      70 + order,
      const [
        'Foundations',
        'Guided Practice',
        'Apply Your Skills',
      ][(order - 1) ~/ 3],
      order,
      kind: const ['video', 'pdf', 'text'][(order - 1) % 3],
      preview: order == 1,
    ),
];

void main() {
  group('CourseMapper.summary', () {
    test('maps the card fields from a list row', () {
      final course = CourseMapper.summary(_course());

      expect(course.id, 15);
      expect(course.title, 'Drawing from Observation');
      expect(course.category, 'Drawing');
      expect(course.studentsEnrolled, '1 student enrolled');
    });

    test('an unreviewed course has no rating rather than a zero', () {
      final course = CourseMapper.summary(_course());

      // `Avg()` over no reviews is JSON null. Rendering it as 0.0 would claim
      // the course is rated badly, which is a different statement entirely.
      expect(course.rating, '');
      expect(course.ratingsCount, '(0 ratings)');
      expect(course.ratingBars, isEmpty);
    });

    test('accepts a numeric-string rating, which the schema promises', () {
      final course = CourseMapper.summary({
        ..._course(),
        'average_rating': '4.5',
        'review_count': '12',
      });

      expect(course.rating, '4.5');
      expect(course.ratingsCount, '(12 ratings)');
    });

    test('a paid course shows a formatted price, a free one does not', () {
      expect(
        CourseMapper.summary({
          ..._course(),
          'is_paid': true,
          'price': '1299.00',
        }).price,
        'Rs. 1,299',
      );
      expect(CourseMapper.summary(_course()).price, '');
    });

    test(
      'the card label says Free for a free course, blank if paid and unpriced',
      () {
        // `price` stays empty for a free course — it drives the detail screen's
        // bottom bar, which leads with total time instead. `priceLabel` is the
        // card's slot, and it states `Free` (product decision, 2026-10-31).
        final free = CourseMapper.summary(_course());
        expect(free.price, '');
        expect(free.priceLabel, 'Free');

        // A paid course whose price the API did not send must not be labelled
        // free — that would hand out a paid course.
        final unpriced = CourseMapper.summary({
          ..._course(),
          'is_paid': true,
          'price': null,
        });
        expect(unpriced.priceLabel, '');
        expect(unpriced.isPaid, isTrue);

        expect(
          CourseMapper.summary({
            ..._course(),
            'is_paid': true,
            'price': '1299.00',
          }).priceLabel,
          'Rs. 1,299',
        );
      },
    );

    test('an academic course labels itself by grade and subject', () {
      final course = CourseMapper.summary({
        ..._course(),
        'course_type': 'academic',
        'grade': 10,
        'grade_name': 'Grade 10',
        'subject': 3,
        'subject_name': 'English',
        'skill_category': null,
        'skill_category_name': null,
      });

      // The lede is the description now, so the grade/subject line only shows
      // for a course that has no description at all.
      expect(course.subtitle, 'Learn drawing with practical activities.');
      expect(course.classLevel, 'Grade 10');
      expect(course.category, 'English');
    });

    test(
      'the description is the lede, not a body in the Description section',
      () {
        final course = CourseMapper.summary(_course());

        expect(course.subtitle, 'Learn drawing with practical activities.');
        expect(
          course.descriptionBlocks.single.body,
          isNot(contains('Learn drawing')),
          reason: 'the section is the changelog, the lede is at the top',
        );
      },
    );

    test('the Description section is a Course Updates changelog', () {
      final course = CourseMapper.summary(_course());

      expect(course.descriptionIntro, 'Course Updates:');
      expect(course.descriptionBlocks.single.heading, 'v 1.0 - October 2026');
      expect(course.descriptionBlocks.single.body, 'First release.');
      // Nothing further to reveal, so the view hides "Show more".
      expect(course.descriptionMoreBlocks, isEmpty);
    });

    test('a course with no created_at gets no invented version', () {
      final course = CourseMapper.summary({..._course(), 'created_at': null});

      expect(course.descriptionBlocks, isEmpty);
      expect(
        course.descriptionIntro,
        isEmpty,
        reason: '`Course Updates:` over nothing reads as a broken section',
      );
    });

    test('a course with no description falls back to its category', () {
      final course = CourseMapper.summary({..._course(), 'description': '  '});

      expect(course.subtitle, 'Drawing');
    });

    test('level comes from the course record', () {
      // The instructor picks it in the builder and `Course.level` stores the
      // model's lowercase choice name; the card prints the capitalised label.
      expect(CourseMapper.summary(_course()).level, 'Beginner');
    });

    test('level is blank when the instructor never picked one', () {
      // Blank, not 'Beginner': a course with no level must not claim one.
      expect(CourseMapper.summary({..._course(), 'level': ''}).level, '');
      expect(CourseMapper.summary({..._course(), 'level': null}).level, '');
    });
  });

  group('CourseMapper.detail', () {
    test('pdf lessons are not lectures', () {
      final course = CourseMapper.detail(
        course: _course(),
        lessons: _nineLessons(),
      );

      expect(course.modules.map((m) => m.title), [
        'Foundations',
        'Guided Practice',
        'Apply Your Skills',
      ]);
      // The fixture cycles video/pdf/text: the pdf row is lifted out as a
      // resource, so each section keeps its video and its text lecture.
      expect(course.modules.every((m) => m.lessons.length == 2), isTrue);
      expect(
        course.modules.expand((m) => m.lessons).map((l) => l.title),
        isNot(contains('Foundations: Activity 2')),
      );
    });

    test('a pdf lesson becomes a resource, not a lecture', () {
      final course = CourseMapper.detail(
        course: _course(),
        lessons: _nineLessons(),
      );

      // Orders 2, 5, 8 are the pdf rows.
      expect(course.resources, hasLength(3));
      expect(course.resources.first.title, 'Foundations: Activity 2');
      expect(course.resources.first.type, CourseResourceType.pdf);
      expect(
        course.modules.expand((m) => m.lessons).map((l) => l.title),
        isNot(contains('Foundations: Activity 2')),
      );
    });

    test('durations survive as clock labels and section totals', () {
      final course = CourseMapper.detail(
        course: _course(),
        lessons: _nineLessons(),
      );

      // order 1 → 180 + 45 = 225s → 03:45
      expect(course.modules.first.lessons.first.duration, '03:45');
      // Video + text rows only: 225 + 315 = 540s → 9 mins (rounded)
      expect(course.modules.first.duration, '9 mins');
      // 3645s → 1hr 0min → '1hr'
      expect(course.totalTime, '1hr');
      expect(course.curriculumSummary, '3 sections · 6 lessons · 1hr');
    });

    test('the preview flag reaches the curriculum', () {
      final course = CourseMapper.detail(
        course: _course(),
        lessons: [
          _lesson(1, 'Foundations', 1, preview: true),
          _lesson(2, 'Foundations', 2),
        ],
      );

      expect(course.modules.first.lessons.first.isPreview, isTrue);
      expect(course.modules.first.lessons[1].isPreview, isFalse);
    });

    test('lessons with no section land in one container', () {
      final course = CourseMapper.detail(
        course: _course(),
        lessons: [_lesson(1, null, 1), _lesson(2, '  ', 2)],
      );

      expect(course.modules, hasLength(1));
      expect(course.modules.single.lessons, hasLength(2));
    });

    test('a course with no lessons still builds', () {
      final course = CourseMapper.detail(course: _course(), lessons: const []);

      expect(course.modules, isEmpty);
      expect(course.curriculumSummary, isEmpty);
      expect(course.totalTime, '1hr', reason: 'comes from the course total');
    });

    test('outcomes, requirements and the description reach the view', () {
      final course = CourseMapper.detail(course: _course(), lessons: const []);

      expect(course.learningOutcomes, hasLength(2));
      expect(course.requirements, hasLength(1));
      // The description lands in the lede under the title; the Description
      // section carries the changelog.
      expect(course.subtitle, contains('Learn drawing'));
      expect(course.descriptionIntro, 'Course Updates:');
      expect(course.descriptionBlocks, hasLength(1));
    });

    test('"This course includes" states the video length and the policy rows', () {
      final course = CourseMapper.detail(
        course: _course(),
        lessons: _nineLessons(),
      );

      // The video row is the course's own total (3645s); the three pdf rows are
      // the resource pack. The mobile/desktop/TV row was removed on 2026-10-30.
      expect(course.includes.map((i) => i.label), [
        '1hr of on-demand video',
        '3 support files',
        'Full lifetime access',
        'Certificate of completion',
      ]);
    });

    test('a pdf lesson is a resource, never a lecture row', () {
      // The earlier version printed `2 documents · 1 written lesson` — a
      // course shape that does not exist. A pdf is a *resource*; a text row is
      // not a file, so it stays a lecture rather than becoming one.
      final course = CourseMapper.detail(
        course: _course(),
        lessons: [
          _lesson(1, 'Foundations', 1, kind: 'pdf'),
          _lesson(2, 'Foundations', 2, kind: 'text'),
        ],
      );

      expect(
        course.modules.single.lessons.single.title,
        'Foundations: Activity 2',
      );
      expect(course.resources, hasLength(1));
      expect(course.includes.map((i) => i.label), contains('1 support file'));
      final labels = course.includes.map((i) => i.label);
      expect(labels.where((l) => l.contains('document')), isEmpty);
      expect(labels.where((l) => l.contains('written')), isEmpty);
    });

    test('with no lessons the total still fills the video row', () {
      // A list row carries `total_duration_seconds` but no lessons, so the
      // section is populated before the detail fetch lands.
      final course = CourseMapper.summary(_course());

      expect(course.includes.map((i) => i.label), [
        '1hr of on-demand video',
        'Full lifetime access',
        'Certificate of completion',
      ]);
    });

    test('the instructor card falls back to the course owner', () {
      final course = CourseMapper.detail(course: _course(), lessons: const []);

      expect(course.instructors.single.name, 'Test Instructor');
      expect(course.instructors.single.avatar, '');
    });

    test('a public instructor profile fills the card', () {
      final course = CourseMapper.detail(
        course: _course(),
        lessons: const [],
        instructor: {
          'id': 4,
          'name': 'Test Instructor',
          'profile_photo_url': 'https://example.com/a.jpg',
          'qualification': 'MSc Computer Science',
          'subject_expertise': 'Python, Django',
          'average_rating': 4.5,
          'review_count': 12,
          'total_students': 340,
          'total_courses': 5,
        },
      );

      final instructor = course.instructors.single;
      expect(instructor.avatar, 'https://example.com/a.jpg');
      expect(instructor.title, 'MSc Computer Science');
      expect(instructor.rating, '4.5');
      // **Bare numbers, because the card prints the label itself.** The first
      // version passed `'12 reviews'`, which rendered as `12 reviews` over the
      // word `Reviews` and wrapped `19 courses` onto two lines at 360pt.
      expect(instructor.reviews, '12');
      expect(instructor.students, '340');
      expect(instructor.courses, '5');
    });

    test('an instructor with no reviews prints a dash, not a blank cell', () {
      final course = CourseMapper.detail(
        course: _course(),
        lessons: const [],
        instructor: {
          'id': 4,
          'name': 'Test Instructor',
          'profile_photo_url': null,
          'qualification': 'MSc Computer Science',
          'subject_expertise': 'Python, Django',
          'average_rating': null,
          'review_count': 0,
          'total_students': 0,
          'total_courses': 1,
        },
      );

      expect(course.instructors.single.rating, '—');
      expect(course.instructors.single.reviews, '0');
    });
  });

  group('CourseMapper.detail — reviews', () {
    Map<String, dynamic> review(int rating, int daysAgo) => {
      'id': rating,
      'rating': rating,
      'review': 'Rating $rating',
      'student': {'id': 3, 'name': 'Test Student', 'profile_photo_url': null},
      'created_at': DateTime.now()
          .toUtc()
          .subtract(Duration(days: daysAgo))
          .toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    test('the nested student object becomes a name, not a stringified map', () {
      final course = CourseMapper.detail(
        course: _course(),
        lessons: const [],
        reviews: [review(5, 11)],
      );

      expect(course.reviews.single.name, 'Test Student');
      expect(course.reviews.single.stars, 5);
      expect(course.reviews.single.when, '11 days ago');
    });

    test('a string student is tolerated, because the schema says string', () {
      final course = CourseMapper.detail(
        course: _course(),
        lessons: const [],
        reviews: [
          {...review(4, 1), 'student': 'Someone'},
        ],
      );

      expect(course.reviews.single.name, 'Someone');
      expect(course.reviews.single.when, 'yesterday');
    });

    test('rating bars are derived from the reviews we were given', () {
      final course = CourseMapper.detail(
        course: _course(),
        lessons: const [],
        reviews: [review(5, 2), review(5, 3), review(1, 4), review(4, 5)],
      );

      expect(course.ratingBars, hasLength(5));
      // Highest first, and 2 of 4 reviews are five stars.
      expect(course.ratingBars.first.label, '5 ★');
      expect(course.ratingBars.first.percent, 50);
      expect(course.ratingBars.last.percent, 25);
    });
  });

  group('CoursePage', () {
    test('parses the paginated envelope', () {
      final page = CoursePage.tryParse({
        'count': 18,
        'next': 'http://127.0.0.1:8000/api/v1/courses/?page=2',
        'previous': null,
        'results': [_course()],
      });

      expect(page, isNotNull);
      expect(page!.count, 18);
      expect(page.hasMore, isTrue);
      expect(page.courses.single.title, 'Drawing from Observation');
    });

    test('a bare array is rejected rather than silently emptied', () {
      // `/lessons/` answers a bare array and `/courses/` an envelope. If the
      // envelope ever collapses, this must fail loudly instead of rendering
      // "no courses" over a perfectly good list.
      expect(CoursePage.tryParse([_course()]), isNull);
    });

    test('the last page has no next', () {
      final page = CoursePage.tryParse({
        'count': 1,
        'next': null,
        'previous': null,
        'results': [_course()],
      });

      expect(page!.hasMore, isFalse);
    });
  });

  group('CourseProgress', () {
    test('parses the measured shape', () {
      final progress = CourseProgress.tryParse({
        'course_id': 15,
        'total_lessons': 9,
        'completed_lessons': 3,
        'progress_percentage': 33.33,
        'is_completed': false,
      });

      expect(progress!.percentLabel, '33%');
      expect(progress.completedLessons, 3);
      expect(progress.isCompleted, isFalse);
    });

    test('a zero-lesson course is 0% and not complete', () {
      final progress = CourseProgress.tryParse({
        'course_id': 9,
        'total_lessons': 0,
        'completed_lessons': 0,
        'progress_percentage': 0.0,
        'is_completed': false,
      });

      expect(progress!.percentLabel, '0%');
    });
  });

  group('covers and the enrolment CTA', () {
    Map<String, dynamic> academic(String title, String subject) => {
      ..._course(),
      'course_type': 'academic',
      'title': title,
      'grade_name': 'Grade 9',
      'subject_name': subject,
      'skill_category': null,
      'skill_category_name': null,
      'thumbnail_url': '',
    };

    test('a missing thumbnail stays empty — no borrowed art', () {
      final course = CourseMapper.summary(
        academic('Grade 9: Matter and Chemical Reactions', 'Science'),
      );

      // **This used to substitute a stock illustration matched by keyword.** A
      // course called `paytest` in the Coding category came out with the Python
      // logo — a cover its instructor never uploaded, and not the tile the
      // builder previews for the same course. Empty is the honest answer: the
      // card draws the generated initials tile instead (see `CourseImage`).
      expect(course.image, '');
    });

    test('a real thumbnail is used as it is', () {
      final course = CourseMapper.summary({
        ...academic('Grade 10: Geometry and Trigonometry', 'Mathematics'),
        'thumbnail_url': 'https://example.com/geometry.png',
      });

      expect(course.image, 'https://example.com/geometry.png');
    });

    test('a subject the app has no art for is no different', () {
      final course = CourseMapper.summary(
        academic('Grade 10: Reading and Writing with Confidence', 'English'),
      );

      // Every course without a cover is in the same state now — there is no
      // "matched" and "unmatched" any more, just a cover or the tile.
      expect(course.image, '');
    });

    test('an academic course offers Start Learning, not Enroll Now', () {
      final course = CourseMapper.summary(
        academic('Grade 9: Matter and Chemical Reactions', 'Science'),
      );

      // `POST /courses/{id}/enroll/` answers COURSE_NOT_ENROLLABLE for anything
      // that is not a skill course, so this label is the client half of a rule
      // the server already enforces.
      expect(course.isAcademic, isTrue);
      expect(course.enrollLabel, 'Start Learning');
      expect(CourseMapper.summary(_course()).enrollLabel, 'Enroll Now');
    });
  });

  group('courseMetaRows', () {
    test('an API course shows level and language beside the update date', () {
      // Level and language are both authored in the course builder and stored on
      // `Course`, so an API course fills the same rows the bundled catalogue
      // does. There is no subtitle row at all — it was removed on 2026-10-30.
      final rows = courseMetaRows(CourseMapper.summary(_course()));

      expect(rows.map((row) => row.text), [
        'Last updated 10/2026',
        'Beginner',
        'English',
      ]);
      expect(rows.first.icon, contains('alert-circle'));
      expect(rows[1].icon, contains('award'));
      expect(rows[1].semanticsLabel, 'Course level');
      expect(rows[2].icon, contains('language'));
      expect(rows[2].semanticsLabel, 'Available languages');
    });

    test('a course with no level omits the row rather than inventing one', () {
      final rows = courseMetaRows(
        CourseMapper.summary({..._course(), 'level': ''}),
      );

      expect(rows.map((row) => row.text), ['Last updated 10/2026', 'English']);
    });

    test('the level is capitalised from the wire choice name', () {
      // The model stores `beginner`; the screen prints `Beginner`. Doing it here
      // rather than on the server means the label can be reworded without a
      // migration.
      expect(
        CourseMapper.summary({..._course(), 'level': 'advanced'}).level,
        'Advanced',
      );
      expect(
        CourseMapper.summary({..._course(), 'level': 'intermediate'}).level,
        'Intermediate',
      );
    });

    test('the bundled catalogue fills the same three rows as the API', () {
      // Three, not four. The CC/subtitle row was removed on 2026-10-30: no
      // backend field ever fed it, so its only content was the catalogue's
      // hardcoded `CC English [Auto]` — and it disappeared the moment the same
      // course arrived from the API. The catalogue must not be able to claim a
      // row a real course cannot.
      final rows = courseMetaRows(coursePool.first);

      expect(rows, hasLength(3));
      expect(rows[1].text, 'Beginner');
      expect(rows[1].semanticsLabel, 'Course level');
      expect(rows[2].text, contains('English'));
      expect(rows[2].semanticsLabel, 'Available languages');
      expect(rows.where((row) => row.icon.contains('cc.svg')), isEmpty);
    });

    test('a course with nothing to say produces no rows', () {
      final rows = courseMetaRows(
        const CourseDetailData(
          image: '',
          title: 'Untitled',
          subtitle: '',
          rating: '',
          level: '',
          category: '',
          ratingsCount: '',
          studentsEnrolled: '',
          instructorName: '',
          instructorAvatar: '',
          lastUpdated: '',
          languages: '',
          learningOutcomes: <String>[],
          curriculumSummary: '',
          modules: <CourseModule>[],
          includes: <CourseInclude>[],
          requirements: <String>[],
          descriptionBlocks: <CourseDescriptionBlock>[],
          descriptionMoreBlocks: <CourseDescriptionBlock>[],
          instructors: <CourseInstructor>[],
          courseRating: '',
          ratingBars: <RatingBar>[],
          reviews: <CourseReview>[],
          totalTime: '',
        ),
      );

      // The whole block collapses, rather than three empty icons.
      expect(rows, isEmpty);
    });
  });

  group('CourseEnrollment', () {
    test('a free enrolment is active and grants access', () {
      final enrollment = CourseEnrollment.tryParse({
        'id': 12,
        'course': 15,
        'course_title': 'Drawing from Observation',
        'status': 'active',
        'amount_paid': null,
        'enrolled_at': '2026-10-27T06:04:13.639471Z',
        'completed_at': null,
      });

      expect(enrollment!.grantsAccess, isTrue);
      expect(enrollment.awaitsPayment, isFalse);
    });

    test('a paid enrolment waits for payment and grants nothing', () {
      final enrollment = CourseEnrollment.tryParse({
        'id': 13,
        'course': 20,
        'status': 'pending_payment',
      });

      // This is the state that must not open the player.
      expect(enrollment!.grantsAccess, isFalse);
      expect(enrollment.awaitsPayment, isTrue);
    });

    test('a body without ids is rejected', () {
      expect(CourseEnrollment.tryParse({'status': 'active'}), isNull);
    });
  });
}
