import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The row of single-digit boxes used to enter an emailed code.
///
/// **Extracted rather than written twice.** Both signup verification and password
/// reset ask for a 4-digit code from the same backend, and the focus handling
/// below is fiddly enough that a second copy would drift — which is the same
/// reasoning that produced `showOptionPickerSheet` and `showApiErrorSnack`.
///
/// **Owns its own controllers and focus nodes.** The caller does not reach in; it
/// receives the joined value through [onChanged] and holds it. That is what lets
/// this be a `StatefulWidget` with no external lifecycle for the parent to get
/// wrong — a screen that forgot to dispose a controller would leak, and there is
/// no way for it to make that mistake here.
///
/// **Empty boxes contribute nothing**, so the joined value is *shorter* than
/// [length] until every box is filled. Deliberate: it lets a caller test
/// `code.length != length` for "incomplete" without knowing which boxes are blank,
/// which is exactly what both screens need to do before submitting.
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    required this.onChanged,
    this.length = 4,
    this.autofocus = true,
    this.enabled = true,
  });

  /// The digits entered so far, joined left to right. Never null; empty when
  /// nothing has been typed.
  final ValueChanged<String> onChanged;

  /// How many boxes to draw. Four is the only value the backend accepts for
  /// either flow, so change this only with a backend change.
  final int length;

  /// Focus the first box once this is built. Turn it off for a screen that
  /// appears behind a dialog or is not the user's next action.
  final bool autofocus;

  /// Greys the boxes out and blocks input — set while a request is in flight.
  ///
  /// **The digits are kept, not cleared.** A rejected code stays on screen so the
  /// user can correct the one wrong digit rather than retype all four, which is
  /// the behaviour the two OTP screens were written around.
  final bool enabled;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    // Not optional. A live `TextEditingController` or `FocusNode` on a disposed
    // State throws, and the OTP screens are pushed and popped constantly.
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// The digits entered so far, joined. Each box holds at most one character, so
  /// this is the code with any gaps collapsed — see the class doc.
  String get _code => _controllers.map((c) => c.text.trim()).join();

  void _handleChanged(int index, String value) {
    // Typing a digit advances; clearing a box steps back. Without the second half
    // there is no way to correct a wrong digit without tapping the previous box
    // by hand, and on a numeric keyboard the user cannot see a cursor to aim at.
    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    widget.onChanged(_code);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (index) {
        return Padding(
          padding: EdgeInsets.only(right: index == widget.length - 1 ? 0 : 16),
          child: _OtpBox(
            autofocus: widget.autofocus && index == 0,
            enabled: widget.enabled,
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            onChanged: (value) => _handleChanged(index, value),
          ),
        );
      }),
    );
  }
}

/// One box. Rebuilds itself when its [focusNode] changes, so the focus ring is
/// correct however focus moved — a tap, a programmatic advance, or the keyboard's
/// own next/previous.
///
/// The original signup implementation drove this from a `setState` in the parent's
/// `onChanged`, which missed the tap-to-focus case: tapping a box moved the
/// caret but left the ring on the old box until something else rebuilt.
class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.autofocus,
    required this.enabled,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final bool autofocus;
  final bool enabled;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        final border = BorderSide(
          color: focused ? const Color(0xFFE6B800) : const Color(0xFFE5E7EB),
          width: focused ? 2 : 1,
        );

        return SizedBox(
          width: 64,
          height: 64,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            autofocus: autofocus,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            onChanged: onChanged,
            style: GoogleFonts.manrope(
              color: const Color(0xFF111827),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: enabled ? Colors.white : const Color(0xFFF2F1F7),
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: border,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: border,
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: border,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFE6B800),
                  width: 2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
