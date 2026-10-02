import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/profile/data/profile_completeness.dart';
import 'package:skillsikka/features/profile/data/profile_role.dart';
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

  group('the instructor course-creation gate', () {
    test(
      'an instructor is checked against instructor fields, not student ones',
      () {
        final result = checkProfileCompleteness(
          const UserProfile(role: ProfileRole.instructor),
          fields: completionFieldsFor(ProfileRole.instructor),
        );

        expect(result.missing.map((field) => field.key).toList(), [
          'phone',
          'location',
          'qualification',
          'expertise',
          'experience',
        ]);
        // An instructor has no class and no school. Demanding them is the bug this
        // split fixes — the gate used to check the student list while opening the
        // instructor form, so it could never be satisfied.
        expect(
          result.missing.map((field) => field.key),
          isNot(contains('grade')),
        );
        expect(
          result.missing.map((field) => field.key),
          isNot(contains('school')),
        );
      },
    );

    test('a filled instructor profile is complete', () {
      final profile = UserProfile(
        role: ProfileRole.instructor,
        values: {
          for (final field in instructorCourseCreationFields) field.key: 'x',
        },
      );

      final result = checkProfileCompleteness(
        profile,
        fields: completionFieldsFor(ProfileRole.instructor),
      );

      expect(result.isComplete, isTrue);
      expect(result.fraction, 1);
    });

    test('the CV and certificates do not gate course creation', () {
      // Same reasoning as the student ID card: they gate verification, which a
      // human reviews over 24-48 business hours, so blocking the action on them
      // would stop an instructor working while an admin reads their CV.
      final keys = instructorCourseCreationFields.map((field) => field.key);
      expect(keys, isNot(contains(ProfileDocumentSlot.cvResume)));
      expect(keys, isNot(contains(ProfileDocumentSlot.certificates)));
    });

    test('the student role still gets the enrolment fields', () {
      expect(completionFieldsFor(ProfileRole.student), studentEnrolmentFields);
    });

    test('the provider follows the signed-in role', () {
      // Pins the role-awareness of `profileCompletenessProvider` directly: a
      // filled instructor profile must read as complete even though it has none
      // of the student fields.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(userProfileProvider.notifier);
      notifier.setRole(ProfileRole.instructor);
      notifier.save({
        for (final field in instructorCourseCreationFields) field.key: 'x',
      });

      expect(container.read(profileCompletenessProvider).isComplete, isTrue);
    });

    test('the provider still checks the student fields for a student', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(userProfileProvider.notifier);
      notifier.setRole(ProfileRole.student);
      notifier.save({
        for (final field in instructorCourseCreationFields) field.key: 'x',
      });

      // Instructor fields only: a student is still missing class, province,
      // district and school.
      expect(container.read(profileCompletenessProvider).isComplete, isFalse);
    });
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
        'avatar.jpg',
      );
      final updated = withPhoto.withValues({'name': 'Sita'});

      expect(updated.photoBytes, isNotNull);
      // The name travels with the bytes; the upload needs it for the content
      // type, so a text update must not drop it.
      expect(updated.photoFileName, 'avatar.jpg');
      expect(updated.valueFor('name'), 'Sita');
    });

    test('keeps the photo across every other update', () {
      // Each of these goes through the same copy helper as withValues. A text
      // update was only the first one found dropping the name, so pin all of
      // them rather than the one that happened to be noticed.
      final withPhoto = const UserProfile().withPhoto(
        Uint8List.fromList([1, 2, 3]),
        'avatar.jpg',
      );
      final updates = <String, UserProfile>{
        'role': withPhoto.withRole(ProfileRole.instructor),
        'interests': withPhoto.withInterests(const ['Yoga']),
        'document': withPhoto.withDocument(
          ProfileDocumentSlot.cvResume,
          PickedDocument(bytes: Uint8List.fromList([9]), fileName: 'cv.pdf'),
        ),
        'document removed': withPhoto
            .withDocument(
              ProfileDocumentSlot.cvResume,
              PickedDocument(
                bytes: Uint8List.fromList([9]),
                fileName: 'cv.pdf',
              ),
            )
            .withoutDocument(ProfileDocumentSlot.cvResume),
      };

      updates.forEach((label, updated) {
        expect(updated.photoBytes, isNotNull, reason: label);
        expect(updated.photoFileName, 'avatar.jpg', reason: label);
      });
    });

    test('an unknown key reads as empty rather than throwing', () {
      expect(const UserProfile().valueFor('nonsense'), '');
    });
  });
}
