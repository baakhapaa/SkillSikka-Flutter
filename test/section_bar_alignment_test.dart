import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// The font package exposes its test asset manifest through this internal API.
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_assets;
import 'package:skillsikka/core/widgets/section_bar.dart';
import 'package:skillsikka/features/home/presentation/home_page.dart';

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
    for (final family in ['Manrope', 'Figtree', 'Inter'])
      for (final suffix in suffixes) 'test-fonts/$family-$suffix.ttf',
  };

  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    font_assets.clearCache();
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
      GoogleFonts.inter(fontWeight: weight);
    }
    await GoogleFonts.pendingFonts();
  });

  tearDown(() {
    messenger.setMockMessageHandler('flutter/assets', null);
    font_assets.assetManifest = originalManifest;
    font_assets.clearCache();
    GoogleFonts.config.allowRuntimeFetching = originalFetching;
  });

  /// Drains layout exceptions raised by parts of the home page this test does
  /// not own, so an unrelated pre-existing overflow can't mask a real failure
  /// here. Anything that is not a RenderFlex overflow still fails the test.
  void drainUnrelatedOverflows(WidgetTester tester) {
    for (var e = tester.takeException(); e != null; e = tester.takeException()) {
      expect(
        e.toString(),
        contains('overflowed'),
        reason: 'unexpected non-overflow exception on the home page',
      );
    }
  }

  Future<void> pumpHome(WidgetTester tester, double width) async {
    await tester.binding.setSurfaceSize(Size(width, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pump();
  }

  // NOTE: kept as a single test on purpose. Pumping HomePage twice in one file
  // hangs the second test (see home_heading_alignment_test.dart, same symptom),
  // so both checks share one pump.
  testWidgets('home section headings and enrollment block are aligned', (
    tester,
  ) async {
    // 360x800 is the phone the enrollment bug was reported on.
    await pumpHome(tester, 360);

    for (final title in ['Explore our Top instructors', 'Get Premium Courses']) {
      final row = find
          .ancestor(of: find.text(title), matching: find.byType(Row))
          .first;
      final bar = find.descendant(of: row, matching: find.byType(SectionBar));
      expect(bar, findsOneWidget, reason: title);

      final barRect = tester.getRect(bar);
      final titleRect = tester.getRect(find.text(title));
      // For Manrope/Roboto the line-box centre sits within ~0.25px of the
      // heading's cap-height centre, so this is the optical centre too.
      // The old `Text('|')` version was ~3.5px above it.
      expect(
        barRect.center.dy,
        closeTo(titleRect.center.dy, 0.5),
        reason: '$title: accent bar is not vertically centred on the heading',
      );
    }

    final label = find.text('ENROLLMENT').first;
    final price = find.text('Rs.24.99').first;
    final pill = find
        .ancestor(of: label, matching: find.byType(Container))
        .first;
    final stack = find.ancestor(of: label, matching: find.byType(Column)).first;

    expect(
      tester.getRect(stack).center.dy,
      closeTo(tester.getRect(pill).center.dy, 0.5),
      reason: 'enrollment stack is not vertically centred in the pill',
    );
    // The two 1.0-height line boxes only leave ~3px of air on their own, which
    // reads as the price colliding with the label.
    expect(
      tester.getRect(price).top - tester.getRect(label).bottom,
      greaterThanOrEqualTo(5),
      reason: 'price is crowding the ENROLLMENT label',
    );

    // The label and the price must each render on ONE line, and the stack must
    // fit inside the pill. A fixed 69pt spacer used to starve the column: on a
    // 360pt device only 52pt was left for 'ENROLLMENT', which needs 72pt, so
    // the pill rendered "ENROLLM / ENT" and "Rs.24. / 99" and overflowed by 1px.
    for (final (finder, text, lineHeight) in [
      (label, 'ENROLLMENT', 10.0),
      (price, 'Rs.24.99', 17.0),
    ]) {
      final rect = tester.getRect(finder);
      expect(
        rect.height,
        lessThan(lineHeight * 1.5),
        reason: '$text wrapped onto a second line at 360pt',
      );
      // Also prove nothing was ellipsised: a truncated run would be clamped to
      // the available width, i.e. narrower than the unconstrained string.
      final style = tester.widget<Text>(finder).style!;
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(
        rect.width,
        greaterThanOrEqualTo(painter.width - 1.0),
        reason: '$text was truncated at 360pt',
      );
    }
    expect(
      tester.getRect(stack).height,
      lessThanOrEqualTo(tester.getRect(pill).height),
      reason: 'the enrollment stack does not fit inside the pill',
    );

    drainUnrelatedOverflows(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
