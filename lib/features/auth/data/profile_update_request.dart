import 'package:flutter/foundation.dart';

import '../../../core/validation/validators.dart';
import '../../profile/data/gender.dart';

/// The seven fields every role shares, shaped for `PATCH /me/`.
///
/// **The counterpart to [InstructorCompletionRequest], and the other half of the
/// same change.** The instructor request handles the nine fields only that
/// completion route accepts; this one handles the fields `PATCH /me/` accepts —
/// `name`, `email`, `gender`, `dob`, `phone_country_code`, `phone_number`,
/// `location` — which is every field Edit Profile shows above the role's own
/// block.
///
/// **Why a class and not a map built at the call site.** The conversion is not
/// one line. The store is keyed the way the **form controllers** are (`gender`
/// holds the label `Female`, `phone` holds one number, `dob` holds
/// `DD / MM / YYYY`) and the wire wants its own vocabulary (`female`, the number
/// split in two, `YYYY-MM-DD`). Scattered across a save method those three
/// conversions would be easy to apply to one role and not the other, and a
/// missed one is silent — the backend accepts a body with the key simply
/// absent.
///
/// **Blank values are omitted, not sent empty.** Measured on the live backend
/// 2026-10-02: `{"gender": ""}` is a 400 (`"" is not a valid choice`) and
/// `{"dob": ""}` is a 400 (wrong format), while `{"location": ""}` and
/// `{"phone_number": ""}` are accepted and clear the field. So an emptied gender
/// or date of birth has to be *left out* — the field keeps its server value
/// rather than erroring the whole save. That asymmetry is a backend constraint,
/// not a choice, and it is why [isEmpty] can be true for a form the user filled
/// in and then cleared.
@immutable
class ProfileUpdateRequest {
  const ProfileUpdateRequest({required this.fields});

  /// Builds the body from the profile store's values — the same map the edit
  /// form's controllers hold and the completeness gate reads, so a field the
  /// form shows cannot arrive here under a different key than it was saved with.
  factory ProfileUpdateRequest.fromValues(Map<String, String> values) {
    final phone = splitPhoneNumber(values['phone']);
    return ProfileUpdateRequest(
      fields: {
        if (_nonBlank(values['name']) case final String name) 'name': name,
        if (_nonBlank(values['email']) case final String email) 'email': email,
        // The store holds the picker's label, the wire wants the lowercase
        // choice. `wireValueOf` passes an unrecognised value through rather
        // than blanking it, so a vocabulary drift fails at the server — where it
        // is defined — instead of silently clearing the user's gender.
        if (_nonBlank(values['gender']) case final String gender)
          'gender': Gender.wireValueOf(gender),
        // ISO, not the form's `DD / MM / YYYY`. A value that does not parse is
        // omitted: `isoDateOf` returns null rather than passing nonsense on, and
        // a wrong format is a 400 that would fail the whole save over one field.
        if (isoDateOf(values['dob']) case final String dob) 'dob': dob,
        // Omitted together when the number did not parse, rather than sent as a
        // blank pair.
        if (phone != null) ...{
          'phone_country_code': phone.countryCode,
          'phone_number': phone.number,
        },
        if (_nonBlank(values['location']) case final String location)
          'location': location,
      },
    );
  }

  /// The wire body, keyed exactly as `PATCH /me/` names the fields.
  final Map<String, String> fields;

  /// True when there is nothing worth sending.
  ///
  /// The caller must not issue the request. An empty body is a `PATCH` that
  /// changes nothing, and — since the endpoint answers 200 to any subset of its
  /// fields — reporting success for it would be a claim about a request that had
  /// no effect.
  bool get isEmpty => fields.isEmpty;

  @override
  String toString() => 'ProfileUpdateRequest(${fields.keys.join(', ')})';
}

/// See `InstructorCompletionRequest._nonBlank` — the same rule, kept local for
/// the same reason: the two files encode for different endpoints, and sharing one
/// helper would couple contracts that can diverge.
String? _nonBlank(String? value) {
  final trimmed = (value ?? '').trim();
  return trimmed.isEmpty ? null : trimmed;
}