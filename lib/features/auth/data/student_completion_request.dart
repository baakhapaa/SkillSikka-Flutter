import 'package:flutter/foundation.dart';

import '../../../core/validation/validators.dart';
import '../../profile/data/profile_role.dart';

/// A student's deferred profile, shaped for `POST /me/complete-profile/`.
///
/// **The counterpart to [InstructorCompletionRequest].** That class handles the
/// nine fields `/instructor/complete-profile/` wants; this one handles the seven
/// `/me/complete-profile/` wants. Until this existed the student's side of Edit
/// Profile was display-only — the class, province, district and school a student
/// picked were written to the in-memory store and never sent.
///
/// **All seven are required, and the route validates the hierarchy.** Measured on
/// the live backend 2026-10-02 by posting an empty body, which names every one:
///
/// ```
/// {"phone_country_code":["This field is required."],
///  "phone_number":["This field is required."],
///  "location":["This field is required."],
///  "grade_id":["This field is required."],
///  "province_id":["This field is required."],
///  "district_id":["This field is required."],
///  "school_id":["This field is required."]}
/// ```
///
/// `municipality_id` is **not** in that list, but omitting it is worse than
/// omitting anything else: the handler reads a `municipality` key it never
/// validated, so a body without it is a **`500 KeyError: 'municipality'`** — a
/// server error rather than a message the user could act on. It has to be sent,
/// and the student's form has no municipality picker to get it from. See
/// [municipalityId]: the school carries it.
///
/// The hierarchy is enforced too — `{"province_id":3,"district_id":73,…}` with
/// Acham under Bagmati answers `"District does not belong to the selected
/// province."`, and likewise for municipality against district. So the ids have
/// to be a genuinely consistent chain, not merely present.
@immutable
class StudentCompletionRequest {
  const StudentCompletionRequest({required this.fields});

  /// Builds the body from the profile store's values plus the ids behind them.
  ///
  /// [values] is `UserProfile.values` — the same map the form's controllers hold
  /// and the completeness gate reads, so a field the gate counts as filled
  /// cannot arrive here blank.
  ///
  /// The ids are passed separately because the store holds the **names** the user
  /// read, and this endpoint wants primary keys. They are resolved from the
  /// reference data rather than remembered from the picker, because a student who
  /// has just signed in has names in the store and no ids anywhere — the picker
  /// state only ever existed while a sheet was open.
  ///
  /// All seven arguments are optional and **omitted when absent** rather than
  /// sent as empty strings: this route is all-or-nothing (see the class doc), so
  /// a partial body earns a 400 naming every missing field rather than a partial
  /// save. [isComplete] decides whether to send at all.
  factory StudentCompletionRequest.fromValues(
    Map<String, String> values, {
    String? gradeId,
    String? provinceId,
    String? districtId,
    String? municipalityId,
    String? schoolId,
  }) {
    final phone = splitPhoneNumber(values['phone']);
    return StudentCompletionRequest(
      fields: {
        // Omitted together when the number did not parse, rather than sent as a
        // blank pair.
        if (phone != null) ...{
          'phone_country_code': phone.countryCode,
          'phone_number': phone.number,
        },
        if (_nonBlank(values['location']) != null)
          'location': values['location']!.trim(),
        if (_nonBlank(gradeId) != null) 'grade_id': gradeId!.trim(),
        if (_nonBlank(provinceId) != null) 'province_id': provinceId!.trim(),
        if (_nonBlank(districtId) != null) 'district_id': districtId!.trim(),
        if (_nonBlank(municipalityId) != null)
          'municipality_id': municipalityId!.trim(),
        if (_nonBlank(schoolId) != null) 'school_id': schoolId!.trim(),
      },
    );
  }

  /// The body, keyed as `/me/complete-profile/` names the fields.
  final Map<String, String> fields;

  /// True when nothing is worth sending.
  ///
  /// The caller must not issue the request. A student who opened Edit Profile
  /// and saved without touching anything should not have their profile marked
  /// complete, and should certainly not be shown an error for it.
  bool get isEmpty => fields.isEmpty;

  /// True when every field the route needs is present.
  ///
  /// **This route has no partial mode.** Unlike `PATCH /me/`, which accepts any
  /// subset of its seven, `/me/complete-profile/` demands all of them and names
  /// every missing one in a single 400. So a body that is merely non-empty is
  /// not sendable — a student who filled in a class but not a school gets
  /// nothing saved, and the honest outcome is to leave it alone rather than to
  /// earn an error they cannot resolve.
  ///
  /// Every key in [requiredFields] must be present. This counts **absences, not
  /// entries**: an earlier version compared `fields.length` against
  /// `requiredFields.length`, which read as stricter but was wrong the moment the
  /// body carried `municipality_id` as well — a complete request came back
  /// incomplete and was silently never sent.
  bool get isComplete => requiredFields.every(fields.containsKey);

  /// The keys this route needs.
  ///
  /// The first seven are what an empty body names back, verbatim. `municipality_id`
  /// is here too although the serializer does not list it as required: the handler
  /// reads a `municipality` key it never validated, so omitting it is a **500**
  /// rather than a 400. Listing it here is what makes [isComplete] mean
  /// "safe to send" rather than "passes validation".
  static const requiredFields = <String>{
    'phone_country_code',
    'phone_number',
    'location',
    'grade_id',
    'province_id',
    'district_id',
    'school_id',
    'municipality_id',
  };

  /// The same fields, as whatever the completion endpoint calls its inputs.
  ///
  /// **Identity, deliberately** — the same reasoning as
  /// `InstructorCompletionRequest.toWireBody`. The route discriminates the role
  /// by path, not by a field in the body, and the keys here are already the wire
  /// names, so there is nothing to translate.
  ///
  /// `role` rides along for the same reason it does there: it costs nothing, and
  /// the test double records the role alongside the fields so a test can assert
  /// which set was sent.
  Map<String, String> toWireBody(ProfileRole role) => {
    'role': role.wireValue,
    ...fields,
  };

  @override
  String toString() => 'StudentCompletionRequest(${fields.keys.join(', ')})';
}

/// See `InstructorCompletionRequest._nonBlank` — the same rule, kept local for
/// the same reason: two endpoints, two contracts, and sharing one helper would
/// couple contracts that can diverge.
String? _nonBlank(String? value) {
  final trimmed = (value ?? '').trim();
  return trimmed.isEmpty ? null : trimmed;
}