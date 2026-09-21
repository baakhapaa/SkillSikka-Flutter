import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../location/location_service.dart';

/// Colour + shape tokens lifted from the signup screens so this prompt reads as
/// part of the same app rather than a system dialog.
abstract final class AppPalette {
  static const scaffold = Color(0xFFFAF9F6);
  static const surface = Colors.white;
  static const accent = Color(0xFFE6B800);
  static const accentSoft = Color(0xFFFFF4CC);
  static const cream = Color(0xFFFFFBF0);
  static const ink = Color(0xFF111827);
  static const inkSoft = Color(0xFF4B5563);
  static const muted = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const brownInk = Color(0xFF2F2600);
  static const danger = Color(0xFFEF4444);
  static const success = Color(0xFF16A34A);
}

/// Shows the "use your current location?" popup.
///
/// Returns the confirmed location, or `null` when the user dismissed the popup
/// (or never got a fix) — the caller should leave the field alone in that case.
Future<DetectedLocation?> showLocationPromptDialog(
  BuildContext context, {
  LocationService service = const LocationService(),
  bool skipIntro = false,
}) {
  return showGeneralDialog<DetectedLocation>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Location permission',
    barrierColor: const Color(0x66101828),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) =>
        LocationPromptDialog(service: service, skipIntro: skipIntro),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

enum _Stage { asking, loading, detected, failed }

class LocationPromptDialog extends StatefulWidget {
  const LocationPromptDialog({
    super.key,
    this.service = const LocationService(),
    this.skipIntro = false,
  });

  final LocationService service;

  /// When true (permission already granted) the popup skips the explainer and
  /// starts detecting straight away — no repeated nagging on every visit.
  final bool skipIntro;

  @override
  State<LocationPromptDialog> createState() => _LocationPromptDialogState();
}

class _LocationPromptDialogState extends State<LocationPromptDialog> {
  _Stage _stage = _Stage.asking;
  LocationFailure? _failure;
  DetectedLocation? _detected;

  /// Guards against a stale lookup resolving after the user moved on.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    if (widget.skipIntro) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _detect());
    }
  }

  Future<void> _detect() async {
    final requestId = ++_requestId;
    setState(() {
      _stage = _Stage.loading;
      _failure = null;
    });

    try {
      final location = await widget.service.detectCurrentLocation();
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _detected = location;
        _stage = _Stage.detected;
      });
    } on LocationFailure catch (failure) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _failure = failure;
        _stage = _Stage.failed;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _failure = const LocationFailure(
          LocationFailureReason.lookupFailed,
          "Something went wrong while finding you.",
        );
        _stage = _Stage.failed;
      });
    }
  }

  /// Dismisses without a location. The caller leaves the field untouched, so
  /// whatever the user has typed (or nothing) survives.
  void _dismiss() {
    _requestId++;
    Navigator.of(context).pop();
  }

  void _accept() {
    final location = _detected;
    if (location == null) return;
    Navigator.of(context).pop(location);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A111827),
                  blurRadius: 32,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _badge(),
                const SizedBox(height: 18),
                Text(
                  _title(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: AppPalette.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _message(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: AppPalette.inkSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                if (_stage == _Stage.detected && _detected != null) ...[
                  const SizedBox(height: 18),
                  _DetectedLocationCard(location: _detected!),
                ],
                const SizedBox(height: 22),
                ..._actions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge() {
    switch (_stage) {
      case _Stage.loading:
        return const _Badge(
          background: AppPalette.accentSoft,
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              valueColor: AlwaysStoppedAnimation<Color>(AppPalette.accent),
            ),
          ),
        );
      case _Stage.detected:
        return const _Badge(
          background: Color(0xFFE9F9EF),
          child: Icon(Icons.check_rounded, size: 34, color: AppPalette.success),
        );
      case _Stage.failed:
        return const _Badge(
          background: Color(0xFFFDECEC),
          child: Icon(
            Icons.location_off_rounded,
            size: 32,
            color: AppPalette.danger,
          ),
        );
      case _Stage.asking:
        return _Badge(
          background: AppPalette.accentSoft,
          child: SvgPicture.asset(
            'assets/figma/signup_location.svg',
            width: 30,
            height: 30,
          ),
        );
    }
  }

  String _title() {
    switch (_stage) {
      case _Stage.asking:
        return 'Use your current location?';
      case _Stage.loading:
        return 'Finding you…';
      case _Stage.detected:
        return 'Location detected';
      case _Stage.failed:
        return _failure?.reason == LocationFailureReason.serviceDisabled
            ? 'Turn on location services'
            : 'We need your location';
    }
  }

  String _message() {
    switch (_stage) {
      case _Stage.asking:
        return 'Skill Sikka fills your address automatically and uses it to '
            'show courses, bootcamps and events near you.';
      case _Stage.loading:
        return 'Hang on a second while we read your current location.';
      case _Stage.detected:
        return 'We found you here. Use it, or detect again if it looks wrong.';
      case _Stage.failed:
        final failure = _failure;
        if (failure == null) return 'Please try again.';
        switch (failure.reason) {
          case LocationFailureReason.serviceDisabled:
            return 'Location services are off. Turn them on so we can fill '
                'your address automatically.';
          case LocationFailureReason.permissionDeniedForever:
            return 'Location access is blocked. Open your device settings and '
                'allow location for Skill Sikka.';
          case LocationFailureReason.permissionDenied:
            return 'Without location access we can’t detect your address.';
          case LocationFailureReason.lookupFailed:
            return 'We couldn’t pin down your location just now. Try again.';
        }
    }
  }

  List<Widget> _actions() {
    switch (_stage) {
      case _Stage.asking:
        return [_PrimaryButton(label: 'Allow Location', onPressed: _detect)];
      case _Stage.loading:
        // No primary action while the fix is in flight, but never leave the
        // user with nothing to press — the lookup can take up to 20s.
        return [_SecondaryButton(label: 'Cancel', onPressed: _dismiss)];
      case _Stage.detected:
        return [
          _PrimaryButton(label: 'Use This Location', onPressed: _accept),
          const SizedBox(height: 4),
          _SecondaryButton(label: 'Detect Again', onPressed: _detect),
        ];
      case _Stage.failed:
        final reason = _failure?.reason;
        if (reason == LocationFailureReason.permissionDeniedForever) {
          return [
            _PrimaryButton(
              label: 'Open Settings',
              onPressed: () =>
                  widget.service.openSettings(forLocationServices: false),
            ),
          ];
        }
        if (reason == LocationFailureReason.serviceDisabled) {
          return [
            _PrimaryButton(
              label: 'Turn On Location',
              onPressed: () =>
                  widget.service.openSettings(forLocationServices: true),
            ),
            const SizedBox(height: 4),
            _SecondaryButton(label: 'Try Again', onPressed: _detect),
          ];
        }
        return [_PrimaryButton(label: 'Try Again', onPressed: _detect)];
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.background, required this.child});

  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: 72,
    height: 72,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
    child: child,
  );
}

class _DetectedLocationCard extends StatelessWidget {
  const _DetectedLocationCard({required this.location});

  final DetectedLocation location;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppPalette.cream,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x33E6B800)),
    ),
    child: Row(
      children: [
        SvgPicture.asset(
          'assets/figma/signup_location.svg',
          width: 16,
          height: 16,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detected location',
                style: GoogleFonts.manrope(
                  color: AppPalette.brownInk.withValues(alpha: 0.65),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                location.label,
                style: GoogleFonts.manrope(
                  color: AppPalette.brownInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppPalette.accent,
        foregroundColor: AppPalette.ink,
        elevation: 4,
        shadowColor: const Color(0x40E6B800),
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 44,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppPalette.inkSoft,
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppPalette.inkSoft,
        ),
      ),
    ),
  );
}

/// Gold crosshair button inside the location field, so the popup can be opened
/// at any time without leaving the form.
class CurrentLocationButton extends StatelessWidget {
  const CurrentLocationButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: 'Use my current location',
    icon: const Icon(
      Icons.my_location_rounded,
      size: 18,
      color: AppPalette.accent,
    ),
  );
}

/// One-line hint under the location field.
///
/// The field stays a normal editable input, so this only advertises the
/// shortcut — it never reports a "locked" state.
class LocationFieldHint extends StatelessWidget {
  const LocationFieldHint({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        const Icon(
          Icons.my_location_rounded,
          size: 13,
          color: AppPalette.muted,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            'Tap the crosshair to fill this from your current location',
            style: GoogleFonts.manrope(
              color: AppPalette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}
