import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The project's standard "soft raised" chip / button.
///
/// This is the single source of truth for the tap feedback used across the
/// app — it is the recipe the Class 6–10 chips in
/// `features/courses/presentation/courses.dart` already used.
///
/// Interaction recipe:
///  * **hover** → scales to 1.06 and lifts by 6% of its own height
///  * **hover** → shadow softens (blur 7 → 10, alpha 0x22 → 0x2E)
///  * **press** → shadow travel collapses from 3px to 1px, so the chip
///                visually sits down onto the surface
///  * **press** → the inner inset gradient flips from bottom→top to
///                top→bottom and darkens, so the face reads as pushed in
///  * **press** → the specular highlight along the top edge is dropped
///
/// [selected] keeps the "pushed in" look after the gesture ends — that is how
/// the Class chips stay visibly chosen. Plain buttons can leave it `false` and
/// still get the full finger-down feedback.
class PressableChip extends StatefulWidget {
  const PressableChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w600,
    this.horizontalPadding = 14,
    this.verticalPadding = 8,
    this.radius = 14,
    this.textColor = const Color(0xFF111827),
  });

  /// Text shown on the chip.
  final String label;

  /// Fired on tap. Also drives the press-in animation while the pointer is down.
  final VoidCallback onTap;

  /// Persistent "pushed in" state, used for single-select chip rows.
  final bool selected;

  final double fontSize;
  final FontWeight fontWeight;
  final double horizontalPadding;
  final double verticalPadding;
  final double radius;
  final Color textColor;

  @override
  State<PressableChip> createState() => _PressableChipState();
}

class _PressableChipState extends State<PressableChip> {
  bool _hovered = false;
  bool _pressed = false;

  /// Either the chip is committed-selected, or a finger is currently down.
  bool get _depressed => widget.selected || _pressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: AnimatedSlide(
            offset: _hovered ? const Offset(0, -0.06) : Offset.zero,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.radius),
                boxShadow: [
                  BoxShadow(
                    color: _hovered
                        ? const Color(0x2E000000)
                        : const Color(0x22000000),
                    blurRadius: _hovered ? 10 : 7,
                    offset: Offset(0, _depressed ? 1 : 3),
                  ),
                  const BoxShadow(
                    color: Color(0xCCFFFFFF),
                    blurRadius: 2,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.radius),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(
                                  alpha: _hovered ? 0.96 : 0.82,
                                ),
                                const Color(0xFFF3F4F6).withValues(alpha: 0.55),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Inset shading — flips direction when depressed so the
                    // face looks carved into the surface rather than lit.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: _depressed
                                  ? Alignment.topCenter
                                  : Alignment.bottomCenter,
                              end: _depressed
                                  ? Alignment.bottomCenter
                                  : Alignment.topCenter,
                              colors: [
                                _depressed
                                    ? const Color(0x22000000)
                                    : const Color(0x26000000),
                                const Color(0x00000000),
                              ],
                              stops: _depressed
                                  ? const [0, 0.55]
                                  : const [0, 0.4],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Specular highlight — removed while pressed.
                    if (!_depressed || _hovered)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(
                                    alpha: _hovered ? 0.9 : 0.58,
                                  ),
                                  Colors.white.withValues(alpha: 0),
                                ],
                                stops: const [0, 0.45],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.horizontalPadding,
                        vertical: widget.verticalPadding,
                      ),
                      child: Text(
                        widget.label,
                        style: GoogleFonts.figtree(
                          fontSize: widget.fontSize,
                          fontWeight: widget.fontWeight,
                          color: widget.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
