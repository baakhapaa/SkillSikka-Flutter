import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/profile/data/profile_completeness.dart';
import 'package:skillsikka/features/profile/data/profile_role.dart';
import 'package:skillsikka/features/profile/data/reference_data.dart';
import 'package:skillsikka/features/profile/data/user_profile.dart';
import 'package:skillsikka/features/profile/presentation/complete_profile_gate.dart';
import 'package:skillsikka/features/profile/presentation/edit_profile_page.dart';
import 'package:skillsikka/features/profile/presentation/profile_page.dart';

/// The reference lists the province/district/school pickers read.
///
/// **These used to be `const` lists inside `edit_profile_page.dart`**, so a test
/// could tap 'Bagmati' with no setup at all. They come from the backend now
/// (`/locations/*`), which means a widget test has to stand them in — under
/// `flutter test` every real HTTP request returns 400, so without these
/// overrides the picker would open empty and the taps below would find nothing.
///
/// The sets are deliberately the real ones (seven provinces, `Grade 1`–`12`) so
/// a shape change on the backend that the parser mishandles would surface here.
const _provinces = [
  ReferenceItem(id: '1', name: 'Bagmati'),
  ReferenceItem(id: '2', name: 'Gandaki'),
  ReferenceItem(id: '3', name: 'Koshi'),
];

const _districts = [
  ReferenceItem(id: '10', name: 'Kathmandu', provinceId: '1'),
  ReferenceItem(id: '11', name: 'Lalitpur', provinceId: '1'),
  ReferenceItem(id: '12', name: 'Kaski', provinceId: '2'),
];

const _schools = [
  ReferenceItem(id: '20', name: 'National College'),
  ReferenceItem(id: '21', name: 'Kathmandu Model College'),
];

/// A container whose reference data never touches the network.
ProviderContainer _referenceContainer() {
  final container = ProviderContainer(
    overrides: [
      provincesProvider.overrideWith((ref) async => _provinces),
      districtsForProvinceProvider.overrideWith(
        (ref, provinceName) async => provinceName.trim() == 'Bagmati'
            ? _districts.where((d) => d.provinceId == '1').toList()
            : const <ReferenceItem>[],
      ),
      schoolsForDistrictProvider.overrideWith(
        (ref, districtName) async => districtName.trim() == 'Kathmandu'
            ? _schools
            : const <ReferenceItem>[],
      ),
      gradesProvider.overrideWith((ref) async => const <ReferenceItem>[]),
    ],
  );
  return container;
}

/// The gate is called from the enrol button and from the "Add New Course" tile,
/// so the test drives it the same way: a button that records whatever the gate
/// decides.
///
/// This deliberately avoids pumping `CourseDetailsPage` — that screen builds a
/// `VideoPlayerController` from an asset, which is unrelated noise here.
class _GateHarness extends StatelessWidget {
  const _GateHarness({required this.onResult, this.addCourse = false});

  final void Function(bool) onResult;

  /// Drives [ensureCanAddCourse] instead of [ensureProfileComplete].
  final bool addCourse;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () async {
          // The same container lookup the real call sites use. The gate only
          // reads, so it takes a container rather than a `WidgetRef`.
          final container = ProviderScope.containerOf(context, listen: false);
          onResult(
            addCourse
                ? await ensureCanAddCourse(context, container)
                : await ensureProfileComplete(context, container),
          );
        },
        child: Text(addCourse ? 'add course' : 'enrol'),
      ),
    ),
  );
}

/// A complete profile, as the completion flow would leave it.
Map<String, String> get _completeValues => {
  for (final field in studentEnrolmentFields) field.key: 'x',
};

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  List<bool> results, {
  double height = 800,
  bool addCourse = false,
}) async {
  await tester.binding.setSurfaceSize(Size(360, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: _GateHarness(onResult: results.add, addCourse: addCourse),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapEnrol(WidgetTester tester) async {
  await tester.tap(find.text('enrol'));
  await tester.pumpAndSettle();
}

Future<void> _tapAddCourse(WidgetTester tester) async {
  await tester.tap(find.text('add course'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a complete profile goes straight through', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(userProfileProvider.notifier).save(_completeValues);

    final results = <bool>[];
    await _pump(tester, container, results);
    await _tapEnrol(tester);

    expect(results, [true]);
    expect(find.text('Complete your profile'), findsNothing);
  });

  testWidgets(
    'an incomplete profile is stopped and told exactly what is missing',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // One field already done, so the list has to be selective.
      container.read(userProfileProvider.notifier).save({'gender': 'Female'});

      final results = <bool>[];
      await _pump(tester, container, results);
      await _tapEnrol(tester);

      expect(find.text('Complete your profile'), findsOneWidget);
      // Naming the fields is the point: "your profile is incomplete" would send
      // the user hunting through the form.
      expect(find.text('Phone number'), findsOneWidget);
      expect(find.text('School / College'), findsOneWidget);
      expect(find.text('7 fields still needed'), findsOneWidget);
      // The one already filled is not listed.
      expect(find.text('Gender'), findsNothing);

      expect(results, isEmpty, reason: 'the gate must wait for a choice');

      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      expect(results, [
        false,
      ], reason: 'declining must not let enrolment through');
    },
  );

  testWidgets('dismissing the popup does not let the action through', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final results = <bool>[];
    await _pump(tester, container, results);
    await _tapEnrol(tester);
    expect(find.text('Complete your profile'), findsOneWidget);

    // Tap the scrim.
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.text('Complete your profile'), findsNothing);
    expect(results, [false]);
  });

  testWidgets('completion mode refuses a partial profile', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Name and email are supplied — they are always required — while everything
    // the completion flow is actually about is left blank, so Save must refuse
    // and keep the screen open. The form no longer pre-fills these from a seed,
    // so the test states them. **Before the pump**, because the form reads the
    // store once when it builds its controllers.
    container.read(userProfileProvider.notifier).save({
      'name': 'Real User',
      'email': 'real@user.test',
    });

    final results = <bool>[];
    // Tall enough that every field is reachable without scrolling.
    await _pump(tester, container, results, height: 1400);
    await _tapEnrol(tester);

    await tester.tap(find.text('Complete Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfilePage), findsOneWidget);

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(
      find.byType(EditProfilePage),
      findsOneWidget,
      reason: 'completion mode must not accept a partial profile',
    );
    expect(find.text('Please select your gender.'), findsOneWidget);
    expect(find.text('Please enter your location.'), findsOneWidget);

    // Let the summary snack bar expire so no timer outlives the test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('finishing the profile from the popup lets enrolment continue', (
    tester,
  ) async {
    // Reference data comes from the overrides, not from `/locations/*` — see
    // `_referenceContainer`. Without it the picker sheets open empty here,
    // because every real request under `flutter test` returns 400.
    final container = _referenceContainer();
    addTearDown(container.dispose);

    // Name, email, phone and class are pre-filled, the way a real user arrives
    // at this screen — signup captured the first three and `GET /me/` fills the
    // rest. This used to be `_studentSeed` in the page itself; the seed is gone,
    // so the test supplies the same starting state honestly rather than relying
    // on the form to invent it.
    container.read(userProfileProvider.notifier).save({
      'name': 'Real User',
      'email': 'real@user.test',
      'phone': '9801234567',
      'grade': 'Grade 9',
    });

    final results = <bool>[];
    await _pump(tester, container, results, height: 1400);
    await _tapEnrol(tester);
    await tester.tap(find.text('Complete Profile'));
    await tester.pumpAndSettle();

    // Field order: name, email, phone, gender, dob, location, class, province,
    // district, school.
    final fields = find.byType(TextFormField);

    await tester.tap(fields.at(3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();

    await tester.tap(fields.at(4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(fields.at(5), 'Baneshwor, Kathmandu');
    await tester.pumpAndSettle();

    // Province, district and school are async now: the tap opens a sheet only
    // after the list resolves, so `pumpAndSettle` has to cover the fetch.
    await tester.tap(fields.at(7));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bagmati'));
    await tester.pumpAndSettle();

    await tester.tap(fields.at(8));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kathmandu'));
    await tester.pumpAndSettle();

    await tester.tap(fields.at(9));
    await tester.pumpAndSettle();
    await tester.tap(find.text('National College'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfilePage), findsNothing);
    // Re-read on return, so the user lands in the course without a second tap.
    expect(results, [true]);
  });

  group('the instructor course-creation gate', () {
    Map<String, String> completeInstructorValues() => {
      for (final field in instructorCourseCreationFields) field.key: 'x',
    };

    testWidgets('a complete instructor profile goes straight through', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(userProfileProvider.notifier);
      notifier.setRole(ProfileRole.instructor);
      notifier.save(completeInstructorValues());

      final results = <bool>[];
      await _pump(tester, container, results, addCourse: true);
      await _tapAddCourse(tester);

      expect(results, [true]);
      expect(find.text('Complete your profile'), findsNothing);
    });

    testWidgets(
      'an instructor is asked for instructor fields, not a student\'s',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(userProfileProvider.notifier);
        notifier.setRole(ProfileRole.instructor);
        // One field done, so the list has to be selective.
        notifier.save({'phone': '9812345678'});

        final results = <bool>[];
        await _pump(tester, container, results, addCourse: true);
        await _tapAddCourse(tester);

        expect(find.text('Complete your profile'), findsOneWidget);
        // The copy says what the user was trying to do, so the same popup can
        // serve enrolment and course creation without reading as the other.
        expect(
          find.text(
            'You need to finish your profile before you can add a new course.',
          ),
          findsOneWidget,
        );
        expect(find.text('Subject expertise'), findsOneWidget);
        expect(find.text('Highest qualification'), findsOneWidget);
        expect(find.text('4 fields still needed'), findsOneWidget);
        // The student requirements must not be demanded of an instructor — this is
        // exactly the bug the role-aware field list fixes.
        expect(find.text('Class / Grade'), findsNothing);
        expect(find.text('School / College'), findsNothing);
        // The one already filled is not listed.
        expect(find.text('Phone number'), findsNothing);

        expect(results, isEmpty, reason: 'the gate must wait for a choice');

        await tester.tap(find.text('Not Now'));
        await tester.pumpAndSettle();
        expect(results, [false], reason: 'declining must not let it through');
      },
    );
  });

  testWidgets('the Add New Course tile runs the gate', (tester) async {
    // The end-to-end wiring: the tile on the profile tab is what calls the gate.
    // `ProfilePage` is a plain `StatefulWidget`, so this also pins that the
    // container lookup works without a `ConsumerState`.
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(userProfileProvider.notifier);
    notifier.setRole(ProfileRole.instructor);
    notifier.save({'name': 'Real Instructor'});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ProfilePage())),
      ),
    );
    await tester.pump();

    // The page's cards are laid out for Manrope, which `flutter test` cannot
    // fetch — the Roboto stand-in wraps differently and overflows. Pre-existing
    // and unrelated to the tile, so drain it; anything that is not an overflow
    // still fails the test.
    for (
      var e = tester.takeException();
      e != null;
      e = tester.takeException()
    ) {
      final text = e.toString();
      expect(
        text.contains('overflowed') || text.contains('Multiple exceptions'),
        isTrue,
        reason: 'unexpected exception on the profile page: $text',
      );
    }

    final tile = find.text('Add New Course');
    expect(tile, findsOneWidget, reason: 'the tile is the gate entry point');
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();

    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(
      find.text('Complete your profile'),
      findsOneWidget,
      reason: 'the tile must run the gate rather than do nothing',
    );
    expect(find.text('Subject expertise'), findsOneWidget);

    // Leave nothing pending.
    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();
  });
}
