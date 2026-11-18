import 'dart:io';

/// `video_player` has no platform implementation under `flutter test`.
///
/// Building a controller there throws `UnimplementedError` and can leave a
/// frame scheduled, which makes `pumpAndSettle` wait out its ten-minute limit.
bool get videoPlaybackSupported =>
    !Platform.environment.containsKey('FLUTTER_TEST');

/// Widget tests set this. A real network call from a screen the tests only
/// mount leaves a timer behind and fails the suite.
bool get runningWidgetTests => Platform.environment.containsKey('FLUTTER_TEST');
