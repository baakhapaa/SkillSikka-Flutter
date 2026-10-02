import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/core/widgets/profile_photo_picker.dart';
import 'package:skillsikka/features/auth/data/auth_repository.dart';
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

  /// What the save confirmation says, per outcome.
  ///
  /// The message is the only thing the user sees about whether their answers
  /// reached a server, so it has to match what actually happened. The bug these
  /// cover: a `bool?` collapsed "nothing to send" and "sent, route missing" into
  /// one `false`, so a student — for whom no server call exists at all — was told
  /// their edit was "stored on this device", which invents a limitation and reads
  /// as a warning.
  group('the save confirmation', () {
    /// Opens the editor, taps Save, and returns what the snack bar said.
    ///
    /// [seed] is written to the profile store before the screen opens — the
    /// instructor message only differs from the student one when there is
    /// something for the completion request to carry.
    Future<String> savedMessage(
      WidgetTester tester, {
      required ProfileRole role,
      Map<String, String> seed = const {},
      bool? completionResult,
      ApiException? completionFailure,
    }) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final auth = FakeAuthRepository()
        ..completionResult = completionResult
        ..completionFailure = completionFailure;
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);
      container.read(userProfileProvider.notifier).save({
        // Save requires a name and a valid email, so both are always seeded.
        'name': 'Real User',
        'email': 'real@user.test',
        ...seed,
      });

      // **Pushed, not the root.** Both real call sites (`ProfilePage`,
      // `complete_profile_gate`) push this screen onto a Navigator, and the
      // save confirmation depends on that: `_save` pops the route and *then*
      // shows the snack bar on a messenger captured before the pop. Pumping the
      // page as `MaterialApp.home` instead makes it the route being popped, so
      // its own messenger unmounts with it and the snack bar is never rendered.
      //
      // The host below is the route that survives the pop, which is what the
      // snack bar is actually attached to in the app.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditProfilePage(role: role),
                      ),
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
      // fold and a bare tap would miss it.
      final save = find.widgetWithText(FilledButton, 'Save Changes');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      drainUnrelatedOverflows(tester);

      // Exactly one snack bar, and it must be the confirmation rather than
      // validation's "Please check the highlighted fields." — a test that read
      // whichever snack bar happened to be on screen would report the wrong
      // message for a save that never ran.
      expect(
        find.byType(SnackBar),
        findsOneWidget,
        reason:
            'no snack bar after Save: the tap missed, or the form refused to '
            'validate (which shows its own snack bar, so this also fires if the '
            'seed stopped satisfying the name/email rules)',
      );
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      final message = (snackBar.content as Text).data!;

      // **Let the first snack bar fully clear, then check nothing queued behind
      // it.** `ScaffoldMessenger` shows queued bars one at a time, so a second
      // message is invisible until the first times out — which is exactly how
      // two snack bars (an error and a confirmation) went unnoticed.
      //
      // `pumpAndSettle` is the wrong tool here: it would also sit through a
      // *queued* bar's own four-second wait and its exit, so the run would end
      // with an empty screen either way and the assertion could never fail.
      // Pumping in small steps instead reaches the moment between the last
      // message leaving and the next one arriving — the only instant where a
      // queued message is visible as a failure.
      //
      // The default duration is 4000 ms (`_snackBarDisplayDuration`), plus a
      // short exit animation for the queue to advance.
      await tester.pump(const Duration(milliseconds: 4000));
      await tester.pump(const Duration(milliseconds: 750));
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason:
            'a second snack bar was queued and appeared after the first: only '
            'one message may be shown per save (see `_save`)',
      );

      // Nothing left to time, so no timer can outlive the test.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      return message;
    }

    testWidgets(
      'says "Profile updated." for a student, who has no server call',
      (tester) async {
        final message = await savedMessage(tester, role: ProfileRole.student);

        // Not a hedge, and not an error: the store *is* the store for a student
        // until their own completion contract is known.
        //
        // This overlaps with the `'Profile updated.'` assertion in the
        // full-flow test above, and is kept on purpose: it is the case that
        // proves the *helper* works. Without it, a broken harness would make
        // every instructor case below fail for a reason the failure text does
        // not name.
        expect(message, 'Profile updated.');
      },
    );

    testWidgets(
      'says "Profile updated." for an instructor with nothing to send',
      (tester) async {
        // No instructor fields seeded, so `InstructorCompletionRequest` is empty
        // and no request is made — the same "nothing to do, nothing wrong" case
        // as the student above.
        final message = await savedMessage(
          tester,
          role: ProfileRole.instructor,
          completionResult: false,
        );

        expect(message, 'Profile updated.');
      },
    );

    testWidgets('hedges only when the fields existed and the route 404s', (
      tester,
    ) async {
      final message = await savedMessage(
        tester,
        role: ProfileRole.instructor,
        seed: {'qualification': 'MCA'},
        // What `DioAuthRepository.completeProfile` returns for a 404.
        completionResult: false,
      );

      expect(
        message,
        'Profile saved on this device.',
        reason: 'the user typed this, and it genuinely did not reach a server',
      );
    });

    testWidgets('reports a rejected request without claiming success', (
      tester,
    ) async {
      final message = await savedMessage(
        tester,
        role: ProfileRole.instructor,
        seed: {'qualification': 'MCA'},
        completionFailure: ApiException(
          kind: ApiErrorKind.badRequest,
          statusCode: 400,
          message: 'Bad request',
        ),
      );

      // **The error, and only the error.** This used to assert the confirmation
      // `'Saved on this device — the server rejected the update.'`, which was
      // wrong twice over: `_sendCompletion` showed the error *before* the pop
      // and the confirmation *after*, so both were queued on the same
      // `ScaffoldMessenger` and the confirmation surfaced four seconds later,
      // over a screen the user had already left. The helper reads whichever
      // snack bar is on screen first, so it read the error — and the error is
      // what the user actually sees. One message, not two.
      expect(message, 'Bad request');
    });

    testWidgets('says "Profile updated." when the server accepted it', (
      tester,
    ) async {
      final message = await savedMessage(
        tester,
        role: ProfileRole.instructor,
        seed: {'qualification': 'MCA'},
        completionResult: true,
      );

      expect(message, 'Profile updated.');
    });
  });
}
