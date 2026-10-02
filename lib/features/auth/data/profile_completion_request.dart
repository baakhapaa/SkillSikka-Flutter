import 'package:flutter/foundation.dart';

import '../../../core/validation/validators.dart';
import '../../profile/data/profile_role.dart';

/// The deferred half of an instructor's profile, shaped for
/// `POST /me/complete-profile/`.
///
/// The counterpart to [RegistrationRequest]: registration now asks for identity
/// only, and these nine fields are collected on Edit Profile and sent here.
///
/// **Why this is a class of its own rather than a second `RegistrationRequest`.**
/// The completion body is assembled from the *profile store*, whose keys are the
/// form's (`expertise`, `experience`, `province`) and whose values are the labels
/// the user read — not from the signup controllers, and not the ids the wire
/// needs. The ids only ever exist while a picker is open on Edit Profile, so they
/// are handed in alongside the values. See [forInstructor].
///
/// The wire keys are deliberately the same strings as
/// `RegistrationRequest.instructor`'s; a field renamed in one and not the other
/// would drop the value silently.
@immutable
class InstructorCompletionRequest {
  const InstructorCompletionRequest({required this.fields});

  /// Builds the body from the profile store's values plus the geographic ids.
  ///
  /// [values] is `UserProfile.values` — the same map the completeness gate reads,
  /// so a field the gate says is filled cannot arrive here blank.
  ///
  /// [provinceId] / [districtId] / [municipalityId] are passed separately
  /// because the store holds the names the user saw, and the endpoint validates
  /// the hierarchy by id. They are optional so a caller with no picker state (a
  /// restored session, a test) can still build the request; the ids are simply
  /// then absent, and the backend sees a country-level answer rather than a wrong
  /// one.
  factory InstructorCompletionRequest.forInstructor(
    Map<String, String> values, {
    String? provinceId,
    String? districtId,
    String? municipalityId,
  }) {
    final phone = splitPhoneNumber(values['phone']);
    return InstructorCompletionRequest(
      fields: {
        // Omitted together when the number did not parse, rather than sent as
        // a blank pair.
        if (phone != null) ...{
          'phone_country_code': phone.countryCode,
          'phone_number': phone.number,
        },
        'location': ?_nonBlank(values['location']),
        'qualification': ?_nonBlank(values['qualification']),
        'subject_expertise': ?_nonBlank(values['expertise']),
        // The form invites `5 Years`; the backend types this as a decimal with
        // a digit-only pattern.
        'experience_years': ?experienceYearsValue(values['experience']),
        'province_id': ?_nonBlank(provinceId),
        'district_id': ?_nonBlank(districtId),
        'municipality_id': ?_nonBlank(municipalityId),
      },
    );
  }

  /// The instructor-specific text fields, keyed by their wire names.
  final Map<String, String> fields;

  /// True when there is nothing to send.
  ///
  /// The caller must not issue the request in that case. A user who opens Edit
  /// Profile and saves without touching a field should not have their profile
  /// marked complete, and — while the endpoint is a request rather than a live
  /// contract — should certainly not be shown an error for it.
  bool get isEmpty => fields.isEmpty;

  /// The same fields, as whatever the completion endpoint calls its text inputs.
  ///
  /// **Identity, deliberately.** The endpoint is role-aware on the wire but its
  /// *body* is described as flat `Map<String, String>`, and the instructor keys
  /// above are not the student ones (`grade_id`, `school_id`). Until the backend
  /// confirms the exact spelling it wants, sending the fields the way
  /// `RegistrationRequest` already does is the only encoding we have evidence
  /// for. `role` rides along so a role-discriminated endpoint can tell which set
  /// it is looking at.
  Map<String, String> toWireBody(ProfileRole role) => {
    'role': role.wireValue,
    ...fields,
  };
}

/// See `RegistrationRequest._nonBlank` — the same rule, kept local rather than
/// exported, because the two files' reasons for it differ: there it protects a
/// nullable *argument*, here a nullable *store value*.
String? _nonBlank(String? value) {
  final trimmed = (value ?? '').trim();
  return trimmed.isEmpty ? null : trimmed;
}
