import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/complete_profile_dialog.dart';
import '../data/profile_completeness.dart';
import '../data/user_profile.dart';
import 'edit_profile_page.dart';

/// Returns `true` when the user may go ahead with an action that needs a
/// complete profile — currently enrolling in a course.
///
/// When the profile is incomplete this shows the popup and, if the user agrees,
/// opens Edit Profile in its completion mode: every field mandatory, so they
/// cannot come back still incomplete. On return the check is **re-read** rather
/// than assumed, so a successful completion lets the original action continue
/// without the user having to tap Enrol a second time.
///
/// Callers must only proceed when this returns true — returning false means
/// either "declined" or "still incomplete", and both must block the action.
Future<bool> ensureProfileComplete(BuildContext context, WidgetRef ref) async {
  if (ref.read(profileCompletenessProvider).isComplete) return true;

  final wantsToComplete = await showCompleteProfileDialog(
    context,
    completeness: ref.read(profileCompletenessProvider),
  );
  if (!wantsToComplete || !context.mounted) return false;

  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => EditProfilePage(
        // The gate has to show the same field set the profile tab would, or an
        // instructor would be asked to complete a student's fields.
        role: ref.read(userProfileProvider).effectiveRole,
        requireCompletion: true,
      ),
    ),
  );
  if (!context.mounted) return false;

  return ref.read(profileCompletenessProvider).isComplete;
}
