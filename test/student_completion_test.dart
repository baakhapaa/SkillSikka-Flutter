import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/auth/data/student_completion_request.dart';
import 'package:skillsikka/features/profile/data/profile_role.dart';
import 'package:skillsikka/features/profile/data/reference_data.dart';

/// A slice of the live reference data, copied 2026-10-02.
///
/// Real values, not invented ones: the ids have to be the backend's, because the
/// completion route validates the hierarchy against them and a test with made-up
/// ids would pass while the real save failed.
const _provinces = [
  ReferenceItem(id: '3', name: 'Bagmati'),
  ReferenceItem(id: '4', name: 'Gandaki'),
];
const _districts = [
  ReferenceItem(id: '27', name: 'Kathmandu', provinceId: '3'),
  // Belongs to Gandaki — pairing this with Bagmati is what the endpoint rejects.
  ReferenceItem(id: '36', name: 'Baglung', provinceId: '4'),
];
const _schools = [
  // A school with no municipality, which is what the route 500s on.
  ReferenceItem(id: '1', name: 'Orphan School'),
  ReferenceItem(id: '2', name: 'TestSchooll', municipalityId: '316'),
];
const _grades = [
  ReferenceItem(id: '1', name: 'Grade 1'),
  ReferenceItem(id: '11', name: 'Grade 11'),
];

/// Added 2026-10-05 for the instructor, who has a municipality picker and so
/// needs a municipality resolved from its **name**. The forward direction never
/// used this list, because a student's municipality comes off their school.
const _municipalities = [
  ReferenceItem(
    id: '316',
    name: 'Kathmandu Metropolitan City',
    districtId: '27',
  ),
  // A uniquely named municipality in the *other* district, so the hierarchy
  // check has something it can actually refuse.
  ReferenceItem(id: '320', name: 'Baglung Municipality', districtId: '36'),
  // Two municipalities genuinely share this name. See the duplicate-name test
  // below for why that matters and which direction it breaks.
  ReferenceItem(id: '318', name: 'Aaurahi', districtId: '27'),
  ReferenceItem(id: '319', name: 'Aaurahi', districtId: '36'),
];

void main() {
  group('resolving names to ids', () {
    test('resolves the whole chain from the names the store holds', () {
      final resolved = resolveLocationIds(
        grades: _grades,
        provinces: _provinces,
        districts: _districts,
        schools: _schools,
        gradeName: 'Grade 1',
        provinceName: 'Bagmati',
        districtName: 'Kathmandu',
        schoolName: 'TestSchooll',
      );

      expect(resolved.gradeId, '1');
      expect(resolved.locations.provinceId, '3');
      expect(resolved.locations.districtId, '27');
      // From the **school** — the student's form has no municipality picker.
      expect(resolved.locations.municipalityId, '316');
      expect(resolved.locations.schoolId, '2');
    });

    test('refuses a district that does not belong to the province', () {
      // The endpoint answers "District does not belong to the selected
      // province." Resolving it here would only move that rejection later, and
      // would pair a school with a district it has no relationship to.
      final resolved = resolveLocationIds(
        grades: _grades,
        provinces: _provinces,
        districts: _districts,
        schools: _schools,
        gradeName: 'Grade 1',
        provinceName: 'Bagmati',
        districtName: 'Baglung',
        schoolName: 'TestSchooll',
      );

      expect(resolved.locations.provinceId, '3');
      expect(resolved.locations.districtId, isNull);
    });

    test('matches names case-insensitively', () {
      final resolved = resolveLocationIds(
        grades: _grades,
        provinces: _provinces,
        districts: _districts,
        schools: _schools,
        gradeName: 'grade 11',
        provinceName: 'BAGMATI',
        districtName: 'kathmandu',
        schoolName: 'testschooll',
      );

      expect(resolved.gradeId, '11');
      expect(resolved.locations.schoolId, '2');
    });

    test('yields nulls rather than guessing when a name is unknown', () {
      final resolved = resolveLocationIds(
        grades: _grades,
        provinces: _provinces,
        districts: _districts,
        schools: _schools,
        gradeName: 'Grade 99',
        provinceName: 'Nowhere',
        districtName: 'Nowhere',
        schoolName: 'Nowhere',
      );

      expect(resolved.gradeId, isNull);
      expect(resolved.locations.isEmpty, isTrue);
    });

    test('reads municipality_id off a school', () {
      // The reason `ReferenceItem` grew the field: this is the only place a
      // student's `municipality_id` can come from.
      expect(_schools[1].municipalityId, '316');
      expect(_schools[0].municipalityId, isNull);
    });
  });

  group('the student completion body', () {
    /// The store values a signed-in student has, plus the ids resolved from them.
    Map<String, String> body({
      Map<String, String> values = const {
        'phone': '9800000000',
        'location': 'Kathmandu',
      },
      String? municipalityId = '316',
    }) {
      final request = StudentCompletionRequest.fromValues(
        values,
        gradeId: '1',
        provinceId: '3',
        districtId: '27',
        municipalityId: municipalityId,
        schoolId: '2',
      );
      return request.toWireBody(ProfileRole.student);
    }

    test('sends the seven fields plus the role', () {
      // Verbatim the shape the live backend answered 200 to on 2026-10-02.
      expect(body(), {
        'role': 'student',
        'phone_country_code': '+977',
        'phone_number': '9800000000',
        'location': 'Kathmandu',
        'grade_id': '1',
        'province_id': '3',
        'district_id': '27',
        'municipality_id': '316',
        'school_id': '2',
      });
    });

    test('is complete only when every required field is present', () {
      final complete = StudentCompletionRequest.fromValues(
        const {'phone': '9800000000', 'location': 'Kathmandu'},
        gradeId: '1',
        provinceId: '3',
        districtId: '27',
        municipalityId: '316',
        schoolId: '2',
      );
      expect(complete.isComplete, isTrue);

      // Missing one field fails the whole body at the endpoint, so the client
      // must not send it.
      final missingSchool = StudentCompletionRequest.fromValues(
        const {'phone': '9800000000', 'location': 'Kathmandu'},
        gradeId: '1',
        provinceId: '3',
        districtId: '27',
        municipalityId: '316',
      );
      expect(missingSchool.isComplete, isFalse);
    });

    test('is incomplete without a municipality, which is a 500 not a 400', () {
      // The handler reads a `municipality` key it never validated, so omitting
      // it crashes the server rather than returning a message the user could act
      // on. isComplete has to account for it.
      final request = StudentCompletionRequest.fromValues(
        const {'phone': '9800000000', 'location': 'Kathmandu'},
        gradeId: '1',
        provinceId: '3',
        districtId: '27',
        municipalityId: null,
        schoolId: '2',
      );

      expect(request.fields.containsKey('municipality_id'), isFalse);
      expect(request.isComplete, isFalse);
    });

    test('is empty when there is nothing to send', () {
      expect(StudentCompletionRequest.fromValues(const {}).isEmpty, isTrue);
      // A body holding only a space is as empty as one holding nothing.
      expect(
        StudentCompletionRequest.fromValues(const {'phone': '  '}).isEmpty,
        isTrue,
      );
    });

    test('sends no phone at all when the number does not parse', () {
      final request = StudentCompletionRequest.fromValues(const {
        'phone': 'not a number',
        'location': 'Kathmandu',
      }, gradeId: '1');

      expect(request.fields.containsKey('phone_number'), isFalse);
      expect(request.fields.containsKey('phone_country_code'), isFalse);
      expect(request.isComplete, isFalse);
    });
  });

  /// The instructor half of the same resolver.
  ///
  /// **This is the live bug.** `_instructorBody` used to read ids only from the
  /// picker, so an instructor saving a profile that was prefilled rather than
  /// re-picked sent all three geographic ids missing — and all three are required
  /// on `/instructor/complete-profile/`. A student never hit it because
  /// `_studentBody` already resolved from the names.
  group("resolving an instructor's municipality from its name", () {
    test('resolves all three ids from the names alone', () {
      final resolved = resolveLocationIds(
        grades: _grades,
        provinces: _provinces,
        districts: _districts,
        schools: _schools,
        municipalities: _municipalities,
        gradeName: '',
        provinceName: 'Bagmati',
        districtName: 'Kathmandu',
        schoolName: '',
        municipalityName: 'Kathmandu Metropolitan City',
      );

      expect(resolved.locations.provinceId, '3');
      expect(resolved.locations.districtId, '27');
      expect(
        resolved.locations.municipalityId,
        '316',
        reason: 'the instructor has no school, so the name is the only source',
      );
    });

    test('refuses a municipality outside the chosen district', () {
      // Same rule as district-against-province, and for the same reason: the
      // endpoint checks it, so resolving it here would only move the rejection.
      final resolved = resolveLocationIds(
        grades: _grades,
        provinces: _provinces,
        districts: _districts,
        schools: _schools,
        municipalities: _municipalities,
        gradeName: '',
        provinceName: 'Bagmati',
        districtName: 'Kathmandu',
        schoolName: '',
        // Belongs to district 36 (Baglung), not 27.
        municipalityName: 'Baglung Municipality',
      );

      expect(resolved.locations.municipalityId, isNull);
    });

    test(
      'a duplicate name resolves to the first match, and that is a limit',
      () {
        // **A known asymmetry, recorded rather than worked around.** `_byName`
        // returns the first row whose name matches, and two Aaurahi
        // municipalities really do exist. So a prefilled instructor profile
        // holding the name "Aaurahi" resolves to whichever the endpoint listed
        // first, which may be the wrong district — and the hierarchy check then
        // refuses it, leaving the id unset rather than wrong.
        //
        // That is the safe failure, and it is why this direction never guesses.
        // It is also why the reverse direction can be exact: ids are unique.
        final resolved = resolveLocationIds(
          grades: _grades,
          provinces: _provinces,
          districts: _districts,
          schools: _schools,
          municipalities: _municipalities,
          gradeName: '',
          provinceName: 'Gandaki',
          districtName: 'Baglung',
          schoolName: '',
          municipalityName: 'Aaurahi',
        );

        expect(
          resolved.locations.municipalityId,
          isNull,
          reason:
              'the first Aaurahi belongs to Kathmandu, so pairing it with '
              'Baglung is refused rather than sent',
        );
      },
    );

    test(
      'a student with no municipality name still resolves off the school',
      () {
        // The exact call shape the student's form produces: `municipalityName`
        // absent entirely, because `_studentKeys` has no `municipality` key.
        final resolved = resolveLocationIds(
          grades: _grades,
          provinces: _provinces,
          districts: _districts,
          schools: _schools,
          gradeName: 'Grade 1',
          provinceName: 'Bagmati',
          districtName: 'Kathmandu',
          schoolName: 'TestSchooll',
        );

        expect(
          resolved.locations.municipalityId,
          '316',
          reason:
              'the name path must not shadow the school path, or the student '
              'route 500s on a missing municipality_id',
        );
      },
    );
  });

  group('resolving ids back to names', () {
    test('maps the whole chain', () {
      final resolved = resolveLocationNames(
        grades: _grades,
        provinces: _provinces,
        districts: _districts,
        municipalities: _municipalities,
        schools: _schools,
        gradeId: '11',
        provinceId: '3',
        districtId: '27',
        municipalityId: '316',
        schoolId: '2',
      );

      expect(resolved.gradeName, 'Grade 11');
      expect(resolved.locations.province, 'Bagmati');
      expect(resolved.locations.district, 'Kathmandu');
      expect(resolved.locations.municipality, 'Kathmandu Metropolitan City');
      expect(resolved.locations.school, 'TestSchooll');
    });

    test('tells two same-named municipalities apart by id', () {
      // The reason this direction can be exact where the forward one cannot:
      // ids are unique, names are not.
      final first = resolveLocationNames(
        grades: _grades,
        provinces: _provinces,
        districts: _districts,
        municipalities: _municipalities,
        schools: _schools,
        municipalityId: '318',
      );
      final second = resolveLocationNames(
        grades: _grades,
        provinces: _provinces,
        districts: _districts,
        municipalities: _municipalities,
        schools: _schools,
        municipalityId: '319',
      );

      expect(first.locations.municipality, 'Aaurahi');
      expect(second.locations.municipality, 'Aaurahi');
      expect(
        first.locations.district,
        isNull,
        reason: 'ids resolve independently — no hierarchy is re-checked here',
      );
    });

    test('a blank or absent id resolves to nothing at all', () {
      final resolved = resolveLocationNames(
        grades: _grades,
        provinces: _provinces,
        districts: _districts,
        municipalities: _municipalities,
        schools: _schools,
        provinceId: '   ',
        districtId: null,
      );

      expect(resolved.locations.isEmpty, isTrue);
    });

    test('an id the reference data does not have resolves to null', () {
      final resolved = resolveLocationNames(
        grades: _grades,
        provinces: _provinces,
        districts: _districts,
        municipalities: _municipalities,
        schools: _schools,
        provinceId: '9999',
      );

      expect(resolved.locations.province, isNull);
    });
  });

  group('referenceItemById', () {
    test('matches on id and ignores case and padding', () {
      expect(referenceItemById(_provinces, ' 3 ')?.name, 'Bagmati');
      expect(referenceItemById(_provinces, '4')?.name, 'Gandaki');
    });

    test('a blank id matches nothing, even against a row with a blank id', () {
      // `ReferenceItem.id` falls back to '' when the backend omits one, so a
      // naive `firstWhere((i) => i.id == id)` would return that malformed row.
      const withBlankId = [
        ReferenceItem(id: '', name: 'Row With No Id'),
        ReferenceItem(id: '3', name: 'Bagmati'),
      ];

      expect(referenceItemById(withBlankId, ''), isNull);
      expect(referenceItemById(withBlankId, null), isNull);
      expect(referenceItemById(withBlankId, '   '), isNull);
      expect(referenceItemById(withBlankId, '3')?.name, 'Bagmati');
    });
  });
}
