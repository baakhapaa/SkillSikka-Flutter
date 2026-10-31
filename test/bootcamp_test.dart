import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/features/bootcamp/data/bootcamp.dart';

/// A `GET /courses/{id}/` row for a bootcamp, with the profile flattened on it
/// exactly the way `CourseSerializer.to_representation` does.
Map<String, dynamic> bootcampRow({
  int id = 7,
  String title = 'ICT & AI BOOTCAMP at Sundarbazar',
  int days = 4,
  int students = 12400,
  String status = 'upcoming',
}) => {
  'id': id,
  'title': title,
  'description':
      'Master the foundations of design strategy, brand framework '
      'design, and digital delivery systems.',
  'course_type': 'bootcamp',
  'is_paid': false,
  'price': null,
  'is_published': true,
  'thumbnail_url': 'https://cdn.example.com/card.png',
  'level': 'beginner',
  'language': 'English',
  'students_enrolled': students,
  'venue_name': 'Sundarbazar',
  'days': days,
  'starts_on': '2026-11-16',
  'ends_on': '2026-11-19',
  'status': status,
  'episode_no': 2,
  'short_description': 'Four days of strategy, brand and delivery.',
  'hero_video_url': 'https://cdn.example.com/hero.mp4',
  'hero_poster_url': 'https://cdn.example.com/hero.jpg',
  'quality_label': 'HD',
  'view_count': 2500,
  'instructors': [
    {'id': 4, 'name': 'Shuvanga Karki', 'role': 'lead'},
    {'id': 5, 'name': 'Amrit Bhandari', 'role': 'coach'},
  ],
};

Map<String, dynamic> lessonRow({
  required int id,
  required int day,
  required String section,
  required String title,
  required int order,
  int duration = 1125,
  bool completed = false,
  String? url = 'https://cdn.example.com/lesson.mp4',
  String type = 'video',
}) => {
  'id': id,
  'title': title,
  'section': section,
  'day_number': day,
  'duration_seconds': duration,
  'content_type': type,
  'content_url': url,
  'content_text': '',
  'is_preview': false,
  'is_completed': completed,
  'order': order,
};

void main() {
  group('BootcampDetail.fromWire', () {
    BootcampDetail build({
      List<Map<String, dynamic>>? lessons,
      List<CourseResource> resources = const [],
      Map<String, dynamic>? course,
    }) => BootcampDetail.fromWire(
      course: course ?? bootcampRow(),
      lessons:
          lessons ??
          [
            lessonRow(
              id: 1,
              day: 1,
              section: 'Foundations',
              title: 'Demo',
              order: 1,
            ),
            lessonRow(
              id: 2,
              day: 1,
              section: 'Foundations',
              title: 'Defining the Product Strategy Grid',
              order: 2,
            ),
            lessonRow(
              id: 3,
              day: 2,
              section: 'Design & Prototyping',
              title: 'Wireframing for Mobile Interfaces',
              order: 1,
            ),
          ],
      resources: resources,
    );

    test('reads the profile fields the design prints', () {
      final camp = build();

      expect(camp.title, 'ICT & AI BOOTCAMP at Sundarbazar');
      expect(camp.venueName, 'Sundarbazar');
      expect(camp.durationDays, 4);
      expect(camp.runLabel, '4 days');
      expect(camp.qualityLabel, 'HD');
      expect(camp.episodeNo, 2);
      expect(camp.studentsLabel, '12.4k students');
      expect(camp.statusLabel, 'Upcoming');
      expect(camp.isLive, isFalse);
      expect(camp.releasedLabel, 'Nov 2026');
      expect(camp.dateRangeLabel, '16 – 19 Nov 2026');
      expect(camp.instructorLine, 'Shuvanga Karki, Amrit Bhandari');
      expect(camp.lede, 'Four days of strategy, brand and delivery.');
    });

    test(
      'groups the curriculum by day, then by section, numbering across days',
      () {
        final camp = build();

        expect(camp.days.map((day) => day.number), [1, 2]);
        expect(camp.days.first.label, 'Day 1');
        expect(camp.days.first.sections.single.title, 'Foundations');
        expect(
          camp.days.first.sections.single.lessons.map((lesson) => lesson.title),
          ['Demo', 'Defining the Product Strategy Grid'],
        );
        // The number is the row's place in the whole camp, as the design has it —
        // not its position inside the day.
        expect(
          [
            for (final day in camp.days)
              for (final s in day.sections)
                for (final l in s.lessons) l.number,
          ],
          [1, 2, 3],
        );
        expect(camp.days.first.sections.single.lessons.first.duration, '18:45');
        expect(camp.lessonCount, 3);
      },
    );

    test('a lesson with no section still renders, under one unnamed group', () {
      final camp = build(
        lessons: [
          lessonRow(
            id: 1,
            day: 1,
            section: '',
            title: 'Loose lesson',
            order: 1,
          ),
        ],
      );

      expect(camp.days.single.sections.single.title, '');
      expect(
        camp.days.single.sections.single.lessons.single.title,
        'Loose lesson',
      );
    });

    test('groups the resource pack by section', () {
      final camp = build(
        lessons: const [],
        resources: const [
          CourseResource(
            'Grid Template',
            CourseResourceType.pdf,
            id: 1,
            url: 'https://cdn.example.com/grid.pdf',
            section: 'Section 1: Course Materials',
          ),
          CourseResource(
            'Wireframing Kit',
            CourseResourceType.figma,
            id: 2,
            url: 'https://cdn.example.com/kit',
            section: 'Section 2: Design Tools',
          ),
          CourseResource('Handbook', CourseResourceType.pdf, id: 3),
        ],
      );

      expect(camp.fileSections.map((section) => section.title), [
        'Section 1: Course Materials',
        'Section 2: Design Tools',
        '',
      ]);
      expect(camp.fileSections.first.files.single.type, CourseResourceType.pdf);
      expect(camp.fileSections[1].files.single.type, CourseResourceType.figma);
    });

    test('a locked lesson has no URL, and says so', () {
      final camp = build(
        lessons: [
          lessonRow(
            id: 1,
            day: 1,
            section: 'Foundations',
            title: 'Locked',
            order: 1,
            url: null,
          ),
        ],
      );

      final lesson = camp.days.single.sections.single.lessons.single;
      expect(lesson.contentUrl, isNull);
      expect(lesson.isPlayable, isFalse);
    });

    test('a camp with no profile fields still parses', () {
      final camp = build(
        course: {'id': 9, 'title': 'Bare camp'},
        lessons: const [],
      );

      expect(camp.id, 9);
      expect(camp.title, 'Bare camp');
      expect(camp.runLabel, '0 days');
      expect(camp.studentsLabel, 'No students yet');
      expect(camp.days, isEmpty);
      expect(camp.instructorNames, isEmpty);
      expect(camp.instructorLine, '—');
    });

    test('the student count is pluralised', () {
      expect(
        build(course: bootcampRow(students: 1)).studentsLabel,
        '1 student',
      );
      expect(
        build(course: bootcampRow(students: 2)).studentsLabel,
        '2 students',
      );
      expect(
        build(course: bootcampRow(students: 0)).studentsLabel,
        'No students yet',
      );
    });
  });

  group('BootcampCard', () {
    test('reads the row the home rail receives', () {
      final card = BootcampCard.tryParse(bootcampRow())!;

      expect(card.id, 7);
      expect(card.venueName, 'Sundarbazar');
      expect(card.days, 4);
      expect(card.image, 'https://cdn.example.com/hero.jpg');
      expect(card.viewLabel, '2.5K VIEWS');
    });

    test('falls back to the card image, then to nothing', () {
      final posterless = BootcampCard.tryParse({
        ...bootcampRow(),
        'hero_poster_url': '',
      })!;
      expect(posterless.image, 'https://cdn.example.com/card.png');

      final bare = BootcampCard.tryParse({
        ...bootcampRow(),
        'hero_poster_url': '',
        'thumbnail_url': '',
      })!;
      // Empty is the signal for the rail to draw its bundled artwork.
      expect(bare.image, '');
      expect(bare.viewLabel, '2.5K VIEWS');
    });

    test('a camp nobody has watched prints its run instead of views', () {
      final card = BootcampCard.tryParse({...bootcampRow(), 'view_count': 0})!;
      expect(card.viewLabel, '4 DAYS');
    });

    test('a row with no id is not a camp', () {
      expect(BootcampCard.tryParse({'title': 'x'}), isNull);
      expect(BootcampCard.tryParse(null), isNull);
    });
  });

  group('formatting', () {
    test('compactCount', () {
      expect(compactCount(980), '980');
      expect(compactCount(12400), '12.4k');
      expect(compactCount(20000), '20k');
      expect(compactCount(1250000), '1.3m');
    });

    test('clock', () {
      expect(clock(1125), '18:45');
      expect(clock(3725), '01:02:05');
      expect(clock(null), '');
      expect(clock(0), '');
    });

    test('monthYear', () {
      expect(monthYear(DateTime(2026, 10, 24)), 'Oct 2026');
    });
  });
}
