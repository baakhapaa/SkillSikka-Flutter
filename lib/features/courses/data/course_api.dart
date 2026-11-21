import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/course_detail_view.dart';
import '../../profile/data/reference_data.dart';
import 'course_adapter.dart';
import 'instructor_analytics.dart';

/// Reads and writes the course endpoints.
///
/// Every route is JWT-authenticated; the bearer token is attached by the
/// interceptor on [ApiClient]'s `Dio`, so nothing here deals with auth.
///
/// **Three contract details this is built around**, all measured against the
/// running backend on 2026-10-27 rather than read off the schema:
///
/// 1. `GET /courses/` answers a **paginated envelope** (`{count, next, previous,
///    results}`), while `/lessons/`, `/courses/{id}/reviews/` and
///    `/my-enrollments/` answer **bare arrays**. Same API, two shapes — hence
///    [CoursePage] here and plain lists elsewhere.
/// 2. `POST /courses/{id}/enroll/` answers **201 with an `Enrollment` body**, not
///    the 200-with-nothing the schema used to claim.
/// 3. Errors carry a stable `code` (`ALREADY_ENROLLED`, `NOT_ENROLLED`,
///    `COURSE_NOT_FOUND`, …). [ApiException.code] surfaces it, and the UI should
///    branch on that rather than on [ApiException.message], which is prose.
class CourseApi {
  const CourseApi(this._client);

  final ApiClient _client;

  /// `GET /courses/` — the catalogue.
  ///
  /// [grade] and [skillCategory] take **ids**, never the chip labels. An unknown
  /// query value is silently ignored by the server, so sending `Class 6` where it
  /// wants `6` returns the whole catalogue and looks like the filter worked.
  Future<CoursePage> list({
    String? courseType,
    int? subject,
    int? grade,
    int? instructor,
    int? skillCategory,
    bool? isPaid,
    String? search,
    String? ordering,
    int? page,
    int? pageSize,
  }) {
    return _page(
      '/courses/',
      query: {
        'course_type': ?courseType,
        'subject': ?subject,
        'grade': ?grade,
        'instructor': ?instructor,
        'skill_category': ?skillCategory,
        'is_paid': ?isPaid,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'ordering': ?ordering,
        'page': ?page,
        'page_size': ?pageSize,
      },
    );
  }

  /// Fetches an absolute `next` URL exactly as the server sent it.
  ///
  /// It already carries every filter and the page number, so rebuilding it would
  /// be a second place for the two to disagree. dio treats an absolute URL as
  /// absolute and ignores `baseUrl`; the interceptor still attaches the token,
  /// and the URL is same-origin.
  Future<CoursePage> nextPage(String url) => _page(url);

  /// One course, fully assembled: detail + lessons + reviews + instructor.
  ///
  /// The course and its lessons are required — without them there is no screen.
  /// Reviews and the instructor profile are **best effort**: a detail page that
  /// got the course should still render if the reviews call fails, and
  /// `/instructors/{id}/` 404s for an instructor who has no published course yet.
  Future<CourseDetailData> detail(int id) async {
    // Started together so the two required calls overlap; awaited in order so
    // the course's own 404 surfaces before a lessons failure can mask it.
    final courseCall = _client.get<Map<String, dynamic>>('/courses/$id/');
    final lessonsCall = _client.get<List<dynamic>>(
      '/lessons/',
      query: {'course': id},
    );
    final course = await courseCall;
    final lessons = _rows(await lessonsCall);

    final reviews = await _rowsOrEmpty('/courses/$id/reviews/');
    final instructor = await _instructorOrNull(course['instructor']);

    return CourseMapper.detail(
      course: course,
      lessons: lessons,
      reviews: reviews,
      instructor: instructor,
    );
  }

  /// `GET /courses/{id}/reviews/` — the rows, with ids.
  ///
  /// Separate from [detail] because the edit/delete calls address a review the
  /// presentational model has no id for.
  Future<List<Map<String, dynamic>>> reviews(int courseId) =>
      _rowsOrEmpty('/courses/$courseId/reviews/');

  /// `GET /courses/{courseId}/progress/` — 403 `NOT_ENROLLED` when not enrolled.
  Future<CourseProgress> progress(int courseId) async {
    final body = await _client.get<Map<String, dynamic>>(
      '/courses/$courseId/progress/',
    );
    final progress = CourseProgress.tryParse(body);
    if (progress == null) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'That progress came back in an unexpected shape.',
      );
    }
    return progress;
  }

  /// `POST /courses/{courseId}/enroll/` — 201 with the enrolment.
  ///
  /// A paid course enrols into `pending_payment`, which grants no lesson access;
  /// the caller has to branch on [CourseEnrollment.awaitsPayment] rather than
  /// treating any 201 as "you can start learning".
  ///
  /// [source] is optional: `direct`, `organic`, `social`, or `unknown`. Omitting
  /// it is `unknown`. Anything else is `400`.
  Future<CourseEnrollment> enroll(int courseId, {String? source}) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/courses/$courseId/enroll/',
      data: source == null ? null : {'source': source},
    );
    final enrollment = CourseEnrollment.tryParse(body);
    if (enrollment == null) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'The enrolment came back in an unexpected shape.',
      );
    }
    return enrollment;
  }

  /// `GET /courses/{courseId}/enrollment/` — this student's enrolment, or null.
  ///
  /// **`enroll()` cannot answer this.** It refuses a second call with
  /// `ALREADY_ENROLLED` whatever the row's status, so a student who enrolled in
  /// a paid course and never paid looks identical to one who paid, from there.
  /// Only the status separates them, and only this endpoint reports it.
  ///
  /// The endpoint answers **404 when there is no enrolment**, which is the common
  /// case for a course nobody has started and is not an error.
  Future<CourseEnrollment?> enrollmentFor(int courseId) async {
    try {
      final body = await _client.get<Map<String, dynamic>>(
        '/courses/$courseId/enrollment/',
      );
      return CourseEnrollment.tryParse(body);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  /// `GET /courses/{id}/instructor-analytics/?period=`.
  ///
  /// Course owner or admin. `period` is `7d`, `30d`, `90d`, or `all`; omitted
  /// on the server means `30d`. Null fields are not recorded. Zero is a real zero.
  Future<InstructorCourseAnalytics> instructorAnalytics(
    int courseId, {
    String period = '30d',
  }) async {
    final body = await _client.get<Map<String, dynamic>>(
      '/courses/$courseId/instructor-analytics/',
      query: {'period': period},
    );
    final analytics = InstructorCourseAnalytics.tryParse(body);
    if (analytics == null) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'Those analytics came back in an unexpected shape.',
      );
    }
    return analytics;
  }

  /// `POST /lessons/{lessonId}/progress/` — seconds watched since the last report.
  ///
  /// [watchedSeconds] is 1–120. The server may credit fewer than were sent.
  Future<void> reportLessonProgress(
    int lessonId, {
    required int watchedSeconds,
    required int positionSeconds,
  }) async {
    final watched = watchedSeconds.clamp(1, 120);
    await _client.post<Object?>(
      '/lessons/$lessonId/progress/',
      data: {
        'watched_seconds': watched,
        'position_seconds': positionSeconds < 0 ? 0 : positionSeconds,
      },
    );
  }

  /// `POST /lessons/{lessonId}/complete/` — records the completion.
  ///
  /// Side effects on the server: the streak advances and badges are evaluated,
  /// so this is not a no-op even when the local UI already shows the tick.
  Future<void> completeLesson(int lessonId) async {
    await _client.post<Object?>('/lessons/$lessonId/complete/');
  }

  /// The id of the lesson this course should resume on, per the server.
  ///
  /// **`/courses/{id}/progress/` reports counts only** — it never says *which*
  /// lessons are done. The one place the server names a lesson is
  /// `continue_learning.next_lesson`, which My Learning computes as the first
  /// lesson in `order` that is not complete. That also makes the inverse exact:
  /// every lesson before it *is* complete.
  ///
  /// Returns null when the course is absent from My Learning — not enrolled, or
  /// `pending_payment`, which that endpoint excludes — and when nothing is left
  /// to resume.
  Future<int?> nextLessonId(int courseId) async {
    final body = await _client.get<Map<String, dynamic>>('/my-learning/');

    final rows = <Map<String, dynamic>>[
      if (body['continue_learning'] case final Map<String, dynamic> row) row,
      ..._rowsOf(body['courses']),
      ..._rowsOf(body['completed_courses']),
    ];

    for (final row in rows) {
      final course = row['course'];
      if (course is! Map || course['id'] != courseId) continue;
      final next = row['next_lesson'];
      if (next is Map && next['id'] is int) return next['id'] as int;
      return null;
    }
    return null;
  }

  static List<Map<String, dynamic>> _rowsOf(Object? value) => value is List
      ? [
          for (final row in value)
            if (row is Map<String, dynamic>) row,
        ]
      : const [];

  /// `GET /courses/{courseId}/reviews/me/` — this student's own review, or null.
  ///
  /// The endpoint answers **404 when there is none**, which is the common case
  /// and not an error: it is what tells the screen whether to offer `Write a
  /// review` or `Edit your review`, and it is where the sheet's initial stars
  /// and text come from.
  Future<Map<String, dynamic>?> myReview(int courseId) async {
    try {
      return await _client.get<Map<String, dynamic>>(
        '/courses/$courseId/reviews/me/',
      );
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.notFound) return null;
      rethrow;
    }
  }

  /// `POST /courses/{courseId}/reviews/` — one review per student.
  ///
  /// A second attempt answers 400 `REVIEW_EXISTS`; [updateReview] is the edit
  /// path.
  Future<void> submitReview(
    int courseId, {
    required int rating,
    String review = '',
  }) async {
    await _client.post<Object?>(
      '/courses/$courseId/reviews/',
      data: {'rating': rating, 'review': review},
    );
  }

  /// `PATCH /courses/{courseId}/reviews/me/` — edit your own review.
  Future<void> updateReview(
    int courseId, {
    required int rating,
    String review = '',
  }) async {
    await _client.patch<Object?>(
      '/courses/$courseId/reviews/me/',
      data: {'rating': rating, 'review': review},
    );
  }

  /// `DELETE /courses/{courseId}/reviews/me/` — 204.
  Future<void> deleteReview(int courseId) =>
      _client.delete('/courses/$courseId/reviews/me/');

  // ── plumbing ──────────────────────────────────────────────────────────────

  Future<CoursePage> _page(String path, {Map<String, dynamic>? query}) async {
    final body = await _client.get<Object?>(path, query: query);
    final page = CoursePage.tryParse(body);
    if (page == null) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'The course list came back in an unexpected shape.',
      );
    }
    return page;
  }

  /// `GET /instructors/{id}/`, or null when it is not public yet.
  ///
  /// The endpoint only serves **verified** instructors with at least one
  /// published course, so a 404 here is a normal state rather than a failure —
  /// the course still renders, with the name it already carries.
  Future<Map<String, dynamic>?> _instructorOrNull(Object? id) async {
    if (id is! int) return null;
    try {
      return await _client.get<Map<String, dynamic>>('/instructors/$id/');
    } on ApiException {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _rowsOrEmpty(String path) async {
    try {
      return _rows(await _client.get<List<dynamic>>(path));
    } on ApiException {
      return const [];
    }
  }

  static List<Map<String, dynamic>> _rows(List<dynamic> body) => [
    for (final row in body)
      if (row is Map<String, dynamic>) row,
  ];
}

/// One page of `GET /courses/`.
class CoursePage {
  const CoursePage({required this.count, required this.courses, this.next});

  /// The total across every page, which is what a "24 courses" heading wants.
  final int count;

  /// The server's absolute `next` URL, or null on the last page.
  final String? next;

  final List<CourseDetailData> courses;

  bool get hasMore => next != null;

  static CoursePage? tryParse(Object? body) {
    if (body is! Map) return null;
    final results = body['results'];
    if (results is! List) return null;
    final next = body['next'];
    return CoursePage(
      count: body['count'] is int ? body['count'] as int : results.length,
      next: next is String && next.trim().isNotEmpty ? next.trim() : null,
      courses: [
        for (final row in results)
          if (row is Map<String, dynamic>) CourseMapper.summary(row),
      ],
    );
  }
}

/// `GET /courses/{id}/progress/`.
class CourseProgress {
  const CourseProgress({
    required this.courseId,
    required this.totalLessons,
    required this.completedLessons,
    required this.percentage,
    required this.isCompleted,
  });

  final int courseId;
  final int totalLessons;
  final int completedLessons;

  /// 0–100, already rounded to two places by the server.
  final double percentage;

  final bool isCompleted;

  /// `68%`, matching the My Learning cards.
  String get percentLabel => '${percentage.round()}%';

  static CourseProgress? tryParse(Object? body) {
    if (body is! Map) return null;
    final courseId = body['course_id'];
    if (courseId is! int) return null;
    final percentage = body['progress_percentage'];
    return CourseProgress(
      courseId: courseId,
      totalLessons: body['total_lessons'] is int
          ? body['total_lessons'] as int
          : 0,
      completedLessons: body['completed_lessons'] is int
          ? body['completed_lessons'] as int
          : 0,
      percentage: percentage is num ? percentage.toDouble() : 0,
      isCompleted: body['is_completed'] == true,
    );
  }
}

/// `POST /courses/{id}/enroll/` — the row the server created.
class CourseEnrollment {
  const CourseEnrollment({
    required this.id,
    required this.courseId,
    required this.status,
    this.amountPaid,
    this.enrolledAt,
    this.completedAt,
  });

  final int id;
  final int courseId;

  /// `pending_payment | active | completed | cancelled`.
  final String status;

  final String? amountPaid;
  final String? enrolledAt;
  final String? completedAt;

  /// Content is readable in these two states, and only these two.
  bool get grantsAccess => status == 'active' || status == 'completed';

  /// Enrolled but unpaid: the course must not open the player, and the UI should
  /// offer "continue payment" instead of "continue learning".
  bool get awaitsPayment => status == 'pending_payment';

  static CourseEnrollment? tryParse(Object? body) {
    if (body is! Map) return null;
    final id = body['id'];
    final courseId = body['course'];
    if (id is! int || courseId is! int) return null;
    return CourseEnrollment(
      id: id,
      courseId: courseId,
      status: body['status'] is String
          ? body['status'] as String
          : 'pending_payment',
      amountPaid: body['amount_paid'] == null ? null : '${body['amount_paid']}',
      enrolledAt: body['enrolled_at'] is String
          ? body['enrolled_at'] as String
          : null,
      completedAt: body['completed_at'] is String
          ? body['completed_at'] as String
          : null,
    );
  }
}

final courseApiProvider = Provider<CourseApi>(
  (ref) => CourseApi(ref.watch(apiClientProvider)),
);

/// Academic courses for the home rail.
///
/// [classIndex] `0` is All. `1` is Class 6, matching the chip row. The grade
/// filter is the grade's id, the same rule the Courses tab uses: the chip
/// label is not a query the server understands.
final homeAcademicCoursesProvider = FutureProvider.autoDispose
    .family<List<CourseDetailData>, int>((ref, classIndex) async {
      int? gradeId;
      if (classIndex > 0) {
        final grades = await ref.watch(gradesProvider.future);
        final wanted = 'grade ${classIndex + 5}';
        for (final grade in grades) {
          if (grade.name.trim().toLowerCase() == wanted) {
            gradeId = int.tryParse(grade.id);
            break;
          }
        }
        if (gradeId == null) return const [];
      }
      final page = await ref
          .watch(courseApiProvider)
          .list(courseType: 'academic', grade: gradeId, pageSize: 4);
      return page.courses;
    });

/// The two premium courses on the home rail. Same list the Premium Courses
/// page reads, just the first two.
final homePremiumCoursesProvider =
    FutureProvider.autoDispose<List<CourseDetailData>>((ref) async {
      final page = await ref
          .watch(courseApiProvider)
          .list(courseType: 'premium', pageSize: 2);
      return page.courses;
    });

/// Every published skill course, the same list the Skill Courses tab counts.
///
/// The home rail's "12 Courses" used to come from the bundled sample pool, so
/// the card and the tab could not agree. One request, the same category names.
final skillCatalogueProvider =
    FutureProvider.autoDispose<List<CourseDetailData>>((ref) async {
      final page = await ref
          .watch(courseApiProvider)
          .list(courseType: 'skill', pageSize: 50);
      return page.courses;
    });
