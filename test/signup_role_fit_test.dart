import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
const _phone = Size(360, 800);
const _phoneInsets = EdgeInsets.only(top: 38.5, bottom: 24);

/// The other reported case: Chrome DevTools emulating an iPhone 16 Pro Max, so
/// the app is a Flutter web canvas with no system insets at all.
const _tall = Size(440, 956);

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

  // NOTE ON FONTS: `flutter test` cannot fetch Manrope, so this harness
  // substitutes Roboto (1.17em line box against Manrope's 1.37em). Every text
  // block is therefore ~15% short, which hands the assertions ~20pt of extra
  // margin. The measured device numbers are quoted in the comments so a failure
  // can be told apart from the font gap.
  //
  // Both viewports share one testWidgets on purpose: pumping the same page from
  // two tests in one file hangs the second one (see home_heading_alignment_test).
  testWidgets('the role step fits a phone and a tall viewport', (tester) async {
    Future<void> pumpAt(Size size, EdgeInsets insets) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        // The role step records the chosen role in the profile store, so it is
        // a ConsumerStatefulWidget and needs a scope even though this test only
        // measures layout.
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: size, padding: insets),
              child: const SignupRolePage(),
            ),
          ),
        ),
      );
      await tester.pump();
      final problems = <Object>[];
      for (
        var e = tester.takeException();
        e != null;
        e = tester.takeException()
      ) {
        problems.add(e);
      }
      expect(problems, isEmpty, reason: 'the role step raised during layout');
    }

    double scrollExtent() {
      final scrollable = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      return tester.state<ScrollableState>(scrollable).position.maxScrollExtent;
    }

    final cta = find.widgetWithText(FilledButton, 'Continue');
    // The form block's first painted element. (The wordmark is an asset and does
    // not paint in a golden, but its box still reports a rect.)
    final formTop = find.byType(Image).first;
    final header = find.text('Step: 1 of 4');

    // --- the phone: everything must fit with the CTA above the safe area ---
    await pumpAt(_phone, _phoneInsets);
    const phoneSafeBottom = 800 - 24;
    expect(cta, findsOneWidget);

    // The originally reported bug: the button sat at 744.5..796.5 on a device,
    // i.e. 20.5pt below the safe area.
    expect(
      tester.getRect(cta).bottom,
      lessThanOrEqualTo(phoneSafeBottom),
      reason: 'the Continue button runs past the safe area',
    );

    // "Fits" means no scrolling at all — the column used to be 16pt taller than
    // the space its own padding left, so the page scrolled even when it fitted.
    expect(
      scrollExtent(),
      0,
      reason: 'the role step does not fit one screen — it still scrolls',
    );

    // And it is anchored to the bottom rather than stranded in the middle.
    // On a device the clearance is exactly the 16pt page padding.
    expect(
      phoneSafeBottom - tester.getRect(cta).bottom,
      lessThanOrEqualTo(40),
      reason: 'the Continue button is stranded above the bottom of the page',
    );

    // --- a short Android (360x640): the spacing must tighten to fit it ---
    // 592pt of viewport against ~651pt of content at the design gaps, so this
    // one only fits because the gaps shrink below 737.5pt. It needed 74pt of
    // scrolling before that.
    await pumpAt(
      const Size(360, 640),
      const EdgeInsets.only(top: 24, bottom: 24),
    );
    expect(
      scrollExtent(),
      0,
      reason: 'the role step should fit a 360x640 phone without scrolling',
    );
    expect(
      616 - tester.getRect(cta).bottom,
      greaterThanOrEqualTo(0),
      reason: 'the Continue button falls below the fold on a short phone',
    );

    // --- the smallest phone still sold: iPhone SE 3 / 8 at 375x667 ---
    // A home-button iPhone has no bottom inset, so the viewport is 647pt.
    // This is the boundary case for "works on any phone": everything larger
    // (Galaxy A 360x780, iPhone mini 375x812, Pixel 412x915, 430x932) has more
    // room. Devices below it (320x568, a 360x640 Android) scroll instead.
    await pumpAt(const Size(375, 667), const EdgeInsets.only(top: 20));
    expect(
      scrollExtent(),
      0,
      reason: 'the role step should fit the smallest phone still on sale',
    );
    // A home-button iPhone has no bottom inset, so the safe bottom is 667.
    expect(
      667 - tester.getRect(cta).bottom,
      greaterThanOrEqualTo(0),
      reason: 'the Continue button falls below the fold on an iPhone SE',
    );

    // --- switching roles must not move the page ---
    // The A55 size. The selected card's 2pt border used to shave 2pt off the
    // description's width, which on a 360pt phone pushed it onto a fourth line:
    // the card grew 20pt and the logo/title/subtitle jumped 9pt. Padding and
    // border now total 20pt in both states, so the content width — the root
    // cause, and independent of the font — is identical either way.
    await pumpAt(
      const Size(360, 780),
      const EdgeInsets.only(top: 28, bottom: 24),
    );

    double contentWidth(String cardTitle) => tester
        .getRect(
          find
              .ancestor(
                of: find.text(cardTitle),
                matching: find.byType(Expanded),
              )
              .first,
        )
        .width;
    Rect cardOf(String cardTitle) =>
        tester.getRect(find.widgetWithText(GestureDetector, cardTitle).first);

    final studentWidth = contentWidth('I am a Student');
    final instructorWidth = contentWidth('I am an Instructor');
    final studentHeight = cardOf('I am a Student').height;
    final titleTop = tester.getRect(find.text('Choose Your Role')).top;

    await tester.tap(find.text('I am an Instructor'));
    await tester.pump();

    expect(
      contentWidth('I am a Student'),
      closeTo(studentWidth, 0.01),
      reason: 'the selected card narrows its own text column',
    );
    expect(
      contentWidth('I am an Instructor'),
      closeTo(instructorWidth, 0.01),
      reason: 'the deselected card widens its own text column',
    );
    expect(
      cardOf('I am a Student').height,
      closeTo(studentHeight, 0.01),
      reason: 'the card changes height when the selection moves',
    );
    expect(
      tester.getRect(find.text('Choose Your Role')).top,
      closeTo(titleTop, 0.5),
      reason: 'the section above the cards shifts when switching roles',
    );

    // --- the tall viewport: the form must not be pushed into the bottom half ---
    await pumpAt(_tall, EdgeInsets.zero);
    const tallSafeBottom = 956.0;
    expect(
      tallSafeBottom - tester.getRect(cta).bottom,
      lessThanOrEqualTo(40),
      reason: 'on a tall viewport the CTA is not pinned to the bottom',
    );
    // A two-child column put every spare point into one gap and started the form
    // at y=458 of 956. Splitting the slack across two gaps puts it at y=230.
    expect(
      tester.getRect(formTop).top,
      lessThan(0.35 * _tall.height),
      reason: 'on a tall viewport the form drifts into the bottom half',
    );
    expect(
      tester.getRect(formTop).top - tester.getRect(header).bottom,
      lessThan(0.30 * _tall.height),
      reason: 'the header is stranded at the top with a void beneath it',
    );
  });
}
