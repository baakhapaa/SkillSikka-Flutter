import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Recomputed whenever the profile changes, so the enrol button can never act
/// on a stale answer.
final profileCompletenessProvider = Provider<ProfileCompleteness>(
  (ref) => checkProfileCompleteness(ref.watch(userProfileProvider)),
);
