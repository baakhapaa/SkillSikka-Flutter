import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillsikka/features/bootcamp/data/bootcamp.dart';
import 'package:skillsikka/features/bootcamp/data/bootcamp_api.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/features/courses/data/course_api.dart';
import 'package:skillsikka/features/events/data/event_page.dart';
import 'package:skillsikka/features/events/data/events_providers.dart';
import 'package:skillsikka/features/learning/data/learning_api.dart';
import 'package:skillsikka/features/learning/data/my_learning.dart';

/// Wraps [child] in a `ProviderScope` whose shell fetches are stubbed.
///
/// **Three providers, one scope.** `AppShell` builds every tab inside an
/// `IndexedStack`, so mounting it runs three requests nobody asked for:
///
/// | Provider | Since | What it would otherwise do |
/// |---|---|---|
/// | `nearbyEventsProvider` | 2026-10-08 | `GET /events/?near=true` **and** `geolocator`, which throws `MissingPluginException` under `flutter test` |
/// | `bootcampsProvider` | 2026-10-31 | `GET /courses/?course_type=bootcamp` |
/// | `myLearningProvider` | 2026-10-27 | `GET /my-learning/` |
/// | `homePremiumCoursesProvider` | 2026-11-20 | `GET /courses/?course_type=premium` |
/// | `skillCatalogueProvider` | 2026-11-20 | `GET /courses/?course_type=skill` |
///
/// A live request here is worse than noise: dio's 15s timeout outlives the
/// widget, so a test that disposes mid-flight fails the *next* assertion with
/// `A Timer is still pending` — and with the dev host unreachable the whole
/// suite waits on that timeout instead of running.
///
/// **Overriding the provider, not the API**, is deliberate: it is the single
/// seam each screen reads, so one override removes the network, the location
/// call and the timer together.
///
/// All defaults are **empty**, which makes each section render nothing. That
/// keeps a layout test measuring the sections it actually asserts on, instead of
/// a rail whose height depends on whether a mocked request has landed yet.
///
/// The name predates the second and third provider and is kept so eight suites
/// do not churn over a rename; it is the shell scope, not an events-only one.
Widget eventsTestScope({
  required Widget child,
  EventPage? page,
  List<BootcampCard> bootcamps = const <BootcampCard>[],
  List<CourseDetailData> premium = const <CourseDetailData>[],
  List<CourseDetailData> academic = const <CourseDetailData>[],
  MyLearning? learning,
}) {
  return ProviderScope(
    overrides: [
      nearbyEventsProvider.overrideWith((ref) async => page ?? EventPage.empty),
      bootcampsProvider.overrideWith((ref) async => bootcamps),
      homeAcademicCoursesProvider.overrideWith(
        (ref, classIndex) async => academic,
      ),
      homePremiumCoursesProvider.overrideWith((ref) async => premium),
      skillCatalogueProvider.overrideWith((ref) async => const []),
      myLearningProvider.overrideWith(
        (ref) async => learning ?? const MyLearning(),
      ),
    ],
    child: child,
  );
}
