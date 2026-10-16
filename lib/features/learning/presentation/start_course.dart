import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/course_detail_view.dart';
import '../../profile/presentation/complete_profile_gate.dart';
import '../data/enrollment.dart';
import 'course_player_page.dart';

/// The provider container above [context], or **null when there is none**.
///
/// `ProviderScope.containerOf` throws a `StateError` with no scope above it, and
/// the course-detail pages are deliberately pumped bare by their suites — they
/// have to render without one. Probing the inherited widget directly is the only
/// way to ask the question without an exception, and it is safe to call from
/// `build`: unlike `dependOnInheritedWidgetOfExactType`, it registers no
/// dependency.
ProviderContainer? scopeOf(BuildContext context) {
  final element = context
      .getElementForInheritedWidgetOfExactType<UncontrolledProviderScope>();
  final scope = element?.widget;
  return (scope as UncontrolledProviderScope?)?.container;
}

/// Whether [course] is already enrolled in.
///
/// False without a scope, which is the honest answer for a screen rendering
/// outside the app rather than a reason to throw.
bool isCourseEnrolled(BuildContext context, CourseDetailData course) =>
    scopeOf(
      context,
    )?.read(enrolledCoursesProvider.notifier).isEnrolled(course) ??
    false;

/// The one enrolment flow, shared by the three detail pages.
///
/// Runs the profile gate, records the enrolment, then opens the player. This was
/// three byte-identical `_enrol` methods, each ending in an
/// `'Enrolled successfully!'` SnackBar; the moment one of them had to navigate,
/// three copies would have been three behaviours inside a week.
///
/// **The SnackBar is gone on purpose.** Landing on the player is a louder
/// confirmation than a toast over a screen change — but it was a signed-off
/// string, so its removal is a decision rather than a tidy-up.
Future<void> startCourse(
  BuildContext context,
  CourseDetailData course, {
  int startIndex = 0,
}) async {
  final container = scopeOf(context);
  // No scope means no store to record into; the button is inert rather than
  // crashing a screen that was never meant to be shown outside the app.
  if (container == null) return;

  final allowed = await ensureProfileComplete(context, container);
  if (!allowed || !context.mounted) return;

  container
      .read(enrolledCoursesProvider.notifier)
      .record(course, startIndex: startIndex);

  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => CoursePlayerPage(course: course, startIndex: startIndex),
    ),
  );
}

/// Reopens the player for a course already enrolled in, resuming on the lecture
/// the user stopped at.
///
/// Deliberately skips the profile gate: the user is past it, and the gate is
/// there to stop someone enrolling, not to stop them learning.
Future<void> continueCourse(
  BuildContext context,
  CourseDetailData course,
) async {
  final resume =
      scopeOf(
        context,
      )?.read(enrolledCoursesProvider.notifier).of(course)?.lastIndex ??
      0;

  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => CoursePlayerPage(course: course, startIndex: resume),
    ),
  );
}
