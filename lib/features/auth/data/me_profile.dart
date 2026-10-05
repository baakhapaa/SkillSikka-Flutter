import 'package:flutter/foundation.dart';

import '../../../core/validation/validators.dart';
import '../../profile/data/gender.dart';
import '../../profile/data/profile_role.dart';

/// What `GET /me/` returns for the signed-in user.
///
/// **Shape confirmed against the live backend on 2026-09-28**, and re-confirmed
/// on **2026-10-02** after the backend shipped the profile fields this model
/// used to be missing. The current live response:
///
/// ```json
/// {"id":"23","email":"...","name":"Probe Renamed","role":"student",
///  "gender":"female","dob":"2001-05-14","phone_country_code":"+977",
///  "phone_number":"9800000000","location":"Kathmandu",
///  "verification_status":"not_applicable","onboarding_completed":false,
///  "is_active":true}
/// ```
///
/// The five fields added on 2026-10-02 (`gender`, `dob`,
/// `phone_country_code`, `phone_number`, `location`) are the ones Edit Profile
/// needs to repopulate after a fresh login. Before them `/me/` returned only
/// name, email and role, so the store could hold nothing else and every field
/// opened blank — see [profileValues].
///
/// **Flat, unlike the auth responses.** `/register/` and `/login/` nest the user
/// under `user` and add `tokens`; `/me/` puts the fields at the top level and has
/// no tokens at all — it is a read of the current user, not a session. The
/// tolerant wrappers below accept either, so one model covers both, but the
/// flat form is what this endpoint actually sends.
///
/// The backend's own schema documents this endpoint as having **no response
/// body**, which is wrong — it returns the object above. Do not trust that
/// description when changing anything here; the live response is in the doc
/// comment above for exactly that reason.
@immutable
class MeProfile {
  const MeProfile({
    this.userId,
    this.email,
    this.name,
    this.role,
    this.gender,
    this.dob,
    this.phoneCountryCode,
    this.phoneNumber,
    this.location,
    this.verificationStatus,
    this.onboardingCompleted,
    this.isActive,
    this.gradeId,
    this.provinceId,
    this.districtId,
    this.municipalityId,
    this.schoolId,
    this.qualification,
    this.subjectExpertise,
    this.experienceYears,
    this.profilePhotoUrl,
  });

  final String? userId;
  final String? email;
  final String? name;

  /// Null when the server sent a role we do not recognise.
  ///
  /// Deliberately not coerced to `student`, for the same reason as
  /// `RegisteredAccount.role`: an unrecognised role means the contract drifted,
  /// and silently showing a student's screens to an instructor hides it.
  final ProfileRole? role;

  /// The **wire** value — `male` / `female` / `other`, lowercased. Held raw
  /// rather than as a [Gender] so an unrecognised value survives the round trip
  /// instead of being dropped; [profileValues] is what decides what the store
  /// can show.
  final String? gender;

  /// Date of birth as the server sends it: `YYYY-MM-DD`.
  ///
  /// Raw for the same reason as [gender]. [profileValues] converts it to the
  /// form's `DD / MM / YYYY` via [formDateOf].
  final String? dob;

  /// The two halves the wire splits a phone number into. Kept apart rather than
  /// pre-joined because that is the shape every endpoint takes it in;
  /// [profileValues] rejoins them for the form.
  final String? phoneCountryCode;
  final String? phoneNumber;

  final String? location;

  /// `not_applicable` / `pending` / `verified` / `rejected`. Instructors are
  /// `pending` until an admin reviews them.
  final String? verificationStatus;

  /// True once the user has finished the onboarding the backend tracks. Not the
  /// same thing as this app's profile-completion gate, which is computed
  /// client-side from [UserProfile.values] — keep the two apart.
  final bool? onboardingCompleted;

  final bool? isActive;

  // ---------------------------------------------------------------------------
  // The profile-completion fields
  //
  // **Shipped 2026-10-05**, in answer to
  // `backend-ask-profile-completion-fields-2026-10-05.md` §A1. All eight are
  // always present on `/me/`, `null` when unset.
  //
  // The parse below still accepts a plausible alternative spelling for each,
  // and that is deliberate rather than belt-and-braces: the field names came
  // from the backend's reply, not from a contract we can read, because
  // **`/me/` is still documented as returning "No response body"** in the live
  // OpenAPI schema (re-checked 2026-10-05). One day that will be fixed and the
  // aliases can go; until then they cost nothing and remove a whole class of
  // silent blank-field bug.
  //
  // Everything here is null on a response that lacks these keys, so nothing
  // about the app's behaviour depends on the backend having shipped them.
  //
  // **The geographic four are ids, not names, and the store holds names.** They
  // are deliberately *not* in [profileValues]: this model has no network access
  // to resolve an id into a name. `SessionBootstrap` does that between fetching
  // and applying — see [profileValues] for why that split exists.

  /// The student's grade/class as a primary key into `/grades/`.
  final String? gradeId;

  /// The geographic ids, resolved to names by the bootstrap. See the note above.
  final String? provinceId;
  final String? districtId;
  final String? municipalityId;
  final String? schoolId;

  /// Free text, so unlike the four above these need no resolution and go
  /// straight into [profileValues].
  final String? qualification;

  /// The wire name is `subject_expertise`; the form's key is `expertise`.
  final String? subjectExpertise;

  /// The bare number, 0–100. [profileValues] puts it back into the `5 Years`
  /// form the field displays, via [experienceDisplayValue].
  final String? experienceYears;

  /// Where the uploaded avatar lives, absolute, or null when there is none.
  ///
  /// **Shipped 2026-10-05.** `/me/` had no photo field at all until then, which
  /// is why the store's [UserProfile.photoBytes] was only ever filled at signup —
  /// every later login showed the placeholder.
  ///
  /// Deliberately **not** in [profileValues]: that map is `String` to `String`
  /// and this is a URL whose *bytes* have to be fetched, with the bearer token,
  /// before anything can render. `SessionBootstrap` does that step — see
  /// `AuthApi.fetchProfilePhoto`.
  ///
  /// Same-origin and Bearer-authenticated (confirmed by the backend 2026-10-05),
  /// so the token is safe to send. Only ever read from this field, never from
  /// anything the user supplied.
  final String? profilePhotoUrl;

  /// Parses the `/me/` body, or returns null when it carries no identity.
  ///
  /// Null rather than a half-filled object, matching `RegisteredAccount`: a body
  /// with neither an id nor an email is a contract mismatch, and returning it
  /// would let the caller overwrite a good profile with blanks.
  static MeProfile? tryParse(Object? body) {
    if (body is! Map) return null;
    final json = body.cast<String, dynamic>();

    // `/me/` is flat but a `user` wrapper costs nothing to accept, and the same
    // model then also reads an auth response's user object if it is ever handed
    // one.
    final nested = json['user'];
    final user = nested is Map ? nested.cast<String, dynamic>() : json;

    final userId = _firstString([user['id'], user['pk'], user['user_id']]);
    final email = _firstString([user['email']]);

    // No id and no email means this is not a user object.
    if (userId == null && email == null) return null;

    return MeProfile(
      userId: userId,
      email: email,
      name: _firstString([user['name'], user['full_name'], user['fullname']]),
      role: ProfileRole.tryParse(_firstString([user['role']])),
      gender: _firstString([user['gender']]),
      dob: _firstString([user['dob'], user['date_of_birth']]),
      phoneCountryCode: _firstString([
        user['phone_country_code'],
        user['country_code'],
      ]),
      phoneNumber: _firstString([user['phone_number']]),
      location: _firstString([user['location']]),
      verificationStatus: _firstString([
        user['verification_status'],
        // The older name, kept as a fallback so a drift here degrades instead
        // of dropping the status.
        user['status'],
      ]),
      onboardingCompleted: _firstBool(user['onboarding_completed']),
      isActive: _firstBool(user['is_active']),

      // The completion fields. Each accepts the spellings the write side might
      // use, because only the write side has ever been observed — see the class
      // doc. `_firstString` returns the first non-blank, so a null on the
      // preferred key falls through to the alternative rather than winning.
      gradeId: _firstString([user['grade_id'], user['grade']]),
      provinceId: _firstString([user['province_id'], user['province']]),
      districtId: _firstString([user['district_id'], user['district']]),
      municipalityId: _firstString([
        user['municipality_id'],
        user['municipality'],
      ]),
      schoolId: _firstString([user['school_id'], user['school']]),
      qualification: _firstString([user['qualification']]),
      subjectExpertise: _firstString([
        user['subject_expertise'],
        user['expertise'],
      ]),
      experienceYears: _firstString([
        user['experience_years'],
        user['experience'],
      ]),
      profilePhotoUrl: _firstString([
        user['profile_photo_url'],
        user['photo_url'],
      ]),
    );
  }

  /// Only the fields that map onto [UserProfile.values], for merging.
  ///
  /// Blank values are **omitted**, not written as empty strings: the caller
  /// merges this over an existing profile, and an empty string would erase a
  /// value the user typed. Absent keys leave those fields alone.
  ///
  /// Three conversions happen here rather than at each call site, because the
  /// store is keyed the way the **form controllers** are and the server speaks
  /// its own vocabulary:
  ///
  /// - **gender** arrives as a wire value (`female`) and the store holds the
  ///   label the picker shows (`Female`). An unrecognised value is omitted
  ///   rather than stored raw — the store's contract is labels, and a raw
  ///   `zzz` would render in a field the picker cannot select.
  /// - **dob** arrives as ISO and the form reads `DD / MM / YYYY`, via
  ///   [formDateOf]. Without this the field would show `2001-05-14` and fail its
  ///   own validator on the next save.
  /// - **phone** arrives split in two and the form has one field, via
  /// [joinPhoneNumber].
  ///
  /// - **experience** arrives as the bare number the field displays as
  ///   `5 Years`, via [experienceDisplayValue].
  ///
  /// **The four geographic fields are deliberately absent.** They arrive as ids
  /// and the store is keyed by names, so they need a round trip through the
  /// reference data that this pure getter cannot make — `SessionBootstrap`
  /// resolves them and merges the names separately. Putting them here would mean
  /// a raw id landing in a field that renders a province's name.
  Map<String, String> get profileValues => {
    if ((name ?? '').isNotEmpty) 'name': name!,
    if ((email ?? '').isNotEmpty) 'email': email!,
    if (Gender.tryParse(gender) case final Gender parsed)
      'gender': parsed.label,
    if (formDateOf(dob) case final String date) 'dob': date,
    if (joinPhoneNumber(phoneCountryCode, phoneNumber) case final String phone)
      'phone': phone,
    if ((location ?? '').isNotEmpty) 'location': location!,
    if ((qualification ?? '').isNotEmpty) 'qualification': qualification!,
    if ((subjectExpertise ?? '').isNotEmpty) 'expertise': subjectExpertise!,
    if (experienceDisplayValue(experienceYears) case final String years
        when years.isNotEmpty)
      'experience': years,
  };

  @override
  String toString() =>
      'MeProfile(id: $userId, email: $email, role: ${role?.wireValue}, '
      'verification: $verificationStatus)';
}

/// The first non-blank scalar in [candidates], as a string, or null.
///
/// Duplicated from `registered_account.dart` rather than shared: it is six lines,
/// and a shared "json helpers" module for one function would be a bigger
/// dependency than the duplication. Numbers are stringified because a Django
/// `AutoField` id arrives as a JSON **number** — accepting only strings drops
/// the id silently.
String? _firstString(List<Object?> candidates) {
  for (final candidate in candidates) {
    if (candidate is num) return candidate.toString();
    if (candidate is String && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
  }
  return null;
}

/// A bool, or null when the value is absent or not a bool.
///
/// Not `value as bool?`: a JSON `"false"` or `0` would throw on the cast, and a
/// wrong type in one optional field should not fail the whole parse.
bool? _firstBool(Object? value) => value is bool ? value : null;
