import 'package:flutter/material.dart';

import '../../../core/widgets/course_detail_view.dart';
import '../../learning/presentation/start_course.dart';

/// The course-detail screen for the Courses tab.
///
/// A thin wrapper. All the layout lives in [CourseDetailView], which the premium
/// screen renders too — so the two cannot drift. What this class adds is the
/// course it was opened for, and the enrolment flow.
class CourseDetailPage extends StatefulWidget {
  const CourseDetailPage({super.key, required this.course});

  final CourseDetailData course;

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  /// **Deliberately a plain `StatefulWidget`, not a `ConsumerStatefulWidget`.**
  /// Several suites pump this screen with no `ProviderScope` above it, so it has
  /// to render without one — the same constraint the profile tab and
  /// `navigation_test.dart` ran into. `startCourse` *probes* for the scope
  /// rather than assuming it, and is only reached on tap.
  ///
  /// Enrolment needs a complete profile, so the fields signup stopped asking for
  /// are collected here, on the way in, and the user lands in the player rather
  /// than back on this screen with a toast.
  Future<void> _enrol() async {
    await startCourse(context, widget.course);
    // `build` asks the store whether this course is enrolled in, and the answer
    // changed while the player was open. Without this the bar would still read
    // `Enroll Now` on the way back.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => CourseDetailView(
    data: widget.course,
    isEnrolled: isCourseEnrolled(context, widget.course),
    onEnrol: _enrol,
    onContinue: () => continueCourse(context, widget.course),
  );
}
