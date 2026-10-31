import 'package:dio/dio.dart';
import 'package:skillsikka/core/network/api_client.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/features/bootcamp/data/bootcamp.dart';
import 'package:skillsikka/features/bootcamp/data/bootcamp_api.dart';

/// A bootcamp payload and a fake API, shared by the suites that open one.
///
/// **Why it lives here.** Two screens can now open the bootcamp player — the
/// home rail and My Learning — and both tests need a camp to render. Copying a
/// 20-field fixture into the second suite is how the two drift apart.
///
/// Images are left blank on purpose: a real URL would put `Image.network` on the
/// test's HTTP client, which answers 400 and reports an image-loading error. An
/// empty path takes `CourseImage`'s asset fallback, which is the same branch the
/// design's bundled artwork uses.
BootcampDetail camp({List<BootcampDay>? days}) => BootcampDetail(
  id: 7,
  title: 'ICT & AI BOOTCAMP at Sundarbazar',
  description: 'Master the foundations of design strategy.',
  shortDescription: 'Four days of strategy, brand and delivery.',
  venueName: 'Sundarbazar',
  status: 'upcoming',
  heroVideoUrl: '',
  heroPosterUrl: '',
  image: '',
  qualityLabel: 'HD',
  level: 'beginner',
  language: 'English',
  durationDays: 4,
  studentsEnrolled: 12400,
  viewCount: 2500,
  startsOn: DateTime(2026, 11, 16),
  endsOn: DateTime(2026, 11, 19),
  instructorNames: const ['Shuvanga Karki', 'Amrit Bhandari'],
  days:
      days ??
      const [
        BootcampDay(1, [
          BootcampSection('Section 1: Research & Strategy Foundations', [
            BootcampLesson(
              number: 1,
              id: 11,
              title: 'Defining the Product Strategy Grid',
              duration: '18:45',
              dayNumber: 1,
              section: 'Section 1: Research & Strategy Foundations',
              kind: CourseLessonKind.video,
              isPreview: false,
              isCompleted: false,
              contentUrl: 'https://cdn.example.com/one.mp4',
            ),
          ]),
        ]),
        BootcampDay(2, [
          BootcampSection('Section 2: Design & Prototyping', [
            BootcampLesson(
              number: 2,
              id: 12,
              title: 'Wireframing for Mobile Interfaces',
              duration: '32:40',
              dayNumber: 2,
              section: 'Section 2: Design & Prototyping',
              kind: CourseLessonKind.video,
              isPreview: false,
              isCompleted: false,
              contentUrl: 'https://cdn.example.com/two.mp4',
            ),
          ]),
        ]),
      ],
  fileSections: const [
    BootcampFileSection('Section 1: Course Materials', [
      CourseResource(
        'Product Strategy Grid Template',
        CourseResourceType.pdf,
        id: 3,
        url: 'https://cdn.example.com/grid.pdf',
      ),
    ]),
  ],
  lessonCount: 2,
  episodeNo: 2,
);

/// [BootcampApi] with no network: [detail] answers [value] or throws [failure].
class FakeBootcampApi extends BootcampApi {
  FakeBootcampApi({this.value, this.failure}) : super(ApiClient(Dio()));

  BootcampDetail? value;
  ApiException? failure;

  /// Every course id asked for, so a test can prove the screen opened *this*
  /// camp rather than some other one.
  final List<int> calls = <int>[];

  @override
  Future<BootcampDetail> detail(int id) async {
    calls.add(id);
    final error = failure;
    if (error != null) throw error;
    return value!;
  }
}
