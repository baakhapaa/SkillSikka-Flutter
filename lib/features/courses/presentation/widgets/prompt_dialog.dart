import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'builder_tokens.dart';

/// A one-field dialog that owns its own controller.
///
/// **Why this exists instead of a helper that builds an `AlertDialog` inline.**
/// The obvious version —
///
/// ```dart
/// final controller = TextEditingController();
/// final value = await showDialog<String>(...);
/// controller.dispose();
/// ```
///
/// crashes. `showDialog`'s future completes when the route is *popped*, but the
/// route keeps animating out for another ~200ms and the `TextField` inside it
/// still holds the controller. Disposing at that moment throws
/// `A TextEditingController was used after being disposed`, which then cascades
/// into `'_dependents.isEmpty': is not true` while the overlay rebuilds — so the
/// visible failure names an assertion about inherited widgets, not the controller
/// that actually caused it.
///
/// Making the dialog a `StatefulWidget` moves the dispose to the dialog's own
/// `dispose()`, which Flutter calls after the route is gone. Nothing else about
/// the dialog changes.
class PromptDialog extends StatefulWidget {
  const PromptDialog({
    super.key,
    required this.title,
    required this.hint,
    this.initial = '',
    this.maxLength = 120,
    this.confirmLabel = 'Add',
  });

  final String title;
  final String hint;
  final String initial;
  final int maxLength;
  final String confirmLabel;

  /// Returns the trimmed text, or null when dismissed or left blank.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String hint,
    String initial = '',
    int maxLength = 120,
    String confirmLabel = 'Add',
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => PromptDialog(
        title: title,
        hint: hint,
        initial: initial,
        maxLength: maxLength,
        confirmLabel: confirmLabel,
      ),
    );
  }

  @override
  State<PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<PromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        widget.title,
        style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        textCapitalization: TextCapitalization.sentences,
        style: GoogleFonts.manrope(fontSize: 14, color: builderInk),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: GoogleFonts.manrope(fontSize: 14, color: builderMuted),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: builderFieldBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: builderFieldBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: builderYellow),
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: builderGray,
            ),
          ),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            widget.confirmLabel,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: builderYellow,
            ),
          ),
        ),
      ],
    );
  }
}
