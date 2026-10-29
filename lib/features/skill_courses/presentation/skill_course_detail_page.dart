import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/course_detail_view.dart';
import '../../courses/data/course_api.dart';
import '../../courses/presentation/widgets/review_sheet.dart';
import '../../learning/presentation/start_course.dart';

/// The detail screen for a card on the Skill Courses tab.
///
/// A thin wrapper, exactly like the Courses tab's `CourseDetailPage`: all the
/// layout lives in [CourseDetailView], which the premium screen renders too, so
/// the three cannot drift. What this class adds is the course it was opened for,
/// the curriculum, the enrolment flow, and the review sheet.
class SkillCourseDetailPage extends StatefulWidget {
  const SkillCourseDetailPage({super.key, required this.course});

  final CourseDetailData course;

  @override
  State<SkillCourseDetailPage> createState() => _SkillCourseDetailPageState();
}

class _SkillCourseDetailPageState extends State<SkillCourseDetailPage> {
  /// **Deliberately a plain `StatefulWidget`, not a `ConsumerStatefulWidget`.**
  /// Its suite pumps this screen with no `ProviderScope` above it, so it has to
  /// render without one. Rather than give up the full record for that, the fetch
  /// asks [scopeOf] whether there is a container and simply does nothing when
  /// there is not — the same probe `startCourse` uses, and the same reason: an
  /// un-scoped test must be able to render the page and assert on layout.
  ///
  /// So an id-less course (the hardcoded catalogue) and a scope-less render both
  /// skip the fetch, and the passed-in summary is what shows.
  CourseDetailData? _detail;

  /// This student's own review, or null when they have not written one. See the
  /// same field in `CourseDetailPage`.
  Map<String, dynamic>? _myReview;

  /// Whether the server says this student may review — see the full note on
  /// `CourseDetailPage._canReview`.
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
    final container = scopeOf(context);
    if (container == null) return;
    final api = container.read(courseApiProvider);
    final localEnrolment = isCourseEnrolled(context, _course);
    try {
      final detail = await api.detail(id);
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
      // The summary is already on screen and is a truthful subset — see the
      // same decision in `CourseDetailPage`.
    }
  }

  /// Opens the review sheet, then reloads so the new average and review row come
  /// from the server.
  Future<void> _writeReview(int courseId) async {
    final container = scopeOf(context);
    if (container == null) return;
    final saved = await openCourseReview(
      context,
      api: container.read(courseApiProvider),
      courseId: courseId,
    );
    if (!saved || !mounted) return;
    await _loadDetail();
  }

  /// Enrolment needs a complete profile, so the fields signup stopped asking for
  /// are collected here, on the way in. The user then lands **in the player**
  /// rather than back on this screen with a toast — see `startCourse`.
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
    final id = _course.id;
    return CourseDetailView(
      data: _course,
      isEnrolled: enrolled,
      onEnrol: _enrol,
      onContinue: () => continueCourse(context, _course),
      hasReviewed: _myReview != null,
      onWriteReview: (enrolled || _canReview == true) && id != null
          ? () => _writeReview(id)
          : null,
    );
  }
}
