import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

const _gold = Color(0xFFE6B800);

/// `00:42` under an hour, `1:04:42` over it.
///
/// Top-level and pure so it can be tested without a controller: `video_player`
/// has no platform implementation under `flutter test`, and anything that needs
/// one cannot be asserted there.
String formatVideoPosition(Duration position) {
  final total = position.inSeconds < 0 ? 0 : position.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${two(minutes)}:${two(seconds)}'
      : '${two(minutes)}:${two(seconds)}';
}

/// The transport layer over a playing lecture.
///
/// **Built by hand rather than with Chewie.** Chewie wraps the same
/// `video_player` controller in Material's default control set — a second
/// theming layer to fight on top of a screen whose player is otherwise custom
/// (figtree labels, gold accent, the white back pill). Nothing Chewie does here
/// is hard to do directly, and this way the bar matches the rest of the app.
///
/// What it adds, in the order a learner reaches for them:
///
/// * **Tap the picture** to toggle the bar, which auto-hides after four seconds
///   of playback — a permanent bar eats a fifth of a 16:9 stage on a phone.
/// * **Play/pause**, as the centre button *and* in the bar, because the centre
///   one is what a paused frame invites.
/// * **A seek bar** bound to `seekTo`. While a thumb is being dragged the bar
///   stops following the controller, otherwise the position stream would drag
///   the thumb back out from under the finger.
/// * **Mute**, which is the whole of volume control on a phone — the OS owns
///   the level.
/// * **Fullscreen**, as a callback: the same bar is reused inside
///   [FullscreenVideoPage], where the button means "leave" instead.
///
/// It never constructs or disposes a controller — it is handed one, and the
/// screen that owns it keeps owning it.
class VideoTransportControls extends StatefulWidget {
  const VideoTransportControls({
    super.key,
    required this.controller,
    this.onFullscreen,
    this.isFullscreen = false,
    this.title = '',
  });

  final VideoPlayerController controller;

  /// Null hides the fullscreen button — a screen with nowhere to go fullscreen
  /// to should not offer it.
  final VoidCallback? onFullscreen;

  final bool isFullscreen;

  /// The lecture name, shown in fullscreen where the page has no other context.
  final String title;

  @override
  State<VideoTransportControls> createState() => _VideoTransportControlsState();
}

class _VideoTransportControlsState extends State<VideoTransportControls> {
  /// Whether the bar is on screen. Starts visible so a paused frame explains
  /// itself, and hides itself once playback is running.
  bool _visible = true;

  /// True from touch-down to touch-up on the seek bar.
  bool _dragging = false;

  /// The thumb's own position while dragging, in milliseconds.
  double _dragMs = 0;

  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerTick);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_onControllerTick);
    super.dispose();
  }

  /// Re-subscribes when the screen swaps in another lecture's controller.
  ///
  /// The course player keeps one bar in one place in the tree and changes the
  /// controller under it, so `initState` runs once and `didUpdateWidget` runs
  /// for every lecture after the first. Without this the bar would go on
  /// listening to the *previous* lesson's disposed controller and freeze.
  @override
  void didUpdateWidget(covariant VideoTransportControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onControllerTick);
    widget.controller.addListener(_onControllerTick);
    _hideTimer?.cancel();
    _dragging = false;
    _visible = true;
    _scheduleHide();
  }

  /// Keeps the bar out of the way while the lecture plays, and puts it back the
  /// moment playback stops — a paused video with no visible controls looks
  /// frozen.
  void _onControllerTick() {
    if (!mounted) return;
    if (!widget.controller.value.isPlaying) {
      _hideTimer?.cancel();
      _hideTimer = null;
      if (!_visible) setState(() => _visible = true);
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      // Re-checked at fire time: the user may have paused during the four
      // seconds, and hiding the controls then would strand them.
      if (widget.controller.value.isPlaying) setState(() => _visible = false);
    });
  }

  void _show() {
    if (!_visible) setState(() => _visible = true);
    _scheduleHide();
  }

  void _toggleVisible() {
    if (_visible) {
      _hideTimer?.cancel();
      setState(() => _visible = false);
    } else {
      _show();
    }
  }

  void _togglePlay() {
    final controller = widget.controller;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    _show();
  }

  void _toggleMute() {
    final controller = widget.controller;
    controller.setVolume(controller.value.volume > 0 ? 0 : 1);
    _show();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final durationMs = value.duration.inMilliseconds.toDouble();
        // A slider needs a positive max, and an unloaded or live stream reports
        // zero. One millisecond makes it inert rather than throwing.
        final maxMs = durationMs <= 0 ? 1.0 : durationMs;
        final positionMs = _dragging
            ? _dragMs
            : value.position.inMilliseconds.toDouble().clamp(0.0, maxMs);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Tap-to-toggle over the whole picture, under the controls so a tap
            // on a button is a tap on the button.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleVisible,
              ),
            ),
            Center(
              child: AnimatedOpacity(
                opacity: _visible || !value.isPlaying ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: IgnorePointer(
                  ignoring: !(_visible || !value.isPlaying),
                  child: _roundButton(
                    icon: value.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 54,
                    iconSize: 26,
                    filled: true,
                    onTap: _togglePlay,
                    tooltip: value.isPlaying ? 'Pause' : 'Play',
                  ),
                ),
              ),
            ),
            if (value.isBuffering)
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
              ),
            // Fullscreen has no page around it, so the lecture name has to come
            // from the bar. On the course screen the title is already below the
            // stage twice, and a third copy would be noise.
            if (widget.isFullscreen && widget.title.trim().isNotEmpty)
              Positioned(
                left: 62,
                right: 62,
                top: 14,
                child: AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: IgnorePointer(
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.figtree(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: IgnorePointer(
                  ignoring: !_visible,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
                    decoration: BoxDecoration(
                      // A scrim, not a panel: the picture stays visible behind
                      // the controls, which is the point of an overlay.
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                    // **One row, not two.** The stage is 16:9 — about 200pt on
                    // a 360pt phone — and a slider stacked above a button row
                    // ate half of it. Everything the bar needs fits side by
                    // side: play, scrub, time, mute, fullscreen.
                    child: Row(
                      children: [
                        _roundButton(
                          icon: value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          size: 28,
                          iconSize: 18,
                          onTap: _togglePlay,
                          tooltip: value.isPlaying ? 'Pause' : 'Play',
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: SizedBox(
                            // A `Slider` claims 48pt of height by default. The
                            // overlay only has room for the thumb.
                            height: 26,
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                activeTrackColor: _gold,
                                inactiveTrackColor: Colors.white.withValues(
                                  alpha: 0.28,
                                ),
                                thumbColor: _gold,
                                overlayColor: _gold.withValues(alpha: 0.16),
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12,
                                ),
                              ),
                              child: Slider(
                                value: positionMs,
                                max: maxMs,
                                onChangeStart: (next) {
                                  _hideTimer?.cancel();
                                  setState(() {
                                    _dragging = true;
                                    _dragMs = next;
                                  });
                                },
                                onChanged: (next) =>
                                    setState(() => _dragMs = next),
                                onChangeEnd: (next) {
                                  widget.controller.seekTo(
                                    Duration(milliseconds: next.round()),
                                  );
                                  setState(() => _dragging = false);
                                  _show();
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${formatVideoPosition(_dragging ? Duration(milliseconds: _dragMs.round()) : value.position)}'
                          ' / ${formatVideoPosition(value.duration)}',
                          style: GoogleFonts.figtree(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        _roundButton(
                          icon: value.volume > 0
                              ? Icons.volume_up
                              : Icons.volume_off,
                          size: 28,
                          iconSize: 17,
                          onTap: _toggleMute,
                          tooltip: value.volume > 0 ? 'Mute' : 'Unmute',
                        ),
                        if (widget.onFullscreen != null)
                          _roundButton(
                            icon: widget.isFullscreen
                                ? Icons.fullscreen_exit
                                : Icons.fullscreen,
                            size: 28,
                            iconSize: 19,
                            onTap: () {
                              _show();
                              widget.onFullscreen!();
                            },
                            tooltip: widget.isFullscreen
                                ? 'Exit fullscreen'
                                : 'Fullscreen',
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// A circular hit target. `filled` is the centre button, which needs its own
  /// dark disc to stay legible over a bright frame.
  Widget _roundButton({
    required IconData icon,
    required double size,
    required double iconSize,
    required VoidCallback onTap,
    required String tooltip,
    bool filled = false,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? Colors.black.withValues(alpha: 0.42) : null,
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
      ),
    );
  }
}

/// The same picture and the same bar, on a black page in landscape.
///
/// **It does not own the controller.** The course player keeps playing while
/// this route is open and keeps owning the lifecycle, so leaving fullscreen
/// resumes the lecture exactly where it was — there is no second controller to
/// initialise, and no gap where both exist.
///
/// Orientation and system UI are restored in [dispose] rather than on a back
/// button: a system back gesture must not leave the app stuck in landscape with
/// no status bar.
class FullscreenVideoPage extends StatefulWidget {
  const FullscreenVideoPage({
    super.key,
    required this.controller,
    this.title = '',
  });

  final VideoPlayerController controller;
  final String title;

  @override
  State<FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<FullscreenVideoPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // The app locks nothing anywhere else, so restoring *all* orientations is
    // the correct "no opinion" state — not portrait, which would be a new
    // restriction invented here.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: widget.controller.value.aspectRatio <= 0
                  ? 16 / 9
                  : widget.controller.value.aspectRatio,
              // `contain`, not `cover`: fullscreen is where you go to see the
              // whole frame, so nothing may be cropped.
              child: VideoPlayer(widget.controller),
            ),
          ),
          VideoTransportControls(
            controller: widget.controller,
            isFullscreen: true,
            title: widget.title,
            onFullscreen: () => Navigator.of(context).maybePop(),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  size: 19,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
