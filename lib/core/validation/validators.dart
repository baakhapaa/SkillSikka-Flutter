/// Reusable field validators, all shaped as `FormFieldValidator<String>` — they
/// return `null` when the value is acceptable and a user-facing message when it
/// is not, so they can be handed straight to a `TextFormField`.
///
/// Two conventions run through all of them:
///
///  * **Values are trimmed before checking.** A pasted email carrying a trailing
///    space is the single most common real-world input error, and rejecting it
///    with "enter a valid email address" is a bad experience.
///  * **Messages are actionable.** Each one says what to do, not just what went
///    wrong, and mirrors the hint text where the field has one.
library;

// ---------------------------------------------------------------------------
// Limits
// ---------------------------------------------------------------------------

const int kNameMinLength = 2;
const int kNameMaxLength = 60;

/// 254 is the RFC 5321 limit on a forward-path address.
const int kEmailMaxLength = 254;

/// 8 is the usual floor; 64 keeps the value inside bcrypt's 72-byte input limit
/// even once multi-byte characters are involved.
const int kPasswordMinLength = 8;
const int kPasswordMaxLength = 64;

const int kLocationMinLength = 2;
const int kLocationMaxLength = 120;

/// The student form targets Class 8 and up, so a primary-school age is a typo
/// rather than a real user. Raise this if the audience widens.
const int kMinAgeYears = 10;
const int kMaxAgeYears = 100;

const int kMaxExperienceYears = 60;

// ---------------------------------------------------------------------------
// Patterns
// ---------------------------------------------------------------------------

/// Letters and combining marks from any script — so Devanagari names pass — plus
/// the spaces, apostrophes, hyphens and periods real names contain.
final _namePattern = RegExp(
  r"^[\p{L}\p{M}][\p{L}\p{M}\s.'\-]*$",
  unicode: true,
);

/// Permissive about the local part but structurally strict: exactly one `@`, a
/// dotted domain, no whitespace, no consecutive dots, alphabetic TLD of 2+.
final _emailPattern = RegExp(
  r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$',
);

/// Nepali mobile numbers are ten digits beginning 96–99.
final _nepaliMobilePattern = RegExp(r'^9[6-9]\d{8}$');

final _hasLetter = RegExp(r'[A-Za-z]');
final _hasDigit = RegExp(r'\d');

/// `DD / MM / YYYY`, tolerating the spaces the picker writes and a typed `/`.
final _datePattern = RegExp(r'^(\d{1,2})\s*/\s*(\d{1,2})\s*/\s*(\d{4})$');

/// `5`, `5 Years`, `5 yrs` — the field's hint invites the spelled-out form.
final _experiencePattern = RegExp(
  r'^(\d{1,2})\s*(?:years?|yrs?)?$',
  caseSensitive: false,
);

// ---------------------------------------------------------------------------
// Validators
// ---------------------------------------------------------------------------

/// Letters, spaces and the punctuation real names use. Digits are rejected
/// outright rather than being lumped in with "invalid characters", because
/// mistyping a phone number into this field is the common mistake.
String? validateFullName(String? value) {
  final name = (value ?? '').trim();
  if (name.isEmpty) return 'Please enter your full name.';
  if (name.length < kNameMinLength) {
    return 'Name must be at least $kNameMinLength characters.';
  }
  if (name.length > kNameMaxLength) {
    return 'Name must be $kNameMaxLength characters or fewer.';
  }
  if (_hasDigit.hasMatch(name)) return 'Name cannot contain numbers.';
  if (!_namePattern.hasMatch(name)) {
    return "Use letters, spaces, hyphens or apostrophes only.";
  }
  return null;
}

String? validateEmail(String? value) {
  final email = (value ?? '').trim();
  if (email.isEmpty) return 'Please enter your email address.';
  if (email.length > kEmailMaxLength) return 'Email address is too long.';
  if (email.contains('..')) {
    return 'Email address cannot contain two dots in a row.';
  }
  if (!_emailPattern.hasMatch(email)) {
    return 'Enter a valid email address, e.g. name@example.com.';
  }
  return null;
}

/// At least [kPasswordMinLength] characters with a letter and a number.
///
/// Deliberately not requiring a symbol or mixed case: those rules push people
/// towards `Password1!`, and the app has no rate-limiting story that makes them
/// worth the friction. Revisit if the backend asks for more.
String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Please enter a password.';
  if (password.length < kPasswordMinLength) {
    return 'Use at least $kPasswordMinLength characters.';
  }
  if (password.length > kPasswordMaxLength) {
    return 'Password must be $kPasswordMaxLength characters or fewer.';
  }
  if (!_hasLetter.hasMatch(password)) return 'Include at least one letter.';
  if (!_hasDigit.hasMatch(password)) return 'Include at least one number.';
  return null;
}

/// Compares against [password] as typed — not trimmed, since leading and
/// trailing spaces are legitimate password characters.
String? validateConfirmPassword(String? value, String password) {
  final confirmation = value ?? '';
  if (confirmation.isEmpty) return 'Please re-enter your password.';
  if (confirmation != password) return 'Passwords do not match.';
  return null;
}

/// For the fields that open a picker rather than a keyboard.
String? validateChoice(String? value, String label) {
  if ((value ?? '').trim().isEmpty) return 'Please select your $label.';
  return null;
}

/// Parses the form's `DD / MM / YYYY` representation, or null if it is not a
/// real calendar date.
DateTime? parseDateOfBirth(String? value) {
  final match = _datePattern.firstMatch((value ?? '').trim());
  if (match == null) return null;

  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;

  final date = DateTime(year, month, day);
  // DateTime rolls 31/02 forward into March, so confirm the parts survived.
  if (date.day != day || date.month != month || date.year != year) return null;
  return date;
}

/// [today] is injectable so tests do not drift with the wall clock.
String? validateDateOfBirth(String? value, {DateTime? today}) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return 'Please select your date of birth.';

  final date = parseDateOfBirth(raw);
  if (date == null) return 'Enter a valid date as DD / MM / YYYY.';

  final now = today ?? DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  if (date.isAfter(startOfToday)) {
    return 'Date of birth cannot be in the future.';
  }

  final age = _ageInYears(date, startOfToday);
  if (age < kMinAgeYears) {
    return 'You must be at least $kMinAgeYears years old.';
  }
  if (age > kMaxAgeYears) return 'Please check the year you entered.';
  return null;
}

int _ageInYears(DateTime birthDate, DateTime today) {
  var age = today.year - birthDate.year;
  final hadBirthday =
      today.month > birthDate.month ||
      (today.month == birthDate.month && today.day >= birthDate.day);
  if (!hadBirthday) age--;
  return age;
}

/// Accepts the `+977` country code and any spacing, dashes or brackets, so
/// `+977 98-1234-5678` and `9812345678` are treated the same.
String? validatePhoneNumber(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return 'Please enter your phone number.';

  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final national = digits.startsWith('977') && digits.length > 10
      ? digits.substring(3)
      : digits;

  if (!_nepaliMobilePattern.hasMatch(national)) {
    return 'Enter a 10-digit mobile number, e.g. 9812345678.';
  }
  return null;
}

String? validateLocation(String? value) {
  final location = (value ?? '').trim();
  if (location.isEmpty) return 'Please enter your location.';
  if (location.length < kLocationMinLength) {
    return 'Enter a little more detail.';
  }
  if (location.length > kLocationMaxLength) {
    return 'Location must be $kLocationMaxLength characters or fewer.';
  }
  return null;
}

/// The hint invites `5 Years`, so both the bare number and the spelled-out form
/// are accepted.
String? validateYearsOfExperience(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return 'Please enter your years of experience.';

  final match = _experiencePattern.firstMatch(raw);
  if (match == null) return 'Enter a number of years, e.g. 5 or 5 Years.';

  final years = int.parse(match.group(1)!);
  if (years > kMaxExperienceYears) {
    return 'Enter $kMaxExperienceYears years or fewer.';
  }
  return null;
}

/// Free text with length bounds — qualifications, subject expertise and the
/// like, where there is no shape to check beyond "something was typed".
String? validateShortText(
  String? value,
  String label, {
  int minLength = 2,
  int maxLength = 120,
}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'Please enter your $label.';
  if (text.length < minLength) {
    return 'Please enter at least $minLength characters.';
  }
  if (text.length > maxLength) {
    return 'Please keep $label under $maxLength characters.';
  }
  return null;
}

/// Wraps [validator] so it only runs when the field actually has a value.
///
/// Profile fields are optional — the user may legitimately want to change only
/// their name — but a value that *is* present should still be well-formed.
String? Function(String?) validateWhenPresent(
  String? Function(String?) validator,
) {
  return (value) => (value ?? '').trim().isEmpty ? null : validator(value);
}
