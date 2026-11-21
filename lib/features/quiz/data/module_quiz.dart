/// A quiz attached to one course module.
///
/// The module is not a row of its own. [section] is the same string stored on
/// each of that module's lessons (`Lesson.section`). Null means the lessons
/// that were saved with no section. A module with no [ModuleQuiz] has no quiz,
/// which is what makes the quiz optional.
class ModuleQuiz {
  const ModuleQuiz({
    this.id,
    this.courseId,
    this.section,
    this.title = '',
    this.description = '',
    this.passPercentage = 60,
    this.maxAttempts = 1,
    this.timeLimitSeconds = 180,
    this.isPublished = false,
    this.questions = const [],
    this.questionCount = 0,
    this.attemptsUsed = 0,
    this.bestPercentage,
    this.isPassed = false,
    this.hasCompletedAttempts = false,
  });

  final int? id;
  final int? courseId;

  /// Module name, matching `Lesson.section`.
  final String? section;

  final String title;
  final String description;
  final int passPercentage;
  final int maxAttempts;

  /// One clock for the whole attempt, in seconds. The next question does not
  /// start it again.
  final int timeLimitSeconds;
  final bool isPublished;
  final List<QuizQuestionDraft> questions;

  /// From the course quiz list, which does not embed the questions.
  ///
  /// [count] prefers the embedded list once the management payload has been
  /// loaded, because that list is the one the editor is about to save.
  final int questionCount;

  final int attemptsUsed;
  final double? bestPercentage;
  final bool isPassed;

  /// True once any student has finished an attempt. Questions stay put.
  final bool hasCompletedAttempts;

  int get count => questions.isNotEmpty ? questions.length : questionCount;

  /// The line under a module in the lesson list.
  String get statusLabel {
    if (isPassed && bestPercentage != null) {
      return 'Passed ${bestPercentage!.round()}%';
    }
    if (attemptsUsed >= maxAttempts && attemptsUsed > 0) {
      return 'No attempts left';
    }
    if (attemptsUsed > 0 && bestPercentage != null) {
      return 'Best ${bestPercentage!.round()}% · Retry';
    }
    return 'Optional';
  }

  bool get canRetry => attemptsUsed < maxAttempts;

  ModuleQuiz copyWith({
    int? id,
    int? courseId,
    Object? section = _keep,
    String? title,
    String? description,
    int? passPercentage,
    int? maxAttempts,
    int? timeLimitSeconds,
    bool? isPublished,
    List<QuizQuestionDraft>? questions,
    int? questionCount,
    int? attemptsUsed,
    Object? bestPercentage = _keep,
    bool? isPassed,
    bool? hasCompletedAttempts,
  }) {
    return ModuleQuiz(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      section: section == _keep ? this.section : section as String?,
      title: title ?? this.title,
      description: description ?? this.description,
      passPercentage: passPercentage ?? this.passPercentage,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
      isPublished: isPublished ?? this.isPublished,
      questions: questions ?? this.questions,
      questionCount: questionCount ?? this.questionCount,
      attemptsUsed: attemptsUsed ?? this.attemptsUsed,
      bestPercentage: bestPercentage == _keep
          ? this.bestPercentage
          : bestPercentage as double?,
      isPassed: isPassed ?? this.isPassed,
      hasCompletedAttempts: hasCompletedAttempts ?? this.hasCompletedAttempts,
    );
  }

  /// Instructor payload: `GET /quizzes/` and `GET /quizzes/{id}/`.
  factory ModuleQuiz.fromManagement(Map<String, dynamic> row) {
    final questions = [
      for (final item in _asList(row['questions']))
        if (item is Map) QuizQuestionDraft.fromJson(_stringKeyMap(item)),
    ]..sort((a, b) => a.order.compareTo(b.order));
    return ModuleQuiz(
      id: _asInt(row['id']),
      courseId: _asInt(row['course']),
      section: _section(row['section']),
      title: _asString(row['title']) ?? '',
      description: _asString(row['description']) ?? '',
      passPercentage: _asInt(row['pass_percentage']) ?? 60,
      maxAttempts: _asInt(row['max_attempts']) ?? 1,
      timeLimitSeconds: _seconds(row['time_limit_seconds']),
      isPublished: row['is_published'] == true,
      questions: questions,
      questionCount: questions.length,
      hasCompletedAttempts: row['has_completed_attempts'] == true,
    );
  }

  /// Student list: `GET /courses/{id}/quizzes/`. No questions, no correct flags.
  factory ModuleQuiz.fromCourseList(Map<String, dynamic> row) {
    return ModuleQuiz(
      id: _asInt(row['id']),
      section: _section(row['section']),
      title: _asString(row['title']) ?? '',
      description: _asString(row['description']) ?? '',
      passPercentage: _asInt(row['pass_percentage']) ?? 60,
      maxAttempts: _asInt(row['max_attempts']) ?? 1,
      timeLimitSeconds: _seconds(row['time_limit_seconds']),
      isPublished: true,
      questionCount: _asInt(row['question_count']) ?? 0,
      attemptsUsed: _asInt(row['attempts_used']) ?? 0,
      bestPercentage: _asDouble(row['best_percentage']),
      isPassed: row['is_passed'] == true,
    );
  }

  /// Student detail: `GET /student/quizzes/{id}/`. Options omit `is_correct`.
  factory ModuleQuiz.fromStudent(Map<String, dynamic> row) {
    final questions = [
      for (final item in _asList(row['questions']))
        if (item is Map) QuizQuestionDraft.fromJson(_stringKeyMap(item)),
    ]..sort((a, b) => a.order.compareTo(b.order));
    return ModuleQuiz(
      id: _asInt(row['id']),
      courseId: _asInt(row['course']),
      section: _section(row['section']),
      title: _asString(row['title']) ?? '',
      description: _asString(row['description']) ?? '',
      passPercentage: _asInt(row['pass_percentage']) ?? 60,
      maxAttempts: _asInt(row['max_attempts']) ?? 1,
      timeLimitSeconds: _seconds(row['time_limit_seconds']),
      isPublished: true,
      questions: questions,
      questionCount: questions.length,
    );
  }
}

class QuizQuestionDraft {
  const QuizQuestionDraft({
    required this.key,
    this.id,
    this.text = '',
    this.hint = '',
    this.explanation = '',
    this.marks = 1,
    this.points = 0,
    this.order = 0,
    this.options = const [],
  });

  /// Client identity. Survives a reorder; [id] does not exist until the save.
  final String key;
  final int? id;
  final String text;
  final String hint;
  final String explanation;
  final int marks;
  final int points;
  final int order;
  final List<QuizOptionDraft> options;

  QuizQuestionDraft copyWith({
    int? id,
    String? text,
    String? hint,
    String? explanation,
    int? marks,
    int? points,
    int? order,
    List<QuizOptionDraft>? options,
  }) {
    return QuizQuestionDraft(
      key: key,
      id: id ?? this.id,
      text: text ?? this.text,
      hint: hint ?? this.hint,
      explanation: explanation ?? this.explanation,
      marks: marks ?? this.marks,
      points: points ?? this.points,
      order: order ?? this.order,
      options: options ?? this.options,
    );
  }

  factory QuizQuestionDraft.fromJson(Map<String, dynamic> row) {
    final id = _asInt(row['id']);
    return QuizQuestionDraft(
      key: 'question-${id ?? _nextKey++}',
      id: id,
      text: _asString(row['text']) ?? '',
      hint: _asString(row['hint']) ?? '',
      explanation: _asString(row['explanation']) ?? '',
      marks: _asInt(row['marks']) ?? 1,
      points: _asInt(row['points']) ?? 0,
      order: _asInt(row['order']) ?? 0,
      options: [
        for (final item in _asList(row['options']))
          if (item is Map) QuizOptionDraft.fromJson(_stringKeyMap(item)),
      ],
    );
  }
}

class QuizOptionDraft {
  const QuizOptionDraft({
    required this.key,
    this.id,
    this.text = '',
    this.isCorrect = false,
  });

  final String key;
  final int? id;
  final String text;
  final bool isCorrect;

  QuizOptionDraft copyWith({int? id, String? text, bool? isCorrect}) {
    return QuizOptionDraft(
      key: key,
      id: id ?? this.id,
      text: text ?? this.text,
      isCorrect: isCorrect ?? this.isCorrect,
    );
  }

  factory QuizOptionDraft.fromJson(Map<String, dynamic> row) {
    final id = _asInt(row['id']);
    return QuizOptionDraft(
      key: 'option-${id ?? _nextKey++}',
      id: id,
      text: _asString(row['text']) ?? '',
      isCorrect: row['is_correct'] == true,
    );
  }
}

/// What the check-answer call tells the quiz screen.
class QuizCheckResult {
  const QuizCheckResult({
    required this.isCorrect,
    required this.correctOptionId,
    required this.explanation,
    required this.marksAwarded,
  });

  final bool isCorrect;
  final int correctOptionId;
  final String explanation;
  final double marksAwarded;

  factory QuizCheckResult.fromJson(Map<String, dynamic> row) {
    return QuizCheckResult(
      isCorrect: row['is_correct'] == true,
      correctOptionId: _asInt(row['correct_option']) ?? 0,
      explanation: _asString(row['explanation']) ?? '',
      marksAwarded: _asDouble(row['marks_awarded']) ?? 0,
    );
  }
}

/// The finished attempt, from `POST .../submit/`.
class QuizSubmitResult {
  const QuizSubmitResult({
    required this.attemptId,
    required this.score,
    required this.percentage,
    required this.isPassed,
    required this.pointsEarned,
  });

  final int attemptId;
  final double score;
  final double percentage;
  final bool isPassed;
  final int pointsEarned;

  factory QuizSubmitResult.fromJson(Map<String, dynamic> row) {
    final attempt = row['attempt'];
    final map = attempt is Map ? _stringKeyMap(attempt) : row;
    return QuizSubmitResult(
      attemptId: _asInt(map['id']) ?? 0,
      score: _asDouble(map['score']) ?? 0,
      percentage: _asDouble(map['percentage']) ?? 0,
      isPassed: map['is_passed'] == true,
      pointsEarned: _asInt(row['points_earned']) ?? 0,
    );
  }
}

/// The same rules the server enforces before it will publish a quiz.
///
/// Checked in the editor so the instructor sees the problem on the question
/// instead of as a 400 after the course has already gone live.
List<String> quizIssues(ModuleQuiz quiz) {
  final issues = <String>[];
  if (quiz.title.trim().isEmpty) {
    issues.add('Give the quiz a title.');
  }
  if (quiz.passPercentage < 0 || quiz.passPercentage > 100) {
    issues.add('Pass percentage must be between 0 and 100.');
  }
  if (quiz.maxAttempts < 1) {
    issues.add('Allow at least one attempt.');
  }
  if (quiz.questions.isEmpty) {
    issues.add('Add at least one question.');
    return issues;
  }
  for (var index = 0; index < quiz.questions.length; index++) {
    final question = quiz.questions[index];
    final label = 'Question ${index + 1}';
    if (question.text.trim().isEmpty) {
      issues.add('$label needs text.');
    }
    final filled = [
      for (final option in question.options)
        if (option.text.trim().isNotEmpty) option,
    ];
    if (filled.length < 2) {
      issues.add('$label needs at least two options.');
    }
    final correct = filled.where((option) => option.isCorrect).length;
    if (correct != 1) {
      issues.add('$label needs exactly one correct option.');
    }
  }
  return issues;
}

/// A blank question with four options, the first one marked correct.
QuizQuestionDraft blankQuestion({required String key, int order = 0}) {
  return QuizQuestionDraft(
    key: key,
    order: order,
    options: [
      for (var index = 0; index < 4; index++)
        QuizOptionDraft(key: '$key-option-$index', isCorrect: index == 0),
    ],
  );
}

const _keep = Object();

List<Object?> _asList(Object? value) {
  if (value is List) return value;
  return const [];
}

Map<String, dynamic> _stringKeyMap(Map<dynamic, dynamic> row) {
  return row.map((key, value) => MapEntry(key.toString(), value));
}

int _seconds(Object? value) {
  final seconds = _asInt(value);
  if (seconds == null || seconds < 15) return 180;
  if (seconds > 3600) return 3600;
  return seconds;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String? _asString(Object? value) {
  if (value is! String) return null;
  return value;
}

/// Blank and missing are the same section: the lessons with no module name.
String? _section(Object? value) {
  final text = _asString(value)?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

var _nextKey = 0;
