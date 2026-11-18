import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/api_error_snack.dart';
import '../../../core/widgets/course_detail_view.dart'
    show CourseResource, CourseResourceType;
import '../data/course_builder_api.dart';
import '../data/course_draft.dart';
import 'widgets/course_basics_step.dart';
import 'widgets/course_curriculum_step.dart';
import 'widgets/course_publish_step.dart';
import 'widgets/lesson_editor_sheet.dart';
import 'widgets/prompt_dialog.dart';

const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _yellow = Color(0xFFE6B800);
const _pillFill = Color(0xFFFFF4CC);
const _brown = Color(0xFF2F2600);

/// The three-step course builder.
///
/// **Draft-first.** Step 1's `Continue` is what creates the course on the
/// server, so everything after it — every lesson, every edit — has a real id to
/// attach to, and an abandoned session leaves a resumable draft rather than
/// nothing. That is the one architectural rule the rest of this page follows.
///
/// **Takes its dependencies as constructor arguments** rather than reading them
/// from a `ProviderScope`. Two reasons: the page is pushed from
/// `ProfilePage`, which is deliberately a plain `StatefulWidget` (several tests
/// pump it with no scope), and a widget test can drive the whole builder with a
/// fake [CourseBuilderApi] and no provider container at all.
class CourseBuilderPage extends StatefulWidget {
  const CourseBuilderPage({
    super.key,
    required this.api,
    required this.instructorVerified,
    this.courseId,
    this.categoryOptions = const <(int, String)>[],
    this.pickCover,
    this.pickResources,
  });

  final CourseBuilderApi api;

  /// Whether the signed-in instructor may publish. Comes from `/me/`'s
  /// `verification_status`; the builder shows the gate but cannot grant it.
  final bool instructorVerified;

  /// When set, the builder resumes that draft instead of starting a new course.
  final int? courseId;

  /// Overrides the fetched category list. A test passes a fixed one; in the app
  /// this stays empty and [_categories] is used.
  final List<(int, String)> categoryOptions;

  /// Overrides the OS file picker for the cover.
  ///
  /// The same seam `LessonEditorSheet` uses for its upload: `FilePicker` talks
  /// to a platform channel that does not exist under `flutter test`, so without
  /// an injection point the whole cover path — pick, preview, upload, patch —
  /// would be unreachable by a test. Null means the real picker.
  final Future<PickedCover?> Function()? pickCover;

  /// Overrides the OS file picker for **course-wide** resources.
  ///
  /// A separate seam from [pickCover] because it answers several files, and a
  /// single `PickedCover` cannot express a pick of five worksheets. Null means
  /// the real picker.
  final Future<List<PickedFile>?> Function()? pickResources;

  @override
  State<CourseBuilderPage> createState() => _CourseBuilderPageState();
}

class _CourseBuilderPageState extends State<CourseBuilderPage> {
  final ValueNotifier<CourseDraft> _draft = ValueNotifier(const CourseDraft());
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _price = TextEditingController();

  int _step = 0;
  bool _busy = false;
  bool _loading = false;
  String? _loadError;

  /// The order last written to the server, per lesson key.
  ///
  /// Reordering is a local edit until the user leaves the curriculum; this map is
  /// what makes that push incremental — only the lessons whose position actually
  /// changed get a request.
  final Map<String, int> _syncedOrder = {};

  /// The `section` last written to the server, per lesson key.
  ///
  /// Kept separately from [_syncedOrder] because a module **rename** changes a
  /// lesson's section without changing its position. Without this, renaming
  /// "Getting Started" to "Foundations" would leave every lesson still pointing
  /// at the old name and the modules would split on the next reload.
  final Map<String, String?> _syncedSection = {};

  /// Bumped whenever the user edits anything, so the exit guard can tell a
  /// deliberate empty form from one they typed into.
  bool _dirty = false;

  /// The cover that has already been uploaded, by identity.
  ///
  /// Compared with `identical` rather than by bytes: re-uploading the same
  /// picture on every save would spend a mobile connection on nothing, and a
  /// byte comparison over a multi-megabyte image on each save is worse than the
  /// reference check it replaces. The draft's `copyWith` carries the same
  /// instance through, so the reference survives edits to other fields.
  PickedCover? _uploadedCover;

  /// The course's **own** files — the ones that belong to no lesson.
  ///
  /// The player's Resources tab shows a file on every lesson when its `lesson`
  /// is null, so this is the course-wide pack: a syllabus, a reading list, a
  /// starter repository. Per-lesson files are attached in the lesson sheet and
  /// are deliberately not listed here — one row would then appear twice.
  List<CourseResource> _courseResources = const [];
  bool _resourcesLoading = false;
  bool _resourcesUploading = false;

  /// Reference lists for an academic course, fetched the first time the user
  /// switches the type. Loading them at open would cost two requests for a path
  /// most courses never take.
  List<(int, String)> _subjects = const [];
  List<(int, String)> _grades = const [];
  List<(int, String)> _categories = const [];

  /// The **premium** categories — a different table from [_categories].
  List<(int, String)> _premiumCategories = const [];
  bool _referenceLoaded = false;
  bool _categoriesLoaded = false;
  bool _premiumCategoriesLoaded = false;

  @override
  void initState() {
    super.initState();
    _draft.addListener(_onDraftChanged);
    if (widget.courseId != null) {
      _load(widget.courseId!);
    }
  }

  @override
  void dispose() {
    _draft.removeListener(_onDraftChanged);
    _draft.dispose();
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  /// Loads whichever reference list the selected course type needs.
  ///
  /// The three are mutually exclusive: an academic course needs subject + grade,
  /// a skill course the skill categories, a premium course **its own**
  /// categories. Loading more than one would cost a request for a list the
  /// picker is not showing — and premium's list is a different table, not a
  /// subset, so the wrong one is not merely wasteful: it files the course in a
  /// taxonomy its catalogue does not read.
  void _onDraftChanged() {
    final kind = _draft.value.kind;
    if (kind == CourseKind.academic && !_referenceLoaded) {
      _referenceLoaded = true;
      _loadReference();
      return;
    }
    if (kind.isAlwaysPaid) {
      if (!_premiumCategoriesLoaded) {
        _premiumCategoriesLoaded = true;
        _loadPremiumCategories();
      }
      return;
    }
    if (kind.isSkillLike && !_categoriesLoaded) {
      _categoriesLoaded = true;
      _loadCategories();
    }
  }

  Future<void> _loadReference() async {
    try {
      final subjects = await widget.api.loadSubjects();
      final grades = await widget.api.loadGrades();
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
        _grades = grades;
      });
    } on ApiException {
      // The pickers keep their empty state. An academic course cannot be saved
      // without both anyway, and the server says so on save — failing loudly
      // here would interrupt a user who is still filling in the title.
      _referenceLoaded = false;
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await widget.api.loadCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
    } on ApiException {
      // Same reasoning as above: the picker shows "No categories available" and
      // the course still saves, just without one.
      _categoriesLoaded = false;
    }
  }

  /// The premium list. A separate request because it is a separate table — see
  /// `CourseBuilderApi.loadPremiumCategories`.
  Future<void> _loadPremiumCategories() async {
    try {
      final categories = await widget.api.loadPremiumCategories();
      if (!mounted) return;
      setState(() => _premiumCategories = categories);
    } on ApiException {
      // Same as the skill list: an empty picker beats a blocked step, and the
      // publish gate still refuses to publish without a category.
      _premiumCategoriesLoaded = false;
    }
  }

  Future<void> _load(int courseId) async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final loaded = await widget.api.loadCourse(courseId);
      if (!mounted) return;
      if (loaded == null) {
        setState(() {
          _loading = false;
          _loadError = 'That course is not available.';
        });
        return;
      }
      _adopt(loaded);
      setState(() => _loading = false);
      // After the draft, not before: the resources request is the one that can
      // fail without the course being unusable, and a slow one must not hold up
      // the form the instructor came here to edit.
      unawaited(_loadResources(courseId));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.displayMessage;
      });
    }
  }

  /// `GET /courses/{id}/resources/`, narrowed to the course-wide rows.
  ///
  /// Silent on failure, like the profile grid's course fetch: the builder is
  /// perfectly usable without this list, and a course with no files is the
  /// normal case. A second visit retries.
  ///
  /// **Only `lesson == null` rows.** Per-lesson files belong to the lesson
  /// sheet; listing them here would show one file in two places and let the
  /// instructor delete a lesson's worksheet from a screen that never mentions
  /// the lesson.
  Future<void> _loadResources(int courseId) async {
    if (_resourcesLoading) return;
    setState(() => _resourcesLoading = true);
    try {
      final resources = await widget.api.listResources(courseId);
      if (!mounted) return;
      setState(() {
        _courseResources = [
          for (final resource in resources)
            if (resource.lessonId == null) resource,
        ];
        _resourcesLoading = false;
      });
    } on ApiException {
      if (mounted) setState(() => _resourcesLoading = false);
    }
  }

  /// Picks files, uploads them **in one request**, then writes one row each.
  ///
  /// Upload first, row second — the same order the lesson sheet uses, and for
  /// the same reason: a row needs a URL, and a URL only exists once the bytes
  /// have landed. A file the server refused gets no row, and the message counts
  /// the refusals rather than pretending the whole pick failed.
  Future<void> _addCourseResources() async {
    final courseId = _draft.value.id;
    if (courseId == null) {
      _snack('Save the course details first.');
      return;
    }
    final pick = widget.pickResources ?? pickResourceFiles;
    final picked = await pick();
    if (picked == null || picked.isEmpty || !mounted) return;

    setState(() => _resourcesUploading = true);
    try {
      final urls = await widget.api.uploadCourseAssets(
        courseId: courseId,
        kind: 'resource',
        files: picked,
      );
      final added = <CourseResource>[];
      for (var index = 0; index < picked.length; index++) {
        final url = index < urls.length ? urls[index] : null;
        if (url == null) continue;
        final file = picked[index];
        final id = await widget.api.createResource(
          courseId: courseId,
          title: file.fileName,
          fileUrl: url,
          fileFormat: resourceFormatOf(file.fileName),
          order: _courseResources.length + added.length,
        );
        added.add(
          CourseResource(
            file.fileName,
            CourseResourceType.fromFormat(resourceFormatOf(file.fileName)),
            id: id,
            url: url,
          ),
        );
      }
      if (!mounted) return;
      setState(() => _courseResources = [..._courseResources, ...added]);
      if (added.length < picked.length) {
        _snack(
          added.isEmpty
              ? 'Those files were not accepted.'
              : '${picked.length - added.length} of ${picked.length} files '
                    'were not accepted.',
        );
      }
    } on ApiException catch (error) {
      if (mounted) showApiErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _resourcesUploading = false);
    }
  }

  /// Deletes one course-wide file, row and all.
  ///
  /// The row goes first in the UI only after the server agrees: removing it
  /// locally on a failed DELETE would leave a file the instructor believes they
  /// deleted still showing to every student.
  Future<void> _removeCourseResource(CourseResource resource) async {
    final courseId = _draft.value.id;
    final resourceId = resource.id;
    if (courseId == null || resourceId == null) return;

    setState(() => _resourcesUploading = true);
    try {
      await widget.api.deleteResource(
        courseId: courseId,
        resourceId: resourceId,
      );
      if (!mounted) return;
      setState(() {
        _courseResources = [
          for (final row in _courseResources)
            if (row.id != resourceId) row,
        ];
      });
    } on ApiException catch (error) {
      if (mounted) showApiErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _resourcesUploading = false);
    }
  }

  void _adopt(CourseDraft draft) {
    _draft.value = draft;
    _title.text = draft.title;
    _description.text = draft.description;
    _price.text = draft.price;
    // Global order, not per-module index: `order` is one sequence across the
    // whole course, so a lesson in the second module starts after the first
    // module's count. Seeding it per-module would make the first save re-push
    // every lesson in every module but the first.
    var order = 0;
    for (final module in draft.modules) {
      final section = _sectionTitle(module);
      for (final lesson in module.lessons) {
        order += 1;
        _syncedOrder[lesson.key] = order;
        _syncedSection[lesson.key] = section;
      }
    }
  }

  /// The `section` string for a module, or null when it has no name.
  ///
  /// An unnamed module is not persisted as a section — the server treats null and
  /// `''` the same, and a blank section would collide with every other blank one.
  static String? _sectionTitle(CourseModule module) {
    final title = module.title.trim();
    return title.isEmpty ? null : title;
  }

  /// Looks the module up by key, because the lesson call sites only carry the key.
  String? _sectionOf(String moduleKey) {
    for (final module in _draft.value.modules) {
      if (module.key == moduleKey) return _sectionTitle(module);
    }
    return null;
  }

  // ── navigation ────────────────────────────────────────────────────────────

  Future<void> _handleBack() async {
    if (_step > 0) {
      setState(() => _step -= 1);
      return;
    }
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await _confirmDiscard();
    if (discard == true && mounted) {
      await _discardDraft();
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// The header's ⋯ — the two things an instructor can do to the course they
  /// are editing without leaving it.
  ///
  /// **No "Publish" here**, for the reason the grid's menu has none: publishing
  /// is gated on the six readiness checks, and this menu cannot evaluate them.
  /// Taking a course *down* needs no gate, which is why that direction is here.
  Widget _courseMenu() {
    return PopupMenuButton<_CourseAction>(
      tooltip: 'Course actions',
      iconSize: 18,
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_horiz, color: _ink),
      onSelected: (action) {
        switch (action) {
          case _CourseAction.unpublish:
            _unpublishCourse();
          case _CourseAction.delete:
            _deleteCourse();
        }
      },
      itemBuilder: (_) => [
        if (_draft.value.isPublished)
          PopupMenuItem(
            value: _CourseAction.unpublish,
            child: Text(
              'Unpublish',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
        PopupMenuItem(
          value: _CourseAction.delete,
          child: Text(
            'Delete course',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFEF4444),
            ),
          ),
        ),
      ],
    );
  }

  /// `PATCH /courses/{id}/ {"is_published": false}` — back to a draft.
  ///
  /// Reversible, so it asks nothing: the course keeps its lessons, its files and
  /// its enrolments, and students simply stop seeing it. Re-publishing goes
  /// through the checklist at step 3 again.
  Future<void> _unpublishCourse() async {
    final id = _draft.value.id;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await widget.api.unpublishCourse(id);
      if (!mounted) return;
      _draft.value = _draft.value.copyWith(isPublished: false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unpublished. Students can no longer see this course.'),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.displayMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// `DELETE /courses/{id}/` — irreversible, so it names the course and says
  /// what goes with it. A generic "Delete this course?" is what makes people
  /// delete the wrong one.
  Future<void> _deleteCourse() async {
    final id = _draft.value.id;
    if (id == null) return;
    final title = _draft.value.title.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Delete “${title.isEmpty ? 'this course' : title}”?',
          style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'The course, its lessons and its files are removed, and every '
          'enrolled student loses access. This cannot be undone.',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _gray,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Keep it',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _gray,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.api.deleteCourse(id);
      if (!mounted) return;
      // The course is gone, so this screen has nothing left to edit. `true` is
      // what the profile grid's push already expects back.
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.displayMessage)));
    }
  }

  Future<bool?> _confirmDiscard() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Discard this draft?',
        style: GoogleFonts.manrope(fontSize: 19, fontWeight: FontWeight.w800),
      ),
      content: Text(
        _draft.value.lessonCount == 0
            ? 'This course has not been published and will be deleted.'
            : 'This course and its ${_draft.value.lessonCount} '
                  '${_draft.value.lessonCount == 1 ? 'lesson' : 'lessons'} '
                  'will be deleted.',
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _gray,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Keep editing',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _gray,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'Discard',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFEF4444),
            ),
          ),
        ),
      ],
    ),
  );

  /// Best-effort delete of the server-side draft.
  ///
  /// Failure is deliberately ignored: the user asked to discard, and holding
  /// them on the screen because a DELETE failed would be worse than leaving an
  /// empty draft behind.
  Future<void> _discardDraft() async {
    final id = _draft.value.id;
    if (id == null) return;
    try {
      await widget.api.deleteCourse(id);
    } on ApiException {
      // Intentionally swallowed — see the doc above.
    }
  }

  // ── saving ────────────────────────────────────────────────────────────────

  /// Creates the course on the first call and patches it afterwards.
  ///
  /// Returns false when the write failed, so callers can stay on the current
  /// step instead of advancing with a draft that was never saved.
  Future<bool> _saveDraft() async {
    setState(() => _busy = true);
    try {
      return await _persist(_draft.value);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The one write path: create or patch, then upload a pending cover.
  ///
  /// Shared by [ _continue ] and [_publish] deliberately. Publishing used to
  /// call `updateCourse` on its own, which meant a course published straight
  /// from step 3 could skip the cover upload entirely and go live with a
  /// picture that only existed on the instructor's phone.
  ///
  /// **A failed cover upload does not fail the save.** The course metadata is
  /// already written by then, and holding the user on step 1 for a picture —
  /// with every field intact but nothing saved — is worse than saving the text
  /// and naming the one thing that did not go up. The bytes stay in the draft,
  /// so the next save retries automatically.
  Future<bool> _persist(CourseDraft draft) async {
    int courseId;
    try {
      final id = draft.id;
      if (id == null) {
        courseId = await widget.api.createCourse(draft);
        draft = draft.copyWith(id: courseId);
        _draft.value = draft;
      } else {
        courseId = id;
        await widget.api.updateCourse(courseId, draft);
      }
    } on ApiException catch (error) {
      if (mounted) showApiErrorSnack(context, error);
      return false;
    }

    final pending = draft.cover;
    if (pending != null && !identical(pending, _uploadedCover)) {
      try {
        final url = await widget.api.uploadCover(
          courseId: courseId,
          bytes: pending.bytes,
          fileName: pending.fileName,
        );
        _uploadedCover = pending;
        draft = draft.copyWith(coverUrl: url);
        _draft.value = draft;
        await widget.api.updateCourse(courseId, draft);
      } on ApiException catch (error) {
        if (!mounted) return true;
        _snack(
          'Your course is saved, but the cover did not upload. '
          '${error.displayMessage}',
        );
      }
    }

    _dirty = false;
    return true;
  }

  Future<void> _continue() async {
    if (_step == 0) {
      if (_draft.value.title.trim().isEmpty) {
        _snack('Give your course a title before continuing.');
        return;
      }
      if (!await _saveDraft()) return;
      if (!mounted) return;
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      // Order is the only curriculum property the server stores, so this is the
      // moment a reorder becomes permanent — before the publish step, which
      // reads the curriculum back.
      await _syncOrders();
      if (!mounted) return;
      setState(() => _step = 2);
    }
  }

  Future<void> _publish() async {
    final readiness = PublishReadiness.of(
      _draft.value,
      instructorVerified: widget.instructorVerified,
    );
    if (!readiness.canPublish) return;

    final id = _draft.value.id;
    if (id == null) return;

    setState(() => _busy = true);
    try {
      // The metadata and the cover, through the same path a draft save takes —
      // then the curriculum order, then the one call that flips publication.
      if (!await _persist(_draft.value)) return;
      await _syncOrders();
      await widget.api.publishCourse(id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      // A 403 here is the verification gate, not a validation problem — say so
      // rather than showing "check the highlighted fields" over a form with
      // nothing highlighted.
      if (error.statusCode == 403) {
        _snack(
          'Publishing needs a verified instructor account. Your course is saved '
          'as a draft.',
        );
      } else {
        showApiErrorSnack(context, error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAndClose() async {
    if (await _saveDraft()) {
      if (!mounted) return;
      Navigator.of(context).pop(false);
    }
  }

  /// Pushes any lesson whose position **or section** changed since the last sync.
  ///
  /// The section half is what makes a module rename stick: the name lives on
  /// every lesson, not on a module row, so renaming a module has to rewrite each
  /// of its lessons or the old name survives on the server.
  Future<void> _syncOrders() async {
    final draft = _draft.value;
    var order = 0;
    final pending = <(CourseLesson, int, String?)>[];
    for (final module in draft.modules) {
      final section = _sectionTitle(module);
      for (final lesson in module.lessons) {
        order += 1;
        if (lesson.id == null) continue;
        final moved = _syncedOrder[lesson.key] != order;
        final regrouped = _syncedSection[lesson.key] != section;
        if (!moved && !regrouped) continue;
        pending.add((lesson, order, section));
      }
    }
    if (pending.isEmpty) return;

    for (final (lesson, position, section) in pending) {
      try {
        await widget.api.updateLesson(
          lesson: lesson,
          order: position,
          section: section,
        );
        _syncedOrder[lesson.key] = position;
        _syncedSection[lesson.key] = section;
      } on ApiException catch (error) {
        // One failure stops the sweep: the remaining orders are relative to this
        // one, so continuing would leave the sequence half-written.
        if (mounted) showApiErrorSnack(context, error);
        return;
      }
    }
  }

  // ── curriculum mutations ──────────────────────────────────────────────────

  /// The order a lesson would take if appended to [moduleKey].
  int _appendOrder(String moduleKey) {
    var order = 0;
    for (final module in _draft.value.modules) {
      for (final _ in module.lessons) {
        order += 1;
      }
      if (module.key == moduleKey) return order + 1;
    }
    return order + 1;
  }

  /// Adding a module asks for its name first.
  ///
  /// It used to create "New module" and leave renaming to the ⋯ menu, which
  /// meant every course started with a placeholder nobody had chosen — and the
  /// first thing an instructor did was rename it anyway.
  ///
  /// **The name must be unique**, and that is not cosmetic: a module exists on
  /// the server only as the `section` string its lessons carry, so two modules
  /// called "Foundations" reload as one. The instructor would then lose a
  /// divider they had drawn, with nothing on screen explaining it.
  Future<void> _addModule() async {
    final title = await PromptDialog.show(
      context,
      title: 'Name this module',
      hint: 'e.g. Getting Started',
      maxLength: 80,
      confirmLabel: 'Add',
    );
    if (title == null || !mounted) return;

    if (_draft.value.hasModuleTitle(title)) {
      _snack('There is already a module called “$title”. Pick another name.');
      return;
    }

    final modules = [..._draft.value.modules];
    modules.add(
      CourseModule(
        key: 'module-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
      ),
    );
    _write(_draft.value.copyWith(modules: modules));
  }

  /// Renames a module, refusing a name another module already has.
  ///
  /// Silently allowing the duplicate is what makes a curriculum quietly lose a
  /// divider on the next load — see [_addModule]. Renaming a module to its own
  /// current name stays allowed, which is what [exceptKey] is for.
  void _renameModule(String moduleKey, String title) {
    if (_draft.value.hasModuleTitle(title, exceptKey: moduleKey)) {
      _snack('There is already a module called “$title”. Pick another name.');
      return;
    }
    final modules = [
      for (final module in _draft.value.modules)
        module.key == moduleKey ? module.copyWith(title: title) : module,
    ];
    _write(_draft.value.copyWith(modules: modules));
  }

  void _deleteModule(String moduleKey) {
    // The lessons inside it are real rows on the server, so dropping the module
    // locally would orphan them: they would keep their `order` and reappear in
    // the flat list the next time the course is loaded.
    CourseModule? doomed;
    for (final module in _draft.value.modules) {
      if (module.key == moduleKey) doomed = module;
    }
    final modules = [
      for (final module in _draft.value.modules)
        if (module.key != moduleKey) module,
    ];
    _write(_draft.value.copyWith(modules: modules));
    for (final lesson in doomed?.lessons ?? const <CourseLesson>[]) {
      _deleteLessonRemotely(lesson);
    }
  }

  Future<void> _deleteLessonRemotely(CourseLesson lesson) async {
    final id = lesson.id;
    _syncedOrder.remove(lesson.key);
    _syncedSection.remove(lesson.key);
    if (id == null) return;
    try {
      await widget.api.deleteLesson(id);
    } on ApiException catch (error) {
      if (mounted) showApiErrorSnack(context, error);
    }
  }

  Future<void> _addLesson(String moduleKey) async {
    // Checked *before* the sheet opens, not after: the sheet uploads a file
    // against the course, so it needs the id while it is still open.
    final id = _draft.value.id;
    if (id == null) {
      _snack('Save the course details first.');
      return;
    }

    final result = await LessonEditorSheet.show(
      context,
      onUpload: (bytes, fileName) => widget.api.uploadLessonAsset(
        courseId: id,
        bytes: bytes,
        fileName: fileName,
      ),
      onUploadResources: (files) => widget.api.uploadCourseAssets(
        courseId: id,
        kind: 'resource',
        files: files,
      ),
    );
    if (result is! LessonSaved || !mounted) return;
    final lesson = result.lesson;

    setState(() => _busy = true);
    try {
      final order = _appendOrder(moduleKey);
      final section = _sectionOf(moduleKey);
      final created = await widget.api.createLesson(
        courseId: id,
        lesson: lesson,
        order: order,
        section: section,
      );
      _syncedOrder[lesson.key] = order;
      _syncedSection[lesson.key] = section;
      _replaceLessons(moduleKey, (lessons) {
        return [...lessons, lesson.copyWith(id: created)];
      });
      await _attachResources(
        courseId: id,
        lessonId: created,
        resources: result.resources,
      );
    } on ApiException catch (error) {
      if (mounted) showApiErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Creates the resource rows for the files the sheet already uploaded.
  ///
  /// **After the lesson exists, never before** — a row needs `lesson` and the id
  /// is minted by the `POST /lessons/` above. The upload itself happened on pick
  /// inside the sheet, so a failure here is a row that did not save, not bytes
  /// that did not travel: the lesson is kept either way and the message says so.
  Future<void> _attachResources({
    required int courseId,
    required int lessonId,
    required List<PendingResource> resources,
  }) async {
    if (resources.isEmpty) return;
    var failed = 0;
    for (var index = 0; index < resources.length; index++) {
      final resource = resources[index];
      try {
        await widget.api.createResource(
          courseId: courseId,
          lessonId: lessonId,
          title: resource.title,
          fileUrl: resource.url,
          fileFormat: resource.format,
          sizeBytes: resource.sizeBytes,
          order: index,
        );
      } on Object {
        failed++;
      }
    }
    if (failed > 0 && mounted) {
      _snack(
        failed == resources.length
            ? 'The lesson saved, but its files did not.'
            : 'The lesson saved; $failed of ${resources.length} files did not.',
      );
    }
  }

  Future<void> _editLesson(String moduleKey, CourseLesson lesson) async {
    final courseId = _draft.value.id;
    if (courseId == null) {
      _snack('Save the course details first.');
      return;
    }

    final result = await LessonEditorSheet.show(
      context,
      initial: lesson,
      onUpload: (bytes, fileName) => widget.api.uploadLessonAsset(
        courseId: courseId,
        bytes: bytes,
        fileName: fileName,
      ),
      onUploadResources: (files) => widget.api.uploadCourseAssets(
        courseId: courseId,
        kind: 'resource',
        files: files,
      ),
    );
    if (result == null || !mounted) return;

    if (result is LessonDeleted) {
      await _deleteLesson(moduleKey, lesson);
      return;
    }

    final edited = (result as LessonSaved).lesson;

    if (edited.id == null) {
      _replaceLessons(
        moduleKey,
        (lessons) => [
          for (final row in lessons) row.key == lesson.key ? edited : row,
        ],
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final order = _syncedOrder[lesson.key] ?? _appendOrder(moduleKey);
      final section = _sectionOf(moduleKey);
      await widget.api.updateLesson(
        lesson: edited,
        order: order,
        section: section,
      );
      _syncedOrder[lesson.key] = order;
      _syncedSection[lesson.key] = section;
      _replaceLessons(
        moduleKey,
        (lessons) => [
          for (final row in lessons) row.key == lesson.key ? edited : row,
        ],
      );
      await _attachResources(
        courseId: courseId,
        lessonId: edited.id!,
        resources: result.resources,
      );
    } on ApiException catch (error) {
      if (mounted) showApiErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteLesson(String moduleKey, CourseLesson lesson) async {
    _replaceLessons(
      moduleKey,
      (lessons) => [
        for (final row in lessons)
          if (row.key != lesson.key) row,
      ],
    );
    await _deleteLessonRemotely(lesson);
  }

  void _replaceLessons(
    String moduleKey,
    List<CourseLesson> Function(List<CourseLesson>) update,
  ) {
    final modules = [
      for (final module in _draft.value.modules)
        module.key == moduleKey
            ? module.copyWith(lessons: update(module.lessons))
            : module,
    ];
    _write(_draft.value.copyWith(modules: modules));
  }

  /// `onReorderItem` hands over a **already-adjusted** index, so neither of these
  /// does the classic `if (newIndex > oldIndex) newIndex -= 1` — doing it twice
  /// moves the item one slot too far, and only when dragging downwards.
  void _reorderModules(int oldIndex, int newIndex) {
    final modules = [..._draft.value.modules];
    modules.insert(newIndex, modules.removeAt(oldIndex));
    _write(_draft.value.copyWith(modules: modules));
  }

  void _reorderLessons(String moduleKey, int oldIndex, int newIndex) {
    _replaceLessons(moduleKey, (lessons) {
      final next = [...lessons];
      next.insert(newIndex, next.removeAt(oldIndex));
      return next;
    });
  }

  void _write(CourseDraft next) {
    _draft.value = next;
    _dirty = true;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: PopScope(
        // The builder owns back: inside the wizard it steps back, and on step 1
        // it asks before throwing away a draft. Letting the route pop would skip
        // both.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack();
        },
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                step: _step,
                title: _headerTitle(_draft.value),
                onBack: _busy ? null : _handleBack,
                // Only once the course exists: a brand-new draft has nothing to
                // take down or delete until step 1 has saved it.
                trailing: _draft.value.id == null ? null : _courseMenu(),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: _yellow,
                          ),
                        ),
                      )
                    : _loadError != null
                    ? _LoadFailure(
                        message: _loadError!,
                        onRetry: () => _load(widget.courseId!),
                      )
                    : ValueListenableBuilder<CourseDraft>(
                        valueListenable: _draft,
                        builder: (context, draft, _) => _stepBody(draft),
                      ),
              ),
              if (!_loading && _loadError == null)
                ValueListenableBuilder<CourseDraft>(
                  valueListenable: _draft,
                  builder: (context, draft, _) => _bottomBar(draft),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// What the header calls this screen.
  ///
  /// A resumed draft is not a new course, and calling it one makes the instructor
  /// wonder whether they opened the right thing. The title itself is the best
  /// answer once there is one — it is the only thing that distinguishes two
  /// drafts in a grid of them.
  String _headerTitle(CourseDraft draft) {
    final title = draft.title.trim();
    if (title.isNotEmpty) return title;
    return widget.courseId == null ? 'New course' : 'Edit course';
  }

  Widget _stepBody(CourseDraft draft) {
    switch (_step) {
      case 1:
        return CourseCurriculumStep(
          draft: _draft,
          onAddModule: _addModule,
          onRenameModule: _renameModule,
          onDeleteModule: _deleteModule,
          onAddLesson: _addLesson,
          onEditLesson: _editLesson,
          onDeleteLesson: _deleteLesson,
          onReorderModules: _reorderModules,
          onReorderLessons: _reorderLessons,
        );
      case 2:
        return CoursePublishStep(
          draft: _draft,
          instructorVerified: widget.instructorVerified,
          priceController: _price,
          onEditStep: (step) => setState(() => _step = step),
          onEdited: () => _dirty = true,
          resources: _courseResources,
          resourcesLoading: _resourcesLoading,
          resourcesUploading: _resourcesUploading,
          onAddResources: _addCourseResources,
          onRemoveResource: _removeCourseResource,
        );
      default:
        return CourseBasicsStep(
          draft: _draft,
          titleController: _title,
          descriptionController: _description,
          categoryOptions: widget.categoryOptions.isNotEmpty
              ? widget.categoryOptions
              : (_draft.value.kind.isAlwaysPaid
                    ? _premiumCategories
                    : _categories),
          subjectOptions: _subjects,
          gradeOptions: _grades,
          pickCover: widget.pickCover,
          onEdited: () => _dirty = true,
        );
    }
  }

  Widget _bottomBar(CourseDraft draft) {
    final readiness = PublishReadiness.of(
      draft,
      instructorVerified: widget.instructorVerified,
    );

    if (_step < 2) {
      return _BottomBar(
        child: _PrimaryButton(
          label: _busy ? 'Saving…' : 'Continue',
          onPressed: _busy ? null : _continue,
        ),
      );
    }

    return _BottomBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PrimaryButton(
            label: _busy ? 'Publishing…' : 'Publish course',
            // Gold at reduced opacity rather than a grey the app never uses —
            // the checklist above the button is what explains the state.
            onPressed: _busy || !readiness.canPublish ? null : _publish,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _busy ? null : _saveAndClose,
              style: OutlinedButton.styleFrom(
                foregroundColor: _ink,
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                shape: const StadiumBorder(),
              ),
              child: Text(
                'Save as draft',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.step,
    required this.title,
    required this.onBack,
    this.trailing,
  });

  final int step;
  final String title;
  final VoidCallback? onBack;

  /// The course-actions menu, when the course exists. Null on a first draft.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                onPressed: onBack,
                padding: EdgeInsets.zero,
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                color: _ink,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  shape: const CircleBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _pillFill,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'Step ${step + 1} of 3',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _brown,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 4), trailing!],
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
    ),
    child: child,
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: _yellow,
            foregroundColor: _ink,
            elevation: 4,
            shadowColor: const Color(0x40E6B800),
            shape: const StadiumBorder(),
            disabledBackgroundColor: _yellow,
            disabledForegroundColor: _ink,
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(fontSize: 14, color: _gray, height: 1.5),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Try again',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _yellow,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The two course-level actions in the header's ⋯.
///
/// A closed set on purpose: publishing is not one of them — it is gated on the
/// six readiness checks and belongs to step 3's button.
enum _CourseAction { unpublish, delete }
