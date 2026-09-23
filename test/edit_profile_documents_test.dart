import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/widgets/upload_card.dart';
import 'package:skillsikka/features/profile/data/user_profile.dart';
import 'package:skillsikka/features/profile/presentation/edit_profile_page.dart';

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
  final fake = _FakeFilePicker(
    FilePickerResult([
      PlatformFile(
        name: 'id-card.pdf',
        size: idCardBytes.length,
        bytes: idCardBytes,
      ),
    ]),
  );

  setUp(() {
    // Static, and mutated per test. The isolate ends with the file, so there is
    // nothing to restore — but every test must set it or the getter throws.
    FilePicker.platform = fake;
    fake.lastWithData = null;
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
}
