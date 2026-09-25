import 'package:flutter/foundation.dart';

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

  /// An instructor's registration: everything is collected up front, so this is
  /// a single request rather than the student's two phases.
  ///
  /// The wire keys here are **still wrong** against the confirmed contract —
  /// `phone` should be `phone_country_code` + `phone_number`, `expertise`
  /// should be `subject_expertise`, and `experience` should be
  /// `experience_years`. That is instructor-path work and deliberately not done
  /// in the student-signup pass; see `student-signup-backend-spec.md` §D.
  factory RegistrationRequest.instructor({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    required String gender,
    required String dob,
    required String phone,
    required String location,
    required String qualification,
    required String expertise,
    required String experience,
    required PickedDocument photo,
    required PickedDocument cv,
    required PickedDocument certificates,
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
        'phone': phone,
        'location': location,
        'qualification': qualification,
        'expertise': expertise,
        'experience': experience,
      },
      photo: photo,
      documents: {
        ProfileDocumentSlot.cvResume: cv,
        ProfileDocumentSlot.certificates: certificates,
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
