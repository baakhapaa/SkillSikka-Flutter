import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// The font package exposes its test asset manifest through this internal API.
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_assets;
import 'package:skillsikka/features/signup/presentation/signup_role_page.dart';

class _FontAssets extends Fake implements AssetManifest {
  _FontAssets(this.paths);
  final List<String> paths;

  @override
  List<String> listAssets() => paths;
}

/// The phone the overflow was reported on: a 360x800 screen with a 38.5pt
/// status bar and a 24pt gesture inset, which leaves 737.5pt for the page.
const _screen = Size(360, 800);
const _insets = EdgeInsets.only(top: 38.5, bottom: 24);
const _safeBottom = 800 - 24;

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
    FontWeight.w900,
  ];
  const suffixes = [
    'Light',
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
    'Black',
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

  testWidgets('the Continue button clears the safe area on a 360x800 screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(_screen);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: _screen, padding: _insets),
          child: SignupRolePage(),
        ),
      ),
    );
    await tester.pump();

    final problems = <Object>[];
    for (var e = tester.takeException(); e != null; e = tester.takeException()) {
      problems.add(e);
    }
    expect(problems, isEmpty, reason: 'the role step raised during layout');

    // NOTE ON FONTS: `flutter test` cannot fetch Manrope, so this harness
    // substitutes Roboto (1.17em line box against Manrope's 1.37em). Every text
    // block here is therefore ~15% short, which hands the assertions ~20pt of
    // extra margin. On a device the column is 695pt and this page is tuned to
    // leave ~26pt of slack, so the numbers below are still the right shape —
    // but they do not replace a device check.
    final cta = find.widgetWithText(FilledButton, 'Continue');
    expect(cta, findsOneWidget);

    // The reported bug: the primary action sat 20.5pt below the safe area.
    expect(
      tester.getRect(cta).bottom,
      lessThanOrEqualTo(_safeBottom),
      reason: 'the Continue button runs past the safe area',
    );

    // "Fits" means no scrolling at all — the column used to be 16pt taller than
    // the space its own padding left, so the page scrolled even when it fitted.
    final scrollable = find
        .descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(
      position.maxScrollExtent,
      0,
      reason: 'the role step does not fit one screen — it still scrolls',
    );

    // And it is anchored to the bottom rather than stranded in the middle.
    expect(
      _safeBottom - tester.getRect(cta).bottom,
      lessThanOrEqualTo(40),
      reason: 'the Continue button is stranded above the bottom of the page',
    );
  });
}
