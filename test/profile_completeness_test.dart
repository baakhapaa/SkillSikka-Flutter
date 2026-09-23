import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/profile/data/profile_completeness.dart';
import 'package:skillsikka/features/profile/data/user_profile.dart';

void main() {
  test('an empty profile is missing every enrolment field', () {
    final result = checkProfileCompleteness(const UserProfile());

    expect(result.isComplete, isFalse);
    expect(result.missing.length, studentEnrolmentFields.length);
    expect(result.filled, 0);
    expect(result.fraction, 0);
  });

  test('a fully filled profile is complete', () {
    final profile = UserProfile(
      values: {for (final field in studentEnrolmentFields) field.key: 'x'},
    );
    final result = checkProfileCompleteness(profile);

    expect(result.isComplete, isTrue);
    expect(result.missing, isEmpty);
    expect(result.fraction, 1);
  });

  test('whitespace does not count as filled', () {
    final result = checkProfileCompleteness(
      const UserProfile(values: {'phone': '   '}),
    );

    expect(result.missing.map((field) => field.key), contains('phone'));
  });

  test('missing fields keep the declared order', () {
    final result = checkProfileCompleteness(
      const UserProfile(values: {'gender': 'Female', 'province': 'Bagmati'}),
    );

    expect(result.missing.map((field) => field.key).toList(), [
      'phone',
      'dob',
      'location',
      'grade',
      'district',
      'school',
    ]);
  });

  test('progress counts only the filled fields', () {
    final result = checkProfileCompleteness(
      const UserProfile(values: {'phone': '9812345678', 'gender': 'Male'}),
    );

    expect(result.total, studentEnrolmentFields.length);
    expect(result.filled, 2);
    expect(result.fraction, closeTo(2 / studentEnrolmentFields.length, 1e-9));
  });

  test('the student ID card is deliberately not an enrolment requirement', () {
    // It gates verification, which a human reviews over 24-48 business hours.
    // Blocking enrolment on that would stop a student starting a course they
    // had already paid for.
    expect(
      studentEnrolmentFields.map((field) => field.key),
      isNot(contains('studentIdCard')),
    );
  });

  test('an empty field list is complete rather than a divide by zero', () {
    final result = checkProfileCompleteness(
      const UserProfile(),
      fields: const [],
    );

    expect(result.isComplete, isTrue);
    expect(result.fraction, 1);
  });

  group('UserProfile', () {
    test('merges values instead of replacing the whole map', () {
      const profile = UserProfile(
        values: {'name': 'Sita', 'phone': '9812345678'},
      );
      final updated = profile.withValues({'gender': 'Female'});

      expect(updated.valueFor('name'), 'Sita');
      expect(updated.valueFor('phone'), '9812345678');
      expect(updated.valueFor('gender'), 'Female');
      // The original is untouched.
      expect(profile.valueFor('gender'), '');
    });

    test('keeps the photo across a text update', () {
      final withPhoto = const UserProfile().withPhoto(
        Uint8List.fromList([1, 2, 3]),
      );
      final updated = withPhoto.withValues({'name': 'Sita'});

      expect(updated.photoBytes, isNotNull);
      expect(updated.valueFor('name'), 'Sita');
    });

    test('an unknown key reads as empty rather than throwing', () {
      expect(const UserProfile().valueFor('nonsense'), '');
    });
  });
}
