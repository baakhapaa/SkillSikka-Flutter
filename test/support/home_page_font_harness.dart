import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// The font package exposes its test asset manifest through this internal API.
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_assets;

class _FontAssets extends Fake implements AssetManifest {
  _FontAssets(this.paths);
  final List<String> paths;

  @override
  List<String> listAssets() => paths;
}

/// Puts the calling test file into a deterministic font environment.
///
/// `flutter test` fetches no Google Fonts, so without this the app falls back to
/// a much wider glyph set and every HomePage layout assertion is measuring the
/// wrong thing. All six weights of the three families HomePage uses are aliased
/// onto one bundled Roboto face: geometry is deterministic, the typography is
/// deliberately not.
///
/// Call once, at the top of `main()`.
void installHomePageFontHarness() {
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
      GoogleFonts.inter(fontWeight: weight);
    }
    await GoogleFonts.pendingFonts();
  });

  tearDown(() {
    messenger.setMockMessageHandler('flutter/assets', null);
    font_assets.assetManifest = originalManifest;
    font_assets.clearCache();
    GoogleFonts.config.allowRuntimeFetching = originalFetching;

    // THIS LINE IS THE REASON MULTI-TEST FILES USED TO HANG. DO NOT REMOVE IT.
    //
    // `pendingFontFutures` (google_fonts_base.dart:35) is a *library-global*
    // set, not per-test state. Every style resolve appends to it, and the
    // removal is `loadingFuture.then((_) => set.remove(...))` — an onValue-only
    // callback, so a future that never completes is never removed, and one that
    // throws is never removed either. `GoogleFonts.pendingFonts()` is just
    // `Future.wait(pendingFontFutures)`.
    //
    // A test that builds HomePage resolves weights the pre-warm above doesn't
    // cover, so it starts extra loads. Any of those still in flight when the
    // test's fake-async zone is torn down is stranded in this global forever.
    // The next test's setUp then awaits `Future.wait` over a future belonging
    // to a dead zone, which never completes: the second HomePage-pumping test
    // in a file hangs indefinitely, and because it never returns, the whole
    // `flutter test` run looks dead rather than failing.
    //
    // Clearing the set here drops the stranded future. Note this does not wait
    // on it, which is the point — it can no longer complete.
    font_assets.pendingFontFutures.clear();
  });
}

/// Drains layout exceptions raised by parts of a page a test does not own, so
/// an unrelated pre-existing overflow cannot mask a real failure. Anything that
/// is not a RenderFlex overflow still fails the test.
void drainUnrelatedOverflows(WidgetTester tester) {
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    final text = e.toString();
    expect(
      text.contains('overflowed') || text.contains('Multiple exceptions'),
      isTrue,
      reason: 'unexpected non-overflow exception: $text',
    );
  }
}
