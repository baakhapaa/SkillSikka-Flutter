import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/features/courses/data/course_adapter.dart';

/// One row of `GET /courses/?course_type=premium`, shaped like the server's.
///
/// Field names matter here: a premium course carries `premium_category_name`
/// and a **null** `skill_category_name`, and the adapter has to read the first
/// one. A helper that filled `skill_category_name` would make the card look
/// right while the app was reading the wrong field.
Map<String, dynamic> premiumCourseRow({
  int id = 60,
  String title = 'Premium DevOps',
  String category = 'Design',
  String? price = '2499.00',
  double? rating = 4.7,
  int reviews = 12,
  int students = 4195,
  bool isPaid = true,
}) => {
  'id': id,
  'title': title,
  'description': 'A paid track.',
  'course_type': 'premium',
  'premium_category': 2,
  'premium_category_name': category,
  'skill_category': null,
  'skill_category_name': null,
  'is_paid': isPaid,
  'price': isPaid ? price : null,
  'thumbnail_url': '',
  'is_published': true,
  'average_rating': rating,
  'review_count': reviews,
  'students_enrolled': students,
  'lessons_count': 1,
  'total_duration_seconds': 300,
  'instructor': 4,
  'instructor_name': 'Test Instructor',
  'level': 'advanced',
  'language': 'English',
  'learning_outcomes': <String>[],
  'requirements': <String>[],
  'updated_at': '2026-10-30T06:00:00Z',
};

/// The same row through the real mapper, which is what the cards render.
CourseDetailData premiumCourse({
  int id = 60,
  String title = 'Premium DevOps',
  String category = 'Design',
  String? price = '2499.00',
  double? rating = 4.7,
  int reviews = 12,
  int students = 4195,
}) => CourseMapper.summary(
  premiumCourseRow(
    id: id,
    title: title,
    category: category,
    price: price,
    rating: rating,
    reviews: reviews,
    students: students,
  ),
);
