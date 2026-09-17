import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsikka/features/home/presentation/instructor_carousel.dart';

void main() {
  for (final width in [360.0, 400.0]) {
    testWidgets(
      'all portraits fill the strip on tap without edge gaps at $width',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: InstructorCarousel())),
        );
        Finder card(int index) =>
            find.byKey(ValueKey('instructor-card-$index'));
        for (var i = 0; i < 4; i++) {
          expect(card(i), findsOneWidget);
        }
        final firstWidth = tester.getSize(card(0)).width;
        expect(firstWidth, greaterThan(tester.getSize(card(1)).width * 3));
        for (final selected in [3, 1, 0, 2]) {
          await tester.tap(card(selected));
          await tester.pumpAndSettle();
          expect(
            tester.getSize(card(selected)).width,
            closeTo(firstWidth, 0.1),
          );
          if (width == 360) {
            debugPrint(
              'selected=$selected bounds=${List.generate(4, (i) => tester.getRect(card(i)))} content=[18, ${width - 18}]',
            );
          }
          expect(tester.getRect(card(0)).left, closeTo(18, 0.1));
          expect(tester.getRect(card(3)).right, closeTo(width - 18, 0.1));
          for (var i = 0; i < 3; i++) {
            final gap =
                tester.getRect(card(i + 1)).left -
                tester.getRect(card(i)).right;
            expect(gap, closeTo(i == 0 ? 16 : 8, 0.01));
          }
          await tester.drag(card(selected), const Offset(-120, 0));
          await tester.pumpAndSettle();
          expect(
            tester.getSize(card(selected)).width,
            closeTo(firstWidth, 0.1),
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
