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

  /// This student's enrolment, straight from the server.
  ///
  /// **The local store cannot answer this**, and for a paid course the answer is
  /// the whole call to action: `pending_payment` means "Continue payment",
  /// `active` means "Continue Learning", no row means "Buy". The store only knows
  /// about enrolments made since the app started, so a returning student would be
  /// sold a course they had already paid for.
  CourseEnrollment? _enrollment;

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

    // **Read first, and independently of the detail fetch.** A paid course's call
    // to action is `Buy` or `Continue payment` depending on this row, and that
    // must be right even when the curriculum call fails — the bar is the thing
    // the user taps, and it is the only place the enrolment is visible.
    CourseEnrollment? enrollment;
    try {
      enrollment = await api.enrollmentFor(id);
    } on ApiException {
      enrollment = null;
    }
    if (mounted) setState(() => _enrollment = enrollment);

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
      // The enrolment read is also the review probe's first half: an `active`
      // row means the student may review without asking `/progress/` at all. It
      // cannot replace the probe outright, because an **academic** course has no
      // enrolment row and is still accessible by grade.
      var canReview = localEnrolment || (enrollment?.grantsAccess ?? false);
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
  ///
  /// A paid course does not land in the player on the first tap: it enrols into
  /// `pending_payment`, the checkout sheet takes over, and only a confirmed
  /// payment lets `startCourse` continue. Either way the enrolment is re-read
  /// afterwards, so the bar cannot keep selling a course the student just bought.
  Future<void> _enrol() async {
    await startCourse(context, _course);
    if (!mounted) return;
    await _refreshEnrollment();
  }

  Future<void> _refreshEnrollment() async {
    final id = _course.id;
    if (id == null) return;
    try {
      final enrollment = await ref.read(courseApiProvider).enrollmentFor(id);
      if (mounted) setState(() => _enrollment = enrollment);
    } on ApiException {
      // Keep the last known state. The next open refetches, and the player has
      // already answered the only question that matters: can this student read
      // the lessons.
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final enrolled =
        isCourseEnrolled(context, _course) ||
        (_enrollment?.grantsAccess ?? false);
    final awaiting = !enrolled && (_enrollment?.awaitsPayment ?? false);
    return CourseDetailView(
      data: _course,
      isEnrolled: enrolled,
      ctaLabel: _ctaLabel(enrolled: enrolled, awaiting: awaiting),
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

  /// What the bottom bar offers, given the enrolment the server reported.
  ///
  /// Null means "let the view use its own label", which is `Enroll Now` — right
  /// for a free course and for every caller that does not know the status.
  ///
  /// **Academic courses are excluded even when `is_paid` is set.** They are
  /// opened by grade with no enrolment row, so `POST /courses/{id}/enroll/`
  /// answers `COURSE_NOT_ENROLLABLE` and there is nothing to pay against; a
  /// `Buy` button there would lead straight into a 400.
  String? _ctaLabel({required bool enrolled, required bool awaiting}) {
    if (enrolled || _course.isAcademic) return null;
    if (awaiting) return 'Continue payment';
    if (!_course.isPaid) return null;
    final price = _course.price.trim();
    return price.isEmpty ? 'Buy now' : 'Buy $price';
  }
}
