import '../../../core/widgets/course_detail_view.dart';
import '../../courses/data/course_adapter.dart';

/// `GET /my-learning/` — the whole My Learning screen in one payload.
///
/// **`continue_learning` is not a duplicate of `courses`.** The server pulls the
/// one course with a next lesson out of the list and returns it separately, so a
/// screen that renders only `courses` silently loses the hero card.
///
/// `hours_learned` is **always null today** — the server has no watch times to
/// add up — and the screen prints `—` rather than inventing a number.
class MyLearning {
  const MyLearning({
    this.continueLearning,
    this.courses = const [],
    this.completed = const [],
    this.stats = const LearningStats(),
    this.certificates = const [],
  });

  /// The course to resume, or null when nothing is resumable.
  final LearningCourse? continueLearning;

  /// Everything else in progress. **Excludes** [continueLearning].
  final List<LearningCourse> courses;

  final List<LearningCourse> completed;
  final LearningStats stats;
  final List<CourseCertificate> certificates;

  /// Every course the student is enrolled in, hero first.
  List<LearningCourse> get all => [?continueLearning, ...courses];

  bool get isEmpty => all.isEmpty && completed.isEmpty;

  static MyLearning? tryParse(Object? body) {
    if (body is! Map) return null;
    final hero = body['continue_learning'];
    return MyLearning(
      continueLearning: hero is Map<String, dynamic>
          ? LearningCourse.tryParse(hero)
          : null,
      courses: _rows(body['courses']),
      completed: _rows(body['completed_courses']),
      stats: LearningStats.tryParse(body['stats']) ?? const LearningStats(),
      certificates: [
        for (final row in body['certificates'] is List
            ? body['certificates'] as List
            : const [])
          if (row is Map<String, dynamic>) ?CourseCertificate.tryParse(row),
      ],
    );
  }

  static List<LearningCourse> _rows(Object? value) => value is List
      ? [
          for (final row in value)
            if (row is Map<String, dynamic>) ?LearningCourse.tryParse(row),
        ]
      : const [];
}

/// One row of `/my-learning/`: a course plus this student's progress in it.
class LearningCourse {
  const LearningCourse({
    required this.course,
    required this.enrollmentId,
    required this.status,
    required this.percentage,
    required this.completedLessons,
    required this.totalLessons,
    required this.isCompleted,
    this.nextLessonId,
    this.nextLessonNumber,
    this.completedAt,
  });

  final CourseDetailData course;
  final int enrollmentId;

  /// `active | completed`. A `pending_payment` row never appears here — the
  /// endpoint excludes it — which is why the screen cannot show "payment
  /// pending" without a second call.
  final String status;

  /// 0–100, as the server rounded it.
  final double percentage;

  final int completedLessons;
  final int totalLessons;
  final bool isCompleted;

  /// The lecture to resume on, when there is one.
  final int? nextLessonId;

  /// 1-based position of [nextLessonId], which is what `Lesson N of M` prints.
  final int? nextLessonNumber;

  final String? completedAt;

  /// 0–1, for a `LinearProgressIndicator`.
  double get progress => (percentage / 100).clamp(0, 1);

  String get percentLabel => '${percentage.round()}%';

  /// e.g. `Lesson 4 of 9`, or `All 9 lessons` when finished.
  String get positionLabel {
    if (totalLessons == 0) return 'No lessons yet';
    if (nextLessonNumber != null) {
      return 'Lesson $nextLessonNumber of $totalLessons';
    }
    return 'All $totalLessons lessons';
  }

  /// Where the player should open.
  ///
  /// The player re-seeds from the server on open anyway, so this only saves a
  /// visible jump: it is the position of [nextLessonId] within the course's
  /// flattened lesson order.
  int get resumeIndex {
    final target = nextLessonId;
    if (target == null) return 0;
    var index = 0;
    for (final module in course.modules) {
      for (final lesson in module.lessons) {
        if (lesson.id == target) return index;
        index++;
      }
    }
    return 0;
  }

  static LearningCourse? tryParse(Map<String, dynamic> row) {
    final raw = row['course'];
    if (raw is! Map<String, dynamic>) return null;
    final next = row['next_lesson'];
    final percentage = row['progress_percentage'];
    return LearningCourse(
      course: CourseMapper.summary(raw),
      enrollmentId: row['enrollment_id'] is int ? row['enrollment_id'] as int : 0,
      status: row['enrollment_status'] is String
          ? row['enrollment_status'] as String
          : 'active',
      percentage: percentage is num ? percentage.toDouble() : 0,
      completedLessons: row['completed_lessons'] is int
          ? row['completed_lessons'] as int
          : 0,
      totalLessons: row['total_lessons'] is int
          ? row['total_lessons'] as int
          : 0,
      isCompleted: row['is_completed'] == true,
      nextLessonId: next is Map && next['id'] is int ? next['id'] as int : null,
      nextLessonNumber: next is Map && next['lesson_number'] is int
          ? next['lesson_number'] as int
          : null,
      completedAt: row['completed_at'] is String
          ? row['completed_at'] as String
          : null,
    );
  }
}

/// The three numbers in the stat strip.
class LearningStats {
  const LearningStats({
    this.coursesCompleted = 0,
    this.dayStreak = 0,
    this.hoursLearned,
  });

  final int coursesCompleted;
  final int dayStreak;

  /// **Always null today.** The server has no watch times to sum.
  final int? hoursLearned;

  static LearningStats? tryParse(Object? body) {
    if (body is! Map) return null;
    return LearningStats(
      coursesCompleted: body['courses_completed'] is int
          ? body['courses_completed'] as int
          : 0,
      dayStreak: body['day_streak'] is int ? body['day_streak'] as int : 0,
      hoursLearned: body['hours_learned'] is int
          ? body['hours_learned'] as int
          : null,
    );
  }
}

/// A certificate the student has been issued.
///
/// **Metadata only.** The API returns no file, no URL and no serial number, so
/// this cannot be opened or shared — see the backend ask §4.6(g).
class CourseCertificate {
  const CourseCertificate({
    required this.id,
    required this.type,
    required this.title,
    this.issuedAt,
  });

  final int id;

  /// `course` or `grade`.
  final String type;

  /// The course's title, or the grade's name.
  final String title;

  final String? issuedAt;

  static CourseCertificate? tryParse(Map<String, dynamic> row) {
    final id = row['id'];
    if (id is! int) return null;
    final type = row['certificate_type'] is String
        ? row['certificate_type'] as String
        : 'course';
    final title = type == 'grade'
        ? row['grade_name']
        : row['course_title'];
    return CourseCertificate(
      id: id,
      type: type,
      title: title is String && title.trim().isNotEmpty
          ? title.trim()
          : 'Certificate',
      issuedAt: row['issued_at'] is String ? row['issued_at'] as String : null,
    );
  }
}
