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

    // Seeded so the entry-point check below runs against a signed-in user
    // rather than an empty store. A bare `ProviderScope()` would also work —
    // the page degrades to its placeholders — but this is the state the app is
    // actually in when the tab is reachable.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(userProfileProvider.notifier).save({
      'name': 'Real User',
      'grade': 'Grade 9',
    });

    // --- the entry point on the profile page ---
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ProfilePage())),
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

    // Opens with what the profile store holds. This used to assert a hardcoded
    // `_studentSeed` ('Shuvanga Karki' / 'Class 9') that the form fell back to
    // when the store was empty — which meant every account was shown a
    // stranger's name. The seed is gone (see `_initialValue`), so the value
    // under test is now the store's own.
    expect(inPage(find.text('Real User')), findsOneWidget);
    expect(inPage(find.text('Grade 9')), findsOneWidget);
    expect(
      inPage(find.text('Shuvanga Karki')),
      findsNothing,
      reason: 'the deleted seed must not resurface',
    );

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
    // Seeded because Save requires a name and a valid email, and the form no
    // longer invents them from a seed — an empty store would refuse to save,
    // which is correct behaviour but not what this step is checking.
    final saveContainer = ProviderContainer();
    addTearDown(saveContainer.dispose);
    saveContainer.read(userProfileProvider.notifier).save({
      'name': 'Real User',
      'email': 'real@user.test',
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: saveContainer,
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

  testWidgets('the profile header shows the user\'s own photo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // A one-pixel PNG, as the store would hold after signup or Edit Profile.
    final onePixelPng = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAF'
        'AAH/q842iQAAAABJRU5ErkJggg==',
      ),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(userProfileProvider.notifier)
      ..setPhoto(onePixelPng, 'me.png')
      ..save({'name': 'Real User'});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ProfilePage())),
      ),
    );
    await tester.pump();
    drainUnrelatedOverflows(tester);

    // The header used to render a fixed `Image.asset`, so every account showed
    // the same stock portrait. A `MemoryImage` here is the proof it is now the
    // photo this user actually picked — and that it went through bytes, not a
    // `File` (`Image.file` asserts `!kIsWeb`).
    //
    // Addressed by key, not `find.byType(Image)`: the page renders five other
    // images (streak, pencil, chevron icons) and an unscoped finder would be
    // ambiguous.
    final avatar = tester.widget<Image>(find.byKey(avatarKey));
    expect(
      avatar.image,
      isA<MemoryImage>(),
      reason: 'the avatar must render the store, not a bundled asset',
    );
    expect(
      avatar.image,
      isNot(isA<AssetImage>()),
      reason: 'a bundled AssetImage is the hardcoded portrait this replaced',
    );
    expect(avatar.width, 107, reason: 'the header avatar is 107px');

    // The image must be decoded inside a circle, not shown as a raw rectangle.
    expect(
      find.ancestor(of: find.byKey(avatarKey), matching: find.byType(ClipOval)),
      findsWidgets,
    );
  });

  testWidgets('with no photo the header shows a placeholder, not a stranger', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(userProfileProvider.notifier).save({'name': 'Real User'});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ProfilePage())),
      ),
    );
    await tester.pump();
    drainUnrelatedOverflows(tester);

    // No photo means the placeholder, not a bundled portrait. The neutral
    // silhouette is an `Icon`, so the keyed avatar must not contain an `Image`.
    expect(
      find.descendant(of: find.byKey(avatarKey), matching: find.byType(Image)),
      findsNothing,
      reason: 'an account with no photo must not be given someone else\'s face',
    );
    expect(
      find.descendant(
        of: find.byKey(avatarKey),
        matching: find.byIcon(Icons.person),
      ),
      findsOneWidget,
    );
  });
}
