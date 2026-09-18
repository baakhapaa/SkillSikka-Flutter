import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// The font package exposes its test asset manifest through this internal API.
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_assets;
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
  });

  for (final width in [360.0, 400.0]) {
    testWidgets('home headings align with their section content at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      await tester.pump();
      for (final title in ['Get Premium Courses', 'Recommended Books']) {
        final heading = find.text(title);
        final row = find
            .ancestor(of: heading, matching: find.byType(Row))
            .first;
        final section = find
            .ancestor(of: heading, matching: find.byType(Column))
            .first;
        final rowRect = tester.getRect(row);
        final sectionRect = tester.getRect(section);
        expect(rowRect.left, sectionRect.left, reason: title);
        expect(rowRect.right, sectionRect.right, reason: title);
        final seeAll = find.descendant(of: row, matching: find.text('See All'));
        expect(tester.getRect(seeAll).right, sectionRect.right, reason: title);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
