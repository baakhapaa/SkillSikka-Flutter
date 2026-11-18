import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/course_draft.dart';
import 'builder_tokens.dart';
import 'prompt_dialog.dart';

/// Step 2 — modules and their lessons.
///
/// Both levels reorder by dragging their grip, which is why neither list builds
/// Flutter's default drag handles: a handle on every row of a nested list would
/// compete with the row's own tap target. The grip is the only drag source, so a
/// tap anywhere else still opens the lesson.
class CourseCurriculumStep extends StatelessWidget {
  const CourseCurriculumStep({
    super.key,
    required this.draft,
    required this.onAddModule,
    required this.onRenameModule,
    required this.onDeleteModule,
    required this.onAddLesson,
    required this.onEditLesson,
    required this.onDeleteLesson,
    required this.onReorderModules,
    required this.onReorderLessons,
  });

  final ValueNotifier<CourseDraft> draft;
  final VoidCallback onAddModule;
  final void Function(String moduleKey, String title) onRenameModule;
  final void Function(String moduleKey) onDeleteModule;
  final void Function(String moduleKey) onAddLesson;
  final void Function(String moduleKey, CourseLesson lesson) onEditLesson;
  final void Function(String moduleKey, CourseLesson lesson) onDeleteLesson;
  final void Function(int oldIndex, int newIndex) onReorderModules;
  final void Function(String moduleKey, int oldIndex, int newIndex)
  onReorderLessons;

  @override
  Widget build(BuildContext context) {
    final modules = draft.value.modules;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Curriculum',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: builderInk,
                  ),
                ),
              ),
              Text(
                _summary(modules),
                style: GoogleFonts.figtree(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: builderGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (modules.isEmpty)
            _EmptyCurriculum(onAddModule: onAddModule)
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: modules.length,
              onReorderItem: onReorderModules,
              itemBuilder: (context, index) {
                final module = modules[index];
                return _ModuleCard(
                  key: ValueKey(module.key),
                  module: module,
                  index: index,
                  onRename: () => _renameModule(context, module),
                  onDelete: () => _confirmDeleteModule(context, module),
                  onAddLesson: () => onAddLesson(module.key),
                  onEditLesson: (lesson) => onEditLesson(module.key, lesson),
                  onDeleteLesson: (lesson) =>
                      onDeleteLesson(module.key, lesson),
                  onReorderLessons: (oldIndex, newIndex) =>
                      onReorderLessons(module.key, oldIndex, newIndex),
                );
              },
            ),
          if (modules.isNotEmpty) ...[
            const SizedBox(height: 12),
            BuilderAddTile(label: 'Add module', onTap: onAddModule),
          ],
        ],
      ),
    );
  }

  /// `2 modules · 5 lessons`, with the singular forms handled — "1 modules" on a
  /// screen the user is still building reads as a bug.
  String _summary(List<CourseModule> modules) {
    final lessons = modules.fold(0, (total, m) => total + m.lessons.length);
    final moduleWord = modules.length == 1 ? 'module' : 'modules';
    final lessonWord = lessons == 1 ? 'lesson' : 'lessons';
    return '${modules.length} $moduleWord · $lessons $lessonWord';
  }

  Future<void> _renameModule(BuildContext context, CourseModule module) async {
    final next = await PromptDialog.show(
      context,
      title: 'Rename module',
      hint: 'e.g. Getting Started',
      initial: module.title,
      maxLength: 80,
      confirmLabel: 'Save',
    );
    if (next == null) return;
    onRenameModule(module.key, next);
  }

  Future<void> _confirmDeleteModule(
    BuildContext context,
    CourseModule module,
  ) async {
    if (module.lessons.isEmpty) {
      onDeleteModule(module.key);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Delete ${module.title}?',
          style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Its ${module.lessons.length} '
          '${module.lessons.length == 1 ? 'lesson' : 'lessons'} will be deleted '
          'too.',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: builderGray,
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
                color: builderGray,
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
                color: builderDanger,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) onDeleteModule(module.key);
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    super.key,
    required this.module,
    required this.index,
    required this.onRename,
    required this.onDelete,
    required this.onAddLesson,
    required this.onEditLesson,
    required this.onDeleteLesson,
    required this.onReorderLessons,
  });

  final CourseModule module;
  final int index;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onAddLesson;
  final void Function(CourseLesson lesson) onEditLesson;
  final void Function(CourseLesson lesson) onDeleteLesson;
  final void Function(int oldIndex, int newIndex) onReorderLessons;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: builderFieldBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.only(left: 12, right: 4),
            decoration: const BoxDecoration(
              color: Color(0xFFFCFBF8),
              border: Border(bottom: BorderSide(color: builderCardBorder)),
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const _Grip(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    module.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: builderInk,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  module.metaLabel,
                  style: GoogleFonts.figtree(fontSize: 10, color: builderMuted),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: Color(0xFFB4B2A9),
                  ),
                  onSelected: (value) {
                    if (value == 'rename') onRename();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(
                        'Rename module',
                        style: GoogleFonts.manrope(fontSize: 13),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete module',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: builderDanger,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (module.lessons.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No lessons in this module yet.',
                style: GoogleFonts.figtree(fontSize: 11, color: builderMuted),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: module.lessons.length,
              onReorderItem: onReorderLessons,
              itemBuilder: (context, lessonIndex) {
                final lesson = module.lessons[lessonIndex];
                return _LessonRow(
                  key: ValueKey(lesson.key),
                  lesson: lesson,
                  index: lessonIndex,
                  isLast: lessonIndex == module.lessons.length - 1,
                  onTap: () => onEditLesson(lesson),
                  onDelete: () => onDeleteLesson(lesson),
                );
              },
            ),
          InkWell(
            onTap: onAddLesson,
            child: SizedBox(
              height: 36,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.add, size: 15, color: builderYellow),
                  const SizedBox(width: 6),
                  Text(
                    'Add lesson',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: builderYellow,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    super.key,
    required this.lesson,
    required this.index,
    required this.isLast,
    required this.onTap,
    required this.onDelete,
  });

  final CourseLesson lesson;
  final int index;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF7F6F2))),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 4, 7),
          child: Row(
            children: [
              ReorderableDragStartListener(index: index, child: const _Grip()),
              const SizedBox(width: 8),
              SizedBox(
                width: 14,
                child: Text(
                  (index + 1).toString().padLeft(2, '0'),
                  style: GoogleFonts.figtree(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: builderMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: builderInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        style: GoogleFonts.figtree(
                          fontSize: 10,
                          color: builderMuted,
                        ),
                        children: [
                          TextSpan(text: '${lesson.kind.tag} · '),
                          TextSpan(text: lesson.durationLabel),
                          if (lesson.isPreview)
                            TextSpan(
                              text: ' · Free preview',
                              style: GoogleFonts.figtree(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: builderYellow,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Delete lesson',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.close,
                  size: 15,
                  color: Color(0xFFC4C0B6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Grip extends StatelessWidget {
  const _Grip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 24,
      child: Center(
        child: Icon(
          Icons.drag_indicator,
          size: 15,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }
}

class _EmptyCurriculum extends StatelessWidget {
  const _EmptyCurriculum({required this.onAddModule});

  final VoidCallback onAddModule;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No modules yet. Group your lessons into modules — most courses need '
          'at least one.',
          style: GoogleFonts.figtree(
            fontSize: 11,
            color: builderMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        BuilderAddTile(label: 'Add your first module', onTap: onAddModule),
      ],
    );
  }
}
