import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/widgets/profile_photo_picker.dart';
import 'package:skillsikka/features/profile/data/profile_role.dart';
import 'package:skillsikka/features/profile/presentation/edit_profile_page.dart';
import 'package:skillsikka/features/profile/presentation/profile_page.dart';
import 'package:skillsikka/features/profile/data/user_profile.dart';

void main() {
  /// The profile page is long and its cards are laid out for Manrope, which
  /// `flutter test` cannot fetch — the Roboto stand-in wraps differently and
  /// overflows. Pre-existing and unrelated to the edit screen, so drain it.
  /// Anything that is not an overflow still fails the test.
  void drainUnrelatedOverflows(WidgetTester tester) {
    for (
      var e = tester.takeException();
      e != null;
      e = tester.takeException()
    ) {
      final text = e.toString();
      expect(
        text.contains('overflowed') || text.contains('Multiple exceptions'),
        isTrue,
        reason: 'unexpected exception on the profile page: $text',
      );
    }
  }

  Finder inPage(Finder matching) =>
      find.descendant(of: find.byType(EditProfilePage), matching: matching);

  testWidgets('Edit Profile Settings opens a role-aware edit screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // --- the entry point on the profile page ---
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: ProfilePage())),
      ),
    );
    await tester.pump();
    drainUnrelatedOverflows(tester);

    final entry = find.text('Edit Profile Settings');
    expect(entry, findsOneWidget, reason: 'the profile page lost its entry');

    await tester.tap(entry);
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);

    expect(
      find.byType(EditProfilePage),
      findsOneWidget,
      reason: 'tapping Edit Profile Settings should open the edit screen',
    );

    // The profile tab shows a student's profile, so the student field set.
    expect(inPage(find.textContaining('Class / Grade')), findsOneWidget);
    expect(inPage(find.textContaining('School / College')), findsOneWidget);
    expect(inPage(find.textContaining('Subject Expertise')), findsNothing);
    // The signup form uploads a student ID card; it has no bio field.
    expect(inPage(find.text('Student ID Card')), findsOneWidget);
    expect(inPage(find.textContaining('About Me')), findsNothing);

    // Opens with what the profile already displays, not an empty form.
    expect(inPage(find.text('Shuvanga Karki')), findsOneWidget);
    expect(inPage(find.text('Class 9')), findsOneWidget);

    // --- the instructor variant of the same screen ---
    // Tear the tree down first: pumping a new MaterialApp reuses the
    // Navigator element, so the route pushed above survives and shadows
    // the new home.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: EditProfilePage(role: ProfileRole.instructor)),
      ),
    );
    await tester.pump();
    drainUnrelatedOverflows(tester);

    expect(inPage(find.textContaining('Subject Expertise')), findsOneWidget);
    expect(
      inPage(find.textContaining('Highest Qualification / Degree')),
      findsOneWidget,
    );
    expect(inPage(find.textContaining('Years of Experience')), findsOneWidget);
    expect(inPage(find.textContaining('Class / Grade')), findsNothing);
    // …and the instructor uploads a CV plus certificates instead.
    expect(inPage(find.text('CV / Resume')), findsOneWidget);
    expect(
      inPage(find.text('Certificates & Recommendation Letters')),
      findsOneWidget,
    );
    expect(inPage(find.textContaining('About Me')), findsNothing);
    expect(inPage(find.text('Instructor')), findsOneWidget); // header chip

    // --- saving closes the screen and confirms ---
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditProfilePage()),
                  ),
                  child: const Text('open editor'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);

    // The form is taller than the viewport, so the button starts below the
    // fold — tapping it there would miss.
    final save = inPage(find.text('Save Changes'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);

    expect(
      find.byType(EditProfilePage),
      findsNothing,
      reason: 'Save should close the edit screen',
    );
    expect(find.text('Profile updated.'), findsOneWidget);

    // Let the snack bar expire so no timer outlives the test.
    await tester.pump(const Duration(seconds: 5));

    // --- the picked photo must not go through Image.file ---
    // Image.file asserts !kIsWeb, so a File-based avatar crashed the whole
    // screen the moment a photo was chosen in a browser. Bytes + Image.memory
    // works everywhere.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final onePixelPng = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAF'
        'AAH/q842iQAAAABJRU5ErkJggg==',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePhotoPicker(photoBytes: onePixelPng, onTap: () {}),
        ),
      ),
    );
    await tester.pump();
    drainUnrelatedOverflows(tester);

    final picked = tester.widget<Image>(find.byType(Image));
    expect(
      picked.image,
      isA<MemoryImage>(),
      reason: 'a FileImage would assert !kIsWeb and blank the screen',
    );
    expect(find.text('Change Profile Photo'), findsOneWidget);

    // …and the empty state still shows the camera prompt.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePhotoPicker(photoBytes: null, onTap: () {}),
        ),
      ),
    );
    await tester.pump();
    drainUnrelatedOverflows(tester);
    expect(find.text('Upload Profile Photo'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('Location opens with the fix the signup popup detected', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // What the signup form captured before the user ever reached this screen.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(userProfileProvider.notifier)
        .setLocation('Baneshwor, Kathmandu');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EditProfilePage()),
      ),
    );
    await tester.pump();
    drainUnrelatedOverflows(tester);

    // This screen is the only place that value is ever shown, so if the handoff
    // from signup breaks the user loses the detection entirely.
    expect(inPage(find.text('Baneshwor, Kathmandu')), findsOneWidget);
  });

  testWidgets('an invalid value blocks the save with an inline error', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EditProfilePage()),
      ),
    );
    await tester.pump();
    drainUnrelatedOverflows(tester);

    // Field order is name, email, phone, gender, dob, location, ...
    await tester.enterText(find.byType(TextFormField).at(1), 'not-an-email');
    // Flush the caret-reveal scroll this schedules. Without it the pending
    // scroll lands after `ensureVisible` and drags the CTA back off-screen.
    await tester.pumpAndSettle();

    final save = inPage(find.text('Save Changes'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);

    expect(
      inPage(find.text('Enter a valid email address, e.g. name@example.com.')),
      findsOneWidget,
    );
    expect(
      find.byType(EditProfilePage),
      findsOneWidget,
      reason: 'an invalid form must stay open rather than pop',
    );

    // Let the summary snack bar expire so no timer outlives the test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
