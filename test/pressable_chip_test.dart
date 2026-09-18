import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/widgets/pressable_chip.dart';

/// Locks in the project-wide tap-feedback recipe so the "View" button on
/// Premium Courses and the Class 6-10 chips on Courses cannot drift apart.
void main() {
  Future<void> pumpChip(
    WidgetTester tester, {
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PressableChip(
              label: 'View',
              onTap: onTap,
              selected: selected,
            ),
          ),
        ),
      ),
    );
  }

  /// The shadow layer is the outermost AnimatedContainer's decoration.
  BoxDecoration decorationOf(WidgetTester tester) {
    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    return container.decoration! as BoxDecoration;
  }

  Offset shadowOffset(WidgetTester tester) =>
      decorationOf(tester).boxShadow!.first.offset;

  double shadowBlur(WidgetTester tester) =>
      decorationOf(tester).boxShadow!.first.blurRadius;

  testWidgets('rests 3px off the surface when idle', (tester) async {
    await pumpChip(tester, onTap: () {});
    expect(shadowOffset(tester), const Offset(0, 3));
    expect(shadowBlur(tester), 7);
  });

  testWidgets('travels down to 1px while the finger is held', (tester) async {
    await pumpChip(tester, onTap: () {});

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableChip)),
    );
    await tester.pump();

    expect(
      shadowOffset(tester),
      const Offset(0, 1),
      reason: 'press should collapse the shadow travel so the chip sits down',
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(shadowOffset(tester), const Offset(0, 3));
  });

  testWidgets('drops the top highlight while depressed', (tester) async {
    await pumpChip(tester, onTap: () {});

    int highlightLayers() => tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .where((box) {
          final decoration = box.decoration as BoxDecoration;
          final gradient = decoration.gradient;
          return gradient is LinearGradient &&
              gradient.colors.first == Colors.white.withValues(alpha: 0.58);
        })
        .length;

    expect(highlightLayers(), 1, reason: 'idle chip shows its specular edge');

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableChip)),
    );
    await tester.pump();

    expect(highlightLayers(), 0, reason: 'pressed chip should look carved in');

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('scales up on hover', (tester) async {
    await pumpChip(tester, onTap: () {});

    double scale() => tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    expect(scale(), 1.0);

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(tester.getCenter(find.byType(PressableChip))));
    await tester.pump();

    expect(scale(), 1.06);
  });

  testWidgets('selected chip stays pushed in after the tap', (tester) async {
    await pumpChip(tester, onTap: () {}, selected: true);
    expect(shadowOffset(tester), const Offset(0, 1));
  });

  testWidgets('fires onTap', (tester) async {
    var taps = 0;
    await pumpChip(tester, onTap: () => taps++);

    await tester.tap(find.byType(PressableChip));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });
}
