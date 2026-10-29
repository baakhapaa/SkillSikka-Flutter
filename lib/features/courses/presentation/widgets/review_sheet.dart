import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/network/api_error.dart';
import '../../data/course_api.dart';

const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _softGray = Color(0xFF9CA3AF);
const _border = Color(0xFFEAEAEA);
const _field = Color(0xFFF9FAFB);
const _gold = Color(0xFFE6B800);

/// Opens the review sheet for [courseId], prefilled when the student already
/// wrote one.
///
/// **One entry point for both screens that can review** — the course-detail page
/// and the player's "you finished this course" card. It fetches
/// `GET /courses/{id}/reviews/me/` first so the stars start where the student
/// left them; a 404 is the normal "not reviewed yet" answer, not an error.
///
/// Returns true when a review was saved, so the caller can refresh.
Future<bool> openCourseReview(
  BuildContext context, {
  required CourseApi api,
  required int courseId,
}) async {
  Map<String, dynamic>? mine;
  try {
    mine = await api.myReview(courseId);
  } on ApiException {
    // The sheet still opens: submitting is a POST and does not need this read.
    // Worst case an existing review comes back as `REVIEW_EXISTS`, which the
    // sheet already handles by turning the POST into a PATCH.
    mine = null;
  }
  if (!context.mounted) return false;

  final saved = await showReviewSheet(
    context,
    api: api,
    courseId: courseId,
    initialRating: mine?['rating'] is int ? mine!['rating'] as int : 0,
    initialReview: mine?['review'] is String ? mine!['review'] as String : '',
  );
  if (saved && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks for reviewing this course.')),
    );
  }
  return saved;
}

/// A bottom sheet with five stars and an optional note.
///
/// Returns true when the review was saved, false when the sheet was dismissed.
Future<bool> showReviewSheet(
  BuildContext context, {
  required CourseApi api,
  required int courseId,
  int initialRating = 0,
  String initialReview = '',
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ReviewSheet(
      api: api,
      courseId: courseId,
      initialRating: initialRating,
      initialReview: initialReview,
    ),
  );
  return saved ?? false;
}

/// The words under the stars. Index 0 is the untouched state.
const _ratingWords = <String>['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

/// **A `StatefulWidget` so the controller outlives the route.** Disposing a
/// `TextEditingController` when `showModalBottomSheet`'s future completes throws
/// `A TextEditingController was used after being disposed` — the route keeps
/// animating out for another ~200ms with the field still attached. The same trap
/// `PromptDialog` documents at length.
class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({
    required this.api,
    required this.courseId,
    required this.initialRating,
    required this.initialReview,
  });

  final CourseApi api;
  final int courseId;
  final int initialRating;
  final String initialReview;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late int _rating = widget.initialRating;
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialReview,
  );
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.initialRating > 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0 || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final review = _controller.text.trim();
    try {
      if (_isEdit) {
        await widget.api.updateReview(
          widget.courseId,
          rating: _rating,
          review: review,
        );
      } else {
        try {
          await widget.api.submitReview(
            widget.courseId,
            rating: _rating,
            review: review,
          );
        } on ApiException catch (error) {
          // One review per student is a server constraint, not a client one. If
          // a review exists — including one written on another device — the
          // submit becomes an edit instead of failing with a message the student
          // cannot act on.
          if (!error.hasCode('REVIEW_EXISTS')) rethrow;
          await widget.api.updateReview(
            widget.courseId,
            rating: _rating,
            review: review,
          );
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message ?? 'Could not save your review. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        // Without this the keyboard covers the field and the submit button.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _isEdit ? 'Edit your review' : 'Rate this course',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your rating helps other students choose a course.',
                  style: GoogleFonts.figtree(
                    fontSize: 12,
                    color: _gray,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var star = 1; star <= 5; star++)
                        Semantics(
                          button: true,
                          selected: star <= _rating,
                          label: '$star ${star == 1 ? 'star' : 'stars'}',
                          child: GestureDetector(
                            key: ValueKey('review-star-$star'),
                            behavior: HitTestBehavior.opaque,
                            onTap: _saving
                                ? null
                                : () => setState(() => _rating = star),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              child: Icon(
                                star <= _rating
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 36,
                                color: star <= _rating
                                    ? _gold
                                    : const Color(0xFFD1D5DB),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    _rating == 0 ? 'Tap a star to rate' : _ratingWords[_rating],
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _rating == 0 ? _softGray : _ink,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  enabled: !_saving,
                  maxLines: 4,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.figtree(fontSize: 13, color: _ink),
                  decoration: InputDecoration(
                    hintText:
                        'What did you like, or what could be better? (optional)',
                    hintStyle: GoogleFonts.figtree(
                      fontSize: 12,
                      color: _softGray,
                    ),
                    filled: true,
                    fillColor: _field,
                    counterStyle: GoogleFonts.figtree(
                      fontSize: 10,
                      color: _softGray,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _gold),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _error!,
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _rating == 0 || _saving ? null : _submit,
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _gold,
                      borderRadius: BorderRadius.circular(100),
                      // A disabled submit stays visible but stops reading as an
                      // action — the star row above is what has to be answered.
                      boxShadow: _rating == 0 || _saving
                          ? null
                          : const [
                              BoxShadow(
                                color: Color(0x40E6B800),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _ink,
                            ),
                          )
                        : Text(
                            _isEdit ? 'Update review' : 'Submit review',
                            style: GoogleFonts.figtree(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _rating == 0
                                  ? _ink.withValues(alpha: 0.45)
                                  : _ink,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
