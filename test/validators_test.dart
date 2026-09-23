import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/validation/validators.dart';

/// A fixed "today" so age rules do not drift with the wall clock.
final _today = DateTime(2026, 9, 23);

void main() {
  group('validateFullName', () {
    test('accepts ordinary and Nepali names', () {
      expect(validateFullName('Sita Rai'), isNull);
      expect(validateFullName('Prof. Shuvanga Karki'), isNull);
      expect(validateFullName("O'Brien-Smith"), isNull);
      expect(validateFullName('सीता राई'), isNull, reason: 'Devanagari');
      expect(validateFullName('  Sita Rai  '), isNull, reason: 'trimmed');
    });

    test('rejects empty, too short and too long', () {
      expect(validateFullName(null), isNotNull);
      expect(validateFullName(''), isNotNull);
      expect(validateFullName('   '), isNotNull);
      expect(validateFullName('A'), isNotNull);
      expect(validateFullName('A' * (kNameMaxLength + 1)), isNotNull);
    });

    test(
      'names the digit case specifically, because it is usually a phone number',
      () {
        expect(validateFullName('Sita 98'), 'Name cannot contain numbers.');
      },
    );

    test('rejects characters no real name contains', () {
      expect(validateFullName('Sita <Rai>'), isNotNull);
      expect(validateFullName('Sita@home'), isNotNull);
      expect(validateFullName('12345'), isNotNull);
    });
  });

  group('validateEmail', () {
    test('accepts normal addresses', () {
      expect(validateEmail('skill@email.com'), isNull);
      expect(validateEmail('first.last+tag@sub.example.co.uk'), isNull);
      expect(validateEmail('  skill@email.com  '), isNull, reason: 'pasted');
    });

    test('rejects malformed addresses', () {
      for (final bad in [
        '',
        'skill',
        'skill@',
        '@email.com',
        'skill@email',
        'skill@@email.com',
        'skill@email..com',
        'skill @email.com',
        'skill@email.c',
      ]) {
        expect(validateEmail(bad), isNotNull, reason: 'accepted "$bad"');
      }
    });

    test('rejects an over-long address', () {
      final local = 'a' * kEmailMaxLength;
      expect(validateEmail('$local@email.com'), isNotNull);
    });
  });

  group('validatePassword', () {
    test('accepts a letter+digit password of sufficient length', () {
      expect(validatePassword('Passw0rd'), isNull);
      expect(validatePassword('a1bcdefg'), isNull);
    });

    test('rejects short, all-letter and all-digit values', () {
      expect(validatePassword(''), 'Please enter a password.');
      expect(validatePassword('Pa1'), isNotNull, reason: 'too short');
      expect(validatePassword('abcdefgh'), 'Include at least one number.');
      expect(validatePassword('12345678'), 'Include at least one letter.');
    });

    test('rejects a password past the bcrypt-safe ceiling', () {
      expect(validatePassword('a1${'x' * kPasswordMaxLength}'), isNotNull);
    });

    test('does not trim — spaces are legitimate password characters', () {
      expect(validatePassword(' passw0rd '), isNull);
    });
  });

  group('validateConfirmPassword', () {
    test('matches on an exact match only', () {
      expect(validateConfirmPassword('Passw0rd', 'Passw0rd'), isNull);
      expect(validateConfirmPassword('', 'Passw0rd'), isNotNull);
      expect(validateConfirmPassword('passw0rd', 'Passw0rd'), isNotNull);
      expect(
        validateConfirmPassword(' Passw0rd', 'Passw0rd'),
        'Passwords do not match.',
        reason: 'a leading space is a different password',
      );
    });
  });

  group('validateDateOfBirth', () {
    test('accepts a plausible date and reports nothing', () {
      expect(validateDateOfBirth('01 / 01 / 2005', today: _today), isNull);
      expect(validateDateOfBirth('23 / 09 / 2000', today: _today), isNull);
    });

    test('rejects a missing or unparseable date', () {
      expect(validateDateOfBirth('', today: _today), isNotNull);
      expect(validateDateOfBirth('2005-01-01', today: _today), isNotNull);
      expect(
        validateDateOfBirth('1 / 1 / 2005', today: _today),
        isNull,
        reason: 'single digits are tolerated',
      );
    });

    test('rejects dates that do not exist on the calendar', () {
      expect(validateDateOfBirth('31 / 02 / 2005', today: _today), isNotNull);
      expect(validateDateOfBirth('32 / 01 / 2005', today: _today), isNotNull);
      expect(validateDateOfBirth('01 / 13 / 2005', today: _today), isNotNull);
      expect(validateDateOfBirth('00 / 01 / 2005', today: _today), isNotNull);
    });

    test('accepts a leap day only in a leap year', () {
      expect(validateDateOfBirth('29 / 02 / 2004', today: _today), isNull);
      expect(validateDateOfBirth('29 / 02 / 2005', today: _today), isNotNull);
    });

    test('rejects the future', () {
      expect(
        validateDateOfBirth('24 / 09 / 2026', today: _today),
        'Date of birth cannot be in the future.',
      );
      expect(
        validateDateOfBirth('23 / 09 / 2026', today: _today),
        'You must be at least $kMinAgeYears years old.',
        reason: 'today is not the future, but the age rule still bites',
      );
    });

    test('enforces the age window', () {
      expect(
        validateDateOfBirth('01 / 01 / 2020', today: _today),
        'You must be at least $kMinAgeYears years old.',
      );
      expect(
        validateDateOfBirth('01 / 01 / 1850', today: _today),
        'Please check the year you entered.',
      );
    });

    test('birthday-boundary: one day short of the minimum age still fails', () {
      // 10 years before _today is 2016-09-23; the day before is still 9.
      expect(validateDateOfBirth('23 / 09 / 2016', today: _today), isNull);
      expect(validateDateOfBirth('24 / 09 / 2016', today: _today), isNotNull);
    });
  });

  group('validatePhoneNumber', () {
    test('accepts the formats the field actually receives', () {
      for (final good in [
        '9812345678',
        '+977 9812345678',
        '+9779812345678',
        '9779812345678',
        '98-1234-5678',
        '981-234-5678',
        '  9812345678  ',
      ]) {
        expect(validatePhoneNumber(good), isNull, reason: 'rejected "$good"');
      }
    });

    test('rejects numbers that are not Nepali mobiles', () {
      for (final bad in [
        '',
        '12345',
        '1234567890',
        '981234567', // nine digits
        '98123456789', // eleven digits
        '0112345678', // landline
      ]) {
        expect(validatePhoneNumber(bad), isNotNull, reason: 'accepted "$bad"');
      }
    });
  });

  group('validateLocation', () {
    test('accepts a real place and rejects an empty one', () {
      expect(validateLocation('Baneshwor, Kathmandu'), isNull);
      expect(validateLocation(''), isNotNull);
      expect(validateLocation('  '), isNotNull);
    });

    test('bounds the length', () {
      expect(validateLocation('K' * (kLocationMaxLength + 1)), isNotNull);
    });
  });

  group('validateYearsOfExperience', () {
    test('accepts the number and the spelled-out form the hint invites', () {
      expect(validateYearsOfExperience('5'), isNull);
      expect(validateYearsOfExperience('5 Years'), isNull);
      expect(validateYearsOfExperience('12 yrs'), isNull);
      expect(validateYearsOfExperience('0'), isNull, reason: 'a fresher');
    });

    test('rejects text and out-of-range values', () {
      expect(validateYearsOfExperience(''), isNotNull);
      expect(validateYearsOfExperience('five'), isNotNull);
      expect(validateYearsOfExperience('5.5'), isNotNull);
      expect(
        validateYearsOfExperience('${kMaxExperienceYears + 1}'),
        isNotNull,
      );
    });
  });

  group('validateShortText', () {
    test('applies the label and the length bounds', () {
      expect(validateShortText('MCA', 'qualification'), isNull);
      expect(
        validateShortText('', 'qualification'),
        'Please enter your qualification.',
      );
      expect(
        validateShortText('M', 'qualification'),
        'Please enter at least 2 characters.',
      );
      expect(
        validateShortText('M' * 200, 'qualification'),
        'Please keep qualification under 120 characters.',
      );
    });
  });

  group('validateWhenPresent', () {
    test('lets an empty value through but still checks a filled one', () {
      final validator = validateWhenPresent(validateEmail);
      expect(validator(''), isNull, reason: 'optional field');
      expect(validator(null), isNull);
      expect(validator('   '), isNull);
      expect(validator('not-an-email'), isNotNull);
      expect(validator('skill@email.com'), isNull);
    });
  });

  group('validateChoice', () {
    test('names the field in the message', () {
      expect(validateChoice('', 'gender'), 'Please select your gender.');
      expect(validateChoice('Female', 'gender'), isNull);
    });
  });

  group('parseDateOfBirth', () {
    test('returns null rather than throwing on junk', () {
      expect(parseDateOfBirth('nonsense'), isNull);
      expect(parseDateOfBirth(null), isNull);
      expect(parseDateOfBirth('31 / 02 / 2005'), isNull);
      expect(parseDateOfBirth('01 / 01 / 2005'), DateTime(2005, 1, 1));
    });
  });
}
