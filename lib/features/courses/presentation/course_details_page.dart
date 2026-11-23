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
  CourseEnrollment? _enrollment;

  /// Academic courses have no enrolment. Progress says whether they started.
  bool _started = false;

  /// The cached full record, when this course was opened before.
  CourseDetailData? _cachedDetail;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  CourseDetailData get _course => _detail ?? _cachedDetail ?? widget.course;

  Future<void> _loadDetail() async {
    final id = widget.course.id;
    if (id == null) return;
    final api = ref.read(courseApiProvider);
    final localEnrolment = isCourseEnrolled(context, _course);
    final summaryEnrolled = widget.course.isEnrolled;

    // Attach the handlers immediately. A future that fails before it is
    // awaited is reported as uncaught, which fails the test that opened the page.
    final current = ref.read(courseDetailProvider(id));
    final enrollmentCall = api.enrollmentFor(id).then<CourseEnrollment?>(
      (value) => value,
      onError: (Object _) => null,
    );
    // A course opened before is already in [courseDetailProvider]. Refresh it.
    // The first open just reads the future the build method already started.
    final detailCall =
        (current.hasValue || current.hasError
                ? ref.refresh(courseDetailProvider(id).future)
                : ref.read(courseDetailProvider(id).future))
            .then<CourseDetailData?>(
              (value) => value,
              onError: (Object _) => null,
            );

    final enrollment = await enrollmentCall;
    if (mounted) setState(() => _enrollment = enrollment);

    final detail = await detailCall;
    if (detail == null || !mounted) return;
    Map<String, dynamic>? mine;
    try {
      mine = await api.myReview(id);
    } on ApiException {
      mine = null;
    }
    var started = false;
    var progressOk = false;
    try {
      final progress = await api.progress(id);
      started = progress.hasStarted;
      // A successful progress read is the enrolment probe: the endpoint
      // refuses anyone who cannot review. `hasStarted` is separate — an
      // academic course can be open without the student having watched it.
      progressOk = true;
    } on ApiException {
      started = false;
    }
    final canReview =
        localEnrolment ||
        summaryEnrolled ||
        (enrollment?.grantsAccess ?? false) ||
        progressOk;
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _myReview = mine;
      _canReview = canReview;
      _started = started;
    });
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
    final id = widget.course.id;
    _cachedDetail = id == null
        ? null
        : ref.watch(courseDetailProvider(id)).valueOrNull;
    final enrolled =
        isCourseEnrolled(context, _course) ||
        _course.isEnrolled ||
        (_enrollment?.grantsAccess ?? false) ||
        (_course.isAcademic && _started);
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
