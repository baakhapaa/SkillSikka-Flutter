import 'package:flutter/foundation.dart';

import '../../profile/data/profile_role.dart';
import '../../profile/data/user_profile.dart';

/// Everything `POST /auth/register` needs, assembled from the signup wizard.
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

  /// A student's registration: the six fields signup asks for, plus the photo.
  ///
  /// The rest of a student's profile (phone, location, grade, province,
  /// district, school, ID card) is deferred to Edit Profile — the two-phase
  /// contract in the handover doc §4. If the backend says it needs the full
  /// profile up front, this constructor is where the extra fields would go.
  factory RegistrationRequest.student({
    required String name,
    required String email,
    required String password,
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
        'gender': gender,
        'dob': dob,
      },
      photo: photo,
    );
  }

  /// An instructor's registration: everything is collected up front, so this is
  /// a single request rather than the student's two phases.
  factory RegistrationRequest.instructor({
    required String name,
    required String email,
    required String password,
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

  /// Text fields, keyed by the wire names the handover doc proposes.
  ///
  /// `confirm_password` is deliberately absent. It is a client-side check, the
  /// forms already compare it before calling anything, and sending it would put
  /// the same secret on the wire twice for no benefit.
  final Map<String, String> fields;

  /// The avatar. Required for both roles, which is why registration is one
  /// multipart request rather than "create the account, then upload".
  final PickedDocument photo;

  /// Upload slots other than the avatar, keyed by [ProfileDocumentSlot] — whose
  /// values are already the multipart field names the doc proposes.
  final Map<String, PickedDocument> documents;
}
