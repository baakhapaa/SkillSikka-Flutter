import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/courses/data/course_adapter.dart';
import 'package:skillsikka/features/courses/data/course_api.dart';
import 'package:skillsikka/features/learning/data/enrollment.dart';
import 'package:skillsikka/features/learning/presentation/course_player_page.dart';
import 'package:skillsikka/features/quiz/data/module_quiz.dart';
import 'package:skillsikka/features/quiz/data/quiz_api.dart';

import 'support/courses_test_scope.dart';
import 'support/home_page_font_harness.dart';

void main() {
  installHomePageFontHarness();

  group('ModuleQuiz parsing', () {
    test('reads an instructor quiz, including the module and the hint', () {
      final quiz = ModuleQuiz.fromManagement({
        'id': 7,
        'course': 42,
        'section': 'Forces and motion',
        'title': 'Forces Quiz',
        'description': '',
        'pass_percentage': 60,
        'max_attempts': 2,
        'is_published': false,
        'has_completed_attempts': false,
        'questions': [
          {
            'id': 15,
            'text': 'What is the SI unit of force?',
            'hint': 'A push or a pull.',
            'explanation': 'A newton (N) is the SI unit of force.',
            'marks': 1,
            'points': 0,
            'order': 0,
            'options': [
              {'id': 60, 'text': 'Newton', 'is_correct': true},
              {'id': 61, 'text': 'Joule', 'is_correct': false},
            ],
          },
        ],
      });

      expect(quiz.section, 'Forces and motion');
      expect(quiz.questions.single.hint, 'A push or a pull.');
      expect(quiz.questions.single.options.first.isCorrect, isTrue);
      expect(quiz.count, 1);
    });

    test('reads the student list, including a decimal best score', () {
      final quiz = ModuleQuiz.fromCourseList({
        'id': 7,
        'section': 'Foundations',
        'title': 'Forces Quiz',
        'description': '',
        'pass_percentage': 60,
        'max_attempts': 2,
        'question_count': 3,
        'attempts_used': 1,
        'best_percentage': '50.00',
        'is_passed': false,
      });

      expect(quiz.bestPercentage, 50);
      expect(quiz.statusLabel, 'Best 50% · Retry');
      expect(quiz.canRetry, isTrue);
    });

    test('a passed quiz and a spent quiz say so', () {
      const passed = ModuleQuiz(
        isPassed: true,
        bestPercentage: 80,
        attemptsUsed: 1,
        maxAttempts: 2,
      );
      const spent = ModuleQuiz(attemptsUsed: 1, maxAttempts: 1);
      const fresh = ModuleQuiz();

      expect(passed.statusLabel, 'Passed 80%');
      expect(spent.statusLabel, 'No attempts left');
      expect(fresh.statusLabel, 'Optional');
    });

    test('a blank section is the same as no section', () {
      final quiz = ModuleQuiz.fromCourseList({
        'id': 1,
        'section': '  ',
        'title': 'Loose ends',
        'pass_percentage': 40,
        'max_attempts': 1,
        'question_count': 0,
        'attempts_used': 0,
        'best_percentage': null,
        'is_passed': false,
      });
      expect(quiz.section, isNull);
    });
  });

  group('quizIssues', () {
    test('rejects an empty quiz and a question with two correct options', () {
      const empty = ModuleQuiz(title: '');
      expect(quizIssues(empty), contains('Give the quiz a title.'));
      expect(quizIssues(empty), contains('Add at least one question.'));

      final both = ModuleQuiz(
        title: 'Forces Quiz',
        questions: [
          QuizQuestionDraft(
            key: 'q',
            text: 'Unit of force?',
            options: const [
              QuizOptionDraft(key: 'a', text: 'Newton', isCorrect: true),
              QuizOptionDraft(key: 'b', text: 'Joule', isCorrect: true),
            ],
          ),
        ],
      );
      expect(
        quizIssues(both).single,
        'Question 1 needs exactly one correct option.',
      );
    });

    test('accepts one question with one correct option', () {
      final filled = ModuleQuiz(
        title: 'Forces Quiz',
        questions: [
          const QuizQuestionDraft(
            key: 'q',
            text: 'Unit of force?',
            options: [
              QuizOptionDraft(key: 'a', text: 'Newton', isCorrect: true),
              QuizOptionDraft(key: 'b', text: 'Joule'),
            ],
          ),
        ],
      );
      expect(quizIssues(filled), isEmpty);
    });
  });

  testWidgets('the lesson list shows a quiz only under its own module', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final course = CourseMapper.detail(
      course: {
        'id': 99,
        'title': 'Drawing from Observation',
        'description': 'Learn by doing.',
        'course_type': 'skill',
        'skill_category': 13,
        'skill_category_name': 'Drawing',
        'is_paid': false,
        'price': null,
        'thumbnail_url': '',
        'is_published': true,
        'average_rating': null,
        'review_count': 0,
        'students_enrolled': 0,
        'lessons_count': 2,
        'total_duration_seconds': 120,
        'instructor': 4,
        'instructor_name': 'Test Instructor',
        'learning_outcomes': <String>[],
        'requirements': <String>[],
        'updated_at': '2026-10-27T06:04:13.639481Z',
      },
      lessons: [
        {
          'id': 1,
          'title': 'Light',
          'content_type': 'video',
          'content_url': '',
          'section': 'Foundations',
          'order': 1,
          'duration_seconds': 60,
        },
        {
          'id': 2,
          'title': 'Hue',
          'content_type': 'video',
          'content_url': '',
          'section': 'Colour',
          'order': 2,
          'duration_seconds': 60,
        },
      ],
    );

    final container = ProviderContainer(
      overrides: [
        courseApiProvider.overrideWithValue(FakeCourseApi()),
        quizApiProvider.overrideWithValue(
          _ScriptedQuizApi([
            const ModuleQuiz(
              id: 7,
              section: 'Foundations',
              title: 'Forces Quiz',
              questionCount: 3,
              isPublished: true,
            ),
            const ModuleQuiz(
              id: 8,
              section: 'Nowhere',
              title: 'Lost Quiz',
              questionCount: 1,
              isPublished: true,
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(enrolledCoursesProvider.notifier).record(course);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: CoursePlayerPage(course: course)),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Foundations'), findsOneWidget);
    expect(find.text('Colour'), findsOneWidget);
    expect(find.text('Forces Quiz'), findsOneWidget);
    expect(find.text('Module quiz · 3 questions'), findsOneWidget);
    expect(find.text('Optional'), findsOneWidget);
    expect(find.text('Lost Quiz'), findsNothing);
  });
}

class _ScriptedQuizApi extends EmptyQuizApi {
  _ScriptedQuizApi(this.rows);

  final List<ModuleQuiz> rows;

  @override
  Future<List<ModuleQuiz>> courseQuizzes(int courseId) async => rows;
}
