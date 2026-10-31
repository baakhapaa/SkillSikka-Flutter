import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/course_cover_tile.dart';
import '../../../../core/widgets/course_image.dart';
import '../../../../core/widgets/labeled_text_field.dart';
import '../../../../core/widgets/option_picker_sheet.dart';
import '../../../../core/widgets/pressable_chip.dart';
import '../../data/course_draft.dart';
import 'builder_tokens.dart';
import 'repeatable_field.dart';

/// Step 1 — the course's identity.
///
/// Reads and writes [draft] directly rather than taking a callback per field:
/// the page owns one `ValueNotifier<CourseDraft>`, every step mutates it, and the
/// page rebuilds from it. A callback per field would be eleven parameters that
/// all do the same thing.
class CourseBasicsStep extends StatelessWidget {
  const CourseBasicsStep({
    super.key,
    required this.draft,
    required this.titleController,
    required this.descriptionController,
    required this.categoryOptions,
    required this.onEdited,
    this.subjectOptions = const [],
    this.gradeOptions = const [],
    this.pickCover,
  });

  final ValueNotifier<CourseDraft> draft;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final List<(int, String)> categoryOptions;

  /// `(id, name)` pairs. Empty until the reference lists have been fetched, and
  /// empty for good on a backend with no subjects seeded — the picker's own
  /// empty state says so.
  final List<(int, String)> subjectOptions;
  final List<(int, String)> gradeOptions;

  /// Overrides the OS image picker. Null uses [FilePicker] — see
  /// `CourseBuilderPage.pickCover` for why the seam exists.
  final Future<PickedCover?> Function()? pickCover;

  /// Called on any edit so the page can mark itself dirty for the exit guard.
  final VoidCallback onEdited;

  /// The tap target for the cover card.
  ///
  /// Public so a test can tap the card itself rather than the caption inside
  /// it: the whole 16:9 box is the button, and the caption sits *behind* that
  /// hit area — tapping the text by finder only works because the hit lands on
  /// the card underneath.
  static const coverPickerKey = ValueKey('course-cover-picker');

  void _write(CourseDraft next) {
    draft.value = next;
    onEdited();
  }

  /// The category id the draft holds for **this** course type.
  ///
  /// One field per taxonomy: a premium course is filed under
  /// [CourseDraft.premiumCategoryId], a skill course under
  /// [CourseDraft.skillCategoryId]. Reading the wrong one is always null, and
  /// the picker would print its hint over a category the instructor already
  /// chose.
  static int? _categoryId(CourseDraft draft) =>
      draft.kind.isAlwaysPaid ? draft.premiumCategoryId : draft.skillCategoryId;

  @override
  Widget build(BuildContext context) {
    final value = draft.value;
    final isAcademic = value.kind == CourseKind.academic;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Course type'),
          // **`Wrap`, not `Row`, since Premium made it three chips.** Two chips
          // fit in 360pt; three overflow by ~119pt and the third lands off
          // screen, untappable. `Wrap` keeps the same chips, the same 8pt gaps
          // and the same appearance — it only allows the third to take a second
          // line, which is the one thing a fixed `Row` cannot do. The row is
          // still built from `CourseKind.values`, so a new type appears here
          // without touching this widget.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in CourseKind.values)
                PressableChip(
                  label: kind.label,
                  selected: value.kind == kind,
                  onTap: () => _write(value.copyWith(kind: kind)),
                ),
            ],
          ),

          const SizedBox(height: 18),
          _label('Cover'),
          _CoverPicker(
            draft: value,
            onPick: () => _pickCover(context),
            onRemove: () => _write(value.copyWith(clearCover: true)),
          ),
          const SizedBox(height: 6),
          Text(
            value.cover == null && (value.coverUrl ?? '').isEmpty
                ? 'Recommended 16:9. A generated tile is used until you add one.'
                : 'This is the picture students see in the catalogue.',
            style: GoogleFonts.figtree(fontSize: 11, color: builderMuted),
          ),

          const SizedBox(height: 18),
          LabeledTextField(
            label: 'Course title',
            hint: 'e.g. Digital Illustration for Beginners',
            controller: titleController,
            requiredField: true,
            onChanged: (text) {
              _write(draft.value.copyWith(title: text));
            },
          ),

          const SizedBox(height: 16),
          if (isAcademic) ...[
            BuilderPickerField(
              label: 'Subject',
              value: _nameFor(subjectOptions, value.subjectId),
              hint: subjectOptions.isEmpty
                  ? 'No subjects available yet'
                  : 'Select subject',
              requiredField: true,
              onTap: () => _pick(
                context,
                title: 'subject',
                options: subjectOptions,
                onPicked: (id) => _write(draft.value.copyWith(subjectId: id)),
              ),
            ),
            const SizedBox(height: 16),
            BuilderPickerField(
              label: 'Grade',
              value: _nameFor(gradeOptions, value.gradeId),
              hint: gradeOptions.isEmpty
                  ? 'No grades available'
                  : 'Select grade',
              requiredField: true,
              onTap: () => _pick(
                context,
                title: 'grade',
                options: gradeOptions,
                onPicked: (id) => _write(draft.value.copyWith(gradeId: id)),
              ),
            ),
          ] else
            BuilderPickerField(
              label: 'Category',
              // The two course types carry **different ids from different
              // tables**, so the field has to read and write the one that
              // belongs to this draft. `categoryOptions` is already the premium
              // list when the type is Premium — the page swaps it.
              value: _categoryId(value) == null
                  ? value.category
                  : _nameFor(categoryOptions, _categoryId(value)!),
              hint: categoryOptions.isEmpty
                  ? 'No categories available'
                  : 'Select category',
              // Writes the id as well as the label: the server stores the id, and
              // the label is only what this field prints.
              onTap: () => _pick(
                context,
                title: 'category',
                options: categoryOptions,
                onPicked: (id) => _write(
                  value.kind.isAlwaysPaid
                      ? value.copyWith(
                          premiumCategoryId: id,
                          category: _nameFor(categoryOptions, id),
                        )
                      : value.copyWith(
                          skillCategoryId: id,
                          category: _nameFor(categoryOptions, id),
                        ),
                ),
              ),
            ),

          const SizedBox(height: 16),
          _label('Level', optional: true),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final level in CourseLevel.values)
                PressableChip(
                  label: level.label,
                  selected: value.level == level,
                  // Tapping the selected chip clears it: level is optional, and
                  // without a way back out a mis-tap is permanent.
                  onTap: () => _write(
                    value.level == level
                        ? value.copyWith(clearLevel: true)
                        : value.copyWith(level: level),
                  ),
                ),
            ],
          ),

          // The language the lessons are taught in. One value, because that is
          // what `Course.language` stores and what the detail screen prints.
          const SizedBox(height: 16),
          _label('Language'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final language in CourseDraft.languages)
                PressableChip(
                  label: language,
                  selected: value.language == language,
                  onTap: () => _write(value.copyWith(language: language)),
                ),
            ],
          ),

          const SizedBox(height: 18),
          LabeledTextField(
            label: 'Description',
            hint: 'What will a student be able to do by the end?',
            controller: descriptionController,
            maxLines: 5,
            onChanged: (text) {
              _write(draft.value.copyWith(description: text));
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Required before you publish.',
            style: GoogleFonts.figtree(fontSize: 11, color: builderMuted),
          ),

          const SizedBox(height: 18),
          RepeatableField(
            label: 'What students will learn',
            values: value.outcomes,
            addLabel: 'Add outcome',
            hint: 'One thing they will be able to do',
            onChanged: (next) => _write(draft.value.copyWith(outcomes: next)),
          ),

          const SizedBox(height: 18),
          RepeatableField(
            label: 'Requirements',
            values: value.requirements,
            addLabel: 'Add requirement',
            hint: 'A tool, or prior knowledge',
            max: 4,
            onChanged: (next) =>
                _write(draft.value.copyWith(requirements: next)),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, {bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: builderInk,
            ),
          ),
          if (optional) ...[
            const SizedBox(width: 6),
            Text(
              'optional',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: builderMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _nameFor(List<(int, String)> options, int? id) {
    if (id == null) return null;
    for (final (optionId, name) in options) {
      if (optionId == id) return name;
    }
    return null;
  }

  /// Picks a cover image and holds its bytes until the course has an id.
  ///
  /// The file is **not** uploaded here: step 1's `Continue` is what creates the
  /// course, and the upload route is scoped to a course. Picking bytes now and
  /// uploading at save is also what makes the picture appear instantly instead
  /// of after a round trip.
  Future<void> _pickCover(BuildContext context) async {
    final override = pickCover;
    if (override != null) {
      final picked = await override();
      if (picked != null) _write(draft.value.copyWith(cover: picked));
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      // Bytes, not a path: on web a picked file's path is a blob URL nothing
      // else can read, and this app ships to Flutter web.
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That image could not be read.')),
        );
      }
      return;
    }
    _write(
      draft.value.copyWith(
        cover: PickedCover(bytes: bytes, fileName: file.name),
      ),
    );
  }

  Future<void> _pick(
    BuildContext context, {
    required String title,
    required List<(int, String)> options,
    required ValueChanged<int> onPicked,
  }) async {
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No ${title}s are available yet.')),
      );
      return;
    }
    final names = [for (final (_, name) in options) name];
    final picked = await showOptionPickerSheet(
      context,
      title: 'Select $title',
      options: names,
    );
    if (picked == null) return;
    for (final (id, name) in options) {
      if (name == picked) {
        onPicked(id);
        return;
      }
    }
  }
}

/// The 16:9 cover slot.
///
/// Three states, in priority order: the file just picked, the cover the server
/// already has, and a generated tile. **The generated tile is a real answer, not
/// a placeholder** — a course with no cover still needs a card that reads as
/// content, and the initials tile is what the catalogue falls back to as well.
class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.draft,
    required this.onPick,
    required this.onRemove,
  });

  final CourseDraft draft;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  bool get _hasImage =>
      draft.cover != null || (draft.coverUrl ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _image(),
                // A scrim only over the bottom strip, so the caption stays
                // readable over a bright photo without dimming the picture.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0x99000000)],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.photo_camera_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _hasImage ? 'Change cover' : 'Add cover',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // The whole card is the tap target: a 16:9 box with a small
                // label is a large surface, and asking for precision there is
                // how a picker feels broken.
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: CourseBasicsStep.coverPickerKey,
                    onTap: onPick,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_hasImage)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 14, color: builderMuted),
              label: Text(
                'Remove cover',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: builderMuted,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
      ],
    );
  }

  Widget _image() {
    final picked = draft.cover;
    if (picked != null) {
      return Image.memory(picked.bytes, fit: BoxFit.cover);
    }
    final url = draft.coverUrl;
    if (url != null && url.trim().isNotEmpty) {
      return CourseImage(url, fit: BoxFit.cover, fallback: _generated());
    }
    return _generated();
  }

  /// The tile the catalogue will draw for this course until a cover is added.
  /// One implementation, so the preview cannot promise a different tile from
  /// the one the cards show.
  Widget _generated() => CourseCoverTile(draft.title, seed: draft.id ?? 0);
}
