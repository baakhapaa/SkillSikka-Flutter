import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsikka/features/books/data/book_library.dart';

const bookInk = Color(0xFF111827);
const bookGold = Color(0xFFF5C400);
const bookGoldDeep = Color(0xFFC4A000);
const bookMuted = Color(0xFF6B7280);
const bookLine = Color(0xFFE5E7EB);
const bookChip = Color(0xFFF3F4F6);

class BookTopBar extends StatelessWidget {
  const BookTopBar({
    super.key,
    required this.title,
    required this.bookmarked,
    required this.onBack,
    required this.onBookmark,
    required this.onFont,
    this.foreground = bookInk,
    this.actionFill = bookChip,
  });

  final String title;
  final bool bookmarked;
  final VoidCallback onBack;
  final VoidCallback onBookmark;
  final VoidCallback onFont;
  final Color foreground;
  final Color actionFill;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _RoundAction(
            onTap: onBack,
            fill: actionFill,
            child: Icon(Icons.arrow_back_ios_new, size: 16, color: foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _RoundAction(
            onTap: onBookmark,
            fill: bookmarked ? bookGold : actionFill,
            child: Icon(
              bookmarked ? Icons.bookmark : Icons.bookmark_border,
              size: 18,
              color: foreground,
            ),
          ),
          const SizedBox(width: 8),
          _RoundAction(
            onTap: onFont,
            fill: actionFill,
            child: Text(
              'Aa',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Page colors for Light, Sepia, and Dark.
class ReadingPalette {
  const ReadingPalette({
    required this.background,
    required this.ink,
    required this.muted,
    required this.chip,
    required this.soft,
  });

  final Color background;
  final Color ink;
  final Color muted;
  final Color chip;
  final Color soft;

  static const light = ReadingPalette(
    background: Color(0xFFFFFFFF),
    ink: bookInk,
    muted: bookMuted,
    chip: bookChip,
    soft: Color(0xFFD1D5DB),
  );

  static const sepia = ReadingPalette(
    background: Color(0xFFF3E8D2),
    ink: Color(0xFF30343B),
    muted: Color(0xFF6B5E4E),
    chip: Color(0xFFE7D7BC),
    soft: Color(0xFFB5A48C),
  );

  static const dark = ReadingPalette(
    background: Color(0xFF24262C),
    ink: Color(0xFFFFFFFF),
    muted: Color(0xFFC4C7CE),
    chip: Color(0xFF34363D),
    soft: Color(0xFF8B909A),
  );

  static ReadingPalette of(ReadingAppearance appearance) {
    return switch (appearance) {
      ReadingAppearance.light => light,
      ReadingAppearance.sepia => sepia,
      ReadingAppearance.dark => dark,
    };
  }
}

/// Dims [child] only when brightness is pulled below full.
class ReadingBrightness extends StatelessWidget {
  const ReadingBrightness({
    super.key,
    required this.brightness,
    required this.child,
  });

  final double brightness;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dim = (1 - brightness).clamp(0.0, 1.0) * 0.55;
    return Stack(
      children: [
        child,
        if (dim > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: Colors.black.withValues(alpha: dim)),
            ),
          ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.onTap,
    required this.child,
    this.fill = bookChip,
  });

  final VoidCallback onTap;
  final Widget child;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        child: child,
      ),
    );
  }
}
