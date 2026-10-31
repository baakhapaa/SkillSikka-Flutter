import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// The font package exposes its test asset manifest through this internal API.
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_assets;
import 'package:skillsikka/features/courses/data/course_adapter.dart';
import 'package:skillsikka/features/courses/data/course_api.dart';
import 'package:skillsikka/features/skill_courses/presentation/skill_courses.dart';
import 'package:skillsikka/features/search/presentation/search_page.dart';

import 'support/courses_test_scope.dart';

/// A `GET /courses/` row for a skill course, in the server's field names.
///
/// Free unless [isPaid] is set — the free shape is the one the dev seed and
/// most published courses have.
Map<String, dynamic> skillRow(
  int id,
  String title,
  String category, {
  bool isPaid = false,
  String? price,
}) => {
  'id': id,
  'title': title,
  'description': 'Learn by doing.',
  'course_type': 'skill',
  'subject': null,
  'subject_name': null,
  'grade': null,
  'grade_name': null,
  'skill_category': 1,
  'skill_category_name': category,
  'is_paid': isPaid,
  'price': isPaid ? (price ?? '1299.00') : null,
  'thumbnail_url': '',
  'is_published': true,
  'average_rating': 4.5,
  'review_count': 8,
  'students_enrolled': 120,
  'lessons_count': 9,
  'total_duration_seconds': 3600,
  'instructor': 4,
  'instructor_name': 'Test Instructor',
  'learning_outcomes': <String>[],
  'requirements': <String>[],
};

class _FontAssets extends Fake implements AssetManifest {
  _FontAssets(this.paths);
  final List<String> paths;

  @override
  List<String> listAssets() => paths;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalManifest = font_assets.assetManifest;
  final originalFetching = GoogleFonts.config.allowRuntimeFetching;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const weights = [
    FontWeight.w300,
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
  ];
  const suffixes = [
    'Light',
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
  ];
  final aliases = {
    for (final family in ['Manrope', 'Figtree'])
      for (final suffix in suffixes) 'test-fonts/$family-$suffix.ttf',
  };

  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    font_assets.clearCache();
    // Use bundled Roboto for deterministic geometry, not typography goldens.
    final bytes = await rootBundle.load('assets/fonts/roboto/Regular.ttf');
    final loader = FontLoader('Roboto')..addFont(Future.value(bytes));
    await loader.load();
    font_assets.assetManifest = _FontAssets(aliases.toList());
    messenger.setMockMessageHandler('flutter/assets', (message) {
      final key = utf8.decode(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );
      if (aliases.contains(key)) return Future.value(bytes);
      return messenger.delegate.send('flutter/assets', message);
    });
    for (final weight in weights) {
      GoogleFonts.manrope(fontWeight: weight);
      GoogleFonts.figtree(fontWeight: weight);
    }
    await GoogleFonts.pendingFonts();
  });

  tearDown(() {
    messenger.setMockMessageHandler('flutter/assets', null);
    font_assets.assetManifest = originalManifest;
    font_assets.clearCache();
    GoogleFonts.config.allowRuntimeFetching = originalFetching;
  });

  // Three Coding courses so the carousel has its full three cards, plus one in
  // each other skill so every chip prints a real count.
  Widget app() => coursesTestScope(
    api: FakeCourseApi(
      catalogue: CoursePage(
        count: 6,
        courses: [
          for (final row in [
            skillRow(1, 'Python Basics', 'Coding'),
            skillRow(2, 'Coding Patterns', 'Coding'),
            skillRow(3, 'Coding Projects', 'Coding'),
            skillRow(4, 'Sketching', 'Drawing'),
            skillRow(5, 'Speaking', 'Public Speaking'),
            skillRow(6, 'Rhythm', 'Music'),
          ])
            CourseMapper.summary(row),
        ],
      ),
    ),
    child: MaterialApp(
      theme: ThemeData(
        fontFamily: 'Roboto',
        textTheme: ThemeData().textTheme.apply(fontFamilyFallback: ['Roboto']),
      ),
      home: const SkillCoursesPage(),
    ),
  );

  for (final width in [360.0, 400.0]) {
    testWidgets('search opens a focused editable field and returns at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app());
      await tester.pump();
      await tester.tap(find.byTooltip('Search courses'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchPage), findsOneWidget);
      final field = find.byType(TextField);
      expect(field, findsOneWidget);
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
      await tester.enterText(field, 'Python');
      expect(tester.widget<TextField>(field).controller!.text, 'Python');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SkillCoursesPage), findsOneWidget);
    });

    testWidgets('category and card spacing fits phone width $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app());
      await tester.pump();
      final lists = find.byType(ListView);
      expect(
        tester.widget<ListView>(lists.at(0)).padding,
        const EdgeInsets.symmetric(horizontal: 16),
      );
      expect(tester.getSize(lists.at(0)).height, 60);
      expect(tester.getSize(lists.at(1)).height, 260);
      final coding = find.ancestor(
        of: find.text('Coding'),
        matching: find.byType(AnimatedContainer),
      );
      final drawing = find.ancestor(
        of: find.text('Drawing'),
        matching: find.byType(AnimatedContainer),
      );
      expect(tester.getRect(coding).left, 16);
      expect(tester.getRect(drawing).left - tester.getRect(coding).right, 14);
      expect(
        tester.widget<AnimatedContainer>(coding).padding,
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
      await tester.drag(lists.at(1), const Offset(-250, 0));
      await tester.pumpAndSettle();
    });
  }

  group('the card price slot', () {
    Widget appWith(List<Map<String, dynamic>> rows) => coursesTestScope(
      api: FakeCourseApi(
        catalogue: CoursePage(
          count: rows.length,
          courses: [for (final row in rows) CourseMapper.summary(row)],
        ),
      ),
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        home: const SkillCoursesPage(),
      ),
    );

    testWidgets('a free course says Free, on the carousel and in the list', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        appWith([skillRow(1, 'Python Basics', 'Coding')]),
      );
      await tester.pumpAndSettle();

      // Both cards used to render an empty price slot, which reads as a price
      // that failed to load rather than as a course that costs nothing
      // (product decision, 2026-10-31).
      expect(find.text('Free'), findsWidgets);
    });

    testWidgets('a paid course states its price and never Free', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        appWith([
          skillRow(
            1,
            'Python Basics',
            'Coding',
            isPaid: true,
            price: '1299.00',
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rs. 1,299'), findsWidgets);
      expect(find.text('Free'), findsNothing);
    });
  });

  group('categories the design did not name', () {
    /// The builder offers all fifteen `LearningInterest` rows, so a course can
    /// be published in a category that has no chip. Before the chips were
    /// derived, that course was fetched, filtered out of every chip, and
    /// reachable by nobody — the "I added a course and it is not in the app"
    /// bug.
    Widget appWith(List<Map<String, dynamic>> rows) => coursesTestScope(
      api: FakeCourseApi(
        catalogue: CoursePage(
          count: rows.length,
          courses: [for (final row in rows) CourseMapper.summary(row)],
        ),
      ),
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        home: const SkillCoursesPage(),
      ),
    );

    testWidgets('a new category gets its own chip and is reachable', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        appWith([
          skillRow(1, 'Python Basics', 'Coding'),
          skillRow(2, 'Morning Flow', 'Yoga'),
        ]),
      );
      await tester.pumpAndSettle();

      // The four design chips are still there, and the new one follows them.
      expect(find.text('Coding'), findsOneWidget);
      final chips = find.byType(ListView).first;
      await tester.drag(chips, const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('Yoga'), findsOneWidget);
      await tester.tap(find.text('Yoga'));
      await tester.pumpAndSettle();

      expect(find.text('Morning Flow'), findsWidgets);
      expect(find.text('Python Basics'), findsNothing);
    });

    testWidgets('a course with no category lands in Other, not nowhere', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        appWith([
          skillRow(1, 'Python Basics', 'Coding'),
          skillRow(2, 'Unfiled Course', ''),
        ]),
      );
      await tester.pumpAndSettle();

      final chips = find.byType(ListView).first;
      await tester.drag(chips, const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('Other'), findsOneWidget);
      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();

      expect(find.text('Unfiled Course'), findsWidgets);
    });
  });
}
