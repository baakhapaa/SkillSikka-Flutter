import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsikka/features/books/data/book_library.dart';
import 'package:skillsikka/features/books/presentation/book_chrome.dart';

const _sheetGold = Color(0xFFE6B800);
const _done = Color(0xFF806600);
const _cream = Color(0xFFFFF8DC);
const _chip = Color(0xFFF2F1F7);
const _label = Color(0xFF6B7280);

/// Opens the reading settings sheet. Changes write straight onto [book].
Future<void> showReadingSettings(
  BuildContext context, {
  required OwnedBook book,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) =>
        _ReadingSettingsSheet(book: book, onChanged: onChanged),
  );
}

/// Body and chapter headings follow the chosen face, size, and line height.
TextStyle readingFace(
  ReadingSettings settings, {
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  FontStyle fontStyle = FontStyle.normal,
  Color? color,
  double? height,
  double? letterSpacing,
}) {
  final face = settings.font == ReadingFont.lora
      ? GoogleFonts.lora
      : GoogleFonts.figtree;
  return face(
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    color: color,
    height: height ?? settings.lineHeight,
    letterSpacing: letterSpacing,
  );
}

class _ReadingSettingsSheet extends StatefulWidget {
  const _ReadingSettingsSheet({required this.book, required this.onChanged});

  final OwnedBook book;
  final VoidCallback onChanged;

  @override
  State<_ReadingSettingsSheet> createState() => _ReadingSettingsSheetState();
}

class _ReadingSettingsSheetState extends State<_ReadingSettingsSheet> {
  ReadingSettings get _settings => widget.book.reading;

  void _change(VoidCallback edit) {
    edit();
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final percent = (settings.brightness * 100).round();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEAEA),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Reading settings',
                  style: GoogleFonts.lexendDeca(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: bookInk,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Done',
                    style: GoogleFonts.figtree(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _done,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Font',
              style: GoogleFonts.figtree(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _label,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _Choice(
                    label: 'Lora',
                    lora: true,
                    selected: settings.font == ReadingFont.lora,
                    onTap: () =>
                        _change(() => settings.font = ReadingFont.lora),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Choice(
                    label: 'Figtree',
                    lora: false,
                    selected: settings.font == ReadingFont.figtree,
                    onTap: () =>
                        _change(() => settings.font = ReadingFont.figtree),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Text size',
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: bookInk,
                  ),
                ),
                const Spacer(),
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: _chip,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _StepButton(
                        icon: Icons.remove,
                        onTap: () => _change(settings.decreaseTextSize),
                      ),
                      SizedBox(
                        width: 55,
                        child: Text(
                          '${settings.textSize} px',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.figtree(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: bookInk,
                          ),
                        ),
                      ),
                      _StepButton(
                        icon: Icons.add,
                        onTap: () => _change(settings.increaseTextSize),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 98,
                  child: Text(
                    'Line spacing',
                    style: GoogleFonts.figtree(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: bookInk,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      for (final height in ReadingSettings.lineHeights) ...[
                        Expanded(
                          child: _Choice(
                            label: height.toStringAsFixed(1),
                            lora: false,
                            selected: settings.lineHeight == height,
                            onTap: () =>
                                _change(() => settings.lineHeight = height),
                          ),
                        ),
                        if (height != ReadingSettings.lineHeights.last)
                          const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Appearance',
              style: GoogleFonts.figtree(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _label,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _AppearanceChip(
                    label: 'Light',
                    fill: Colors.white,
                    ink: bookInk,
                    selected: settings.appearance == ReadingAppearance.light,
                    onTap: () => _change(
                      () => settings.appearance = ReadingAppearance.light,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AppearanceChip(
                    label: 'Sepia',
                    fill: const Color(0xFFF3E8D2),
                    ink: const Color(0xFF30343B),
                    selected: settings.appearance == ReadingAppearance.sepia,
                    onTap: () => _change(
                      () => settings.appearance = ReadingAppearance.sepia,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AppearanceChip(
                    label: 'Dark',
                    fill: const Color(0xFF24262C),
                    ink: Colors.white,
                    selected: settings.appearance == ReadingAppearance.dark,
                    onTap: () => _change(
                      () => settings.appearance = ReadingAppearance.dark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Brightness',
                  style: GoogleFonts.figtree(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _label,
                  ),
                ),
                const Spacer(),
                Text(
                  '$percent%',
                  style: GoogleFonts.figtree(fontSize: 12, color: _label),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.wb_sunny_outlined, size: 18, color: _label),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: _sheetGold,
                      inactiveTrackColor: _chip,
                      thumbColor: Colors.white,
                      overlayColor: _sheetGold.withValues(alpha: 0.15),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: settings.brightness.clamp(0.15, 1),
                      min: 0.15,
                      max: 1,
                      onChanged: (value) =>
                          _change(() => settings.brightness = value),
                    ),
                  ),
                ),
                const Icon(Icons.wb_sunny, size: 22, color: _label),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Saved automatically for this book',
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(fontSize: 11, color: _label),
            ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.lora,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool lora;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _cream : _chip,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _sheetGold : _chip),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: (lora ? GoogleFonts.lora : GoogleFonts.figtree)(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: bookInk,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check, size: 14, color: bookInk),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppearanceChip extends StatelessWidget {
  const _AppearanceChip({
    required this.label,
    required this.fill,
    required this.ink,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color fill;
  final Color ink;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _sheetGold : const Color(0xFFEAEAEA),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: GoogleFonts.figtree(fontSize: 13, color: ink)),
            if (selected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check, size: 13, color: ink),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 44,
        child: Icon(icon, size: 17, color: bookInk),
      ),
    );
  }
}
