import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/course_detail_view.dart';
import '../../learning/presentation/start_course.dart';
import '../data/course_api.dart';
import 'widgets/review_sheet.dart';

/// The course-detail screen for the Courses tab.
///
/// A thin wrapper. All the layout lives in [CourseDetailView], which the premium
/// screen renders too — so the two cannot drift. What this class adds is the
/// course it was opened for, the curriculum, and the enrolment flow.
///
/// **Two-stage data.** The list already has enough to paint the header, so it
/// passes that in and the screen renders immediately. When [CourseDetailData.id]
/// is set it then fetches the full record — lessons, reviews, instructor — and
/// swaps it in. An id of `null` means "came from the hardcoded catalogue", and
/// nothing is fetched, which is what keeps the existing tests off the network.
class CourseDetailPage extends ConsumerStatefulWidget {
  const CourseDetailPage({super.key, required this.course});

  final CourseDetailData course;

  @override
  ConsumerState<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends ConsumerState<CourseDetailPage> {
  /// The full record once it lands. Null until then, or when there is no id.
  CourseDetailData? _detail;

  /// This student's own review, or null when they have not written one.
  ///
  /// Read from `GET /courses/{id}/reviews/me/` so the feedback section can say
  /// `Edit your review` instead of `Write a review` — and so the sheet opens on
  /// the stars they already chose.
  Map<String, dynamic>? _myReview;

  /// Whether the server says this student may review the course.
  ///
  /// **The in-session store is not enough.** It only holds enrolments made since
  /// the app started, so a student who enrolled yesterday would open this page
  /// and find no way to review. `GET /courses/{id}/progress/` is the cheapest
  /// honest probe: it requires an `active`/`completed` enrolment — byte for byte
  /// the same rule `POST /courses/{id}/reviews/` enforces.
  bool? _canReview;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  CourseDetailData get _course => _detail ?? widget.course;

  Future<void> _loadDetail() async {
    final id = widget.course.id;
    if (id == null) return;
    final api = ref.read(courseApiProvider);
    final localEnrolment = isCourseEnrolled(context, _course);
    try {
      final detail = await api.detail(id);
      // Best effort: a failed `reviews/me/` must not cost the whole page. It
      // 404s for every student who has not reviewed yet, which is most of them.
      Map<String, dynamic>? mine;
      try {
        mine = await api.myReview(id);
      } on ApiException {
        mine = null;
      }
      var canReview = localEnrolment;
      if (!canReview) {
        try {
          await api.progress(id);
          canReview = true;
        } on ApiException {
          // 403 `NOT_ENROLLED` — see [_canReview].
          canReview = false;
        }
      }
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _myReview = mine;
        _canReview = canReview;
      });
    } on ApiException {
      // The summary is already on screen and is a truthful subset. Failing the
      // whole screen because the curriculum did not load would hide a course the
      // user can see in the grid — and an empty curriculum reads as "no lessons
      // published yet", which is the honest state of a half-filled course.
    }
  }

  /// Opens the review sheet, then reloads so the new average and review row are
  /// the server's rather than something this screen made up.
  Future<void> _writeReview() async {
    final id = _course.id;
    if (id == null) return;
    final saved = await openCourseReview(
      context,
      api: ref.read(courseApiProvider),
      courseId: id,
    );
    if (!saved || !mounted) return;
    await _loadDetail();
  }

  /// Enrolment needs a complete profile, so the fields signup stopped asking for
  /// are collected here, on the way in, and the user lands in the player rather
  /// than back on this screen with a toast.
  Future<void> _enrol() async {
    await startCourse(context, _course);
    // `build` asks the store whether this course is enrolled in, and the answer
    // changed while the player was open. Without this the bar would still read
    // `Enroll Now` on the way back.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final enrolled = isCourseEnrolled(context, _course);
    return CourseDetailView(
      data: _course,
      isEnrolled: enrolled,
      onEnrol: _enrol,
      onContinue: () => continueCourse(context, _course),
      hasReviewed: _myReview != null,
      // Enrolment is the server's own rule for reviewing — see
      // `CourseReviewAccessMixin.check_enrollment`. Completion is *not* required
      // by the API, and the player prompts the student the moment they finish.
      onWriteReview: (enrolled || _canReview == true) && _course.id != null
          ? _writeReview
          : null,
    );
  }
}
