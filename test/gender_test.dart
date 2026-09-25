import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/profile/data/gender.dart';

/// The gender vocabulary is a wire contract, and the picker stores the label the
/// user saw rather than the value the API wants. So the mapping between the two
/// is the part most likely to regress silently — and a wrong value fails
/// validation on a required field, on every single registration.
void main() {
  test('sends the lowercase wire values the backend confirmed', () {
    expect(Gender.female.wireValue, 'female');
    expect(Gender.male.wireValue, 'male');
    expect(Gender.other.wireValue, 'other');
  });

  test('maps a stored label to its wire value', () {
    expect(Gender.wireValueOf('Female'), 'female');
    expect(Gender.wireValueOf('Male'), 'male');
    expect(Gender.wireValueOf('Other'), 'other');
  });

  test('passes through a value it does not recognise', () {
    // Blanking it would surface as an empty required field and hide the real
    // problem. An unknown value should fail where the vocabulary is defined.
    expect(Gender.wireValueOf('Non-binary'), 'Non-binary');
    expect(Gender.wireValueOf(null), '');
    expect(Gender.wireValueOf('   '), '');
  });

  test('accepts a wire value as well as a label', () {
    expect(Gender.tryParse('male'), Gender.male);
    expect(Gender.tryParse('MALE'), Gender.male);
    expect(Gender.tryParse('Male'), Gender.male);
    expect(Gender.tryParse(''), isNull);
    expect(Gender.tryParse('x'), isNull);
  });

  test('the picker options are the labels, not the wire values', () {
    expect(Gender.labels, ['Female', 'Male', 'Other']);
  });
}
