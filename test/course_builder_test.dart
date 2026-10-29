import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/features/courses/data/course_builder_api.dart';
import 'package:skillsikka/features/courses/data/course_draft.dart';
import 'package:skillsikka/features/courses/presentation/course_builder_page.dart';
import 'package:skillsikka/features/courses/presentation/widgets/course_basics_step.dart';
import 'package:skillsikka/features/courses/presentation/widgets/lesson_editor_sheet.dart';
import 'package:skillsikka/features/courses/presentation/widgets/prompt_dialog.dart';
import 'package:skillsikka/core/widgets/upload_card.dart';

/// Returns whatever files a test hands it, so the sheet's **Attach resources**
/// block can be driven without an OS dialog.
class _FakeFilePicker extends FilePicker {
  _FakeFilePicker(this.result);

  FilePickerResult? result;

  /// The last `allowMultiple` asked for. Attaching a lesson's files one at a
  /// time would be a worse flow than the one the block promises.
  bool? lastAllowMultiple;

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
    lastAllowMultiple = allowMultiple;
    return result;
  }
}

/// Stands in for the network so the builder can be driven end to end.
///
/// Every method the page calls is recorded rather than stubbed away: the point of
/// these tests is the *order* of the writes — create the draft before any lesson
/// exists, publish only after the metadata is saved — which a fake that returned
/// canned values could not show.
class _FakeCourseApi implements CourseBuilderApi {
  int _nextId = 100;

  final List<CourseDraft> createdCourses = [];
  final Map<int, CourseDraft> updatedCourses = {};
  final List<({int courseId, CourseLesson lesson, int order, String? section})>
  createdLessons = [];
  final List<({CourseLesson lesson, int order, String? section})>
  updatedLessons = [];
  final List<int> deletedLessons = [];
  final List<int> published = [];

  /// The id `createLesson` answered — what a resource row must point at.
  int? lastCreatedLessonId;

  bool failCreate = false;

  @override
  Future<int> createCourse(CourseDraft draft) async {
    if (failCreate) {
      throw const ApiException(kind: ApiErrorKind.unknown, message: 'nope');
    }
    createdCourses.add(draft);
    return _nextId++;
  }

  @override
  Future<void> updateCourse(int courseId, CourseDraft draft) async {
    updatedCourses[courseId] = draft;
  }

  @override
  Future<void> publishCourse(int courseId) async => published.add(courseId);

  @override
  Future<void> deleteCourse(int courseId) async {}

  @override
  Future<int> createLesson({
    required int courseId,
    required CourseLesson lesson,
    required int order,
    String? section,
  }) async {
    createdLessons.add((
      courseId: courseId,
      lesson: lesson,
      order: order,
      section: section,
    ));
    return lastCreatedLessonId = _nextId++;
  }

  @override
  Future<void> updateLesson({
    required CourseLesson lesson,
    required int order,
    String? section,
  }) async {
    updatedLessons.add((lesson: lesson, order: order, section: section));
  }

  @override
  Future<void> deleteLesson(int lessonId) async => deletedLessons.add(lessonId);

  @override
  Future<CourseDraft?> loadCourse(int courseId) async => null;

  int uploads = 0;
  bool failUpload = false;

  @override
  Future<String> uploadLessonAsset({
    required int courseId,
    required Uint8List bytes,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    uploads += 1;
    if (failUpload) {
      throw const ApiException(kind: ApiErrorKind.unknown, statusCode: 404);
    }
    return 'https://example.com/$fileName';
  }

  /// Every cover that went up, in order.
  final List<({int courseId, String fileName})> coverUploads = [];
  bool failCover = false;

  @override
  Future<String> uploadCover({
    required int courseId,
    required Uint8List bytes,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    coverUploads.add((courseId: courseId, fileName: fileName));
    if (failCover) {
      throw const ApiException(kind: ApiErrorKind.unknown, statusCode: 500);
    }
    return 'https://example.com/covers/$fileName';
  }

  /// Every resource file that went up, in order.
  final List<({int courseId, String fileName})> resourceUploads = [];

  /// Every resource row created, in order — the assertion that a file attached
  /// while adding a lesson actually reaches the server, with the lesson id the
  /// create answered.
  final List<
    ({
      int courseId,
      int? lessonId,
      String title,
      String fileUrl,
      String fileFormat,
    })
  >
  createdResources = [];

  bool failResource = false;

  @override
  Future<String> uploadResourceAsset({
    required int courseId,
    required Uint8List bytes,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    resourceUploads.add((courseId: courseId, fileName: fileName));
    if (failResource) {
      throw const ApiException(kind: ApiErrorKind.unknown, statusCode: 400);
    }
    return 'https://example.com/resources/$fileName';
  }

  @override
  Future<int> createResource({
    required int courseId,
    required String title,
    required String fileUrl,
    required String fileFormat,
    int? lessonId,
    int? sizeBytes,
    int? order,
  }) async {
    createdResources.add((
      courseId: courseId,
      lessonId: lessonId,
      title: title,
      fileUrl: fileUrl,
      fileFormat: fileFormat,
    ));
    return _nextId++;
  }

  @override
  Future<void> deleteResource({
    required int courseId,
    required int resourceId,
  }) async {}

  @override
  Future<String> uploadCourseAsset({
    required int courseId,
    required String kind,
    required Uint8List bytes,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) {
    if (kind == 'cover') {
      return uploadCover(courseId: courseId, bytes: bytes, fileName: fileName);
    }
    if (kind == 'resource') {
      return uploadResourceAsset(
        courseId: courseId,
        bytes: bytes,
        fileName: fileName,
      );
    }
    return uploadLessonAsset(
      courseId: courseId,
      bytes: bytes,
      fileName: fileName,
    );
  }

  @override
  Future<List<(int, String)>> loadGrades() async => const [];

  @override
  Future<List<(int, String)>> loadSubjects() async => const [];

  @override
  Future<List<(int, String)>> loadCategories() async => const [
    (1, 'Coding'),
    (13, 'Drawing'),
    (14, 'Public Speaking'),
    (15, 'Music'),
  ];
}

Widget _app(_FakeCourseApi api, {bool verified = true}) => MaterialApp(
  home: CourseBuilderPage(api: api, instructorVerified: verified),
);

/// Types into the title field, which is the only required field on step 1.
Future<void> _title(WidgetTester tester, String value) async {
  await tester.enterText(find.byType(TextFormField).first, value);
  await tester.pump();
}

/// Adds a module, which now asks for its name first.
Future<void> _addModule(WidgetTester tester, String name) async {
  await tester.tap(find.text('Add your first module'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byType(PromptDialog),
      matching: find.byType(TextField),
    ),
    name,
  );
  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // `FilePicker.platform` is static and the getter throws until it is set.
    // Inert by default so a stray tap on an upload card cannot reach an OS
    // dialog; the resources test installs its own.
    FilePicker.platform = _FakeFilePicker(null);
  });

  testWidgets('step 1 refuses to continue without a title', (tester) async {
    final api = _FakeCourseApi();
    await tester.pumpWidget(_app(api));

    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(
      find.text('Give your course a title before continuing.'),
      findsOneWidget,
    );
    expect(api.createdCourses, isEmpty);
    // Still on step 1 — the header pill is the assertion, not the button.
    expect(find.text('Step 1 of 3'), findsOneWidget);
  });

  testWidgets('continue creates the draft, then advances', (tester) async {
    final api = _FakeCourseApi();
    await tester.pumpWidget(_app(api));

    await _title(tester, 'Digital Illustration');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(api.createdCourses, hasLength(1));
    expect(api.createdCourses.single.title, 'Digital Illustration');
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('Curriculum'), findsOneWidget);
  });

  testWidgets('picking a category records its id, not just its label', (
    tester,
  ) async {
    final api = _FakeCourseApi();
    await tester.pumpWidget(_app(api));

    // The draft has to change before the lazy reference fetch runs, which is
    // what typing the title does.
    await _title(tester, 'Sketching');
    await tester.pumpAndSettle();

    // The Category row sits below the fold at the default test size, and the
    // sticky footer covers it — scroll it into view before tapping.
    await tester.ensureVisible(find.text('Select category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drawing'));
    await tester.pumpAndSettle();

    // The label is what the field prints.
    expect(find.text('Drawing'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // The id is what the server stores. Without it the course appears under no
    // Skill chip at all — `skill_category` is a FK, and a name is ignored.
    expect(api.createdCourses.single.skillCategoryId, 13);
    expect(api.createdCourses.single.category, 'Drawing');
  });

  testWidgets('a failed create keeps the user on step 1', (tester) async {
    final api = _FakeCourseApi()..failCreate = true;
    await tester.pumpWidget(_app(api));

    await _title(tester, 'Anything');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 3'), findsOneWidget);
  });

  testWidgets('a module can be added and a lesson saved into it', (
    tester,
  ) async {
    final api = _FakeCourseApi();
    await tester.pumpWidget(_app(api));

    await _title(tester, 'Illustration');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Empty curriculum first: the add tile doubles as the empty state.
    expect(find.text('Add your first module'), findsOneWidget);
    await _addModule(tester, 'Getting Started');

    expect(find.text('Getting Started'), findsOneWidget);

    await tester.tap(find.text('Add lesson'));
    await tester.pumpAndSettle();

    expect(find.byType(LessonEditorSheet), findsOneWidget);

    // Content defaults to upload; the link tab is where a URL lives.
    await tester.tap(find.text('Paste a link'));
    await tester.pumpAndSettle();

    final fields = find.descendant(
      of: find.byType(LessonEditorSheet),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), 'Line and shape');
    await tester.enterText(fields.at(1), '09:30');
    await tester.enterText(fields.at(2), 'https://example.com/a.mp4');
    await tester.pump();

    await tester.tap(find.text('Save lesson'));
    await tester.pumpAndSettle();

    expect(api.createdLessons, hasLength(1));
    final saved = api.createdLessons.single;
    expect(saved.lesson.title, 'Line and shape');
    expect(saved.lesson.duration, const Duration(minutes: 9, seconds: 30));
    expect(saved.order, 1);
    // The module name goes on the wire as the lesson's `section`. Without it the
    // grouping is lost on the next load — see CourseDraft.fromServer.
    expect(saved.section, 'Getting Started');
    expect(find.text('Line and shape'), findsOneWidget);
    // The row prints the duration it was given, not a placeholder.
    expect(find.textContaining('09:30'), findsOneWidget);
  });

  testWidgets('a lesson carries resources, attached once the lesson exists', (
    tester,
  ) async {
    // The order is the point. A resource row needs `lesson`, and the lesson id is
    // only minted by `POST /lessons/` — so the file uploads first, the lesson is
    // created second, and the row goes up third. A sheet that created the row
    // on save would have had no id to send.
    final api = _FakeCourseApi();
    final picker = _FakeFilePicker(
      FilePickerResult([
        PlatformFile(
          name: 'worksheet.pdf',
          size: 2048,
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        PlatformFile(
          name: 'template.xlsx',
          size: 4096,
          bytes: Uint8List.fromList([4, 5, 6]),
        ),
      ]),
    );
    FilePicker.platform = picker;

    await tester.pumpWidget(_app(api));
    await _title(tester, 'Illustration');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await _addModule(tester, 'Getting Started');
    await tester.tap(find.text('Add lesson'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paste a link'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(LessonEditorSheet),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), 'Line and shape');
    await tester.enterText(fields.at(1), '09:30');
    await tester.enterText(fields.at(2), 'https://example.com/a.mp4');
    await tester.pump();

    // The block sits under the content fields, so on the default surface it is
    // below the fold — a bare `tap` would hit whatever is under that point.
    await tester.ensureVisible(find.text('Attach files'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attach files'));
    await tester.pumpAndSettle();

    expect(picker.lastAllowMultiple, isTrue);
    expect(api.resourceUploads, hasLength(2));
    expect(
      api.createdResources,
      isEmpty,
      reason: 'no row can exist before the lesson does',
    );
    expect(find.text('worksheet.pdf'), findsOneWidget);

    await tester.tap(find.text('Save lesson'));
    await tester.pumpAndSettle();

    expect(api.createdLessons, hasLength(1));
    expect(api.createdResources, hasLength(2));
    // Every row points at the lesson `createLesson` answered — the id that did
    // not exist when the files were uploaded.
    expect(
      api.createdResources.every((r) => r.lessonId == api.lastCreatedLessonId),
      isTrue,
    );
    expect(api.createdResources.map((r) => r.fileFormat), ['pdf', 'xlsx']);
    expect(
      api.createdResources.first.fileUrl,
      'https://example.com/resources/worksheet.pdf',
    );
  });

  testWidgets('a failed resource upload keeps the lesson saveable', (
    tester,
  ) async {
    // Losing a lesson because a spreadsheet was too big would be the worse
    // outcome; the sheet reports the file and lets the save through.
    final api = _FakeCourseApi()..failResource = true;
    FilePicker.platform = _FakeFilePicker(
      FilePickerResult([
        PlatformFile(
          name: 'huge.zip',
          size: 99999999,
          bytes: Uint8List.fromList([7]),
        ),
      ]),
    );

    await tester.pumpWidget(_app(api));
    await _title(tester, 'Illustration');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await _addModule(tester, 'Getting Started');
    await tester.tap(find.text('Add lesson'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paste a link'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(LessonEditorSheet),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), 'Line and shape');
    await tester.enterText(fields.at(1), '09:30');
    await tester.enterText(fields.at(2), 'https://example.com/a.mp4');
    await tester.pump();

    // The block sits under the content fields, so on the default surface it is
    // below the fold — a bare `tap` would hit whatever is under that point.
    await tester.ensureVisible(find.text('Attach files'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attach files'));
    await tester.pumpAndSettle();

    // The failure is named inline, and the file is not attached.
    expect(find.textContaining('huge.zip'), findsOneWidget);
    expect(find.text('Save lesson'), findsOneWidget);

    await tester.tap(find.text('Save lesson'));
    await tester.pumpAndSettle();

    expect(api.createdLessons, hasLength(1));
    expect(api.createdResources, isEmpty);
  });

  testWidgets('the lesson sheet rejects a duration it cannot read', (
    tester,
  ) async {
    final api = _FakeCourseApi();
    await tester.pumpWidget(_app(api));

    await _title(tester, 'Illustration');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await _addModule(tester, 'Getting Started');
    await tester.tap(find.text('Add lesson'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paste a link'));
    await tester.pumpAndSettle();

    final fields = find.descendant(
      of: find.byType(LessonEditorSheet),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), 'Something');
    await tester.enterText(fields.at(1), 'abc');
    await tester.enterText(fields.at(2), 'https://example.com/a.mp4');
    await tester.pump();

    await tester.tap(find.text('Save lesson'));
    await tester.pumpAndSettle();

    expect(find.text('Duration must look like 09:30.'), findsOneWidget);
    expect(api.createdLessons, isEmpty);
  });

  testWidgets('publish is gated on verification, and the gate is visible', (
    tester,
  ) async {
    final api = _FakeCourseApi();
    await tester.pumpWidget(_app(api, verified: false));

    await _title(tester, 'Illustration');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.text('Account under review'), findsOneWidget);
    expect(find.text('Not yet'), findsOneWidget);

    await tester.tap(find.text('Publish course'));
    await tester.pumpAndSettle();

    expect(api.published, isEmpty);
  });

  testWidgets('choosing Paid says how the student pays', (tester) async {
    // The instructor sets a price and never sees the student's screen, so the
    // one thing they cannot otherwise know — that the money is taken by eSewa
    // before the course opens — is said next to the choice.
    final api = _FakeCourseApi();
    await tester.pumpWidget(_app(api, verified: true));

    await _title(tester, 'Illustration');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Students pay with eSewa'), findsNothing);

    await tester.tap(find.text('Paid'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Students pay with eSewa'), findsOneWidget);
    expect(
      find.text('Students pay once and keep lifetime access.'),
      findsOneWidget,
    );
  });

  testWidgets('every step renders at 360x800 without overflowing', (
    tester,
  ) async {
    // The design target, and the surface `flutter test` does not default to. The
    // fallback test font is markedly wider than Manrope, so this is the stricter
    // of the two layouts — a step that fits here fits on a phone.
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final api = _FakeCourseApi();
    await tester.pumpWidget(_app(api, verified: false));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await _title(tester, 'Digital Illustration for Beginners');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await _addModule(tester, 'Getting Started');
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('lesson content source', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpWidget(_app(_FakeCourseApi()));
      await _title(tester, 'Illustration');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await _addModule(tester, 'Getting Started');
      await tester.tap(find.text('Add lesson'));
      await tester.pumpAndSettle();
    }

    testWidgets('offers upload and link, and opens on upload', (tester) async {
      await openSheet(tester);

      expect(find.text('Upload a file'), findsOneWidget);
      expect(find.text('Paste a link'), findsOneWidget);
      // The upload panel is the default, and it is the app's own UploadCard —
      // not a bespoke dropzone.
      expect(
        find.descendant(
          of: find.byType(LessonEditorSheet),
          matching: find.byType(UploadCard),
        ),
        findsOneWidget,
      );
      expect(find.text('Lesson video'), findsOneWidget);
    });

    testWidgets('switching to a link swaps the panel for a URL field', (
      tester,
    ) async {
      await openSheet(tester);
      await tester.tap(find.text('Paste a link'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(LessonEditorSheet),
          matching: find.byType(UploadCard),
        ),
        findsNothing,
      );
      // `textContaining`, not `text`: `LabeledTextField` renders a required
      // field's label as `Lesson link *` through `Text.rich`.
      expect(find.textContaining('Lesson link'), findsOneWidget);
    });

    testWidgets('saving with no file chosen explains both ways forward', (
      tester,
    ) async {
      await openSheet(tester);

      final fields = find.descendant(
        of: find.byType(LessonEditorSheet),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(0), 'Something');
      await tester.enterText(fields.at(1), '05:00');
      await tester.pump();

      await tester.tap(find.text('Save lesson'));
      await tester.pumpAndSettle();

      expect(
        find.text('Choose a file, or paste a link instead.'),
        findsOneWidget,
      );
    });
  });

  group('the outcome and requirement dialogs', () {
    /// Scrolls the basics step until [finder] is on screen and taps it.
    ///
    /// Step 1 is taller than a 360x800 viewport, so the repeaters sit below the
    /// fold — and a missed tap only prints a warning, which would let a broken
    /// assertion pass for the wrong reason.
    Future<void> open(WidgetTester tester, String label) async {
      await tester.pumpWidget(_app(_FakeCourseApi()));
      await tester.pumpAndSettle();
      final target = find.text(label);
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    testWidgets('adding an outcome closes cleanly and lands in the list', (
      tester,
    ) async {
      await open(tester, 'Add outcome');
      expect(find.byType(PromptDialog), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byType(PromptDialog),
          matching: find.byType(TextField),
        ),
        'Draw clean line work',
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // The regression this exists for: disposing the dialog's controller while
      // the route was still animating out threw
      // `'_dependents.isEmpty': is not true` on both Add and Cancel.
      expect(tester.takeException(), isNull);
      expect(find.text('Draw clean line work'), findsOneWidget);
    });

    testWidgets('cancelling leaves the list alone and throws nothing', (
      tester,
    ) async {
      await open(tester, 'Add requirement');
      expect(find.byType(PromptDialog), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PromptDialog), findsNothing);
      expect(find.text('Add requirement'), findsOneWidget);
    });
  });

  group('the cover', () {
    /// A real 1x1 PNG. `Image.memory` decodes asynchronously, so a made-up byte
    /// list would fail the test with a decode error rather than proving anything
    /// about the builder.
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
      'hQGAhKmMIQAAAABJRU5ErkJggg==',
    );

    /// Taps a control on step 1 that may sit below the fold.
    ///
    /// The cover is the second element on the step, but the default 800x600 test
    /// surface plus the pinned bottom bar leaves it clipped — a bare `tap` lands
    /// on the bar instead, and the only symptom is a warning plus an assertion
    /// that fails for the wrong reason.
    Future<void> tapInStep(WidgetTester tester, String label) async {
      final target = find.text(label);
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    /// The cover card itself, which is the real tap target.
    Future<void> tapCover(WidgetTester tester) async {
      final target = find.byKey(CourseBasicsStep.coverPickerKey);
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    testWidgets('picking one uploads it after the course is created', (
      tester,
    ) async {
      final api = _FakeCourseApi();
      await tester.pumpWidget(
        MaterialApp(
          home: CourseBuilderPage(
            api: api,
            instructorVerified: true,
            pickCover: () async =>
                PickedCover(bytes: png, fileName: 'cover.png'),
          ),
        ),
      );

      await tapCover(tester);
      // The picked picture replaces the generated tile immediately, before any
      // request — that is what makes the picker feel like it worked.
      expect(find.byType(Image), findsWidgets);

      await _title(tester, 'Digital Illustration');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // The course has to exist first: the upload route is course-scoped.
      expect(api.createdCourses, hasLength(1));
      expect(api.coverUploads, hasLength(1));
      expect(api.coverUploads.single.fileName, 'cover.png');
      expect(api.coverUploads.single.courseId, 100);
      // …and the URL the upload answered is what gets patched back, so the
      // student card can render it.
      expect(
        api.updatedCourses[100]?.coverUrl,
        'https://example.com/covers/cover.png',
      );
      expect(find.text('Step 2 of 3'), findsOneWidget);
    });

    testWidgets('a failed upload keeps the course and says what happened', (
      tester,
    ) async {
      final api = _FakeCourseApi()..failCover = true;
      await tester.pumpWidget(
        MaterialApp(
          home: CourseBuilderPage(
            api: api,
            instructorVerified: true,
            pickCover: () async =>
                PickedCover(bytes: png, fileName: 'cover.png'),
          ),
        ),
      );

      await tapCover(tester);
      await _title(tester, 'Digital Illustration');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // The metadata is already saved by then; blocking the step would throw
      // away a form the server has accepted.
      expect(api.createdCourses, hasLength(1));
      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(find.textContaining('the cover did not upload'), findsOneWidget);
    });

    testWidgets('removing the cover clears both the file and the URL', (
      tester,
    ) async {
      final api = _FakeCourseApi();
      await tester.pumpWidget(
        MaterialApp(
          home: CourseBuilderPage(
            api: api,
            instructorVerified: true,
            pickCover: () async =>
                PickedCover(bytes: png, fileName: 'cover.png'),
          ),
        ),
      );

      await tapCover(tester);
      expect(find.text('Remove cover'), findsOneWidget);

      await tapInStep(tester, 'Remove cover');
      expect(find.text('Remove cover'), findsNothing);

      await _title(tester, 'Digital Illustration');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(api.coverUploads, isEmpty);
    });
  });

  group('PublishReadiness', () {
    CourseDraft draft({
      String title = 'Course',
      String description = 'About it',
      List<CourseLesson> lessons = const [],
      bool isPaid = false,
      String price = '',
      int? skillCategoryId = 1,
    }) => CourseDraft(
      title: title,
      description: description,
      isPaid: isPaid,
      price: price,
      skillCategoryId: skillCategoryId,
      modules: [
        if (lessons.isNotEmpty)
          CourseModule(key: 'm', title: 'M', lessons: lessons),
      ],
    );

    const lesson = CourseLesson(
      key: 'l',
      title: 'One',
      kind: LessonKind.video,
      duration: Duration(minutes: 5),
      contentUrl: 'https://example.com/a.mp4',
    );

    test('a complete free course can publish', () {
      final readiness = PublishReadiness.of(
        draft(lessons: [lesson]),
        instructorVerified: true,
      );
      expect(readiness.canPublish, isTrue);
    });

    test('an unverified instructor cannot, however complete the course', () {
      final readiness = PublishReadiness.of(
        draft(lessons: [lesson]),
        instructorVerified: false,
      );
      expect(readiness.canPublish, isFalse);
      expect(readiness.instructorVerified, isFalse);
    });

    test('a paid course needs a positive price', () {
      expect(
        PublishReadiness.of(
          draft(lessons: [lesson], isPaid: true, price: ''),
          instructorVerified: true,
        ).priceSet,
        isFalse,
      );
      expect(
        PublishReadiness.of(
          draft(lessons: [lesson], isPaid: true, price: '1299'),
          instructorVerified: true,
        ).priceSet,
        isTrue,
      );
    });

    test('a lesson without a duration blocks publishing', () {
      final readiness = PublishReadiness.of(
        draft(
          lessons: const [
            CourseLesson(key: 'x', title: 'No duration', kind: LessonKind.text),
          ],
        ),
        instructorVerified: true,
      );
      expect(readiness.durationsComplete, isFalse);
      expect(readiness.canPublish, isFalse);
    });

    test('a course with no lessons blocks publishing', () {
      expect(
        PublishReadiness.of(draft(), instructorVerified: true).hasLesson,
        isFalse,
      );
    });

    test('a skill course with no category cannot publish', () {
      // Published but unplaced is the "I added a course and it is not in the
      // app" bug: the Skills tab filters on the category, so a course with none
      // would be reachable by no chip.
      final readiness = PublishReadiness.of(
        draft(lessons: [lesson], skillCategoryId: null),
        instructorVerified: true,
      );
      expect(readiness.placementChosen, isFalse);
      expect(readiness.canPublish, isFalse);
    });

    test('an academic course needs both a subject and a grade', () {
      final partial = CourseDraft(
        title: 'Course',
        description: 'About it',
        kind: CourseKind.academic,
        subjectId: 1,
        modules: [
          const CourseModule(key: 'm', title: 'M', lessons: [lesson]),
        ],
      );
      expect(
        PublishReadiness.of(partial, instructorVerified: true).placementChosen,
        isFalse,
      );
      expect(
        PublishReadiness.of(
          partial.copyWith(gradeId: 6),
          instructorVerified: true,
        ).placementChosen,
        isTrue,
      );
    });
  });

  group('parseDuration', () {
    test('reads mm:ss', () {
      expect(
        LessonEditorSheet.parseDuration('09:30'),
        const Duration(minutes: 9, seconds: 30),
      );
    });

    test('reads h:mm:ss', () {
      expect(
        LessonEditorSheet.parseDuration('1:02:03'),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
    });

    test('reads a bare number as minutes', () {
      expect(
        LessonEditorSheet.parseDuration('12'),
        const Duration(minutes: 12),
      );
    });

    test('rejects nonsense rather than returning zero', () {
      expect(LessonEditorSheet.parseDuration(''), isNull);
      expect(LessonEditorSheet.parseDuration('abc'), isNull);
      expect(LessonEditorSheet.parseDuration('0:00'), isNull);
      expect(LessonEditorSheet.parseDuration('1:2:3:4'), isNull);
    });
  });

  group('curriculum round trip', () {
    Map<String, dynamic> course() => {
      'id': 7,
      'title': 'Illustration',
      'course_type': 'skill',
      'is_paid': false,
      'is_published': true,
    };

    Map<String, dynamic> lesson(int id, String? section, int order) => {
      'id': id,
      'title': 'Lesson $id',
      'content_type': 'video',
      'content_url': 'https://example.com/$id.mp4',
      'content_text': '',
      'order': order,
      'section': section,
      'duration_seconds': 252,
      'is_preview': id == 1,
    };

    test(
      'modules are rebuilt from the section strings, in first-seen order',
      () {
        final draft = CourseDraft.fromServer(course(), [
          lesson(1, 'Getting Started', 1),
          lesson(2, 'Getting Started', 2),
          lesson(3, 'Core Skills', 3),
        ]);

        expect(draft.modules.map((m) => m.title), [
          'Getting Started',
          'Core Skills',
        ]);
        expect(draft.modules[0].lessons.map((l) => l.title), [
          'Lesson 1',
          'Lesson 2',
        ]);
        expect(draft.modules[1].lessons.single.title, 'Lesson 3');
      },
    );

    test('duration and the preview flag survive the read', () {
      final draft = CourseDraft.fromServer(course(), [
        lesson(1, 'Getting Started', 1),
      ]);
      final only = draft.modules.single.lessons.single;

      expect(only.duration, const Duration(seconds: 252));
      expect(only.isPreview, isTrue);
      expect(draft.totalDuration, const Duration(seconds: 252));
    });

    test('lessons with no section land in one container, not nowhere', () {
      final draft = CourseDraft.fromServer(course(), [
        lesson(1, null, 1),
        lesson(2, '', 2),
        lesson(3, '   ', 3),
      ]);

      expect(draft.modules, hasLength(1));
      expect(draft.modules.single.title, CourseDraft.orphanSectionTitle);
      // All three are reachable, which is the point — a blank section is treated
      // as no section, not as a shared module name.
      expect(draft.modules.single.lessons, hasLength(3));
    });

    test('a course with no lessons has no modules', () {
      expect(CourseDraft.fromServer(course(), const []).modules, isEmpty);
    });

    test(
      'two modules with the same name merge — a known, documented limit',
      () {
        final draft = CourseDraft.fromServer(course(), [
          lesson(1, 'Intro', 1),
          lesson(2, 'Middle', 2),
          lesson(3, 'Intro', 3),
        ]);

        expect(draft.modules, hasLength(2));
        expect(draft.modules[0].lessons, hasLength(2));
      },
    );
  });
}
