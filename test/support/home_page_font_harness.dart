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

    // **`await` this one. It is load-bearing, and dropping it costs the whole
    // home-page layout suite.** Do not "fix" the hang by removing the await.
    //
    // `googleFontsTextStyle` (google_fonts_base.dart:110-117) returns the
    // `TextStyle` *synchronously* — `fontFamily: 'Manrope_w700'` plus
    // `fontFamilyFallback: ['Manrope']` — and does not wait for the load. What
    // the load does is register that family in the engine's font table. So all
    // the `await` buys is that the family exists before the first layout pass,
    // and that is the entire difference between:
    //
    //   registered    → every glyph is Roboto's, ~0.5em average advance
    //   unregistered  → nothing matches `fontFamily`, so the text falls back to
    //                   **Ahem**, the framework's default test font: one square
    //                   per glyph, advance exactly 1.0em.
    //                   (flutter_test matchers.dart:534 — "the Flutter framework
    //                   uses a font called 'Ahem' which shows squares instead of
    //                   characters".)
    //
    // Ahem is what the 2026-10-12 run saw, and it is why the overflows were
    // *huge* rather than a few pixels:
    //
    //   home_page.dart:1485  the featured-course author Row. Observed
    //                       **525px of children in a 296px box — 229 over**
    //                       (296 at 360pt, 336 at 400pt; children 525 either
    //                       way). Ahem predicts 514. The same row in Roboto is
    //                       ~280 and fits with room to spare.
    //   home_page.dart:1838  the Recommended-Books tag Row. Observed **294 and
    //                       318px**, again identical at 360 and 400. Ahem
    //                       predicts 288/288/312 — a uniform +6 is just
    //                       `_buildTag`'s padding+border, not a font difference.
    //
    // The giveaway is that those widths do not change with the surface width:
    // intrinsic widths that ignore their parent are not "a bit too wide", they
    // are the wrong font. Four tests failed on it — every HomePage test using
    // this harness, at 360 and at 400.
    //
    // `pendingFonts()` is `Future.wait(pendingFontFutures)` over a
    // *library-global* set (google_fonts_base.dart:35), and the prewarm above
    // has just put one future in it per resolved style. Each is served by the
    // mocked `flutter/assets` handler installed a few lines up, which answers
    // with `Future.value(bytes)` — a microtask, with no timer, no socket and no
    // plugin in the path — so this wait cannot hang on its own. See `tearDown`
    // for the futures that *can* strand, and why `clear()` there is what keeps
    // the next test alive.
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
    //
    // **Why `setUp`'s `await` is safe and this `clear()` is still needed.**
    // They cover different futures. The prewarm's own futures are served by the
    // mocked `flutter/assets` handler installed above, which answers with
    // `Future.value(bytes)` — a microtask, no timer and no socket — so waiting
    // on them cannot hang. THIS line exists for the loads the *test body*
    // starts instead: HomePage resolves weights the prewarm does not cover, and
    // any of those still in flight when the body returns is stranded, because
    // the removal is `loadingFuture.then((_) => set.remove(...))` registered in
    // the body's fake-async zone — and `flutter test` tears that zone down the
    // moment the body completes, before `tearDown` runs. `clear()` drops those
    // entries unconditionally instead of waiting on a future that can never
    // settle. Waiting here would hang for the same reason the stranded future
    // does.
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
