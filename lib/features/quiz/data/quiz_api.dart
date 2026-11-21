import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'module_quiz.dart';

/// Reads and writes for module quizzes.
///
/// The contract is `docs/module-quiz-backend.md`. Endpoints that already exist
/// (`/quizzes/`, `/questions/`, `/question-options/`, the course list, start,
/// submit) are called as they are today. `section`, hints, and
/// `POST .../answer/` are the additions that document asks the backend for.
/// Until those ship, a call fails as an [ApiException] and the screen says so
/// instead of pretending the quiz was saved.
class QuizApi {
  const QuizApi(this._client);

  final ApiClient _client;

  /// Every quiz on [courseId].
  ///
  /// Sends `?course=` (see the handoff). Also filters client-side, because a
  /// server that has not added the query yet still returns the instructor's
  /// other courses, and those must not show up on this one.
  Future<List<ModuleQuiz>> listForCourse(int courseId) async {
    final body = await _client.get<dynamic>(
      '/quizzes/',
      query: {'course': courseId},
    );
    return [
      for (final row in _rows(body))
        if (_asInt(row['course']) == courseId) ModuleQuiz.fromManagement(row),
    ];
  }

  /// Published quizzes a student can see on the course, with attempt status.
  Future<List<ModuleQuiz>> courseQuizzes(int courseId) async {
    final body = await _client.get<dynamic>('/courses/$courseId/quizzes/');
    return [for (final row in _rows(body)) ModuleQuiz.fromCourseList(row)];
  }

  Future<ModuleQuiz> studentQuiz(int quizId) async {
    final body = await _client.get<Map<String, dynamic>>(
      '/student/quizzes/$quizId/',
    );
    return ModuleQuiz.fromStudent(body);
  }

  /// Opens an attempt. Returns its id. A still-open attempt comes back as the
  /// same id instead of a second row — the server already does that.
  Future<int> start(int quizId) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/student/quizzes/$quizId/start/',
    );
    final id = _asInt(body['id']);
    if (id == null) {
      throw StateError('POST /student/quizzes/$quizId/start/ returned no id.');
    }
    return id;
  }

  Future<QuizCheckResult> answer(
    int attemptId, {
    required int questionId,
    required int optionId,
  }) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/student/quiz-attempts/$attemptId/answer/',
      data: {'question': questionId, 'selected_option': optionId},
    );
    return QuizCheckResult.fromJson(body);
  }

  Future<QuizSubmitResult> submit(
    int attemptId,
    List<({int questionId, int optionId})> answers,
  ) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/student/quiz-attempts/$attemptId/submit/',
      data: {
        'answers': [
          for (final answer in answers)
            {'question': answer.questionId, 'selected_option': answer.optionId},
        ],
      },
    );
    return QuizSubmitResult.fromJson(body);
  }

  /// Creates or updates the quiz, then writes the question diff.
  ///
  /// Questions are their own resources. The quiz payload's `questions` list is
  /// read-only on the server, so a save is one quiz write plus a create, patch,
  /// or delete per question and option that actually changed.
  ///
  /// [previous] is the last copy this client saved. Null means the quiz is new.
  /// Passing it is what makes a removed option become a DELETE instead of an
  /// orphan the next reload brings back.
  Future<ModuleQuiz> persist(
    ModuleQuiz quiz, {
    required int courseId,
    ModuleQuiz? previous,
  }) async {
    final id = quiz.id ?? await _createQuiz(quiz, courseId);
    if (quiz.id != null) await _patchQuiz(id, quiz);
    if (!quiz.hasCompletedAttempts) {
      await _syncQuestions(id, quiz.questions, previous?.questions ?? const []);
    }
    final fresh = await _client.get<Map<String, dynamic>>('/quizzes/$id/');
    return ModuleQuiz.fromManagement(fresh);
  }

  Future<ModuleQuiz> updateSection(ModuleQuiz quiz, String? section) async {
    final id = quiz.id;
    if (id == null) return quiz.copyWith(section: section);
    final body = await _client.patch<Map<String, dynamic>>(
      '/quizzes/$id/',
      data: {'section': section},
    );
    return ModuleQuiz.fromManagement(body);
  }

  Future<ModuleQuiz> publish(int quizId) async {
    final body = await _client.patch<Map<String, dynamic>>(
      '/quizzes/$quizId/',
      data: {'is_published': true},
    );
    return ModuleQuiz.fromManagement(body);
  }

  Future<void> deleteQuiz(int quizId) => _client.delete('/quizzes/$quizId/');

  Future<int> _createQuiz(ModuleQuiz quiz, int courseId) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/quizzes/',
      data: _quizPayload(quiz, courseId: courseId),
    );
    final id = _asInt(body['id']);
    if (id == null) throw StateError('POST /quizzes/ returned no id.');
    return id;
  }

  Future<void> _patchQuiz(int id, ModuleQuiz quiz) async {
    await _client.patch<Map<String, dynamic>>(
      '/quizzes/$id/',
      data: {
        'title': quiz.title.trim(),
        'description': quiz.description.trim(),
        'pass_percentage': quiz.passPercentage,
        'max_attempts': quiz.maxAttempts,
        'time_limit_seconds': quiz.timeLimitSeconds,
        'section': quiz.section,
      },
    );
  }

  Map<String, Object?> _quizPayload(ModuleQuiz quiz, {required int courseId}) {
    return {
      'course': courseId,
      'title': quiz.title.trim(),
      'description': quiz.description.trim(),
      'pass_percentage': quiz.passPercentage,
      'max_attempts': quiz.maxAttempts,
      'time_limit_seconds': quiz.timeLimitSeconds,
      'section': quiz.section,
    };
  }

  Future<void> _syncQuestions(
    int quizId,
    List<QuizQuestionDraft> next,
    List<QuizQuestionDraft> previous,
  ) async {
    final kept = {for (final question in next) question.id: question};
    for (final question in previous) {
      final id = question.id;
      if (id != null && !kept.containsKey(id)) {
        await _client.delete('/questions/$id/');
      }
    }

    for (var index = 0; index < next.length; index++) {
      final question = next[index];
      final id = question.id;
      final savedId = id ?? await _createQuestion(quizId, question, index);
      if (id != null) await _patchQuestion(savedId, question, index);
      final before = _previousQuestion(previous, id);
      await _syncOptions(
        savedId,
        question.options,
        before?.options ?? const [],
      );
    }
  }

  QuizQuestionDraft? _previousQuestion(
    List<QuizQuestionDraft> previous,
    int? id,
  ) {
    if (id == null) return null;
    for (final question in previous) {
      if (question.id == id) return question;
    }
    return null;
  }

  Future<int> _createQuestion(
    int quizId,
    QuizQuestionDraft question,
    int order,
  ) async {
    final body = await _client.post<Map<String, dynamic>>(
      '/questions/',
      data: _questionPayload(question, quizId: quizId, order: order),
    );
    final id = _asInt(body['id']);
    if (id == null) throw StateError('POST /questions/ returned no id.');
    return id;
  }

  Future<void> _patchQuestion(int id, QuizQuestionDraft question, int order) {
    return _client.patch<Map<String, dynamic>>(
      '/questions/$id/',
      data: _questionPayload(question, order: order),
    );
  }

  Map<String, Object?> _questionPayload(
    QuizQuestionDraft question, {
    int? quizId,
    required int order,
  }) {
    return {
      'quiz': ?quizId,
      'text': question.text.trim(),
      'marks': question.marks < 1 ? 1 : question.marks,
      'points': question.points,
      'order': order,
      'hint': question.hint.trim(),
      'explanation': question.explanation.trim(),
    };
  }

  Future<void> _syncOptions(
    int questionId,
    List<QuizOptionDraft> next,
    List<QuizOptionDraft> previous,
  ) async {
    final kept = {for (final option in next) option.id: option};
    for (final option in previous) {
      final id = option.id;
      if (id != null && !kept.containsKey(id)) {
        await _client.delete('/question-options/$id/');
      }
    }
    for (final option in next) {
      if (option.text.trim().isEmpty) continue;
      final id = option.id;
      if (id == null) {
        await _client.post<Map<String, dynamic>>(
          '/question-options/',
          data: _optionPayload(option, questionId: questionId),
        );
      } else {
        await _client.patch<Map<String, dynamic>>(
          '/question-options/$id/',
          data: _optionPayload(option),
        );
      }
    }
  }

  Map<String, Object?> _optionPayload(
    QuizOptionDraft option, {
    int? questionId,
  }) {
    return {
      'question': ?questionId,
      'text': option.text.trim(),
      'is_correct': option.isCorrect,
    };
  }
}

/// Answers no quizzes.
///
/// Player tests install this so opening a course does not leave for the
/// network. A course with no quiz rows is the real server's answer too, so the
/// lesson list under test is unchanged.
class EmptyQuizApi extends QuizApi {
  EmptyQuizApi() : super(ApiClient(Dio()));

  @override
  Future<List<ModuleQuiz>> listForCourse(int courseId) async => const [];

  @override
  Future<List<ModuleQuiz>> courseQuizzes(int courseId) async => const [];
}

final quizApiProvider = Provider<QuizApi>(
  (ref) => QuizApi(ref.watch(apiClientProvider)),
);

List<Map<String, dynamic>> _rows(Object? body) {
  final list = body is Map && body['results'] is List
      ? body['results'] as List
      : body;
  if (list is! List) return const [];
  return [
    for (final row in list)
      if (row is Map) row.map((key, value) => MapEntry(key.toString(), value)),
  ];
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
