import 'package:flutter/foundation.dart';

import '../../../core/validation/validators.dart';
import '../../profile/data/profile_role.dart';
import '../../profile/data/user_profile.dart';

/// Everything the registration endpoints need, assembled from the signup
/// wizard.
///
/// [role] selects the endpoint (`/register/student/` or `/register/instructor/`)
/// — the backend has one per role rather than a single endpoint taking a `role`
/// field, so it is not part of [fields].
///
/// The two named constructors exist so the **wire keys live in exactly one
/// file**. The forms pass values, not keys — otherwise `degree` would have to be
/// remembered as `qualification` in two places, and a typo would drop a field
/// silently rather than fail.
@immutable
class RegistrationRequest {
  const RegistrationRequest({
    required this.role,
    required this.fields,
    required this.photo,
    this.documents = const {},
  });

  /// A student's registration: the fields signup asks for, the password
  /// confirmation the backend requires, and the photo.
  ///
  /// The rest of a student's profile (phone, location, grade, province,
  /// district, school, ID card) is deferred to Edit Profile — the two-phase
  /// contract the backend confirmed. If the backend agrees to make phone and
  /// location optional at registration (spec §A1), they arrive later through
  /// profile completion; if it refuses, they belong in this constructor.
  factory RegistrationRequest.student({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    required String gender,
    required String dob,
    required PickedDocument photo,
  }) {
    return RegistrationRequest(
      role: ProfileRole.student,
      fields: {
        'name': name,
        'email': email,
        'password': password,
        'confirm_password': confirmPassword,
        'gender': gender,
        'dob': dob,
      },
      photo: photo,
    );
  }

  /// An instructor's registration — **the same six fields as a student's**.
  ///
  /// **Granted 2026-10-01.** This is the third state of this constructor, and the
  /// history is worth keeping because each version was wrong for a different
  /// reason:
  ///
  /// 1. Trimmed to eight fields, assuming the instructor endpoint deferred what
  ///    the student one defers. It did not.
  /// 2. Restored to all fifteen after a probe POST answered `400` naming exactly
  ///    the seven that were missing — `location`, `province_id`, `district_id`,
  ///    `municipality_id`, `qualification`, `subject_expertise`,
  ///    `experience_years` — which is the seven repeated "This field is
  ///    required." lines the signup screen showed.
  /// 3. **This one.** We asked for the instructor endpoint to be brought in line
  ///    with the student one and the backend did it. Exception; the seven above
  ///    plus `phone_country_code` and `phone_number` are now optional.
  ///
  /// So the deferred set is the nine the request named, and it is collected on
  /// Edit Profile behind the same completion gate the student uses. The send path
  /// for it is [InstructorCompletionRequest] — a field that is here but has no
  /// route to the server is worse than one the form never asked for.
  ///
  /// Every deferred argument is optional and **omitted when blank** rather than
  /// sent as an empty string: the endpoint accepts an absent `province_id`, but a
  /// blank one still has to parse as an integer, so sending `''` would turn a
  /// skipped field into a `400`. Signup passes none of them.
  ///
  /// Wire keys follow the schema: `subject_expertise`, `experience_years`,
  /// `province_id` / `district_id` / `municipality_id`, and the phone split. The
  /// CV and certificates remain optional here and are collected on Edit Profile
  /// with the rest.
  factory RegistrationRequest.instructor({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    required String gender,
    required String dob,
    required PickedDocument photo,
    String? phone,
    String? location,
    String? qualification,
    String? expertise,
    String? experience,
    String? provinceId,
    String? districtId,
    String? municipalityId,
    PickedDocument? cv,
    PickedDocument? certificates,
  }) {
    return RegistrationRequest(
      role: ProfileRole.instructor,
      fields: {
        'name': name,
        'email': email,
        'password': password,
        'confirm_password': confirmPassword,
        'gender': gender,
        'dob': dob,
        // One input on the form, two fields on the wire, null-aware so both
        // keys are **absent** when the number did not parse rather than sent as
        // blanks. An absent optional field registers; a blank `province_id` is a
        // parse error.
        'phone_country_code': ?splitPhoneNumber(phone)?.countryCode,
        'phone_number': ?splitPhoneNumber(phone)?.number,
        'location': ?_nonBlank(location),
        'qualification': ?_nonBlank(qualification),
        'subject_expertise': ?_nonBlank(expertise),
        // The field invites `5 Years`; the backend's decimal pattern does not.
        // Normalised here rather than at the call site so no future caller can
        // send the display form by accident.
        'experience_years': ?experienceYearsValue(experience),
        'province_id': ?_nonBlank(provinceId),
        'district_id': ?_nonBlank(districtId),
        'municipality_id': ?_nonBlank(municipalityId),
      },
      photo: photo,
      documents: {
        ProfileDocumentSlot.cvResume: ?cv,
        ProfileDocumentSlot.certificates: ?certificates,
      },
    );
  }

  final ProfileRole role;

  /// Text fields, keyed by the wire names the contract uses.
  ///
  /// `confirm_password` **is** sent. We had left it out on the grounds that the
  /// forms already compare the two values client-side, but the backend requires
  /// the field and validates the pair server-side, so omitting it fails
  /// registration outright.
  final Map<String, String> fields;

  /// The avatar. Required for both roles, which is why registration is one
  /// multipart request rather than "create the account, then upload".
  final PickedDocument photo;

  /// Upload slots other than the avatar, keyed by [ProfileDocumentSlot] — whose
  /// values are already the multipart field names the doc proposes.
  final Map<String, PickedDocument> documents;
}

/// A value worth sending, or null.
///
/// The distinction that matters: the backend's optional geographic fields are
/// integers, so an empty string is a *parse* error rather than a missing value.
/// Trimming here also stops a field the user typed a space into from looking
/// filled to the completeness check and going out as `" "`.
String? _nonBlank(String? value) {
  final trimmed = (value ?? '').trim();
  return trimmed.isEmpty ? null : trimmed;
}
