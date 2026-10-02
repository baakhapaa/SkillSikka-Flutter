import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_role.dart';
import 'user_profile.dart';

/// A profile field that has to be filled before the user can enrol.
@immutable
class ProfileField {
  const ProfileField(this.key, this.label);

  /// Matches the edit screen's controller keys and [UserProfile].
  final String key;

  /// Shown to the user, so this is their wording, not the code's.
  final String label;
}

/// Everything a student must supply before enrolling.
///
/// This is exactly the set that signup stopped asking for — the point of
/// trimming that form was to defer these fields, not to drop them. Add a field
/// here and the popup, the progress count and the gate all follow.
///
/// The student ID card is deliberately absent: it gates *verification*, which a
/// human reviews over 24-48 business hours. Blocking enrolment on that would
/// stop a student from starting a course they had already paid for.
const studentEnrolmentFields = <ProfileField>[
  ProfileField('phone', 'Phone number'),
  ProfileField('gender', 'Gender'),
  ProfileField('dob', 'Date of birth'),
  ProfileField('location', 'Location'),
  ProfileField('grade', 'Class / Grade'),
  ProfileField('province', 'Province'),
  ProfileField('district', 'District'),
  ProfileField('school', 'School / College'),
];

/// Everything an instructor must supply before they can publish a course.
///
/// The counterpart to [studentEnrolmentFields], and deliberately the *deferred*
/// set: signup now stops at the phone number, so location, qualification,
/// expertise and experience are the fields it never asks for. Phone is included
/// even though signup does collect it — it is the contact number a course
/// listing carries, and a profile without one is not usable for the action.
///
/// **The CV and certificates are deliberately absent**, for exactly the reason
/// the student ID card is: they gate *verification*, which a human reviews over
/// 24-48 business hours. Blocking course creation on that would stop an
/// instructor working on a course while an admin reads their CV. There is also a
/// mechanical limit — [checkProfileCompleteness] reads text values only, and the
/// uploads live in `documents`, not in `values`.
///
/// Gender and date of birth are absent because both roles supply them at signup;
/// they are not what this gate is about.
const instructorCourseCreationFields = <ProfileField>[
  ProfileField('phone', 'Phone number'),
  ProfileField('location', 'Location'),
  ProfileField('qualification', 'Highest qualification'),
  ProfileField('expertise', 'Subject expertise'),
  ProfileField('experience', 'Years of experience'),
];

/// The fields a profile has to have before [role] can take its gated action.
///
/// Students are gated on enrolment, instructors on publishing a course. Without
/// this split an instructor was checked against the student list — asked for a
/// class and a school on a form that shows them qualification and expertise, so
/// the check could never pass.
List<ProfileField> completionFieldsFor(ProfileRole role) => switch (role) {
  ProfileRole.student => studentEnrolmentFields,
  ProfileRole.instructor => instructorCourseCreationFields,
};

@immutable
class ProfileCompleteness {
  const ProfileCompleteness({required this.fields, required this.missing});

  /// Every field being checked.
  final List<ProfileField> fields;

  /// The subset still to be filled, in [fields] order.
  final List<ProfileField> missing;

  bool get isComplete => missing.isEmpty;

  int get total => fields.length;

  int get filled => fields.length - missing.length;

  /// 0..1, for a progress indicator. An empty field list counts as complete.
  double get fraction => fields.isEmpty ? 1 : filled / fields.length;
}

/// Pure, so it can be unit-tested without a widget or a provider container.
ProfileCompleteness checkProfileCompleteness(
  UserProfile profile, {
  List<ProfileField> fields = studentEnrolmentFields,
}) {
  final missing = fields
      .where((field) => profile.valueFor(field.key).trim().isEmpty)
      .toList(growable: false);
  return ProfileCompleteness(fields: fields, missing: missing);
}

/// Recomputed whenever the profile changes, so the gated action can never act
/// on a stale answer.
///
/// **Role-aware since 2026-10-01.** It used to check [studentEnrolmentFields]
/// regardless of role while the gate opened `EditProfilePage` with the real one,
/// so an instructor was asked to fill in a class and a school on a form that
/// showed them qualification and expertise — and could never satisfy the check.
final profileCompletenessProvider = Provider<ProfileCompleteness>((ref) {
  final profile = ref.watch(userProfileProvider);
  return checkProfileCompleteness(
    profile,
    fields: completionFieldsFor(profile.effectiveRole),
  );
});
