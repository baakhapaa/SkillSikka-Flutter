import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'builder_tokens.dart';
import 'prompt_dialog.dart';

/// A capped list of one-line strings — *What students will learn* and
/// *Requirements*.
///
/// A card of rows plus a gold `+ Add …` row, which is the same shape the design
/// uses for the module list, so a screen with two of these does not look like it
/// invented a second list style. Adding opens a one-field dialog rather than
/// expanding an inline editor: the rows are single sentences, and an inline
/// editor for one sentence is more chrome than content.
class RepeatableField extends StatelessWidget {
  const RepeatableField({
    super.key,
    required this.label,
    required this.values,
    required this.addLabel,
    required this.hint,
    required this.onChanged,
    this.max = 6,
  });

  final String label;
  final List<String> values;
  final String addLabel;
  final String hint;

  /// Hard cap. Reaching it hides the add row instead of showing a disabled one —
  /// a control that cannot do anything is noise.
  final int max;

  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final canAdd = values.length < max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: builderInk,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: builderBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < values.length; index++)
                _Row(
                  text: values[index],
                  isLast: index == values.length - 1 && !canAdd,
                  onRemove: () => onChanged([
                    for (var i = 0; i < values.length; i++)
                      if (i != index) values[i],
                  ]),
                ),
              if (canAdd)
                _AddRow(
                  label: addLabel,
                  onTap: () async {
                    final line = await PromptDialog.show(
                      context,
                      title: addLabel,
                      hint: hint,
                    );
                    if (line == null) return;
                    onChanged([...values, line]);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.text,
    required this.isLast,
    required this.onRemove,
  });

  final String text;
  final bool isLast;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF7F6F2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(fontSize: 12, color: builderInk),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 16, color: builderMuted),
          ),
        ],
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 38,
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.add, size: 15, color: builderYellow),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: builderYellow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
