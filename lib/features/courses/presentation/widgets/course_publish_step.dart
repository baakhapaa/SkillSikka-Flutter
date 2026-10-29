import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/course_image.dart';
import '../../../../core/widgets/labeled_text_field.dart';
import '../../../../core/widgets/pressable_chip.dart';
import '../../data/course_draft.dart';
import 'builder_tokens.dart';

/// Step 3 — price, review, and the gate.
///
/// The checklist is the reason this step exists. A disabled *Publish* button with
/// no explanation is the single most common dead end in a builder; here every
/// failing row names what is missing and jumps to the step that fixes it, so the
/// button's state is never a mystery.
class CoursePublishStep extends StatelessWidget {
  const CoursePublishStep({
    super.key,
    required this.draft,
    required this.instructorVerified,
    required this.priceController,
    required this.onEditStep,
    required this.onEdited,
  });

  final ValueNotifier<CourseDraft> draft;
  final bool instructorVerified;
  final TextEditingController priceController;
  final void Function(int step) onEditStep;
  final VoidCallback onEdited;

  @override
  Widget build(BuildContext context) {
    final value = draft.value;
    final readiness = PublishReadiness.of(
      value,
      instructorVerified: instructorVerified,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!instructorVerified) ...[
            const _VerificationCard(),
            const SizedBox(height: 16),
          ],

          _label('Pricing'),
          Row(
            children: [
              PressableChip(
                label: 'Free',
                selected: !value.isPaid,
                onTap: () {
                  draft.value = value.copyWith(isPaid: false);
                  onEdited();
                },
              ),
              const SizedBox(width: 8),
              PressableChip(
                label: 'Paid',
                selected: value.isPaid,
                onTap: () {
                  draft.value = value.copyWith(isPaid: true);
                  onEdited();
                },
              ),
            ],
          ),

          if (value.isPaid) ...[
            const SizedBox(height: 14),
            LabeledTextField(
              label: 'Price',
              hint: '1,299',
              controller: priceController,
              requiredField: true,
              keyboardType: TextInputType.number,
              onChanged: (text) {
                draft.value = draft.value.copyWith(price: text);
                onEdited();
              },
            ),
            const SizedBox(height: 6),
            Text(
              'Students pay once and keep lifetime access.',
              style: GoogleFonts.figtree(fontSize: 11, color: builderMuted),
            ),
            const SizedBox(height: 10),
            // A paid course is startable now: the student enrols into
            // `pending_payment`, pays eSewa in the checkout sheet, and the
            // server flips the enrolment to `active` when the gateway confirms.
            // Said here because the instructor sets a price and cannot otherwise
            // see what the student will meet.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: builderCream,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: builderYellow.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: builderYellow,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Students pay with eSewa before they can start. '
                      'The course unlocks as soon as the payment is confirmed.',
                      style: GoogleFonts.figtree(
                        fontSize: 11,
                        height: 1.4,
                        color: builderBrown,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),
          _sectionHead('Summary', trailing: 'tap to edit'),
          _SummaryCard(draft: value, onTap: () => onEditStep(0)),

          const SizedBox(height: 16),
          _sectionHead('Before you publish'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: builderBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _CheckRow(
                  label: 'Course details complete',
                  passed: readiness.detailsComplete,
                  onTap: () => onEditStep(0),
                ),
                _CheckRow(
                  label: value.kind == CourseKind.academic
                      ? 'Subject and grade chosen'
                      : 'Category chosen',
                  // A published course with no placement is reachable by
                  // nobody: the Skills tab filters on the category and the
                  // Courses tab on the grade.
                  passed: readiness.placementChosen,
                  onTap: () => onEditStep(0),
                ),
                _CheckRow(
                  label: 'At least one lesson',
                  passed: readiness.hasLesson,
                  onTap: () => onEditStep(1),
                ),
                _CheckRow(
                  label: 'Every lesson has a duration',
                  passed: readiness.durationsComplete,
                  onTap: () => onEditStep(1),
                ),
                _CheckRow(
                  label: 'Price set',
                  passed: readiness.priceSet,
                  onTap: () => onEditStep(2),
                ),
                _CheckRow(
                  label: 'Instructor account verified',
                  passed: readiness.instructorVerified,
                  // Not fixable in the builder, so it does not pretend to be:
                  // tapping it does nothing and it carries no chevron.
                  trailing: readiness.instructorVerified ? null : 'Not yet',
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: builderInk,
      ),
    ),
  );

  Widget _sectionHead(String text, {String? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: builderInk,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: GoogleFonts.figtree(fontSize: 10, color: builderMuted),
          ),
      ],
    ),
  );
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: builderCream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: builderYellow),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: builderPillFill,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline,
              size: 15,
              color: Color(0xFF8A7A2E),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account under review',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: builderBrown,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Save drafts now — publishing unlocks once your instructor '
                  'account is verified.',
                  style: GoogleFonts.figtree(
                    fontSize: 11,
                    color: builderGray,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.draft, required this.onTap});

  final CourseDraft draft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lessons = draft.lessonCount;
    final modules = draft.modules.length;
    final price = draft.isPaid
        ? (draft.parsedPrice == null
              ? 'Paid'
              : 'Rs ${_money(draft.parsedPrice!)}')
        : 'Free';
    final meta =
        '${draft.kind == CourseKind.skill ? 'Skill' : 'Academic'} · '
        '$modules ${modules == 1 ? 'module' : 'modules'}, '
        '$lessons ${lessons == 1 ? 'lesson' : 'lessons'} · $price';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: builderBorder),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _thumb(),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.title.trim().isEmpty
                        ? 'Untitled course'
                        : draft.title.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: builderInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.figtree(
                      fontSize: 11,
                      color: builderMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The same three states as the picker on step 1: picked bytes, the server's
  /// URL, then the generated tile. The summary is where an instructor checks
  /// the course before publishing, so it has to show the picture that will
  /// actually ship.
  Widget _thumb() {
    final picked = draft.cover;
    if (picked != null) {
      return Image.memory(picked.bytes, fit: BoxFit.cover);
    }
    final url = draft.coverUrl;
    if (url != null && url.trim().isNotEmpty) {
      return CourseImage(url, fit: BoxFit.cover, fallback: _generatedThumb());
    }
    return _generatedThumb();
  }

  Widget _generatedThumb() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFBE8A8), Color(0xFFEFCB63)],
      ),
    ),
    alignment: Alignment.center,
    child: Text(
      draft.initials,
      style: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF6B5410),
      ),
    ),
  );

  /// `1,299` — no trailing `.00` on a round price, which is how every price in
  /// the app is printed.
  static String _money(double value) {
    final rounded = value.round();
    final text = rounded.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
      buffer.write(text[i]);
    }
    return buffer.toString();
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.passed,
    this.onTap,
    this.trailing,
    this.isLast = false,
  });

  final String label;
  final bool passed;
  final VoidCallback? onTap;
  final String? trailing;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: builderCardBorder)),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: passed ? const Color(0xFFE8F5EC) : builderPillFill,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: passed
                    ? const Icon(Icons.check, size: 10, color: builderSuccess)
                    : Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: builderYellow,
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: passed ? FontWeight.w500 : FontWeight.w700,
                  color: passed ? builderGray : builderInk,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: GoogleFonts.figtree(fontSize: 10, color: builderMuted),
              ),
          ],
        ),
      ),
    );
  }
}
