import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/course_detail_view.dart' show CourseResource;
import 'course_draft.dart';
import 'course_resources_api.dart' show tryParseCourseResource;

/// Writes for the course builder.
///
/// Reads and writes go through [ApiClient], so every failure arrives as an
/// `ApiException` the page can show — no `DioException` translation happens at
/// the call site.
///
/// **The wire now carries the whole course.** Backend commit `ed3a273` added
/// `section`, `duration_seconds` and `is_preview` to `Lesson`, and
/// `skill_category`, `learning_outcomes` and `requirements` to `Course`. This
/// client additionally sends `level`, `language` and `thumbnail_url`, which need
/// the two columns and the upload route described in
/// `docs/backend-ask-course-builder-completion-2026-10-28.md`.
class CourseBuilderApi {
  const CourseBuilderApi(this._client);

  final ApiClient _client;

  /// `POST /courses/` — creates the draft.
  ///
  /// The server forces `instructor = request.user` and `is_published = false`
  /// regardless of what is sent, so neither is in the payload: asking for them
  /// would be a request the backend silently ignores, which reads like a bug the
  /// first time someone debugs it.
  Future<int> createCourse(CourseDraft draft) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/courses/',
      data: _coursePayload(draft),
    );
    final id = body['id'];
    if (id is! int) {
      throw StateError('POST /courses/ returned no id: $body');
    }
    return id;
  }

  /// `PATCH /courses/{id}/` — the metadata, without touching publication.
  Future<void> updateCourse(int courseId, CourseDraft draft) async {
    await _client.patch<Map<String, dynamic>>(
      '/courses/$courseId/',
      data: _coursePayload(draft),
    );
  }

  /// `PATCH /courses/{id}/ {"is_published": true}`.
  ///
  /// Split from [updateCourse] because the server treats it differently: this is
  /// the only write that checks the instructor's verification status, and a 403
  /// from here means "your account", not "your course". Keeping it a separate
  /// call lets the page say which.
  Future<void> publishCourse(int courseId) async {
    await _client.patch<Map<String, dynamic>>(
      '/courses/$courseId/',
      data: {'is_published': true},
    );
  }

  /// `PATCH /courses/{id}/ {"is_published": false}` — back to a draft.
  ///
  /// The mirror of [publishCourse], and the reason it is not a second call to
  /// it: taking a course down runs no checklist. It keeps its lessons, files and
  /// enrolments; students simply stop seeing it, and re-publishing goes through
  /// the builder again.
  Future<void> unpublishCourse(int courseId) async {
    await _client.patch<Map<String, dynamic>>(
      '/courses/$courseId/',
      data: {'is_published': false},
    );
  }

  /// `DELETE /courses/{id}/` — the course, its lessons and its files.
  ///
  /// Irreversible, so every caller confirms first.
  Future<void> deleteCourse(int courseId) =>
      _client.delete('/courses/$courseId/');

  /// `POST /lessons/` — returns the new lesson's id.
  ///
  /// [order] is global across the whole course, not per module, because that is
  /// what the server stores. The caller computes it from the module layout so the
  /// flat sequence still matches what the instructor sees.
  ///
  /// [section] is the module's name. The server stores it on the lesson as a
  /// plain string — there is no module table — so the grouping survives only as
  /// long as every lesson in a module carries the same value.
  Future<int> createLesson({
    required int courseId,
    required CourseLesson lesson,
    required int order,
    String? section,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/lessons/',
      data: _lessonPayload(
        lesson,
        courseId: courseId,
        order: order,
        section: section,
      ),
    );
    final id = body['id'];
    if (id is! int) {
      throw StateError('POST /lessons/ returned no id: $body');
    }
    return id;
  }

  Future<void> updateLesson({
    required CourseLesson lesson,
    required int order,
    String? section,
  }) async {
    final id = lesson.id;
    if (id == null) {
      throw StateError('updateLesson called on an unsaved lesson');
    }
    await _client.patch<Map<String, dynamic>>(
      '/lessons/$id/',
      data: _lessonPayload(lesson, order: order, section: section),
    );
  }

  Future<void> deleteLesson(int lessonId) =>
      _client.delete('/lessons/$lessonId/');

  /// `GET /courses/{id}/` plus `GET /lessons/?course={id}`.
  ///
  /// Two calls because the curriculum is a separate collection. Returns null when
  /// the course is not visible to this user — the server answers 404 for an
  /// unpublished course that is not yours, and that is a "not found", not an
  /// error worth a red screen.
  Future<CourseDraft?> loadCourse(int courseId) async {
    final course = await _client.get<Map<String, dynamic>>(
      '/courses/$courseId/',
    );
    final lessons = await _client.get<List<dynamic>>(
      '/lessons/',
      query: {'course': courseId},
    );
    return CourseDraft.fromServer(course, [
      for (final row in lessons)
        if (row is Map<String, dynamic>) row,
    ]);
  }

  /// Uploads the 16:9 cover and returns the URL to store in `thumbnail_url`.
  ///
  /// Same route as a lesson asset, told apart by `kind` — the server files both
  /// under the course, and one endpoint means one place that validates a type
  /// and a size. The caller patches `thumbnail_url` afterwards with the URL it
  /// gets back, so a failed metadata save cannot leave a cover pointing at a
  /// course that never changed.
  Future<String> uploadCover({
    required int courseId,
    required Uint8List bytes,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) => uploadCourseAsset(
    courseId: courseId,
    kind: 'cover',
    bytes: bytes,
    fileName: fileName,
    onProgress: onProgress,
  );

  /// Uploads one lesson asset and returns the URL to store in `content_url`.
  Future<String> uploadLessonAsset({
    required int courseId,
    required Uint8List bytes,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) => uploadCourseAsset(
    courseId: courseId,
    kind: 'lesson',
    bytes: bytes,
    fileName: fileName,
    onProgress: onProgress,
  );

  /// Uploads one **resource** file — a worksheet, a template, a starter pack.
  ///
  /// A third `kind`, not a lesson asset: the lesson list is a
  /// video/pdf/epub list and a 500 MB cap on a spreadsheet is a mistake waiting
  /// to happen. The server accepts documents and archives up to 25 MB here.
  Future<String> uploadResourceAsset({
    required int courseId,
    required Uint8List bytes,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) => uploadCourseAsset(
    courseId: courseId,
    kind: 'resource',
    bytes: bytes,
    fileName: fileName,
    onProgress: onProgress,
  );

  /// `POST /courses/{id}/assets/` with `files` repeated — **one request for a
  /// whole pick**, not one per file.
  ///
  /// Answers a list the same length as [files], position for position: the URL
  /// the server stored, or null when that particular file was refused. The
  /// server echoes an `index` with each asset precisely so this mapping needs no
  /// guesswork about duplicate filenames.
  ///
  /// **A refusal is per file, not per batch.** Five worksheets where the fourth
  /// is over the 25 MB cap come back as four URLs and one null, which is what
  /// lets the sheet keep what worked and name what did not.
  Future<List<String?>> uploadCourseAssets({
    required int courseId,
    required String kind,
    required List<PickedFile> files,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (files.isEmpty) return const <String?>[];
    final body = await _client.postMultipart<Map<String, dynamic>>(
      '/courses/$courseId/assets/',
      fields: {'kind': kind},
      fileLists: {
        'files': [
          for (final file in files)
            filePart(bytes: file.bytes, fileName: file.fileName),
        ],
      },
      onSendProgress: onProgress,
    );

    final urls = List<String?>.filled(files.length, null);
    final assets = body['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is! Map) continue;
        final index = asset['index'];
        final url = asset['url'];
        if (index is! int || index < 0 || index >= urls.length) continue;
        if (url is! String || url.trim().isEmpty) continue;
        urls[index] = url.trim();
      }
    }
    return urls;
  }

  /// `GET /courses/{id}/resources/` — the course-wide and per-lesson files.
  ///
  /// A **bare array**, unlike `/courses/` and `/discussions/`, because the view
  /// sets `pagination_class = None`. Reading requires access, but a course's own
  /// manager is exempt: that is what makes this usable on a draft, which is the
  /// whole point of listing resources in the builder.
  Future<List<CourseResource>> listResources(int courseId) async {
    final rows = await _client.get<List<dynamic>>(
      '/courses/$courseId/resources/',
    );
    return [for (final row in rows) ?tryParseCourseResource(row)];
  }

  /// `POST /courses/{id}/resources/` — attaches an uploaded file to a lesson.
  ///
  /// [lessonId] is what makes it per-lesson; null leaves a course-wide row, the
  /// shape every bootcamp pack has. [fileUrl] is what [uploadResourceAsset]
  /// answered, and [fileFormat] is the server's own vocabulary (`pdf`, `docx`,
  /// `xlsx`, `zip`, …).
  ///
  /// Called *after* `POST /lessons/`, because the row needs the lesson id and
  /// the lesson does not exist until that answers.
  Future<int> createResource({
    required int courseId,
    required String title,
    required String fileUrl,
    required String fileFormat,
    int? lessonId,
    int? sizeBytes,
    int? order,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
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
    final id = body['id'];
    if (id is! int) {
      throw StateError(
        'POST /courses/$courseId/resources/ returned no id: $body',
      );
    }
    return id;
  }

  Future<void> deleteResource({
    required int courseId,
    required int resourceId,
  }) => _client.delete('/courses/$courseId/resources/$resourceId/');

  /// `POST /courses/{id}/assets/` — multipart, field `file`, plus `kind`.
  ///
  /// [kind] is `cover`, `lesson` or `resource`. The course id is required rather
  /// than a lesson id because a lesson's file has to be uploaded *before* the
  /// lesson row exists: the sheet uploads on save, and the id is only minted by
  /// the `POST /lessons/` that follows.
  Future<String> uploadCourseAsset({
    required int courseId,
    required String kind,
    required Uint8List bytes,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    final body = await _client.postMultipart<Map<String, dynamic>>(
      '/courses/$courseId/assets/',
      fields: {'kind': kind},
      files: {'file': filePart(bytes: bytes, fileName: fileName)},
      onSendProgress: onProgress,
    );
    final url = body['url'] ?? body['asset_url'] ?? body['file_url'];
    if (url is! String || url.trim().isEmpty) {
      throw StateError('Asset upload returned no URL: $body');
    }
    return url.trim();
  }

  /// `GET /grades/` and `GET /subjects/` — the two lists an academic course
  /// needs before it can be saved.
  ///
  /// Both are bare arrays. Subjects is empty on today's backend (only an admin
  /// can create one), which the picker reports as an empty state rather than
  /// pretending the list is still loading.
  Future<List<(int, String)>> loadGrades() => _reference('/grades/');

  Future<List<(int, String)>> loadSubjects() => _reference('/subjects/');

  /// `GET /learning-interests/` — the skill categories.
  ///
  /// This is the list the Category picker offers, and its ids are what
  /// `skill_category` takes. Fifteen rows today, including the three that were
  /// added for the Skill tab's chips (`Drawing`, `Public Speaking`, `Music`).
  Future<List<(int, String)>> loadCategories() =>
      _reference('/learning-interests/');

  /// `GET /premium-categories/` — the **premium** categories.
  ///
  /// A different list from [loadCategories], not a subset of it. The skill list
  /// is the student's own interest taxonomy (the signup step reads it), so a
  /// premium course must be filed under its own set: Art & Craft, Design,
  /// Physics, Business, Technology, Music on a fresh database.
  Future<List<(int, String)>> loadPremiumCategories() =>
      _reference('/premium-categories/');

  Future<List<(int, String)>> _reference(String path) async {
    final rows = await _client.get<List<dynamic>>(path);
    return [
      for (final row in rows)
        if (row is Map<String, dynamic> && row['id'] is int)
          (row['id'] as int, (row['name'] as String?) ?? ''),
    ];
  }

  /// The writable course fields, and nothing else.
  ///
  /// `instructor` and `is_published` are read-only / forced server-side, which
  /// is why publication is its own call — see [publishCourse].
  Map<String, Object?> _coursePayload(CourseDraft draft) {
    final isAcademic = draft.kind == CourseKind.academic;
    // **A premium course is paid, whatever the draft says.** `copyWith` forces
    // it, but a draft built by the raw constructor can still carry `isPaid:
    // false` — and the server rejects premium + free outright, so sending it
    // would be a request we know will 400.
    final paid = draft.isPaid || draft.kind.isAlwaysPaid;
    return {
      'title': draft.title.trim(),
      'description': draft.description.trim(),
      'course_type': draft.kind.wire,
      // The serializer nulls both for a skill course and requires both for an
      // academic one. Sending them explicitly keeps the request honest about
      // which course type it is creating.
      'subject': isAcademic ? draft.subjectId : null,
      'grade': isAcademic ? draft.gradeId : null,
      'is_paid': paid,
      // **Null until the price is typed**, and that is valid: the server now
      // requires a price to *publish*, not to save. It used to require one
      // here, which made every premium course impossible to create — step 1
      // posts `is_paid: true` with no amount, because the price field is on
      // step 3.
      'price': paid ? _priceWire(draft) : null,
      // The id, never the name. `skill_category` is a FK to LearningInterest, so
      // a name is silently ignored — and the course then appears under no Skill
      // chip on the student side. Null for an academic course, which is valid.
      'skill_category': isAcademic ? null : draft.skillCategoryId,
      // **A different table.** A premium course is filed under
      // `premium_category` (`PremiumCategory`), never `skill_category` — the
      // server nulls whichever one does not belong to the course type.
      'premium_category': draft.kind.isAlwaysPaid
          ? draft.premiumCategoryId
          : null,
      // The server trims entries, rejects blanks and caps each at 500 chars, so
      // it is the authority on validity — we send what the instructor typed.
      'learning_outcomes': draft.outcomes,
      'requirements': draft.requirements,
      // Null when the instructor left the level alone. The server column is
      // nullable and the student card simply omits the label.
      'level': draft.level?.name,
      // One string, not a list: `Course.language` is a CharField, and the detail
      // screen prints whatever it holds.
      'language': draft.language.trim().isEmpty
          ? CourseDraft.defaultLanguage
          : draft.language.trim(),
      // The uploaded cover's URL, or `''` when there is none. **Never null**:
      // `thumbnail_url` is `URLField(blank=True)` without `null=True`, so a
      // JSON null is a 400 while an empty string is a valid "no cover". Sending
      // the draft's value on every save is also what carries an existing cover
      // through an edit, and what deletes it when the instructor removes it.
      'thumbnail_url': draft.coverUrl ?? '',
    };
  }

  String? _priceWire(CourseDraft draft) {
    final value = draft.parsedPrice;
    if (value == null || value <= 0) return null;
    return value.toStringAsFixed(2);
  }

  /// The writable lesson fields.
  ///
  /// `section`, `duration_seconds` and `is_preview` are the three that make a
  /// saved curriculum reload intact. [section] comes from the caller because a
  /// lesson does not know which module it is in — the page does.
  Map<String, Object?> _lessonPayload(
    CourseLesson lesson, {
    int? courseId,
    required int order,
    String? section,
  }) {
    final isText = lesson.kind.usesBody;
    return {
      'course': ?courseId,
      'title': lesson.title.trim(),
      'content_type': lesson.kind.wire,
      // The serializer requires a URL for every non-text type and inline text
      // for `text`. Sending `''` rather than null for the unused half is what the
      // model expects — both fields are `blank=True`.
      'content_url': isText ? '' : (lesson.contentUrl ?? '').trim(),
      'content_text': isText ? (lesson.contentText ?? '').trim() : '',
      'order': order,
      // Nullable on the server. A course built before sections existed reads back
      // with `section: null`, and sending null keeps that state rather than
      // inventing a name.
      'section': section,
      // Null when the instructor has not filled the duration in; the server
      // stores it as nullable and `total_duration_seconds` ignores it.
      'duration_seconds': lesson.duration?.inSeconds,
      'is_preview': lesson.isPreview,
    };
  }
}

final courseBuilderApiProvider = Provider<CourseBuilderApi>(
  (ref) => CourseBuilderApi(ref.watch(apiClientProvider)),
);
