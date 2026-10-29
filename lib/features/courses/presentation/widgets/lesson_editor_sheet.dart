import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/network/api_error.dart';
// Only the row style: this file's `CourseLesson` is the builder's draft type,
// and `course_detail_view.dart` exports a different class of the same name.
import '../../../../core/widgets/course_detail_view.dart'
    show CourseResourceType;
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

/// One file the instructor attached while editing the lesson.
///
/// **Already uploaded by the time the sheet closes.** The bytes go out on pick,
/// not on save, so a failed upload is reported against the file the user chose
/// rather than as a dead sheet. What the builder still has to do is create the
/// resource row, because a row needs the lesson id and the lesson does not exist
/// until `POST /lessons/` answers.
class PendingResource {
  const PendingResource({
    required this.title,
    required this.url,
    required this.format,
    this.sizeBytes,
  });

  final String title;
  final String url;

  /// The server's `file_format` vocabulary: `pdf`, `docx`, `xlsx`, `zip`, …
  final String format;

  final int? sizeBytes;
}

class LessonSaved extends LessonSheetResult {
  const LessonSaved(this.lesson, {this.resources = const <PendingResource>[]});

  final CourseLesson lesson;

  /// Files to attach to the lesson once it has an id. Empty on most lessons.
  final List<PendingResource> resources;
}

class LessonDeleted extends LessonSheetResult {
  const LessonDeleted();
}

/// Add / edit one lesson.
class LessonEditorSheet extends StatefulWidget {
  const LessonEditorSheet({
    super.key,
    this.initial,
    required this.onUpload,
    this.onUploadResource,
  });

  final CourseLesson? initial;

  /// Uploads a picked file and answers the URL to store on the lesson.
  ///
  /// Injected rather than reached for through a provider: the sheet is also
  /// pumped bare by tests, and the one thing it needs from the network is this
  /// call. It throws [ApiException] on failure, which the sheet turns into an
  /// inline message instead of closing over a lost lesson.
  final Future<String> Function(Uint8List bytes, String fileName) onUpload;

  /// Uploads one **resource** file — the same route with `kind=resource`, which
  /// is why it is a second callback rather than a second API client. Null hides
  /// the attach block, which is what a caller with no course id gets.
  final Future<String> Function(Uint8List bytes, String fileName)?
  onUploadResource;

  /// Opens the sheet and returns what the user did, or null for a dismissal.
  static Future<LessonSheetResult?> show(
    BuildContext context, {
    CourseLesson? initial,
    required Future<String> Function(Uint8List bytes, String fileName) onUpload,
    Future<String> Function(Uint8List bytes, String fileName)? onUploadResource,
  }) {
    return showModalBottomSheet<LessonSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => LessonEditorSheet(
        initial: initial,
        onUpload: onUpload,
        onUploadResource: onUploadResource,
      ),
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

  /// Files attached to this lesson, already uploaded and waiting for the lesson
  /// row to exist. See [PendingResource].
  final List<PendingResource> _attachments = <PendingResource>[];
  bool _uploadingResource = false;

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
    Navigator.of(context).pop(
      LessonSaved(
        lesson,
        resources: List<PendingResource>.unmodifiable(_attachments),
      ),
    );
  }

  /// The **Attach resources** block.
  ///
  /// Files here belong to *this lesson* — the player's Resources tab shows them
  /// while the lesson is selected. They are not lectures, so they never appear
  /// in the curriculum, which is the distinction that made a `pdf` lesson type a
  /// mistake in the first place.
  Widget _buildAttachments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Resources',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: builderInk,
                ),
              ),
            ),
            TextButton(
              onPressed: _uploadingResource ? null : _pickResources,
              child: _uploadingResource
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: builderInk,
                      ),
                    )
                  : Text(
                      _attachments.isEmpty ? 'Attach files' : 'Add more',
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: builderInk,
                      ),
                    ),
            ),
          ],
        ),
        if (_attachments.isEmpty)
          Text(
            'Optional. Worksheets, templates or starter files shown on this '
            'lesson’s Resources tab.',
            style: GoogleFonts.figtree(fontSize: 11, color: builderMuted),
          )
        else
          for (final attachment in _attachments)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F6F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      CourseResourceType.fromFormat(attachment.format).icon,
                      size: 18,
                      color: CourseResourceType.fromFormat(
                        attachment.format,
                      ).color,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        attachment.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.figtree(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: builderInk,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          setState(() => _attachments.remove(attachment)),
                      icon: const Icon(Icons.close, size: 16),
                      color: builderMuted,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Remove',
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  /// Turns an upload failure into something the user can act on.
  ///
  /// **A 404 is no longer the expected case.** `POST /courses/{id}/assets/`
  /// shipped on 2026-10-28, so a missing route here now means the course itself
  /// is gone — not that uploads do not exist. The old message told the user to
  /// paste a link, which was true then and would send them the long way round
  /// now.
  String _uploadMessage(ApiException error) {
    if (error.statusCode == 404) {
      return 'That course could not be found. Reload and try again.';
    }
    if (error.statusCode == 413) {
      return 'That file is too large for the server.';
    }
    // 400 is the asset route's "that content type is not accepted" — its own
    // detail names the type, so it is better than anything generic here.
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

  /// What `kind=resource` accepts on the server
  /// (`CourseAssetUploadAPIView.RESOURCE_TYPES`). Kept in step with it rather
  /// than wider: a file the picker offers and the server refuses is a worse
  /// error than one the picker never showed.
  static const _resourceExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'zip',
    'csv',
    'png',
    'jpg',
    'jpeg',
    'svg',
  ];

  /// Uploads every picked resource, keeping the ones that succeeded.
  ///
  /// **One failure does not discard the rest.** A batch of five files where the
  /// fourth is over the cap should leave four attached and say so, not make the
  /// instructor pick all five again.
  Future<void> _pickResources() async {
    final upload = widget.onUploadResource;
    if (upload == null || _uploadingResource) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _resourceExtensions,
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _uploadingResource = true;
      _error = null;
    });
    final added = <PendingResource>[];
    String? failure;
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) {
        failure = '${file.name} could not be read.';
        continue;
      }
      try {
        final url = await upload(bytes, file.name);
        added.add(
          PendingResource(
            title: file.name,
            url: url,
            format: _formatOf(file.name),
            sizeBytes: file.size,
          ),
        );
      } on ApiException catch (error) {
        failure = '${file.name}: ${_uploadMessage(error)}';
      } on Object {
        failure = '${file.name} did not upload.';
      }
    }
    if (!mounted) return;
    setState(() {
      _uploadingResource = false;
      _attachments.addAll(added);
      if (failure != null) _error = failure;
    });
  }

  /// The server's `file_format` vocabulary, from the file name.
  ///
  /// The picker filters to the same list, so this only ever sees known
  /// extensions; `other` is the honest fallback rather than a crash.
  String _formatOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return 'other';
    final extension = fileName.substring(dot + 1).toLowerCase();
    return extension == 'jpeg' ? 'jpg' : extension;
  }

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
                    if (widget.onUploadResource != null) ...[
                      const SizedBox(height: 16),
                      _buildAttachments(),
                    ],
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
