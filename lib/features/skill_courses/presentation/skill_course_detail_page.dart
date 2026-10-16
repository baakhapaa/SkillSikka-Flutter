import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/course_detail_view.dart';
import '../../profile/presentation/complete_profile_gate.dart';

/// The detail screen for a card on the Skill Courses tab.
///
/// A thin wrapper, exactly like the Courses tab's `CourseDetailPage`: all the
/// layout lives in [CourseDetailView], which the premium screen renders too, so
/// the three cannot drift. What this class adds is the course it was opened for
/// and the enrolment gate.
class SkillCourseDetailPage extends StatefulWidget {
  const SkillCourseDetailPage({super.key, required this.course});

  final CourseDetailData course;

  @override
  State<SkillCourseDetailPage> createState() => _SkillCourseDetailPageState();
}

class _SkillCourseDetailPageState extends State<SkillCourseDetailPage> {
  /// Enrolment needs a complete profile, so the fields signup stopped asking for
  /// are collected here, on the way in.
  ///
  /// **Deliberately a plain `StatefulWidget`, not a `ConsumerStatefulWidget`.**
  /// The gate takes a container rather than a `ref`, and this screen is pumped
  /// by tests that install no `ProviderScope` — the same constraint the Courses
  /// tab's detail page and the profile tab ran into.
  /// `ProviderScope.containerOf` is only reached on tap, so an un-scoped test
  /// can still render the page.
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
