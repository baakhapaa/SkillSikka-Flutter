import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// The font package exposes its test asset manifest through this internal API.
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_assets;
import 'package:skillsikka/features/login_screen/presentation/login_screen_page.dart';

class _FontAssets extends Fake implements AssetManifest {
  _FontAssets(this.paths);
  final List<String> paths;

  @override
  List<String> listAssets() => paths;
}

/// The phone the overflow was reported on: a 360x800 screen with a 38.5pt
/// status bar and a 24pt gesture inset, which leaves 737.5pt for the form.
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

  testWidgets('the whole login form fits one 360x800 screen', (tester) async {
    await tester.binding.setSurfaceSize(_screen);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: _screen, padding: _insets),
          child: LoginScreenPage(),
        ),
      ),
    );
    await tester.pump();

    final problems = <Object>[];
    for (var e = tester.takeException(); e != null; e = tester.takeException()) {
      problems.add(e);
    }
    expect(problems, isEmpty, reason: 'the login screen raised during layout');

    // NOTE ON FONTS: `flutter test` cannot fetch Manrope, so this harness
    // substitutes Roboto as the repo's other widget tests do. Roboto's line box
    // is 1.17em against Manrope's 1.37em, so every text block here is ~15%
    // shorter than on a real device: the form measures ~687pt on a phone and
    // ~661pt here. The assertions below therefore have ~26pt of extra margin —
    // they still fail on the pre-fix layout by a wide margin (the sign-up line
    // sat 52.5pt below the safe area and the page scrolled 48.5pt).

    final signup = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.textSpan?.toPlainText().contains('have an account') ?? false),
    );
    expect(signup, findsOneWidget);

    // The reported bug: this line rendered below the fold, so it could not be
    // read without scrolling.
    expect(
      tester.getRect(signup).bottom,
      lessThanOrEqualTo(_safeBottom),
      reason: 'the "Don\'t have an account?" line runs past the safe area',
    );

    // "One page" means no scrolling at all, which is a stronger claim than
    // "the last widget is on screen": it also fails if any spacer grows.
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
      reason: 'the login form does not fit one screen — it still scrolls',
    );

    // The column fills the viewport, so the sign-up line is anchored to the
    // bottom instead of floating in the middle of the page.
    expect(
      _safeBottom - tester.getRect(signup).bottom,
      lessThanOrEqualTo(40),
      reason: 'the sign-up line is stranded above the bottom of the page',
    );
  });
}
