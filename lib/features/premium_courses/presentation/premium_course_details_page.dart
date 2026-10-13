import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/course_detail_view.dart';
import '../../profile/presentation/complete_profile_gate.dart';

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
  const PremiumCourseDetailsPage({super.key});

  @override
  ConsumerState<PremiumCourseDetailsPage> createState() =>
      _PremiumCourseDetailsPageState();
}

class _PremiumCourseDetailsPageState
    extends ConsumerState<PremiumCourseDetailsPage> {
  /// Enrolment needs a complete profile. The fields signup stopped asking for
  /// are collected here, on the way in, rather than being demanded up front from
  /// everyone who ever taps Sign Up.
  ///
  /// `ensureProfileComplete` re-reads the profile after the user comes back, so
  /// finishing it lands them straight in the course without a second tap.
  ///
  /// The gate takes a container rather than this widget's `ref`: it only reads,
  /// and its other call site is a plain `StatefulWidget` that has no ref to give.
  Future<void> _enrol() async {
    final allowed = await ensureProfileComplete(
      context,
      ProviderScope.containerOf(context, listen: false),
    );
    if (!allowed || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enrolled successfully!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF111827),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      CourseDetailView(data: _premiumCourseDetail, onEnrol: _enrol);
}

/// The premium screen's content, moved here verbatim when the layout was
/// extracted. `image` is the premium listing's own artwork and is never painted
/// — the banner plays [CourseDetailData.bannerVideoAsset] instead — but the
/// field is required, so it carries the honest value.
const _premiumCourseDetail = CourseDetailData(
  image: 'assets/figma/premiumcourse/premcourse.png',
  bannerVideoAsset: 'assets/figma/stlearning/video.mp4',
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
  subtitleTracks: 'CC English [Auto]',
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
    CourseInclude(Icons.devices, 'Access on mobile, desktop and TV'),
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
);
