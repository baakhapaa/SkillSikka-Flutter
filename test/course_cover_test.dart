import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/widgets/course_cover_tile.dart';
import 'package:skillsikka/core/widgets/course_image.dart';

/// The cover a course has when its instructor has not uploaded one.
///
/// **The bug this covers**: the catalogue used to swap in a stock illustration
/// matched by subject/title keyword, so `paytest` — a Coding course with no
/// cover — was drawn with the Python logo. The instructor never uploaded that,
/// and the builder previewed a gold initials tile for the same course. Now an
/// empty cover is empty everywhere, and every surface draws the same tile.
void main() {
  group('courseInitials', () {
    test('two words print one letter each', () {
      expect(courseInitials('Design Thinking'), 'DT');
    });

    test('one word prints its first two letters', () {
      expect(courseInitials('paytest'), 'PA');
    });

    test('a blank title still prints something', () {
      expect(courseInitials('   '), 'NEW');
      expect(courseInitials(''), 'NEW');
    });
  });

  group('a course with no cover', () {
    testWidgets('draws the initials tile, not an image', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 120,
              height: 90,
              child: CourseImage('', title: 'paytest', coverSeed: 3),
            ),
          ),
        ),
      );

      expect(find.text('PA'), findsOneWidget);
      // No stock illustration and no grey placeholder icon: an empty path is a
      // course without a cover, not a broken image.
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.image), findsNothing);
    });

    testWidgets('the tint is seeded by the course, not random', (tester) async {
      Future<List<Color>> tintOf(int seed) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 120,
                height: 90,
                child: CourseCoverTile('paytest', seed: seed),
              ),
            ),
          ),
        );
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(CourseCoverTile),
            matching: find.byType(Container),
          ),
        );
        final gradient =
            (container.decoration! as BoxDecoration).gradient!
                as LinearGradient;
        return gradient.colors;
      }

      final first = await tintOf(0);
      final same = await tintOf(0);
      final other = await tintOf(1);

      // Same course, same colour — a grid that reshuffles on every rebuild
      // reads as a loading state that never settles.
      expect(same, first);
      // Different courses are told apart by tint.
      expect(other, isNot(first));
    });
  });
}
