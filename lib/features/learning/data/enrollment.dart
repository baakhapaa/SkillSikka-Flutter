import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/course_detail_view.dart';

/// The key a lesson's completion is tracked by.
///
/// **Server lessons use their id; catalogue lessons use a negative position.**
/// A position alone was the old scheme, and it shifts every time a lesson is
/// inserted — fine for a frozen mock catalogue, wrong for anything the backend
/// can reorder. A real id is stable and is what
/// `POST /lessons/{id}/complete/` needs.
///
/// The position fallback is negative so it can never collide with a real id
/// (primary keys are positive), and a set mixing the two can never confuse one
/// for the other.
int lessonProgressKey(CourseLesson lesson, int index) =>
    lesson.id ?? -(index + 1);

/// What the app knows about one course the user has enrolled in.
///
/// Small on purpose. Everything it exposes is derived from the course's own
/// modules plus the set of finished lectures, so there is no second copy of the
/// curriculum to drift from the first.
class Enrollment {
  const Enrollment({
    required this.course,
    this.completed = const <int>{},
    this.lastIndex = 0,
  });

  final CourseDetailData course;

  /// Keys from [lessonProgressKey] — a server lesson id, or a negative position
  /// for a catalogue lesson.
  final Set<int> completed;

  /// The lecture to resume on.
  final int lastIndex;

  /// Every lecture, in order, across every section.
  ///
  /// The player's Prev/Next, its `Lesson n of m` label and the progress bar all
  /// read this one sequence rather than keeping their own counters — the same
  /// derive-don't-author rule the curriculum's `N lessons` count follows.
  List<CourseLesson> get lessonOrder =>
      course.modules.expand((module) => module.lessons).toList(growable: false);

  int get total => lessonOrder.length;

  /// Finished lectures, ignoring any key the course no longer has.
  int get done {
    var count = 0;
    for (var index = 0; index < total; index++) {
      if (completed.contains(lessonProgressKey(lessonOrder[index], index))) {
        count++;
      }
    }
    return count;
  }

  double get progress => total == 0 ? 0 : done / total;

  /// e.g. `68%`.
  String get percentLabel => '${(progress * 100).round()}%';

  /// e.g. `Lesson 12 of 18`.
  String get positionLabel =>
      'Lesson ${(lastIndex + 1).clamp(1, total < 1 ? 1 : total)} of $total';

  Enrollment copyWith({Set<int>? completed, int? lastIndex}) => Enrollment(
    course: course,
    completed: completed ?? this.completed,
    lastIndex: lastIndex ?? this.lastIndex,
  );
}

/// The courses this session has enrolled in.
///
/// **Still in-memory, but no longer the source of truth.** The enrolment itself
/// is created server-side by `POST /courses/{id}/enroll/` (see `startCourse`),
/// and each completion is posted by the player. This store is what the UI reads
/// during a session so a tap does not wait for a round trip; the server's answer
/// is authoritative and is what a reopened app reads (phase 4,
/// `GET /my-learning/`).
///
/// Courses are matched by [CourseDetailData.id] when they have one. The title
/// comparison remains for catalogue entries, which have no id — the two pools'
/// titles are unique, and that is the only reason it ever worked.
class EnrolledCourses extends Notifier<List<Enrollment>> {
  @override
  List<Enrollment> build() => const <Enrollment>[];

  static bool _same(CourseDetailData a, CourseDetailData b) =>
      a.id != null && b.id != null ? a.id == b.id : a.title == b.title;

  bool isEnrolled(CourseDetailData course) =>
      state.any((e) => _same(e.course, course));

  Enrollment? of(CourseDetailData course) {
    for (final enrollment in state) {
      if (_same(enrollment.course, course)) return enrollment;
    }
    return null;
  }

  /// Records an enrolment.
  ///
  /// A second call for a course already enrolled is a no-op, so a double tap —
  /// or coming back and pressing Enroll again — cannot produce two rows.
  void record(CourseDetailData course, {int startIndex = 0}) {
    if (isEnrolled(course)) return;
    state = <Enrollment>[
      ...state,
      Enrollment(course: course, lastIndex: startIndex),
    ];
  }

  /// Seeds the store from the server's view of this course.
  ///
  /// Called when the player opens on a course that came from the API, so a
  /// reopened app shows the ticks the server already has rather than starting at
  /// zero. Creates the row when `record` has not run — a course reached from My
  /// Learning has no local enrolment yet.
  void adoptProgress(
    CourseDetailData course, {
    required Set<int> completed,
    required int lastIndex,
  }) {
    final existing = of(course);
    if (existing == null) {
      state = <Enrollment>[
        ...state,
        Enrollment(
          course: course,
          completed: completed,
          lastIndex: lastIndex,
        ),
      ];
      return;
    }
    state = <Enrollment>[
      for (final enrollment in state)
        if (_same(enrollment.course, course))
          enrollment.copyWith(
            // Union rather than replace: a completion posted during this
            // session is at least as new as the server's answer.
            completed: {...enrollment.completed, ...completed},
            lastIndex: lastIndex,
          )
        else
          enrollment,
    ];
  }

  /// Remembers where the user stopped, so `Continue Learning` resumes there.
  void setLast(CourseDetailData course, int index) {
    state = <Enrollment>[
      for (final enrollment in state)
        if (_same(enrollment.course, course))
          enrollment.copyWith(lastIndex: index)
        else
          enrollment,
    ];
  }

  /// Marks one lecture finished. Idempotent.
  ///
  /// Takes the lesson and its position rather than a bare key: an `int` would
  /// invite a caller to pass the index, which is exactly the bug this replaced —
  /// the key is [lessonProgressKey], and nothing outside this file should have to
  /// know that.
  void markComplete(CourseDetailData course, CourseLesson lesson, int index) {
    final key = lessonProgressKey(lesson, index);
    state = <Enrollment>[
      for (final enrollment in state)
        if (_same(enrollment.course, course))
          enrollment.copyWith(completed: {...enrollment.completed, key})
        else
          enrollment,
    ];
  }
}

final enrolledCoursesProvider =
    NotifierProvider<EnrolledCourses, List<Enrollment>>(EnrolledCourses.new);
