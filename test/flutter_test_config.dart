import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Runs every test file.
///
/// Google Fonts otherwise opens a real download during `flutter test`. That
/// download is not driven by the test clock, but it keeps asking for frames,
/// so `pumpAndSettle` waits out its ten-minute limit and the suite looks stuck.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
