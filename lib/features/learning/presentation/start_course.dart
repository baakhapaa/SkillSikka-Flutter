import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/api_error_snack.dart';
import '../../../core/widgets/course_detail_view.dart';
import '../../courses/data/course_api.dart';
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
/// Runs the profile gate, **enrols on the server**, records the enrolment, then
/// opens the player. This was three byte-identical `_enrol` methods, each ending
/// in an `'Enrolled successfully!'` SnackBar; the moment one of them had to
/// navigate, three copies would have been three behaviours inside a week.
///
/// **The SnackBar is gone on purpose.** Landing on the player is a louder
/// confirmation than a toast over a screen change — but it was a signed-off
/// string, so its removal is a decision rather than a tidy-up.
///
/// **Two refusals happen here rather than in the player.** A `pending_payment`
/// enrolment grants no lesson access, so the player must not open; and a failed
/// enrolment must not push a screen the user cannot use. Both return with a
/// message instead.
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

  // A catalogue course has no id, so there is nothing to enrol in on the
  // server — that path stays purely local.
  //
  // **An academic course has an id and still must not enrol.** The server
  // refuses `POST /courses/{id}/enroll/` for anything that is not a skill
  // course (`COURSE_NOT_ENROLLABLE`), because a school course is opened by
  // grade — `require_course_access` grants it from `student_profile.grade_id`
  // with no enrolment row involved. Calling enroll anyway is exactly what put
  // *"Only skill development courses require enrollment."* over the detail page
  // when a student tapped the CTA on a Grade 10 science course. The lesson
  // endpoints are the real gate: a course outside the student's grade answers
  // `403 ACADEMIC_NOT_ELIGIBLE`, and that surfaces in the player.
  final id = course.id;
  if (id != null && !course.isAcademic) {
    final api = container.read(courseApiProvider);
    CourseEnrollment? enrollment;

    try {
      enrollment = await api.enroll(id);
    } on ApiException catch (error) {
      // `ALREADY_ENROLLED` is success from the user's point of view *only if*
      // the row grants access. The server refuses a second `enroll/` for a
      // `pending_payment` row exactly as it does for an active one, so the code
      // alone cannot tell "you are in" from "you started paying and stopped".
      // Reading it as "you are in" is what let a student into a paid course
      // they had not paid for — the player opened and every lesson then 403'd.
      if (error.code != 'ALREADY_ENROLLED') {
        if (context.mounted) showApiErrorSnack(context, error);
        return;
      }

      try {
        enrollment = await api.enrollmentFor(id);
      } on ApiException catch (lookup) {
        if (context.mounted) showApiErrorSnack(context, lookup);
        return;
      }

      // The server said they are enrolled and then said there is no row. On a
      // **paid** course that is a refusal, not a coin flip: an unconfirmed
      // enrolment must never be the reason someone gets a paid course for free.
      // On a free course it is the old behaviour — they are in — because a free
      // enrolment is created `active` and there is nothing to be owed.
      if (enrollment == null && course.isPaid) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('We could not confirm your enrolment. Try again.'),
          ),
        );
        return;
      }
    }

    if (enrollment != null && !enrollment.grantsAccess) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_awaitingPaymentMessage(course))),
      );
      return;
    }
  }

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

/// What a student is told when the course will not open until it is paid for.
///
/// Names the price when the course carries one, because "needs payment" over a
/// screen that also shows `Rs. 1,299` reads like the price was not applied. A
/// course with no price string falls back to the plain sentence — that is a
/// paid course whose price the API did not send, not a free one.
String _awaitingPaymentMessage(CourseDetailData course) {
  final price = course.price.trim();
  return price.isEmpty
      ? 'This course needs payment before you can start it.'
      : 'This course costs $price and needs payment before you can start it.';
}

/// Reopens the player for a course already enrolled in, resuming on the lecture
/// the user stopped at.
///
/// [startIndex] comes from the server when the caller has it — My Learning knows
/// `next_lesson`, and passing it here means the player opens on the right lecture
/// instead of opening on the first and jumping once the fetch lands.
///
/// Deliberately skips the profile gate: the user is past it, and the gate is
/// there to stop someone enrolling, not to stop them learning.
Future<void> continueCourse(
  BuildContext context,
  CourseDetailData course, {
  int? startIndex,
}) async {
  final resume =
      startIndex ??
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
