import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/course_detail_view.dart';

/// The Resources tab's wire client.
///
/// `GET /courses/{id}/resources/` shipped as a bootcamp-only endpoint: the
/// resolver filtered `course_type='bootcamp'`, so every course the builder can
/// create answered 404 and the tab rendered a list derived from `pdf` lessons.
/// Since 2026-10-29 the same endpoint serves any published course and each row
/// may belong to one lesson.
///
/// Three contract details, all read off `core/bootcamp_views.py`:
///
/// 1. The list answers a **bare array**, unlike `/discussions/`, which is a
///    paginated envelope. `pagination_class = None` on the view.
/// 2. Reading requires **access** — an active/completed enrollment, or staff —
///    so a preview watcher gets `403 NOT_ENROLLED`, not an empty list. The tab
///    has to tell "no files" apart from "not allowed", which is why [list]
///    throws rather than returning `[]`.
/// 3. `?lesson=<id>` filters server-side, but the tab holds the whole pack
///    anyway and filters locally, so one request covers every lesson.
class CourseResourcesApi {
  const CourseResourcesApi(this._client);

  final ApiClient _client;

  /// `GET /courses/{id}/resources/`, optionally narrowed to one lesson.
  ///
  /// Answers 403 `NOT_ENROLLED` for a student without access and 403
  /// `COURSE_NOT_PUBLISHED` for an unpublished course.
  Future<List<CourseResource>> list(int courseId, {int? lessonId}) async {
    final body = await _client.get<Object?>(
      '/courses/$courseId/resources/',
      query: lessonId == null ? null : {'lesson': lessonId},
    );
    if (body is! List) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'The resources came back in an unexpected shape.',
      );
    }
    return [for (final row in body) ?tryParseCourseResource(row)];
  }

  /// `POST /courses/{id}/resources/` — 201 with the created row.
  ///
  /// Allowed for the course owner, a roster instructor or an administrator;
  /// an enrolled student gets 403 `NOT_COURSE_OWNER`. The file itself is
  /// uploaded separately through `POST /courses/{id}/assets/` with
  /// `kind: 'resource'`, and [fileUrl] is what that answered.
  Future<CourseResource> create(
    int courseId, {
    required String title,
    required String fileUrl,
    required String fileFormat,
    int? lessonId,
    int? sizeBytes,
    int? order,
  }) async {
    final body = await _client.post<Object?>(
      '/courses/$courseId/resources/',
      data: {
        'title': title,
        'file_url': fileUrl,
        'file_format': fileFormat,
        'lesson': ?lessonId,
        'file_size_bytes': ?sizeBytes,
        'order': ?order,
      },
    );
    final created = tryParseCourseResource(body);
    if (created == null) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'That file came back in an unexpected shape.',
      );
    }
    return created;
  }

  /// `DELETE /courses/{id}/resources/{resourceId}/` — 204.
  Future<void> remove(int courseId, int resourceId) =>
      _client.delete('/courses/$courseId/resources/$resourceId/');
}

/// Parses one row of `GET /courses/{id}/resources/`.
///
/// Returns null for a row with no id, which is the same "not a real row"
/// convention `CourseThread.tryParse` uses — a demo-catalogue entry has an id
/// of null and must never be mistaken for a server row.
CourseResource? tryParseCourseResource(Object? value) {
  if (value is! Map) return null;
  final id = value['id'];
  if (id is! int) return null;
  final url = value['file_url'];
  final lesson = value['lesson'];
  final size = value['file_size_bytes'];
  return CourseResource(
    value['title'] is String ? (value['title'] as String).trim() : 'Resource',
    CourseResourceType.fromFormat(value['file_format']),
    id: id,
    url: url is String && url.trim().isNotEmpty ? url.trim() : null,
    lessonId: lesson is int ? lesson : null,
    sizeBytes: size is int ? size : null,
    section: value['section'] is String
        ? (value['section'] as String).trim()
        : '',
  );
}

final courseResourcesApiProvider = Provider<CourseResourcesApi>(
  (ref) => CourseResourcesApi(ref.watch(apiClientProvider)),
);
