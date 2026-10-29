import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/learning/presentation/widgets/video_transport_controls.dart';
import 'package:video_player/video_player.dart';

/// The transport bar over a lecture.
///
/// **A controller that was never `initialize()`d is deliberate.** `video_player`
/// has no platform implementation under `flutter test`, so anything that
/// touches the platform — `play`, `seekTo`, `setVolume` — cannot be exercised
/// here. What can be is the part this app wrote: the layout, the time labels,
/// and the callbacks it owns. Construction and disposal of an uninitialised
/// controller never reach the platform, which is what makes the widget testable
/// at all.
void main() {
  VideoPlayerController controller() => VideoPlayerController.networkUrl(
    Uri.parse('https://example.com/lecture.mp4'),
  );

  group('formatVideoPosition', () {
    test('pads minutes and seconds', () {
      expect(formatVideoPosition(Duration.zero), '00:00');
      expect(formatVideoPosition(const Duration(seconds: 7)), '00:07');
      expect(
        formatVideoPosition(const Duration(minutes: 4, seconds: 51)),
        '04:51',
      );
    });

    test('adds the hour only when there is one', () {
      expect(
        formatVideoPosition(const Duration(hours: 1, minutes: 4, seconds: 42)),
        '1:04:42',
      );
      // 59:59 stays in the short form — an `00:59:59` here would make every
      // lecture look like a film.
      expect(
        formatVideoPosition(const Duration(minutes: 59, seconds: 59)),
        '59:59',
      );
    });

    test('a negative position reads as zero, not as -1:-1', () {
      expect(formatVideoPosition(const Duration(seconds: -5)), '00:00');
    });
  });

  testWidgets('the bar reports the position and offers fullscreen', (
    tester,
  ) async {
    final player = controller();
    addTearDown(player.dispose);

    var fullscreen = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 203,
            child: VideoTransportControls(
              controller: player,
              onFullscreen: () => fullscreen = true,
            ),
          ),
        ),
      ),
    );

    // An unloaded controller has no duration, and the label must still be a
    // time rather than an exception or a blank.
    expect(find.text('00:00 / 00:00'), findsOneWidget);

    // Two play buttons on purpose: the centre one a paused frame invites, and
    // the small one in the bar.
    expect(find.byIcon(Icons.play_arrow), findsNWidgets(2));
    expect(find.byIcon(Icons.volume_up), findsOneWidget);

    await tester.tap(find.byIcon(Icons.fullscreen));
    expect(fullscreen, isTrue, reason: 'the button did nothing');
  });

  testWidgets('fullscreen is not offered when there is nowhere to go', (
    tester,
  ) async {
    final player = controller();
    addTearDown(player.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 203,
            // `onFullscreen: null` is what the fullscreen page itself passes
            // when it wants the button to mean "exit" — so the button must be
            // absent, not merely inert.
            child: VideoTransportControls(controller: player),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.fullscreen), findsNothing);
    expect(find.byIcon(Icons.fullscreen_exit), findsNothing);
  });

  testWidgets('a muted controller shows the muted icon', (tester) async {
    final player = controller();
    addTearDown(player.dispose);

    // Set directly rather than through `setVolume`, which would reach the
    // platform. This is the state the icon has to reflect.
    player.value = player.value.copyWith(volume: 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 203,
            child: VideoTransportControls(controller: player),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.volume_off), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsNothing);
  });
}
