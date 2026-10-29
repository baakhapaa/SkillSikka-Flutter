import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/network/api_error.dart';
import '../../../../core/widgets/labeled_text_field.dart';
import '../../../../core/widgets/upload_card.dart';
import '../../../../core/widgets/pressable_chip.dart';
import '../../data/course_draft.dart';
import 'builder_tokens.dart';

/// What the sheet hands back.
///
/// Delete is a result rather than a callback because the sheet is dismissed
/// before the delete happens — and because a delete that ran while the sheet was
/// still open would have to repaint a form for a lesson that no longer exists.
sealed class LessonSheetResult {
  const LessonSheetResult();
}

class LessonSaved extends LessonSheetResult {
  const LessonSaved(this.lesson);

  final CourseLesson lesson;
}

class LessonDeleted extends LessonSheetResult {
  const LessonDeleted();
}

/// Add / edit one lesson.
class LessonEditorSheet extends StatefulWidget {
  const LessonEditorSheet({super.key, this.initial, required this.onUpload});

  final CourseLesson? initial;

  /// Uploads a picked file and answers the URL to store on the lesson.
  ///
  /// Injected rather than reached for through a provider: the sheet is also
  /// pumped bare by tests, and the one thing it needs from the network is this
  /// call. It throws [ApiException] on failure, which the sheet turns into an
  /// inline message instead of closing over a lost lesson.
  final Future<String> Function(Uint8List bytes, String fileName) onUpload;

  /// Opens the sheet and returns what the user did, or null for a dismissal.
  static Future<LessonSheetResult?> show(
    BuildContext context, {
    CourseLesson? initial,
    required Future<String> Function(Uint8List bytes, String fileName) onUpload,
  }) {
    return showModalBottomSheet<LessonSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) =>
          LessonEditorSheet(initial: initial, onUpload: onUpload),
    );
  }

  /// Accepts `9:30`, `09:30`, `1:02:03`, or a bare number of minutes.
  ///
  /// Returns null for anything else, which the caller treats as "not a
  /// duration" rather than silently saving zero. Public so the parser can be
  /// tested without pumping a sheet.
  static Duration? parseDuration(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length > 3) return null;
    var seconds = 0;
    for (final part in parts) {
      final value = int.tryParse(part.trim());
      if (value == null || value < 0) return null;
      seconds = seconds * 60 + value;
    }
    if (parts.length == 1) seconds *= 60;
    if (seconds <= 0) return null;
    return Duration(seconds: seconds);
  }

  @override
  State<LessonEditorSheet> createState() => _LessonEditorSheetState();
}

class _LessonEditorSheetState extends State<LessonEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _duration;
  late final TextEditingController _url;
  late final TextEditingController _body;
  late LessonKind _kind;
  late bool _isPreview;
  String? _error;

  /// Where a non-text lesson's content comes from.
  ///
  /// Upload is the default because that is what an instructor with a finished
  /// recording actually has; a link is the fallback for anything already hosted.
  _ContentSource _source = _ContentSource.upload;
  PlatformFile? _picked;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _title = TextEditingController(text: initial?.title ?? '');
    _duration = TextEditingController(
      text: initial?.duration == null ? '' : _format(initial!.duration!),
    );
    _url = TextEditingController(text: initial?.contentUrl ?? '');
    _body = TextEditingController(text: initial?.contentText ?? '');
    _kind = initial?.kind ?? LessonKind.video;
    _isPreview = initial?.isPreview ?? false;
    // An existing lesson that already has a URL was created from one — showing
    // it under the upload tab would imply a file the user never chose.
    if ((initial?.contentUrl ?? '').isNotEmpty) {
      _source = _ContentSource.link;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    _url.dispose();
    _body.dispose();
    super.dispose();
  }

  /// `04:12`, and `1:04:12` past an hour. Never an em dash here: this is the
  /// input's own text, and the field must never contain a placeholder.
  String _format(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (value.inHours > 0) return '${value.inHours}:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give this lesson a title.');
      return;
    }
    final duration = LessonEditorSheet.parseDuration(_duration.text);
    if (duration == null) {
      setState(() => _error = 'Duration must look like 09:30.');
      return;
    }

    String? contentUrl;
    if (_kind.usesBody) {
      if (_body.text.trim().isEmpty) {
        setState(() => _error = 'Add the lesson text.');
        return;
      }
    } else if (_source == _ContentSource.link) {
      if (_url.text.trim().isEmpty) {
        setState(() => _error = 'Add a link to the lesson file.');
        return;
      }
      contentUrl = _url.text.trim();
    } else {
      final picked = _picked;
      if (picked == null) {
        setState(() => _error = 'Choose a file, or paste a link instead.');
        return;
      }
      final bytes = picked.bytes;
      if (bytes == null) {
        setState(() => _error = 'That file could not be read. Try another.');
        return;
      }
      setState(() {
        _uploading = true;
        _error = null;
      });
      try {
        contentUrl = await widget.onUpload(bytes, picked.name);
      } on ApiException catch (error) {
        if (!mounted) return;
        setState(() {
          _uploading = false;
          _error = _uploadMessage(error);
        });
        return;
      } on Object {
        if (!mounted) return;
        setState(() {
          _uploading = false;
          _error = 'The upload did not finish. Try again, or paste a link.';
        });
        return;
      }
      if (!mounted) return;
      setState(() => _uploading = false);
    }

    final lesson = CourseLesson(
      key:
          widget.initial?.key ??
          'lesson-${DateTime.now().microsecondsSinceEpoch}',
      id: widget.initial?.id,
      title: title,
      kind: _kind,
      duration: duration,
      isPreview: _isPreview,
      contentUrl: _kind.usesBody ? null : contentUrl,
      contentText: _kind.usesBody ? _body.text.trim() : null,
    );
    Navigator.of(context).pop(LessonSaved(lesson));
  }

  /// Turns an upload failure into something the user can act on.
  ///
  /// **A 404 here is the expected case today**: the API has no asset endpoint, so
  /// every upload lands on a missing route. Saying "not found" would read as a
  /// broken app; naming the alternative the sheet can actually do is the honest
  /// version, and the Link tab is one tap away.
  String _uploadMessage(ApiException error) {
    if (error.statusCode == 404) {
      return 'File uploads are not available yet. Paste a link instead.';
    }
    if (error.statusCode == 413) {
      return 'That file is too large for the server.';
    }
    return error.displayMessage;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      // Bytes, not a path: on web a picked file's path is a blob URL nothing
      // else can read, so a path-only pick would upload nothing.
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _picked = result.files.single;
      _error = null;
    });
  }

  List<String> get _allowedExtensions => switch (_kind) {
    LessonKind.video => const ['mp4', 'mov', 'm4v'],
    LessonKind.pdf => const ['pdf'],
    LessonKind.ebook => const ['pdf', 'epub'],
    LessonKind.text => const [],
  };

  String get _uploadTitle => switch (_kind) {
    LessonKind.video => 'Lesson video',
    LessonKind.pdf => 'Lesson PDF',
    LessonKind.ebook => 'Lesson ebook',
    LessonKind.text => 'Lesson file',
  };

  String get _uploadFormats => switch (_kind) {
    LessonKind.video => 'MP4 or MOV · up to 2 GB',
    LessonKind.pdf => 'PDF · up to 200 MB',
    LessonKind.ebook => 'PDF or EPUB · up to 200 MB',
    LessonKind.text => '',
  };

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial?.id != null || widget.initial != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE3E0D8),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // `Flexible`, not `Expanded`: the sheet should hug its content and
            // only grow to the cap when the keyboard is up or a text lesson
            // needs the room. `Expanded` filled the constraint unconditionally,
            // which left a large empty band between the form and the button.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Edit lesson' : 'Add lesson',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: builderInk,
                      ),
                    ),
                    const SizedBox(height: 14),
                    LabeledTextField(
                      label: 'Lesson title',
                      hint: 'e.g. Line, shape and negative space',
                      controller: _title,
                      requiredField: true,
                    ),
                    const SizedBox(height: 14),
                    // **No content-type picker: every lesson is a video.**
                    // PDFs and documents are *resources* attached to the course
                    // (the player's Resources tab), not lectures, and there is
                    // no text or ebook lesson type in the product. The picker
                    // used to offer all four, which let an instructor create a
                    // `pdf` lesson that the app then had nowhere to play.
                    //
                    // `_kind` survives for one reason: a lesson that already
                    // exists as `pdf`/`text` on the server keeps its type when
                    // edited, rather than being silently rewritten to video.
                    LabeledTextField(
                      label: 'Duration',
                      hint: '09:30',
                      controller: _duration,
                      requiredField: true,
                      keyboardType: TextInputType.datetime,
                    ),
                    const SizedBox(height: 14),
                    if (_kind.usesBody) ...[
                      LabeledTextField(
                        label: 'Lesson text',
                        hint: 'The lesson body',
                        controller: _body,
                        requiredField: true,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Shown inline in the player.',
                        style: GoogleFonts.figtree(
                          fontSize: 11,
                          color: builderMuted,
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Text(
                            'Content',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: builderInk,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '*',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: builderDanger,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          PressableChip(
                            label: 'Upload a file',
                            selected: _source == _ContentSource.upload,
                            onTap: () =>
                                setState(() => _source = _ContentSource.upload),
                          ),
                          PressableChip(
                            label: 'Paste a link',
                            selected: _source == _ContentSource.link,
                            onTap: () =>
                                setState(() => _source = _ContentSource.link),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_source == _ContentSource.upload)
                        UploadCard(
                          title: _uploadTitle,
                          formats: _uploadFormats,
                          asset: 'assets/figma/signup_file_text.svg',
                          pickedFile: _picked,
                          onTap: _uploading ? () {} : _pickFile,
                          onClear: () => setState(() => _picked = null),
                          // A lesson is a video — see the note where the
                          // content-type picker used to be.
                          actionLabel: 'Upload Video',
                        )
                      else
                        LabeledTextField(
                          label: 'Lesson link',
                          hint: 'https://…',
                          controller: _url,
                          requiredField: true,
                          keyboardType: TextInputType.url,
                        ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Switch(
                          value: _isPreview,
                          activeThumbColor: Colors.white,
                          activeTrackColor: builderYellow,
                          onChanged: (next) =>
                              setState(() => _isPreview = next),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Free preview',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: builderInk,
                                ),
                              ),
                              Text(
                                'Anyone can watch this before enrolling',
                                style: GoogleFonts.figtree(
                                  fontSize: 10,
                                  color: builderMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _error!,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: builderDanger,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      // Disabled while the file is in flight: a second tap
                      // would upload the same bytes again and the lesson would
                      // be created twice.
                      onPressed: _uploading ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: builderYellow,
                        foregroundColor: builderInk,
                        elevation: 4,
                        shadowColor: const Color(0x40E6B800),
                        shape: const StadiumBorder(),
                        disabledBackgroundColor: builderYellow,
                        disabledForegroundColor: builderInk,
                      ),
                      child: _uploading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: builderInk,
                              ),
                            )
                          : Text(
                              'Save lesson',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  if (widget.initial != null)
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pop(const LessonDeleted()),
                      child: Text(
                        'Delete lesson',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: builderDanger,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Upload a file, or point at one that is already hosted.
enum _ContentSource { upload, link }
