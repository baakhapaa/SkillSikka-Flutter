import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_error.dart';
import '../data/module_quiz.dart';
import '../data/quiz_api.dart';

const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _muted = Color(0xFF9CA3AF);
const _line = Color(0xFFE5E7EB);
const _gold = Color(0xFFE6B800);
const _goldSoft = Color(0xFFFFF6D8);
const _green = Color(0xFF16A34A);
const _greenSoft = Color(0xFFF0FDF4);
const _red = Color(0xFFDC2626);
const _redSoft = Color(0xFFFEF2F2);

/// The student quiz, matched to the four Figma frames under node 274:576.
///
/// Pick an option, Check Answer, then either "Correct! Well done." or
/// "Not quite — keep going" with the right option. The last question submits
/// the attempt. Nothing here unlocks the next module.
class ModuleQuizPage extends StatefulWidget {
  const ModuleQuizPage({super.key, required this.api, required this.summary});

  final QuizApi api;

  /// The row from `GET /courses/{id}/quizzes/`. Questions are loaded here,
  /// because that list does not include them.
  final ModuleQuiz summary;

  @override
  State<ModuleQuizPage> createState() => _ModuleQuizPageState();
}

class _ModuleQuizPageState extends State<ModuleQuizPage> {
  ModuleQuiz? _quiz;
  int? _attemptId;
  int _index = 0;
  int? _selected;
  QuizCheckResult? _checked;
  bool _busy = false;
  String? _error;
  bool _outOfAttempts = false;
  QuizSubmitResult? _result;
  late int _attemptsUsed;

  /// option id chosen for each question id, sent again on submit.
  final Map<int, int> _answers = {};

  Timer? _clock;
  int _remaining = 180;
  bool _timeUp = false;

  @override
  void initState() {
    super.initState();
    _attemptsUsed = widget.summary.attemptsUsed;
    _open();
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  int get _limitSeconds {
    final seconds = _quiz?.timeLimitSeconds ?? widget.summary.timeLimitSeconds;
    if (seconds < 15) return 180;
    return seconds;
  }

  /// Starts the one clock for this attempt. Later questions keep the same
  /// remaining time; they do not start the limit again.
  void _startClock() {
    _clock?.cancel();
    _timeUp = false;
    _remaining = _limitSeconds;
    _clock = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _result != null) {
        timer.cancel();
        return;
      }
      if (_remaining <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _remaining -= 1);
      if (_remaining <= 0) {
        timer.cancel();
        _onTimeUp();
        return;
      }
      if (_remaining <= 10) _pulseClock();
    });
  }

  /// A tick you can feel once the attempt is inside its last ten seconds.
  void _pulseClock() {
    if (_remaining == 10 || _remaining <= 3) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  String get _clockLabel {
    final minutes = (_remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _onTimeUp() async {
    if (_timeUp || _result != null) return;
    _timeUp = true;
    HapticFeedback.heavyImpact();
    if (_checked == null && _selected != null && !_busy) {
      await _check();
    }
    final ids = [for (final question in _questions) ?question.id];
    final finished = ids.isNotEmpty && ids.every(_answers.containsKey);
    if (finished) {
      await _submit();
      return;
    }
    if (mounted) setState(() {});
  }

  List<QuizQuestionDraft> get _questions => _quiz?.questions ?? const [];

  QuizQuestionDraft? get _question =>
      _index >= 0 && _index < _questions.length ? _questions[_index] : null;

  Future<void> _open() async {
    final id = widget.summary.id;
    if (id == null) {
      setState(() => _error = 'This quiz is missing.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _outOfAttempts = false;
    });
    try {
      final quiz = await widget.api.studentQuiz(id);
      final attemptId = await widget.api.start(id);
      if (!mounted) return;
      setState(() {
        _quiz = quiz;
        _attemptId = attemptId;
        _index = 0;
        _selected = null;
        _checked = null;
        _answers.clear();
        _result = null;
        _timeUp = false;
        _busy = false;
      });
      _startClock();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _outOfAttempts = error.code == 'MAX_ATTEMPTS_REACHED';
        _error = error.displayMessage;
      });
    }
  }

  Future<void> _check() async {
    final question = _question;
    final attemptId = _attemptId;
    final selected = _selected;
    if (question == null || attemptId == null || selected == null || _busy) {
      return;
    }
    final questionId = question.id;
    final option = question.options[selected];
    final optionId = option.id;
    if (questionId == null || optionId == null) {
      setState(() => _error = 'This question is not ready to check yet.');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await widget.api.answer(
        attemptId,
        questionId: questionId,
        optionId: optionId,
      );
      if (!mounted) return;
      setState(() {
        _checked = result;
        _answers[questionId] = optionId;
        _busy = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.displayMessage;
      });
    }
  }

  Future<void> _next() async {
    if (_index < _questions.length - 1) {
      setState(() {
        _index += 1;
        _selected = null;
        _checked = null;
      });
      return;
    }
    final attemptId = _attemptId;
    if (attemptId == null || _busy) return;
    await _submit();
  }

  Future<void> _submit() async {
    final attemptId = _attemptId;
    if (attemptId == null || _busy || _result != null) return;
    setState(() => _busy = true);
    try {
      final result = await widget.api.submit(attemptId, [
        for (final entry in _answers.entries)
          (questionId: entry.key, optionId: entry.value),
      ]);
      if (!mounted) return;
      _clock?.cancel();
      if (result.isPassed) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
      setState(() {
        _result = result;
        _attemptsUsed += 1;
        _busy = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.displayMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: result != null
            ? _Results(
                quiz: _quiz ?? widget.summary,
                result: result,
                canRetry: _attemptsUsed < widget.summary.maxAttempts,
                attemptsLeft: (widget.summary.maxAttempts - _attemptsUsed)
                    .clamp(0, widget.summary.maxAttempts),
                onExit: () => Navigator.of(context).pop(),
                onRetry: _open,
              )
            : Column(
                children: [
                  _Nav(
                    title: (_quiz ?? widget.summary).title,
                    onExit: () => Navigator.of(context).pop(),
                  ),
                  Expanded(child: _body()),
                ],
              ),
      ),
    );
  }

  Widget _body() {
    if (_outOfAttempts) {
      return _Message(
        title: 'No attempts left',
        body: _error ?? 'You have used every attempt on this quiz.',
      );
    }
    final quiz = _quiz;
    final question = _question;
    if (_timeUp && _result == null) {
      return _TimeUp(onExit: () => Navigator.of(context).pop());
    }
    if (quiz == null || question == null) {
      if (_error != null) {
        return _Message(title: 'Quiz unavailable', body: _error!);
      }
      return const Center(child: CircularProgressIndicator(color: _gold));
    }
    final checked = _checked;
    final total = _questions.length;
    final topic = (quiz.section ?? widget.summary.section ?? '').trim();
    final urgent = _remaining > 0 && _remaining <= 10;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            children: [
              Row(
                children: [
                  Text(
                    'Question ${_index + 1} of $total',
                    style: GoogleFonts.figtree(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: urgent ? _red : _gray,
                    ),
                  ),
                  const Spacer(),
                  if (checked != null && !urgent)
                    Text(
                      'Answer review',
                      style: GoogleFonts.figtree(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _gray,
                      ),
                    )
                  else
                    _AttemptClock(
                      label: _clockLabel,
                      remaining: _remaining,
                      urgent: urgent,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: urgent
                      ? _remaining / 10
                      : (total == 0 ? 0 : (_index + 1) / total),
                  minHeight: urgent ? 8 : 6,
                  backgroundColor: urgent ? _redSoft : const Color(0xFFF3F4F6),
                  color: urgent ? _red : _gold,
                ),
              ),
              const SizedBox(height: 22),
              if (topic.isNotEmpty)
                Text(
                  topic.toUpperCase(),
                  style: GoogleFonts.figtree(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: _muted,
                  ),
                ),
              if (topic.isNotEmpty) const SizedBox(height: 8),
              Text(
                question.text,
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                checked == null
                    ? 'Select one answer to continue.'
                    : 'Your answer is highlighted below.',
                style: GoogleFonts.figtree(fontSize: 13, color: _gray),
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < question.options.length; index++)
                _OptionTile(
                  letter: String.fromCharCode(65 + index),
                  text: question.options[index].text,
                  selected: _selected == index,
                  locked: checked != null,
                  correct:
                      checked != null &&
                      question.options[index].id == checked.correctOptionId,
                  wrong:
                      checked != null &&
                      _selected == index &&
                      question.options[index].id != checked.correctOptionId,
                  onTap: checked == null
                      ? () => setState(() => _selected = index)
                      : null,
                ),
              if (checked == null && question.hint.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                _HintCard(text: question.hint.trim()),
              ],
              if (checked != null) ...[
                const SizedBox(height: 8),
                _FeedbackCard(
                  correct: checked.isCorrect,
                  correctText: _optionText(question, checked.correctOptionId),
                  explanation: checked.explanation,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: GoogleFonts.figtree(fontSize: 12, color: _red),
                ),
              ],
            ],
          ),
        ),
        _Actions(
          checked: checked != null,
          canCheck: _selected != null && !_busy,
          busy: _busy,
          isLast: _index >= total - 1,
          onCheck: _check,
          onNext: _next,
        ),
      ],
    );
  }

  String _optionText(QuizQuestionDraft question, int optionId) {
    for (final option in question.options) {
      if (option.id == optionId) return option.text;
    }
    return '';
  }
}

class _Nav extends StatelessWidget {
  const _Nav({required this.title, required this.onExit});

  final String title;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title.trim().isEmpty ? 'Quiz' : title.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            GestureDetector(
              onTap: onExit,
              behavior: HitTestBehavior.opaque,
              child: Text(
                'Exit',
                style: GoogleFonts.figtree(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _gray,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.locked,
    required this.correct,
    required this.wrong,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;
  final bool locked;
  final bool correct;
  final bool wrong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color border;
    final Color fill;
    final Color badge;
    final Color badgeText;
    if (correct) {
      border = _green;
      fill = _greenSoft;
      badge = _green;
      badgeText = Colors.white;
    } else if (wrong) {
      border = _red;
      fill = _redSoft;
      badge = _red;
      badgeText = Colors.white;
    } else if (selected) {
      border = _gold;
      fill = _goldSoft;
      badge = _gold;
      badgeText = _ink;
    } else {
      border = _line;
      fill = Colors.white;
      badge = const Color(0xFFF3F4F6);
      badgeText = _ink;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: locked ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: border,
              width: selected || correct || wrong ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: badge, shape: BoxShape.circle),
                child: Text(
                  letter,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: badgeText,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _goldSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hint',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: GoogleFonts.figtree(fontSize: 13, height: 1.4, color: _gray),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.correct,
    required this.correctText,
    required this.explanation,
  });

  final bool correct;
  final String correctText;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final tone = correct ? _green : _red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: correct ? _greenSoft : _redSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            correct ? 'Correct! Well done.' : 'Not quite — keep going',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: tone,
            ),
          ),
          if (!correct && correctText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Correct answer: $correctText',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ],
          if (explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              explanation.trim(),
              style: GoogleFonts.figtree(
                fontSize: 13,
                height: 1.4,
                color: _gray,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.checked,
    required this.canCheck,
    required this.busy,
    required this.isLast,
    required this.onCheck,
    required this.onNext,
  });

  final bool checked;
  final bool canCheck;
  final bool busy;
  final bool isLast;
  final VoidCallback onCheck;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final enabled = checked || canCheck;
    final label = checked
        ? (isLast ? 'See results' : 'Next Question')
        : 'Check Answer';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Column(
        children: [
          GestureDetector(
            onTap: !enabled || busy ? null : (checked ? onNext : onCheck),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: enabled ? _gold : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _ink,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: enabled ? _ink : _muted,
                          ),
                        ),
                        if (checked) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward,
                            size: 18,
                            color: enabled ? _ink : _muted,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            checked
                ? 'Review, learn, and move forward.'
                : 'Choose an answer to enable checking.',
            style: GoogleFonts.figtree(fontSize: 12, color: _muted),
          ),
        ],
      ),
    );
  }
}

/// The attempt clock. Calm time stays a gray label. The last ten seconds
/// become a red pill that bumps once a second, and the bar under it drains.
class _AttemptClock extends StatelessWidget {
  const _AttemptClock({
    required this.label,
    required this.remaining,
    required this.urgent,
  });

  final String label;
  final int remaining;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      urgent ? label : '$label left',
      style: GoogleFonts.figtree(
        fontSize: urgent ? 14 : 13,
        fontWeight: FontWeight.w800,
        color: urgent ? Colors.white : _gray,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    if (!urgent) return text;
    return TweenAnimationBuilder<double>(
      key: ValueKey(remaining),
      tween: Tween(begin: remaining <= 3 ? 1.14 : 1.08, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        alignment: Alignment.centerRight,
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _red,
          borderRadius: BorderRadius.circular(20),
        ),
        child: text,
      ),
    );
  }
}

class _TimeUp extends StatelessWidget {
  const _TimeUp({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        children: [
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 16),
                  child: child,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _redSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.timer_off_outlined,
                      size: 36,
                      color: _red,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '00:00',
                    style: GoogleFonts.manrope(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: _red,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Time's up",
                    style: GoogleFonts.manrope(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The clock ran out before every question was checked.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.figtree(
                      fontSize: 15,
                      height: 1.4,
                      color: _gray,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _GoldButton(label: 'Back to course', onTap: onExit),
        ],
      ),
    );
  }
}

class _Results extends StatefulWidget {
  const _Results({
    required this.quiz,
    required this.result,
    required this.canRetry,
    required this.attemptsLeft,
    required this.onExit,
    required this.onRetry,
  });

  final ModuleQuiz quiz;
  final QuizSubmitResult result;
  final bool canRetry;
  final int attemptsLeft;
  final VoidCallback onExit;
  final VoidCallback onRetry;

  @override
  State<_Results> createState() => _ResultsState();
}

class _ResultsState extends State<_Results>
    with SingleTickerProviderStateMixin {
  late final AnimationController _play;

  @override
  void initState() {
    super.initState();
    _play = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _play.value = 1;
      } else {
        _play.forward();
      }
    });
  }

  @override
  void dispose() {
    _play.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quiz = widget.quiz;
    final result = widget.result;
    final passed = result.isPassed;
    final title = quiz.title.trim().isEmpty ? 'Quiz' : quiz.title.trim();
    final attempts = widget.attemptsLeft == 1
        ? '1 attempt left'
        : '${widget.attemptsLeft} attempts left';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _play,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(_play.value);
                final shown = (result.percentage * t).round();
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$shown%',
                      style: GoogleFonts.manrope(
                        fontSize: 72,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: passed ? _green : _ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      passed ? 'You passed' : 'Not passed',
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _PassTrack(
                      score: result.percentage,
                      passMark: quiz.passPercentage,
                      progress: t,
                      passed: passed,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pass mark ${quiz.passPercentage}%',
                      style: GoogleFonts.figtree(fontSize: 13, color: _gray),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${result.pointsEarned} points earned',
                      style: GoogleFonts.figtree(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      attempts,
                      style: GoogleFonts.figtree(fontSize: 14, color: _gray),
                    ),
                  ],
                );
              },
            ),
          ),
          if (passed) ...[
            _GoldButton(label: 'Back to course', onTap: widget.onExit),
            if (widget.canRetry) ...[
              const SizedBox(height: 10),
              _OutlineButton(label: 'Retry', onTap: widget.onRetry),
            ],
          ] else ...[
            if (widget.canRetry) ...[
              _GoldButton(label: 'Retry', onTap: widget.onRetry),
              const SizedBox(height: 10),
            ],
            if (widget.canRetry)
              _OutlineButton(label: 'Back to course', onTap: widget.onExit)
            else
              _GoldButton(label: 'Back to course', onTap: widget.onExit),
          ],
        ],
      ),
    );
  }
}

/// Score filling toward the right, with a tick where the pass mark sits.
class _PassTrack extends StatelessWidget {
  const _PassTrack({
    required this.score,
    required this.passMark,
    required this.progress,
    required this.passed,
  });

  final double score;
  final int passMark;
  final double progress;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final fill = width * (score.clamp(0, 100) / 100) * progress;
          final mark = width * (passMark.clamp(0, 100) / 100);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 7,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 7,
                width: fill,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: passed ? _green : _red,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              Positioned(
                left: (mark - 1).clamp(0, width - 2),
                top: 2,
                child: Container(width: 2, height: 18, color: _ink),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _gold,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.figtree(fontSize: 14, height: 1.4, color: _gray),
          ),
        ],
      ),
    );
  }
}
