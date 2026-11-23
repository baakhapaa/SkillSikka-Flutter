import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    const families = [
      'Manrope',
      'Figtree',
      'Inter',
      'LexendDeca',
      'JetBrainsMono',
      'Lora',
    ];
    for (final family in families) {
      final text = await rootBundle.loadString(
        'assets/google_fonts/OFL-$family.txt',
      );
      yield LicenseEntryWithLineBreaks([family], text);
    }
  });
  runApp(const ProviderScope(child: SkillSikkaApp()));
}
