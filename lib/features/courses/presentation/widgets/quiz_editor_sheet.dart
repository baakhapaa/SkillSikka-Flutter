import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/pressable_chip.dart';
import '../../../quiz/data/module_quiz.dart';
import 'builder_tokens.dart';

/// What the sheet hands back. The builder does the network write after this
/// closes, same as a lesson: a save that ran while the sheet was open would
/// have to repaint a form the user has already dismissed.
sealed class QuizSheetResult {
  const QuizSheetResult();
}

class QuizSaved extends QuizSheetResult {
  const QuizSaved(this.quiz);

  final ModuleQuiz quiz;
}

class QuizDeleted extends QuizSheetResult {
  const QuizDeleted();
}

/// The instructor's form for one module's quiz.
///
/// There is no Figma frame for this. It uses the builder's own type, gold, and
/// sheet shape so it reads as part of Add New Course rather than a second app.
class QuizEditorSheet extends StatefulWidget {
  const QuizEditorSheet({super.key, required this.moduleTitle, this.quiz});

  final String moduleTitle;
  final ModuleQuiz? quiz;

  static Future<QuizSheetResult?> show(
    BuildContext context, {
    required String moduleTitle,
    ModuleQuiz? quiz,
  }) {
    return showModalBottomSheet<QuizSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) =>
          QuizEditorSheet(moduleTitle: moduleTitle, quiz: quiz),
    );
  }

  @override
  State<QuizEditorSheet> createState() => _QuizEditorSheetState();
}

class _QuizEditorSheetState extends State<QuizEditorSheet> {
  static const _passMarks = [40, 50, 60, 70, 80];

  late ModuleQuiz _quiz;
  late final TextEditingController _title;
  final Map<String, TextEditingController> _fields = {};
  final Set<String> _extrasOpen = {};
  List<String> _issues = const [];
  var _serial = 0;

  bool get _locked => _quiz.hasCompletedAttempts;

  @override
  void initState() {
    super.initState();
    final existing = widget.quiz;
    final module = widget.moduleTitle.trim();
    _quiz =
        existing ??
        ModuleQuiz(
          title: module.isEmpty ? 'Module quiz' : '$module Quiz',
          section: module.isEmpty ? null : module,
          questions: [blankQuestion(key: _freshKey('question'))],
        );
    _title = TextEditingController(text: _quiz.title);
    for (final question in _quiz.questions) {
      if (question.hint.trim().isNotEmpty ||
          question.explanation.trim().isNotEmpty) {
        _extrasOpen.add(question.key);
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _freshKey(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_serial++}';

  TextEditingController _field(String key, String value) {
    return _fields.putIfAbsent(key, () => TextEditingController(text: value));
  }

  void _dropFields(String prefix) {
    final doomed = [
      for (final key in _fields.keys)
        if (key.contains(prefix)) key,
    ];
    for (final key in doomed) {
      _fields.remove(key)?.dispose();
    }
  }

  ModuleQuiz _collect() {
    return _quiz.copyWith(
      title: _title.text,
      questions: [
        for (var index = 0; index < _quiz.questions.length; index++)
          _collectQuestion(_quiz.questions[index], index),
      ],
    );
  }

  QuizQuestionDraft _collectQuestion(QuizQuestionDraft question, int order) {
    return question.copyWith(
      text: _field('text-${question.key}', question.text).text,
      hint: _field('hint-${question.key}', question.hint).text,
      explanation: _field('why-${question.key}', question.explanation).text,
      order: order,
      options: [
        for (final option in question.options)
          option.copyWith(text: _field('opt-${option.key}', option.text).text),
      ],
    );
  }

  void _save() {
    final quiz = _collect();
    final issues = quizIssues(quiz);
    if (issues.isNotEmpty) {
      setState(() => _issues = issues);
      return;
    }
    Navigator.of(context).pop(QuizSaved(quiz));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Delete this quiz?',
          style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Students will no longer see it at the end of this module.',
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
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(const QuizDeleted());
    }
  }

  void _setQuestions(List<QuizQuestionDraft> questions) {
    setState(() => _quiz = _quiz.copyWith(questions: questions));
  }

  void _addQuestion() {
    if (_locked) return;
    final questions = [..._collect().questions];
    questions.add(
      blankQuestion(key: _freshKey('question'), order: questions.length),
    );
    _setQuestions(questions);
  }

  void _duplicate(int index) {
    if (_locked) return;
    final questions = [..._collect().questions];
    final source = questions[index];
    final key = _freshKey('question');
    questions.insert(
      index + 1,
      QuizQuestionDraft(
        key: key,
        text: source.text,
        hint: source.hint,
        explanation: source.explanation,
        options: [
          for (
            var optionIndex = 0;
            optionIndex < source.options.length;
            optionIndex++
          )
            QuizOptionDraft(
              key: '$key-option-$optionIndex',
              text: source.options[optionIndex].text,
              isCorrect: source.options[optionIndex].isCorrect,
            ),
        ],
      ),
    );
    if (source.hint.trim().isNotEmpty || source.explanation.trim().isNotEmpty) {
      _extrasOpen.add(key);
    }
    _setQuestions(questions);
  }

  void _removeQuestion(int index) {
    if (_locked) return;
    final questions = [..._collect().questions];
    if (questions.length == 1) return;
    final removed = questions.removeAt(index);
    _dropFields(removed.key);
    _extrasOpen.remove(removed.key);
    _setQuestions(questions);
  }

  void _markCorrect(int questionIndex, int optionIndex) {
    if (_locked) return;
    final questions = [..._collect().questions];
    final question = questions[questionIndex];
    questions[questionIndex] = question.copyWith(
      options: [
        for (var index = 0; index < question.options.length; index++)
          question.options[index].copyWith(isCorrect: index == optionIndex),
      ],
    );
    _setQuestions(questions);
  }

  void _addOption(int questionIndex) {
    if (_locked) return;
    final questions = [..._collect().questions];
    final question = questions[questionIndex];
    if (question.options.length >= 6) return;
    questions[questionIndex] = question.copyWith(
      options: [
        ...question.options,
        QuizOptionDraft(key: _freshKey('option')),
      ],
    );
    _setQuestions(questions);
  }

  void _removeOption(int questionIndex, int optionIndex) {
    if (_locked) return;
    final questions = [..._collect().questions];
    final question = questions[questionIndex];
    if (question.options.length <= 2) return;
    final options = [...question.options]..removeAt(optionIndex);
    if (!options.any((option) => option.isCorrect) && options.isNotEmpty) {
      options[0] = options[0].copyWith(isCorrect: true);
    }
    questions[questionIndex] = question.copyWith(options: options);
    _setQuestions(questions);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final passMarks = {..._passMarks, _quiz.passPercentage}.toList()..sort();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Module quiz',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: builderInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.moduleTitle.trim().isEmpty
                              ? 'Optional · shown after the lessons'
                              : widget.moduleTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.figtree(
                            fontSize: 12,
                            color: builderGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.quiz?.id != null)
                    IconButton(
                      onPressed: _delete,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: builderDanger,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                children: [
                  if (_locked) ...[
                    const _LockNotice(),
                    const SizedBox(height: 12),
                  ],
                  _label('Quiz title'),
                  _box(controller: _title, hint: 'Forces Quiz'),
                  const SizedBox(height: 14),
                  _label('Pass mark'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final mark in passMarks)
                        PressableChip(
                          label: '$mark%',
                          selected: _quiz.passPercentage == mark,
                          onTap: () => setState(
                            () => _quiz = _quiz.copyWith(passPercentage: mark),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _label('Attempts allowed'),
                  _AttemptStepper(
                    value: _quiz.maxAttempts,
                    onChanged: (value) => setState(
                      () => _quiz = _quiz.copyWith(maxAttempts: value),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _label('Quiz time'),
                  _QuizTimeControl(
                    seconds: _quiz.timeLimitSeconds,
                    onChanged: (seconds) => setState(
                      () => _quiz = _quiz.copyWith(timeLimitSeconds: seconds),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'One clock for the whole quiz. It does not restart on the next question.',
                    style: GoogleFonts.figtree(
                      fontSize: 11,
                      color: builderGray,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _quiz.questions.length,
                    onReorderItem: (oldIndex, newIndex) {
                      if (_locked) return;
                      final questions = [..._collect().questions];
                      final moved = questions.removeAt(oldIndex);
                      questions.insert(newIndex, moved);
                      _setQuestions(questions);
                    },
                    itemBuilder: (context, index) {
                      final question = _quiz.questions[index];
                      return _QuestionCard(
                        key: ValueKey(question.key),
                        index: index,
                        question: question,
                        locked: _locked,
                        extrasOpen: _extrasOpen.contains(question.key),
                        text: _field('text-${question.key}', question.text),
                        hint: _field('hint-${question.key}', question.hint),
                        explanation: _field(
                          'why-${question.key}',
                          question.explanation,
                        ),
                        optionText: (option) =>
                            _field('opt-${option.key}', option.text),
                        onToggleExtras: () => setState(() {
                          if (!_extrasOpen.add(question.key)) {
                            _extrasOpen.remove(question.key);
                          }
                        }),
                        onMarkCorrect: (optionIndex) =>
                            _markCorrect(index, optionIndex),
                        onAddOption: () => _addOption(index),
                        onRemoveOption: (optionIndex) =>
                            _removeOption(index, optionIndex),
                        onDuplicate: () => _duplicate(index),
                        onDelete: _quiz.questions.length == 1
                            ? null
                            : () => _removeQuestion(index),
                      );
                    },
                  ),
                  if (!_locked) ...[
                    const SizedBox(height: 8),
                    BuilderAddTile(label: 'Add question', onTap: _addQuestion),
                  ],
                  if (_issues.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final issue in _issues)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          issue,
                          style: GoogleFonts.figtree(
                            fontSize: 12,
                            color: builderDanger,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: builderYellow,
                    foregroundColor: builderInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _save,
                  child: Text(
                    'Save quiz',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: builderInk,
      ),
    ),
  );

  Widget _box({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      style: GoogleFonts.manrope(fontSize: 14, color: builderInk),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.manrope(fontSize: 14, color: builderMuted),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: builderFieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: builderYellow, width: 1.4),
        ),
      ),
    );
  }
}

class _LockNotice extends StatelessWidget {
  const _LockNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: builderCream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: builderYellow.withValues(alpha: 0.35)),
      ),
      child: Text(
        'Students have already taken this quiz, so the questions stay as they '
        'are. You can still change the title, pass mark, and attempts.',
        style: GoogleFonts.figtree(
          fontSize: 12,
          height: 1.4,
          color: builderBrown,
        ),
      ),
    );
  }
}

class _QuizTimeControl extends StatelessWidget {
  const _QuizTimeControl({required this.seconds, required this.onChanged});

  final int seconds;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return Row(
      children: [
        _part(
          minutes,
          'min',
          onLess: minutes > 0 ? () => _apply(minutes - 1, remainder) : null,
          onMore: minutes < 60 ? () => _apply(minutes + 1, remainder) : null,
        ),
        const SizedBox(width: 18),
        _part(
          remainder,
          'sec',
          onLess: remainder >= 15
              ? () => _apply(minutes, remainder - 15)
              : null,
          onMore: remainder <= 30
              ? () => _apply(minutes, remainder + 15)
              : null,
        ),
      ],
    );
  }

  void _apply(int minutes, int remainder) {
    var total = minutes * 60 + remainder;
    if (total < 15) total = 15;
    if (total > 3600) total = 3600;
    onChanged(total);
  }

  Widget _part(
    int value,
    String unit, {
    required VoidCallback? onLess,
    required VoidCallback? onMore,
  }) {
    return Row(
      children: [
        _button(Icons.remove, onLess),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '$value $unit',
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: builderInk,
            ),
          ),
        ),
        _button(Icons.add, onMore),
      ],
    );
  }

  Widget _button(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xFFF3F4F6) : builderPillFill,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? builderMuted : builderInk,
        ),
      ),
    );
  }
}

class _AttemptStepper extends StatelessWidget {
  const _AttemptStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _step(Icons.remove, value > 1 ? () => onChanged(value - 1) : null),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '$value',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: builderInk,
            ),
          ),
        ),
        _step(Icons.add, value < 5 ? () => onChanged(value + 1) : null),
      ],
    );
  }

  Widget _step(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xFFF3F4F6) : builderPillFill,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? builderMuted : builderInk,
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
    required this.index,
    required this.question,
    required this.locked,
    required this.extrasOpen,
    required this.text,
    required this.hint,
    required this.explanation,
    required this.optionText,
    required this.onToggleExtras,
    required this.onMarkCorrect,
    required this.onAddOption,
    required this.onRemoveOption,
    required this.onDuplicate,
    required this.onDelete,
  });

  final int index;
  final QuizQuestionDraft question;
  final bool locked;
  final bool extrasOpen;
  final TextEditingController text;
  final TextEditingController hint;
  final TextEditingController explanation;
  final TextEditingController Function(QuizOptionDraft option) optionText;
  final VoidCallback onToggleExtras;
  final ValueChanged<int> onMarkCorrect;
  final VoidCallback onAddOption;
  final ValueChanged<int> onRemoveOption;
  final VoidCallback onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: builderFieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!locked)
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_indicator,
                    size: 18,
                    color: builderMuted,
                  ),
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Question ${index + 1}',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: builderInk,
                  ),
                ),
              ),
              if (!locked) ...[
                IconButton(
                  onPressed: onDuplicate,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.copy_outlined,
                    size: 16,
                    color: builderGray,
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: builderDanger,
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: text,
            readOnly: locked,
            minLines: 1,
            maxLines: 3,
            style: GoogleFonts.manrope(fontSize: 14, color: builderInk),
            decoration: _decoration('What is the SI unit of force?'),
          ),
          const SizedBox(height: 10),
          for (
            var optionIndex = 0;
            optionIndex < question.options.length;
            optionIndex++
          )
            _OptionRow(
              letter: String.fromCharCode(65 + optionIndex),
              controller: optionText(question.options[optionIndex]),
              correct: question.options[optionIndex].isCorrect,
              locked: locked,
              canRemove: question.options.length > 2,
              onMark: () => onMarkCorrect(optionIndex),
              onRemove: () => onRemoveOption(optionIndex),
            ),
          if (!locked && question.options.length < 6)
            GestureDetector(
              onTap: onAddOption,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Text(
                  '+ Add option',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: builderYellow,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onToggleExtras,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: builderPillFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: builderYellow.withValues(alpha: 0.55),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: builderYellow,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Hint and explanation',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: builderYellow,
                      ),
                    ),
                  ),
                  Icon(
                    extrasOpen
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: builderYellow,
                  ),
                ],
              ),
            ),
          ),
          if (extrasOpen) ...[
            const SizedBox(height: 6),
            TextField(
              controller: hint,
              readOnly: locked,
              decoration: _decoration('Hint, shown before they answer'),
              style: GoogleFonts.manrope(fontSize: 13, color: builderInk),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: explanation,
              readOnly: locked,
              minLines: 1,
              maxLines: 3,
              decoration: _decoration('Explanation, shown after they answer'),
              style: GoogleFonts.manrope(fontSize: 13, color: builderInk),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _decoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.manrope(fontSize: 13, color: builderMuted),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: builderFieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: builderYellow, width: 1.4),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.letter,
    required this.controller,
    required this.correct,
    required this.locked,
    required this.canRemove,
    required this.onMark,
    required this.onRemove,
  });

  final String letter;
  final TextEditingController controller;
  final bool correct;
  final bool locked;
  final bool canRemove;
  final VoidCallback onMark;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final border = correct ? builderSuccess : builderFieldBorder;
    final fill = correct ? const Color(0xFFF0FDF4) : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: locked ? null : onMark,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: correct ? builderSuccess : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Text(
                letter,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: correct ? Colors.white : builderInk,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: locked,
              style: GoogleFonts.manrope(fontSize: 13, color: builderInk),
              decoration: InputDecoration(
                hintText: 'Option $letter',
                hintStyle: GoogleFonts.manrope(
                  fontSize: 13,
                  color: builderMuted,
                ),
                isDense: true,
                filled: true,
                fillColor: fill,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: correct ? builderSuccess : builderYellow,
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          if (!locked && canRemove)
            IconButton(
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 14, color: builderMuted),
            ),
        ],
      ),
    );
  }
}
