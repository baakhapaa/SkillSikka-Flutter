import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/complete_profile_dialog.dart';
import '../data/profile_completeness.dart';
import '../data/user_profile.dart';
import 'edit_profile_page.dart';

/// Returns `true` when the user may go ahead with an action that needs a
/// complete profile — enrolling in a course, or publishing one.
///
/// **Takes a [ProviderContainer] rather than a `WidgetRef`.** One of the two
/// call sites is a plain `StatefulWidget` — the profile tab, which several tests
/// pump with no `ProviderScope` above it and so cannot become a
/// `ConsumerStatefulWidget`. The gate only ever *reads*, never listens, so the
/// container is the honest dependency.
///
/// When the profile is incomplete this shows the popup and, if the user agrees,
/// opens Edit Profile in its completion mode: every field mandatory, so they
/// cannot come back still incomplete. On return the check is **re-read** rather
/// than assumed, so a successful completion lets the original action continue
/// without the user having to tap again.
///
/// Which fields are required comes from the signed-in role, so an instructor is
/// never asked for a student's fields. [action] completes "You need to finish
/// your profile before you can …" and is the only difference between the two
/// gates.
///
/// Callers must only proceed when this returns true — returning false means
/// either "declined" or "still incomplete", and both must block the action.
Future<bool> ensureProfileComplete(
  BuildContext context,
  ProviderContainer container, {
  String action = 'enrol in this course',
}) async {
  if (container.read(profileCompletenessProvider).isComplete) return true;

  final wantsToComplete = await showCompleteProfileDialog(
    context,
    completeness: container.read(profileCompletenessProvider),
    action: action,
  );
  if (!wantsToComplete || !context.mounted) return false;

  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => EditProfilePage(
        // The gate has to show the same field set the profile tab would, or an
        // instructor would be asked to complete a student's fields.
        role: container.read(userProfileProvider).effectiveRole,
        requireCompletion: true,
      ),
    ),
  );
  if (!context.mounted) return false;

  return container.read(profileCompletenessProvider).isComplete;
}

/// The instructor's gate on publishing a course.
///
/// Same machinery as enrolment; what differs is the required field set — which
/// comes from the role — and the wording. Named separately so the call site
/// reads as what it is rather than as an enrolment check.
Future<bool> ensureCanAddCourse(
  BuildContext context,
  ProviderContainer container,
) => ensureProfileComplete(context, container, action: 'add a new course');
