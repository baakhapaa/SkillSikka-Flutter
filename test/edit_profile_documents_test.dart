import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/widgets/profile_photo_picker.dart';
import 'package:skillsikka/core/widgets/upload_card.dart';
import 'package:skillsikka/features/auth/data/auth_repository.dart';
import 'package:skillsikka/features/profile/data/profile_role.dart';
import 'package:skillsikka/features/profile/data/user_profile.dart';
import 'package:skillsikka/features/profile/presentation/edit_profile_page.dart';

/// A photo picker that answers with a fixed image, so a test can drive a pick
/// without the platform gallery.
///
/// Answers [PickedPhoto] **bytes**, which is the part that matters: the screen
/// must never ask for a path, because on Flutter web a picked file's path is a
/// blob URL nothing else can read.
class _FakePhotoPicker implements PhotoPicker {
  PickedPhoto? result;

  @override
  Future<PickedPhoto?> pickImage() async => result;
}

/// Stands in for the platform file dialog.
///
/// It records the `withData` argument because that argument *is* the bug. With
/// it false the returned file carries no bytes, and on web its `path` is a blob
/// URL nothing else can read — so the document gets picked, displayed, and then
/// uploaded as nothing. Nothing about that failure is visible on screen, which
/// is exactly why it needs a test rather than a look.
class _FakeFilePicker extends FilePicker {
  _FakeFilePicker(this.result);

  FilePickerResult? result;

  /// The last `withData` the screen asked for.
  bool? lastWithData;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    lastWithData = withData;
    return result;
  }
}

void main() {
  // The form is laid out for Manrope, which `flutter test` cannot fetch; the
  // Roboto stand-in wraps differently and overflows. Pre-existing and unrelated,
  // so drain it. Anything that is not an overflow still fails the test.
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
        reason: 'unexpected exception on the edit screen: $text',
      );
    }
  }

  final idCardBytes = Uint8List.fromList([37, 80, 68, 70, 45, 49, 46, 52]);

  /// A real one-pixel PNG. `Image.memory` throws on bytes that are not a
  /// decodable image, so the photo fixtures cannot be arbitrary.
  final onePixelPng = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAF'
      'AAH/q842iQAAAABJRU5ErkJggg==',
    ),
  );

  /// The file every test starts from: a readable PDF named `id-card.pdf`.
  FilePickerResult idCardResult() => FilePickerResult([
    PlatformFile(
      name: 'id-card.pdf',
      size: idCardBytes.length,
      bytes: idCardBytes,
    ),
  ]);

  final fake = _FakeFilePicker(idCardResult());

  setUp(() {
    // Static, and mutated per test. The isolate ends with the file, so there is
    // nothing to restore — but every test must set it or the getter throws.
    FilePicker.platform = fake;
    fake.lastWithData = null;
    // **`result` restored too, not just `lastWithData`.** A test that swaps in
    // the no-bytes variant used to leave it there, so the next test picked a
    // file with no bytes and — correctly — sent nothing. It read as "the upload
    // is broken" rather than "this fake was never reset", which is the worst way
    // for a shared double to fail.
    fake.result = idCardResult();
  });

  /// Pumps the edit screen for a student, which is the field set that carries
  /// the Student ID Card upload.
  Future<ProviderContainer> pumpEditScreen(WidgetTester tester) async {
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
    return container;
  }

  /// Taps the upload card itself. Tapping the 'Student ID Card' label would
  /// miss — that text sits above the card, outside the gesture detector.
  Future<void> tapUploadCard(WidgetTester tester) async {
    final card = find.byType(UploadCard);
    expect(card, findsOneWidget, reason: 'the student ID card upload is gone');
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: card, matching: find.text('Upload Document')),
    );
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);
  }

  testWidgets(
    'a picked document is asked for its bytes and reaches the store',
    (tester) async {
      final container = await pumpEditScreen(tester);

      await tapUploadCard(tester);

      // The regression guard. If this is ever false again the file is silently
      // unusable, and no other assertion in this test would notice.
      expect(
        fake.lastWithData,
        isTrue,
        reason: 'withData must be true or the picked file carries no bytes',
      );

      final stored = container
          .read(userProfileProvider)
          .documentFor(ProfileDocumentSlot.studentIdCard);
      expect(
        stored,
        PickedDocument(bytes: idCardBytes, fileName: 'id-card.pdf'),
        reason: 'the picked file must survive the screen being popped',
      );

      // …and the card switches to its picked state.
      expect(find.text('id-card.pdf'), findsOneWidget);
      expect(find.text('Upload Document'), findsNothing);
    },
  );

  testWidgets('removing a document clears it from the store too', (
    tester,
  ) async {
    final container = await pumpEditScreen(tester);
    await tapUploadCard(tester);

    // Precondition: the store has it, so the clear below is a real change.
    expect(
      container
          .read(userProfileProvider)
          .documentFor(ProfileDocumentSlot.studentIdCard),
      isNotNull,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(UploadCard),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();
    drainUnrelatedOverflows(tester);

    // Clearing only the widget would leave the deleted file queued for upload,
    // because the store took its own copy of the bytes at pick time.
    expect(
      container
          .read(userProfileProvider)
          .documentFor(ProfileDocumentSlot.studentIdCard),
      isNull,
      reason: 'a removed file must not still be uploadable',
    );
    expect(find.text('Upload Document'), findsOneWidget);
  });

  testWidgets('a file that comes back without bytes is refused, not stored', (
    tester,
  ) async {
    fake.result = FilePickerResult([
      // No bytes: what the picker returns when `withData` is false, or when the
      // platform hands back a path the app cannot read.
      PlatformFile(name: 'id-card.pdf', size: idCardBytes.length),
    ]);

    final container = await pumpEditScreen(tester);
    await tapUploadCard(tester);

    expect(
      find.text('That file could not be read. Please pick another.'),
      findsOneWidget,
      reason: 'an unreadable file must be reported rather than accepted',
    );
    expect(
      container
          .read(userProfileProvider)
          .documentFor(ProfileDocumentSlot.studentIdCard),
      isNull,
      reason: 'a file with no bytes must not be stored as if it were usable',
    );
    // The card stays in its empty state rather than claiming a file.
    expect(find.text('Upload Document'), findsOneWidget);

    // Let the snack bar expire so no timer outlives the test.
    await tester.pump(const Duration(seconds: 5));
  });

  /// The bug these pin: the documents reached the **store** and then went
  /// nowhere. `PATCH /me/` had no multipart mode until 2026-10-05, so a user
  /// picked their ID card, saw "Profile updated.", and the file was discarded.
  group('the picked document is actually sent', () {
    /// Pumps the edit screen for a student and hands back the fake repository,
    /// so a test can read what went out rather than what was displayed.
    ///
    /// **Pushed, not the root.** `_save` pops the route and *then* shows the
    /// snack bar on a messenger captured before the pop; pumping the page as
    /// `MaterialApp.home` makes it the route being popped and the messenger
    /// unmounts with it.
    Future<FakeAuthRepository> pumpAndSave(
      WidgetTester tester, {
      required ProfileRole role,
      required Future<void> Function(WidgetTester tester) act,
      Uint8List? photoInStore,
    }) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final auth = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);
      container.read(userProfileProvider.notifier).save({
        'name': 'Real User',
        'email': 'real@user.test',
      });
      if (photoInStore != null) {
        // As signup leaves it: bytes present, never re-picked on this screen.
        container
            .read(userProfileProvider.notifier)
            .setPhoto(photoInStore, 'me.png');
      }

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

      await act(tester);

      final save = find.widgetWithText(FilledButton, 'Save Changes');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      drainUnrelatedOverflows(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      return auth;
    }

    testWidgets('a student ID card goes out under its slot name', (
      tester,
    ) async {
      final auth = await pumpAndSave(
        tester,
        role: ProfileRole.student,
        act: tapUploadCard,
      );

      expect(
        auth.uploads.single,
        ['student_id_card'],
        reason:
            'the slot name is the multipart field name, and this is the whole '
            'point of the test: before 2026-10-05 this list was empty because '
            'nothing was ever sent',
      );
    });

    testWidgets('a photo already in the store is not re-uploaded', (
      tester,
    ) async {
      // The direction the dirty flag guards. `_photoBytes` is seeded from the
      // store so the signup photo shows, which makes "there is a photo" and "the
      // user just changed the photo" the same value — so a save that read that
      // value directly would re-upload the same 5 MB on every single save.
      final auth = await pumpAndSave(
        tester,
        role: ProfileRole.student,
        photoInStore: onePixelPng,
        act: (tester) async {},
      );

      expect(
        auth.uploads.single,
        isEmpty,
        reason: 'nothing was picked on this screen, so nothing should be sent',
      );
    });

    /// Pumps the editor with a fake picker and a photo already in the store —
    /// the state a user is in after a relogin, when the avatar came from
    /// `/me/` rather than from a pick on this screen.
    Future<ProviderContainer> pumpWithPicker(
      WidgetTester tester, {
      required ProfileRole role,
      required Uint8List pickedPhoto,
      String fileName = 'new-photo.png',
    }) async {
      final picker = _FakePhotoPicker()
        ..result = PickedPhoto(bytes: pickedPhoto, name: fileName);

      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
      );
      addTearDown(container.dispose);
      container.read(userProfileProvider.notifier)
        ..save({'name': 'Real User', 'email': 'real@user.test'})
        ..setPhoto(onePixelPng, 'old-photo.png');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: EditProfilePage(role: role, imagePicker: picker),
          ),
        ),
      );
      await tester.pump();
      drainUnrelatedOverflows(tester);
      return container;
    }

    /// **The bug this pins.** A picked photo was uploaded but never written to
    /// the store, so the profile tab behind this screen kept rendering the
    /// **old** avatar — and a relogin was the only thing that made the change
    /// appear. A user who changed their picture and watched it snap back had no
    /// way to tell the upload had worked.
    testWidgets('a picked photo reaches the store, so the tab updates at once', (
      tester,
    ) async {
      final replacement = onePixelPng;
      final container = await pumpWithPicker(
        tester,
        role: ProfileRole.student,
        pickedPhoto: replacement,
      );

      // Tap the picker's own affordance, which is what the user presses.
      final picker = find.byType(ProfilePhotoPicker);
      expect(picker, findsOneWidget);
      await tester.ensureVisible(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change Profile Photo').first);
      await tester.pumpAndSettle();

      final save = find.widgetWithText(FilledButton, 'Save Changes');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      final profile = container.read(userProfileProvider);
      expect(
        profile.photoFileName,
        'new-photo.png',
        reason:
            'the name travels with the bytes so a later re-upload is labelled '
            'with the right content type',
      );
      expect(
        profile.photoBytes,
        replacement,
        reason:
            'the profile tab renders this; if it is stale the avatar is stale',
      );
    });

    testWidgets('an untouched photo is left exactly as it was', (tester) async {
      // The other direction of the same flag: nothing picked, so the photo the
      // login download put in the store must survive a save untouched.
      final container = await pumpWithPicker(
        tester,
        role: ProfileRole.student,
        pickedPhoto: onePixelPng,
      );

      final save = find.widgetWithText(FilledButton, 'Save Changes');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      final profile = container.read(userProfileProvider);
      expect(profile.photoFileName, 'old-photo.png');
      expect(profile.photoBytes, onePixelPng);
    });

    testWidgets('a save with nothing picked sends no files at all', (
      tester,
    ) async {
      final auth = await pumpAndSave(
        tester,
        role: ProfileRole.instructor,
        act: (tester) async {},
      );

      expect(
        auth.uploads.single,
        isEmpty,
        reason: 'the text fields still went; the file half must be empty',
      );
      expect(
        auth.updates.single,
        containsPair('name', 'Real User'),
        reason: 'the text half of the save is unaffected by the file half',
      );
    });
  });
}
