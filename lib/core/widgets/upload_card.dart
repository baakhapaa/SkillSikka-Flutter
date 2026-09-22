import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// The cream "Upload Document" card used by the signup and edit-profile forms:
/// a gold-bordered panel that either invites a file or shows the picked one with
/// its size and a remove action.
///
/// The two signup forms each keep their own private copy of this; new screens
/// should use this one.
class UploadCard extends StatelessWidget {
  const UploadCard({
    super.key,
    required this.title,
    required this.formats,
    required this.asset,
    required this.pickedFile,
    required this.onTap,
    required this.onClear,
    this.requiredField = false,
    this.removeTooltip = 'Remove file',
  });

  /// Label above the card, e.g. `Student ID Card`.
  final String title;

  /// The supported-formats line shown under "Upload Document".
  final String formats;

  /// SVG drawn inside the gold circle.
  final String asset;

  /// The chosen file, or null for the empty state.
  final PlatformFile? pickedFile;

  final VoidCallback onTap;
  final VoidCallback onClear;

  /// Appends the red `*` to the label.
  final bool requiredField;

  final String removeTooltip;

  @override
  Widget build(BuildContext context) {
    final hasFile = pickedFile != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: GoogleFonts.manrope(
              color: const Color(0xFF111827),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            children: [
              TextSpan(text: title),
              if (requiredField)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Color(0xFFEF4444)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF0),
              border: Border.all(color: const Color(0xFFE6B800)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: hasFile ? _pickedState() : _emptyState(),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() => Column(
    children: [
      _icon(),
      const SizedBox(height: 12),
      Text(
        'Upload Document',
        style: GoogleFonts.manrope(
          color: const Color(0xFF2F2600),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(
        formats,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          color: const Color(0xFF4B5563),
          fontSize: 11,
        ),
      ),
    ],
  );

  Widget _pickedState() => Row(
    children: [
      _icon(),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pickedFile!.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                color: const Color(0xFF2F2600),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${_formatSize(pickedFile!.size)} • Tap to replace',
              style: GoogleFonts.manrope(
                color: const Color(0xFF4B5563),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        onPressed: onClear,
        tooltip: removeTooltip,
        icon: const Icon(Icons.close, size: 20),
      ),
    ],
  );

  Widget _icon() => Container(
    width: 40,
    height: 40,
    padding: const EdgeInsets.all(10),
    decoration: const BoxDecoration(
      color: Color(0xFFE6B800),
      shape: BoxShape.circle,
    ),
    child: SvgPicture.asset(asset),
  );

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
