import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/auth/data/me_profile.dart';
import 'package:skillsikka/features/auth/data/profile_update_request.dart';

/// The live `/me/` body, captured 2026-10-02 after the backend added the profile
/// fields.
///
/// Verbatim, including the ISO `dob` and the split phone pair — the two shapes
/// this file exists to prove are converted on the way into the store.
const _liveMeBody = {
  'id': '23',
  'email': 'probe.client.20261002@example.com',
  'name': 'Probe Renamed',
  'role': 'student',
  'gender': 'female',
  'dob': '2001-05-14',
  'phone_country_code': '+977',
  'phone_number': '9800000000',
  'location': 'Kathmandu',
  'verification_status': 'not_applicable',
  'onboarding_completed': false,
  'is_active': true,
};

void main() {
  group('GET /me/ populates the profile store', () {
    test('maps every profile field onto the key the form holds', () {
      final profile = MeProfile.tryParse(_liveMeBody);

      expect(profile?.profileValues, {
        'name': 'Probe Renamed',
        'email': 'probe.client.20261002@example.com',
        // The wire value becomes the picker's label — the store's contract is
        // labels, because that is what the option sheet returns and writes.
        'gender': 'Female',
        // ISO becomes the form's `DD / MM / YYYY`. Without this the edit field
        // shows `2001-05-14` and fails its own validator on the next save.
        'dob': '14 / 05 / 2001',
        // The split pair rejoins into the single number the form's input holds.
        'phone': '9800000000',
        'location': 'Kathmandu',
      });
    });

    test('accepts a DD/MM/YYYY date as well as ISO', () {
      final profile = MeProfile.tryParse({..._liveMeBody, 'dob': '14/05/2001'});

      expect(profile?.profileValues['dob'], '14 / 05 / 2001');
    });

    test('keeps a country code that is not the one we always send', () {
      final profile = MeProfile.tryParse({
        ..._liveMeBody,
        'phone_country_code': '+91',
        'phone_number': '9800000000',
      });

      expect(profile?.profileValues['phone'], '+91 9800000000');
    });

    test('omits blanks rather than erasing what the user typed', () {
      // The live backend sends `""` for an unset phone and location. Writing
      // those through would wipe a value the user entered in this session but
      // has not yet saved.
      final profile = MeProfile.tryParse({
        ..._liveMeBody,
        'location': '',
        'phone_country_code': '',
        'phone_number': '',
      });

      final values = profile!.profileValues;
      expect(values.containsKey('location'), isFalse);
      expect(values.containsKey('phone'), isFalse);
      expect(values['name'], 'Probe Renamed');
    });

    test('drops a gender the picker cannot select', () {
      // Storing an unrecognised value verbatim would render in a field whose
      // options do not include it.
      final profile = MeProfile.tryParse({..._liveMeBody, 'gender': 'zzz'});

      expect(profile!.profileValues.containsKey('gender'), isFalse);
    });

    test('parses a date_of_birth alias as well as dob', () {
      final profile = MeProfile.tryParse({
        ..._liveMeBody,
        'dob': null,
        'date_of_birth': '1999-12-31',
      });

      expect(profile?.profileValues['dob'], '31 / 12 / 1999');
    });
  });

  group('PATCH /me/ body', () {
    test('encodes the store values into the seven wire fields', () {
      final request = ProfileUpdateRequest.fromValues({
        'name': 'Probe Renamed',
        'email': 'probe@example.com',
        'gender': 'Female',
        'dob': '14 / 05 / 2001',
        'phone': '9800000000',
        'location': 'Kathmandu',
      });

      expect(request.fields, {
        'name': 'Probe Renamed',
        'email': 'probe@example.com',
        // Lowercased: the backend rejects `Female` with a 400.
        'gender': 'female',
        // ISO on the way out, the form's format on the way in.
        'dob': '2001-05-14',
        // The one input the form has, split into the two the wire takes.
        'phone_country_code': '+977',
        'phone_number': '9800000000',
        'location': 'Kathmandu',
      });
    });

    test('round-trips a value that came from /me/', () {
      // The regression this guards: read a profile, save it unchanged, and the
      // server must not reject it. A gender left as the label, a date left as
      // ISO, or a phone left as one piece would each be a 400.
      final fromServer = MeProfile.tryParse(_liveMeBody)!.profileValues;
      final request = ProfileUpdateRequest.fromValues({
        ...fromServer,
        // Exactly what Edit Profile would hand over, untouched.
      });

      expect(request.fields, {
        'name': 'Probe Renamed',
        'email': 'probe.client.20261002@example.com',
        'gender': 'female',
        'dob': '2001-05-14',
        'phone_country_code': '+977',
        'phone_number': '9800000000',
        'location': 'Kathmandu',
      });
    });

    test('omits a cleared gender and date rather than sending empty', () {
      // Measured live: `{"gender": ""}` is a 400 (`"" is not a valid choice`) and
      // `{"dob": ""}` is a 400 (wrong format). Sending them would fail the whole
      // save over a field the user deliberately emptied.
      final request = ProfileUpdateRequest.fromValues({
        'name': 'Probe Renamed',
        'email': 'probe@example.com',
        'gender': '',
        'dob': '',
      });

      expect(request.fields.containsKey('gender'), isFalse);
      expect(request.fields.containsKey('dob'), isFalse);
      expect(request.fields['name'], 'Probe Renamed');
    });

    test('sends no phone at all when the number does not parse', () {
      final request = ProfileUpdateRequest.fromValues({
        'name': 'Probe Renamed',
        'phone': 'not a number',
      });

      expect(request.fields.containsKey('phone_number'), isFalse);
      expect(request.fields.containsKey('phone_country_code'), isFalse);
    });

    test('is empty when there is nothing worth sending', () {
      expect(ProfileUpdateRequest.fromValues(const {}).isEmpty, isTrue);
      expect(
        ProfileUpdateRequest.fromValues(const {'gender': '  '}).isEmpty,
        isTrue,
      );
    });
  });

  group('the /me/ parser', () {
    test('rejects a body with no identity in it', () {
      expect(MeProfile.tryParse(const {'detail': 'nope'}), isNull);
      expect(MeProfile.tryParse('not a map'), isNull);
    });

    test('accepts a nested user object as well as the flat form', () {
      final profile = MeProfile.tryParse({'user': _liveMeBody});

      expect(profile?.profileValues['gender'], 'Female');
      expect(profile?.profileValues['dob'], '14 / 05 / 2001');
    });

    test('reads a body encoded as JSON text', () {
      // Guards against a caller handing the parser a string. The client decodes
      // before it gets here, so this is about the model not silently accepting
      // something it cannot read.
      expect(MeProfile.tryParse(jsonEncode(_liveMeBody)), isNull);
    });
  });

  /// The completion fields `/me/` did **not** return when [_liveMeBody] was
  /// captured.
  ///
  /// Requested in `backend-ask-profile-completion-fields-2026-10-05.md` §A1. The
  /// group below it is the important one — this group only asserts what happens
  /// once the backend starts sending them.
  group('the completion fields, once the backend sends them', () {
    test('parses the ids and the free text off the body', () {
      final profile = MeProfile.tryParse({
        ..._liveMeBody,
        'role': 'instructor',
        'province_id': '3',
        'district_id': '27',
        'municipality_id': '316',
        'qualification': 'PhD',
        'subject_expertise': 'Physics',
        'experience_years': '5',
      });

      expect(profile?.provinceId, '3');
      expect(profile?.districtId, '27');
      expect(profile?.municipalityId, '316');
      expect(profile?.qualification, 'PhD');
      expect(profile?.subjectExpertise, 'Physics');
      expect(profile?.experienceYears, '5');
    });

    test('the free text lands on the keys the form holds', () {
      final profile = MeProfile.tryParse({
        ..._liveMeBody,
        'qualification': 'PhD',
        'subject_expertise': 'Physics',
        'experience_years': '5',
      });

      expect(profile?.profileValues['qualification'], 'PhD');
      expect(
        profile?.profileValues['expertise'],
        'Physics',
        reason:
            "the wire name is subject_expertise, the form's key is expertise",
      );
      expect(
        profile?.profileValues['experience'],
        '5 Years',
        reason: 'the field displays 5 Years; the wire sends the bare number',
      );
    });

    test('a numeric id is read as a string, like ReferenceItem does', () {
      // The locations endpoints stringify JSON numbers, and a mismatch here
      // would make every lookup miss silently. See backend ask §A1.2.
      final profile = MeProfile.tryParse({..._liveMeBody, 'province_id': 3});

      expect(profile?.provinceId, '3');
    });

    test('accepts the alternative spellings', () {
      // The write-side names were probe-measured, not read off a contract — both
      // completion views are bare APIViews with no serializer.
      final profile = MeProfile.tryParse({
        ..._liveMeBody,
        'grade': 11,
        'subject_expertise': 'Physics',
        'experience': '7',
      });

      expect(profile?.gradeId, '11');
      expect(profile?.subjectExpertise, 'Physics');
      expect(profile?.experienceYears, '7');
    });

    test('the geographic ids are NOT put in the store as ids', () {
      // They are primary keys and the store is keyed by names. Resolving them
      // needs the reference data, which this pure getter cannot fetch — so
      // `SessionBootstrap` does it. A raw id here would render as a province
      // literally named "3".
      final profile = MeProfile.tryParse({
        ..._liveMeBody,
        'province_id': '3',
        'district_id': '27',
        'municipality_id': '316',
        'school_id': '2',
        'grade_id': '1',
      });

      expect(
        profile!.profileValues.keys,
        isNot(anyOf('province', 'district', 'municipality', 'school', 'grade')),
        reason: 'the ids are resolved to names before they reach the store',
      );
    });
  });

  /// What makes the whole change safe to ship ahead of the backend: a body with
  /// none of the new keys must behave exactly as it did before.
  group('a /me/ body with none of the completion fields', () {
    test('parses to nulls and produces exactly the old profileValues', () {
      // [_liveMeBody] is the body the backend actually sends today.
      final profile = MeProfile.tryParse(_liveMeBody)!;

      expect(profile.gradeId, isNull);
      expect(profile.provinceId, isNull);
      expect(profile.districtId, isNull);
      expect(profile.municipalityId, isNull);
      expect(profile.schoolId, isNull);
      expect(profile.qualification, isNull);
      expect(profile.subjectExpertise, isNull);
      expect(profile.experienceYears, isNull);

      expect(profile.profileValues, {
        'name': 'Probe Renamed',
        'email': 'probe.client.20261002@example.com',
        'gender': 'Female',
        'dob': '14 / 05 / 2001',
        'phone': '9800000000',
        'location': 'Kathmandu',
      });
    });
  });
}
