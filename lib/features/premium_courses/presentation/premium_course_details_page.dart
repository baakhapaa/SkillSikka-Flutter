import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/course_detail_view.dart';
import '../../courses/data/course_api.dart';
import '../../learning/presentation/start_course.dart';

/// The premium course-detail screen.
///
/// The layout is entirely [CourseDetailView], which the Courses tab renders too
/// — this file supplies the premium content and the enrolment gate, and nothing
/// else. Extracted from here on 2026-10-13.
///
/// Renamed from `CourseDetailsPage` on the same day: it sat one letter away from
/// `CourseDetailPage` in the courses feature, which is a trap rather than a
/// distinction.
class PremiumCourseDetailsPage extends ConsumerStatefulWidget {
  const PremiumCourseDetailsPage({super.key, this.courseId});

  /// The premium course to open, or **null for the bundled demo screen**.
  ///
  /// A card in the premium listing has a real `Course.id` from
  /// `GET /courses/?course_type=premium`, and opening it must show *that*
  /// course — the demo const is one fixed DevOps course and was, until
  /// 2026-10-30, what every card opened regardless of which one was tapped.
  final int? courseId;

  @override
  ConsumerState<PremiumCourseDetailsPage> createState() =>
      _PremiumCourseDetailsPageState();
}

class _PremiumCourseDetailsPageState
    extends ConsumerState<PremiumCourseDetailsPage> {
  /// The fetched course, when [PremiumCourseDetailsPage.courseId] is set.
  CourseDetailData? _course;
  bool _loading = false;
  String? _error;

  /// Whichever course this screen is showing: the fetched one, or the demo.
  CourseDetailData get _showing => _course ?? _premiumCourseDetail;

  @override
  void initState() {
    super.initState();
    if (widget.courseId != null) _load(widget.courseId!);
  }

  Future<void> _load(int id) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final course = await ref.read(courseApiProvider).detail(id);
      if (!mounted) return;
      setState(() {
        _course = course;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.displayMessage;
      });
    }
  }

  /// Enrolment needs a complete profile. The fields signup stopped asking for
  /// are collected here, on the way in, rather than being demanded up front from
  /// everyone who ever taps Sign Up.
  ///
  /// `ensureProfileComplete` re-reads the profile after the user comes back, so
  /// finishing it lands them straight in the course without a second tap.
  ///
  /// The gate takes a container rather than this widget's `ref`: it only reads,
  /// and its other call site is a plain `StatefulWidget` that has no ref to give.
  /// `startCourse` owns that, so all three detail pages share one flow.
  Future<void> _enrol() async {
    await startCourse(context, _showing);
    // The bar reads the enrolment store in `build`, and the answer changed while
    // the player was open.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAF9F6),
        body: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF9F6),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _load(widget.courseId!),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return CourseDetailView(
      data: _showing,
      isEnrolled: isCourseEnrolled(context, _showing),
      onEnrol: _enrol,
      onContinue: () => continueCourse(context, _showing),
    );
  }
}

/// The premium screen's content, moved here verbatim when the layout was
/// extracted.
///
/// **No `bannerVideoAsset` since 2026-10-30.** The banner used to play a bundled
/// trailer, which made this screen the one course detail in the app with a video
/// at the top — a skill course shows its cover image. Removing it makes premium
/// match skill, and it takes `VideoPlayerController` out of this screen
/// entirely, which is why the page could never be pumped in a test (see
/// `course_detail_page_test.dart`). `image` is now what the banner paints.
const _premiumCourseDetail = CourseDetailData(
  image: 'assets/figma/premiumcourse/premcourse.png',
  title: 'DevSecOps & DevOps with Jenkins, Kubernetes, Terraform & AWS',
  subtitle:
      'Implement DAST, SCA & DAST in Jenkins DevSecOps Pipelines from scratch '
      'and setup infra using Terraform, Kubernetes in AWS',
  rating: '4.7',
  level: 'Advanced',
  category: 'DevOps',
  classLevel: 'Class 10',
  ratingsCount: '(14,820 ratings)',
  studentsEnrolled: '4,195 students enrolled',
  instructorName: 'Baakhapaa Digital Pvt Ltd',
  instructorAvatar: 'assets/figma/stlearning/avatar.png',
  lastUpdated: 'Last updated 10/2026',
  languages: 'English, Nepali, Hindi',
  learningOutcomes: [
    'Learn to create AWS Infrastructure to be used by Jenkins',
    'Learn to perform Continuous Integration and Continuous Deployment using Jenkins',
    'Learn DevSecOps Implementation in AWS',
    'Learn DevSecOps Multibranch Pipeline',
  ],
  // **Changed from the original design copy on 2026-10-13.** It read
  // `12 sections • 50 lectures`, which the curriculum could never show — the
  // screen has three sections. Now that the sections expand and the lecture
  // count is derived from the lesson lists, a summary that disagrees with them
  // reads as a bug, so the counts were made true. The duration is unchanged.
  curriculumSummary: '3 sections • 18 lectures • 3h 27m total length',
  modules: [
    CourseModule('Introduction and Course Agenda', '45 mins', [
      CourseLesson('Welcome and what we are building', '04:12'),
      CourseLesson('How to get the most from this course', '06:30'),
      CourseLesson('Setting up Jenkins and AWS', '08:15', isPreview: true),
      CourseLesson('The repository and the plan', '05:48'),
    ]),
    CourseModule('Understand the Core concepts of DevSecOps', '1h 12m', [
      CourseLesson('What DevSecOps actually changes', '07:20'),
      CourseLesson('Static analysis with SonarQube', '09:45'),
      CourseLesson('Software composition analysis (SCA)', '08:32'),
      CourseLesson('Dynamic analysis (DAST) in the pipeline', '10:10'),
      CourseLesson('Secrets scanning and policy gates', '07:55'),
      CourseLesson('Reading the security report', '06:18'),
    ]),
    CourseModule('Terraform Infrastructure automation in AWS', '55 mins', [
      CourseLesson('Terraform state and providers', '08:40'),
      CourseLesson('Building the VPC', '09:25'),
      CourseLesson('EC2, security groups and IAM roles', '10:05'),
      CourseLesson('Provisioning EKS', '11:30'),
      CourseLesson('Remote state and workspaces', '08:15'),
      CourseLesson('Modules and reuse', '07:50'),
      CourseLesson('Drift detection', '06:40'),
      CourseLesson('Tearing it all down safely', '05:55'),
    ]),
  ],
  includes: [
    CourseInclude(
      Icons.play_circle_outline,
      '3 hours, 22 minutes on-demand video',
    ),
    CourseInclude(Icons.quiz_outlined, '1 Quiz'),
    CourseInclude(Icons.description_outlined, '3 Support files'),
    CourseInclude(Icons.article_outlined, '5 Articles'),
    CourseInclude(Icons.all_inclusive, 'Full lifetime access'),
    CourseInclude(Icons.verified_outlined, 'Certificate of completion'),
  ],
  requirements: ['Basic computer knowledge', 'Good to have some AWS Knowledge'],
  descriptionIntro: 'Course Updates:',
  descriptionBlocks: [
    CourseDescriptionBlock(
      heading: 'v 4.0 - April 2026',
      body: 'Added AWS Lab in Lecture 11 - Working with AWS CLI',
    ),
    CourseDescriptionBlock(heading: 'v 3.0 - May 2025...'),
  ],
  descriptionMoreBlocks: [
    CourseDescriptionBlock(
      body:
          'Improved guided labs, added CI/CD examples, and expanded the '
          'AWS security modules with practical exercises.',
    ),
    CourseDescriptionBlock(
      heading: 'v 2.0 - October 2024',
      body:
          'Updated the project material and added beginner-friendly '
          'deployment walkthroughs.',
    ),
  ],
  instructors: [
    CourseInstructor(
      avatar: 'assets/figma/instructors/instructor.png',
      name: 'Shuvanga Karki',
      title: 'Security Architect',
      rating: '4.5',
      reviews: '11,067',
      students: '68,611',
      courses: '15',
      bio:
          'A Security Guru is a dedicated mentor and expert in the field of '
          'application security, DevSecOps, DevOps, and security architecture.',
    ),
    CourseInstructor(
      avatar: 'assets/figma/instructors/instructor1.png',
      name: 'Amrit Poudel',
      title: 'App Security | DevSecOps | Pen Test | Testing | Automation',
      rating: '4.5',
      reviews: '19,326',
      students: '1,03,287',
      courses: '42',
      bio:
          'With over 10 years of experience in security, automation, '
          'development, Gen AI and cloud architecture.',
    ),
  ],
  courseRating: '4.4',
  ratingBars: [
    RatingBar('5 ★', 52),
    RatingBar('4 ★', 37),
    RatingBar('3 ★', 9),
    RatingBar('2 ★', 1),
    RatingBar('1 ★', 1),
  ],
  reviews: [
    CourseReview(name: 'Ajay Badukale', when: '11 days ago', body: 'good'),
    CourseReview(
      name: 'Sanchita Majumder Ghosh',
      when: '15 days ago',
      body: 'awesome learning',
    ),
    CourseReview(name: 'Flintin VF', when: '23 days ago', body: 'good'),
  ],
  totalTime: '10hrs',
  // **Premium courses are paid, always** (product rule, 2026-10-30). There is no
  // free premium course, so this is not a per-course flag here: the price is part
  // of what makes the course premium. `isPaid` therefore has to be true as well —
  // it is a different question from `price.isNotEmpty` (see `CourseDetailData`),
  // and leaving it at the default `false` said "this is a free course with a
  // price on it", which is the one state the product does not have.
  //
  // **The amount is the design's value, not the listing's.** The premium screen
  // is hardcoded to this one course and the premium listing's twelve cards are not
  // linked to it, so there is no card price to inherit. If that link is ever
  // built, this becomes the tapped card's price instead.
  price: 'Rs.24.99',
  isPaid: true,
);
