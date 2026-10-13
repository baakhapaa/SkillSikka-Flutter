import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/course_detail_view.dart';
import '../../profile/presentation/complete_profile_gate.dart';

/// The course-detail screen for the Courses tab.
///
/// A thin wrapper. All the layout lives in [CourseDetailView], which the premium
/// screen renders too — so the two cannot drift. What this class adds is the
/// course it was opened for, and the enrolment gate.
class CourseDetailPage extends StatefulWidget {
  const CourseDetailPage({super.key, required this.course});

  final CourseDetailData course;

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  /// Enrolment needs a complete profile, so the fields signup stopped asking
  /// for are collected here, on the way in. `ensureProfileComplete` re-reads the
  /// profile after the user comes back, so finishing it lands them straight in
  /// the course without a second tap.
  ///
  /// **Deliberately a plain `StatefulWidget`, not a `ConsumerStatefulWidget`.**
  /// The gate takes a container rather than a `ref`, and this screen is pumped
  /// by tests that install no `ProviderScope` — the same constraint the profile
  /// tab and `navigation_test.dart` ran into. `ProviderScope.containerOf` is
  /// only reached on tap, so an un-scoped test can still render the page.
  Future<void> _enrol() async {
    final allowed = await ensureProfileComplete(
      context,
      ProviderScope.containerOf(context, listen: false),
    );
    if (!allowed || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enrolled successfully!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF111827),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      CourseDetailView(data: widget.course, onEnrol: _enrol);
}
