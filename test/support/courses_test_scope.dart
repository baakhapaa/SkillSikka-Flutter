import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillsikka/core/network/api_client.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/features/courses/data/course_api.dart';
import 'package:skillsikka/features/courses/data/course_resources_api.dart';
import 'package:skillsikka/features/profile/data/reference_data.dart';

/// A stand-in for `GET /courses/{id}/resources/`.
///
/// The player fetches the pack the first time the Resources tab opens, so every
/// player test that taps that tab needs one of these — otherwise the request
/// leaves for the real Dio stack, which answers 400 under `flutter test` and
/// looks like a product bug.
///
/// **The default is an empty list, not a failure.** An empty answer is what a
/// course with no resource rows returns, and the tab falls back to the
/// `pdf`/`ebook` lessons the adapter lifted out of the curriculum — which is
/// exactly the behaviour the older tests assert.
class FakeCourseResourcesApi extends CourseResourcesApi {
  FakeCourseResourcesApi({this.rows = const <CourseResource>[], this.failure})
    : super(ApiClient(Dio()));

  /// What [list] answers, whatever the course or lesson filter.
  final List<CourseResource> rows;

  /// Thrown from [list] instead of answering.
  final ApiException? failure;

  /// Every course id asked for, so a test can assert the tab asked at all.
  final List<int> calls = <int>[];

  @override
  Future<List<CourseResource>> list(int courseId, {int? lessonId}) async {
    calls.add(courseId);
    final error = failure;
    if (error != null) throw error;
    return rows;
  }

  @override
  Future<CourseResource> create(
    int courseId, {
    required String title,
    required String fileUrl,
    required String fileFormat,
    int? lessonId,
    int? sizeBytes,
    int? order,
  }) async => CourseResource(title, CourseResourceType.fromFormat(fileFormat));

  @override
  Future<void> remove(int courseId, int resourceId) async {}
}

/// A stand-in for the course endpoints.
///
/// **Why a scope and not a mocked network.** The catalogue screens are
/// provider-driven as of 2026-10-27, so a test that pumps one needs a
/// `ProviderScope`. Overriding [courseApiProvider] removes the request and the
/// Dio stack in one move, and leaves the screen's own logic — filtering,
/// paging, empty and error states — under test.
///
/// [lastGradeId] is the point of the class: the Class chips must send a **grade
/// id**, never the `Class 6` label, because the server silently ignores an
/// unknown query value. A test that only checks the cards appeared would pass
/// with the wrong parameter.
class FakeCourseApi extends CourseApi {
  FakeCourseApi({this.catalogue, this.failure}) : super(ApiClient(Dio()));

  /// What [list] answers. Null means an empty catalogue.
  ///
  /// Named `catalogue` rather than `page` because `list()` has its own `page`
  /// parameter (the page number), and the two shadowing each other produces a
  /// confusing `Object` return type rather than an error at the call site.
  final CoursePage? catalogue;

  /// Thrown from [list] instead of answering.
  final ApiException? failure;

  /// Every call, in order, so a test can assert the filters.
  final List<({String? courseType, int? grade, int? skillCategory})> calls = [];

  int? get lastGradeId => calls.isEmpty ? null : calls.last.grade;

  @override
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
  }) async {
    calls.add((
      courseType: courseType,
      grade: grade,
      skillCategory: skillCategory,
    ));
    final error = failure;
    if (error != null) throw error;

    final base = catalogue ?? const CoursePage(count: 0, courses: []);
    if (grade == null) return base;

    // Stands in for the server's `?grade=` filter so a chip test can assert that
    // filtering actually narrowed the grid. `classLevel` carries the grade name
    // ('Grade 6'), which is the only handle the presentational model has.
    final wanted = 'Grade $grade';
    final filtered = [
      for (final course in base.courses)
        if (course.classLevel == wanted) course,
    ];
    return CoursePage(count: filtered.length, courses: filtered);
  }

  @override
  Future<CoursePage> nextPage(String url) async =>
      catalogue ?? const CoursePage(count: 0, courses: []);

  @override
  Future<CourseDetailData> detail(int id) async {
    final value = detailValue;
    if (value != null) return value;
    throw const ApiException(
      kind: ApiErrorKind.unknown,
      message: 'not used in this test',
    );
  }

  /// What [detail] answers. Null keeps the "not used in this test" throw, which
  /// is what keeps every list-only suite off the detail path.
  CourseDetailData? detailValue;

  // ── progress ──────────────────────────────────────────────────────────────

  /// What [progress] answers. Defaults to an untouched course.
  CourseProgress progressValue = const CourseProgress(
    courseId: 0,
    totalLessons: 0,
    completedLessons: 0,
    percentage: 0,
    isCompleted: false,
  );

  /// What [nextLessonId] answers — the lecture the server says to resume on.
  int? nextLesson;

  /// Every lesson id passed to [completeLesson], in order.
  final List<int> completions = [];

  /// Thrown from [enroll] when set.
  ApiException? enrollFailure;

  /// The enrolment [enroll] answers. Defaults to an active free enrolment.
  CourseEnrollment enrollResult = const CourseEnrollment(
    id: 1,
    courseId: 0,
    status: 'active',
  );

  @override
  Future<CourseProgress> progress(int courseId) async => progressValue;

  @override
  Future<int?> nextLessonId(int courseId) async => nextLesson;

  @override
  Future<void> completeLesson(int lessonId) async => completions.add(lessonId);

  @override
  Future<void> reportLessonProgress(
    int lessonId, {
    required int watchedSeconds,
    required int positionSeconds,
  }) async {}

  /// Every course id passed to [enroll], in order.
  final List<int> enrolCalls = [];

  @override
  Future<CourseEnrollment> enroll(int courseId, {String? source}) async {
    enrolCalls.add(courseId);
    final error = enrollFailure;
    if (error != null) throw error;
    return enrollResult;
  }

  /// What [enrollmentFor] answers. Null is the server's 404 — no row at all.
  CourseEnrollment? existingEnrollment;

  /// Thrown from [enrollmentFor] instead of answering.
  ApiException? enrollmentLookupFailure;

  /// Every course id passed to [enrollmentFor], in order.
  final List<int> enrollmentLookups = [];

  @override
  Future<CourseEnrollment?> enrollmentFor(int courseId) async {
    enrollmentLookups.add(courseId);
    final error = enrollmentLookupFailure;
    if (error != null) throw error;
    return existingEnrollment;
  }

  // ── reviews ───────────────────────────────────────────────────────────────

  /// What [myReview] answers. Null means "this student has not reviewed yet",
  /// which is the server's 404.
  Map<String, dynamic>? myReviewValue;

  /// Thrown from [submitReview] when set — used to cover the `REVIEW_EXISTS`
  /// fallback and the inline error.
  ApiException? submitFailure;

  /// Every review written, in order.
  final List<({int courseId, int rating, String review})> submitted = [];

  /// Every review edited, in order.
  final List<({int courseId, int rating, String review})> updated = [];

  @override
  Future<Map<String, dynamic>?> myReview(int courseId) async => myReviewValue;

  @override
  Future<void> submitReview(
    int courseId, {
    required int rating,
    String review = '',
  }) async {
    final error = submitFailure;
    if (error != null) throw error;
    submitted.add((courseId: courseId, rating: rating, review: review));
  }

  @override
  Future<void> updateReview(
    int courseId, {
    required int rating,
    String review = '',
  }) async {
    updated.add((courseId: courseId, rating: rating, review: review));
  }
}

/// Wraps [child] in a scope whose course API is faked.
///
/// [grades] seeds `gradesProvider`, which is what turns a `Class 7` chip into a
/// grade id. Without it the chip resolves to nothing and the screen shows its
/// "no courses for this class" state — correct behaviour, but not what a test
/// about filtering wants to assert.
Widget coursesTestScope({
  required Widget child,
  FakeCourseApi? api,
  List<ReferenceItem>? grades,
}) {
  return ProviderScope(
    overrides: [
      courseApiProvider.overrideWithValue(api ?? FakeCourseApi()),
      if (grades != null) gradesProvider.overrideWith((ref) async => grades),
    ],
    child: child,
  );
}

/// `Grade 6` … `Grade 10`, matching what `GET /grades/` returns.
List<ReferenceItem> fakeGrades() => [
  for (var number = 6; number <= 10; number++)
    ReferenceItem(id: '$number', name: 'Grade $number'),
];
