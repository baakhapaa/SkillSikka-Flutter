import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/features/courses/data/course_resources_api.dart';

/// The resource row and the wire parser behind the player's Resources tab.
///
/// The tab's own behaviour — lazy fetch, per-lesson filtering, the error state —
/// is covered in `course_player_page_test.dart`. This file pins the **contract**:
/// which fields a row carries, what a malformed row does, and what the row
/// prints.
void main() {
  group('parsing', () {
    test('reads the serializer shape', () {
      final row = tryParseCourseResource({
        'id': 7,
        'course': 3,
        'lesson': 11,
        'lesson_title': 'Line and shape',
        'section': 'Foundations',
        'title': 'Worksheet',
        'file_format': 'pdf',
        'file_url': 'https://example.com/a.pdf',
        'file_size_bytes': 2516582,
        'order': 1,
        'created_at': '2026-10-29T09:00:00Z',
      });

      expect(row, isNotNull);
      expect(row!.id, 7);
      expect(row.title, 'Worksheet');
      expect(row.type, CourseResourceType.pdf);
      expect(row.url, 'https://example.com/a.pdf');
      expect(row.lessonId, 11);
      expect(row.sizeBytes, 2516582);
      expect(row.isOpenable, isTrue);
    });

    test('a row with no id is not a row', () {
      expect(
        tryParseCourseResource({'title': 'Demo', 'file_format': 'pdf'}),
        isNull,
      );
      expect(tryParseCourseResource('nonsense'), isNull);
      expect(tryParseCourseResource(null), isNull);
    });

    test('a course-wide row has no lesson', () {
      final row = tryParseCourseResource({
        'id': 1,
        'title': 'Template',
        'file_format': 'zip',
        'file_url': 'https://example.com/t.zip',
        'lesson': null,
      });
      expect(row!.lessonId, isNull);
    });

    test('a row with no file_url is not openable', () {
      // The demo catalogue and an old bootcamp row can both land here. Tapping
      // one must not open a browser at an empty address.
      final row = tryParseCourseResource({
        'id': 2,
        'title': 'Reference card',
        'file_format': 'pdf',
        'file_url': '',
      });
      expect(row!.url, isNull);
      expect(row.isOpenable, isFalse);
    });

    test('a title that is not a string still yields a row', () {
      final row = tryParseCourseResource({
        'id': 3,
        'title': null,
        'file_format': 'docx',
        'file_url': 'https://example.com/a.docx',
      });
      expect(row!.title, 'Resource');
    });
  });

  group('file format', () {
    test('maps the server vocabulary onto a row style', () {
      const expected = {
        'pdf': CourseResourceType.pdf,
        'doc': CourseResourceType.doc,
        'docx': CourseResourceType.doc,
        'xls': CourseResourceType.xls,
        'xlsx': CourseResourceType.xls,
        'csv': CourseResourceType.xls,
        'zip': CourseResourceType.zip,
        'figma': CourseResourceType.figma,
        'svg': CourseResourceType.image,
        'link': CourseResourceType.link,
      };
      for (final entry in expected.entries) {
        expect(
          CourseResourceType.fromFormat(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('an unknown format falls back instead of throwing', () {
      // The server owns `FORMAT_CHOICES` and may add to it; a row must still
      // render.
      expect(CourseResourceType.fromFormat('exe'), CourseResourceType.other);
      expect(CourseResourceType.fromFormat(null), CourseResourceType.other);
      expect(CourseResourceType.fromFormat(7), CourseResourceType.other);
    });

    test('case and padding are tolerated', () {
      expect(CourseResourceType.fromFormat(' PDF '), CourseResourceType.pdf);
    });
  });

  group('row text', () {
    test('the subtitle prints the kind and the size', () {
      const row = CourseResource(
        'Workbook',
        CourseResourceType.xls,
        sizeBytes: 2516582,
      );
      expect(row.subtitle, 'XLS · 2.4 MB');
    });

    test('a row with no size prints only the kind', () {
      const row = CourseResource('Workbook', CourseResourceType.xls);
      expect(row.subtitle, 'XLS');
    });

    test('a zero or absent size is not printed as 0 B', () {
      expect(
        const CourseResource(
          'x',
          CourseResourceType.pdf,
          sizeBytes: 0,
        ).subtitle,
        'PDF',
      );
    });
  });
}
