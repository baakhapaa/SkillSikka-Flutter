import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/course_detail_view.dart';

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

  /// Indices into [lessonOrder].
  ///
  /// Indices rather than titles because the order is derived the same way on
  /// every screen, so an index means the same lecture everywhere. This is also
  /// the fragile half of the model — inserting a lecture shifts every index
  /// after it. Fine while the catalogue is `const` and the store is in-memory;
  /// it needs a real lesson id before any of this is persisted.
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

  /// Finished lectures, ignoring any index the course no longer has.
  int get done => completed.where((i) => i >= 0 && i < total).length;

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
/// **In-memory and session-scoped, deliberately.** There is no `enrollments/`
/// endpoint and no course API at all, so nothing here is written to disk: an
/// enrolment survives navigation and dies with the process. A user who enrols,
/// closes the app and reopens it sees `Enroll Now` again — that is the honest
/// state of a feature with no backend, not a bug to paper over.
///
/// Courses are identified by [CourseDetailData.title]. The model has no id and
/// no `==` override, and the two catalogue pools' titles are unique.
class EnrolledCourses extends Notifier<List<Enrollment>> {
  @override
  List<Enrollment> build() => const <Enrollment>[];

  bool isEnrolled(CourseDetailData course) =>
      state.any((e) => e.course.title == course.title);

  Enrollment? of(CourseDetailData course) {
    for (final enrollment in state) {
      if (enrollment.course.title == course.title) return enrollment;
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

  /// Remembers where the user stopped, so `Continue Learning` resumes there.
  void setLast(CourseDetailData course, int index) {
    state = <Enrollment>[
      for (final enrollment in state)
        if (enrollment.course.title == course.title)
          enrollment.copyWith(lastIndex: index)
        else
          enrollment,
    ];
  }

  /// Marks one lecture finished. Idempotent.
  void markComplete(CourseDetailData course, int index) {
    state = <Enrollment>[
      for (final enrollment in state)
        if (enrollment.course.title == course.title)
          enrollment.copyWith(completed: {...enrollment.completed, index})
        else
          enrollment,
    ];
  }
}

final enrolledCoursesProvider =
    NotifierProvider<EnrolledCourses, List<Enrollment>>(EnrolledCourses.new);
