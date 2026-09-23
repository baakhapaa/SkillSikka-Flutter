import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/profile/data/profile_completeness.dart';
import 'package:skillsikka/features/profile/data/user_profile.dart';
import 'package:skillsikka/features/profile/presentation/complete_profile_gate.dart';
import 'package:skillsikka/features/profile/presentation/edit_profile_page.dart';

/// The gate is called from the enrol button, so the test drives it the same
/// way: a button that records whatever `ensureProfileComplete` decides.
///
/// This deliberately avoids pumping `CourseDetailsPage` — that screen builds a
/// `VideoPlayerController` from an asset, which is unrelated noise here.
class _GateHarness extends ConsumerWidget {
  const _GateHarness({required this.onResult});

  final void Function(bool) onResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () async {
          onResult(await ensureProfileComplete(context, ref));
        },
        child: const Text('enrol'),
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
}) async {
  await tester.binding.setSurfaceSize(Size(360, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: _GateHarness(onResult: results.add)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapEnrol(WidgetTester tester) async {
  await tester.tap(find.text('enrol'));
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

    final results = <bool>[];
    // Tall enough that every field is reachable without scrolling.
    await _pump(tester, container, results, height: 1400);
    await _tapEnrol(tester);

    await tester.tap(find.text('Complete Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfilePage), findsOneWidget);

    // The demo seed fills name, email, phone and class; the rest are empty, so
    // Save must refuse and keep the screen open.
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
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final results = <bool>[];
    await _pump(tester, container, results, height: 1400);
    await _tapEnrol(tester);
    await tester.tap(find.text('Complete Profile'));
    await tester.pumpAndSettle();

    // Field order: name, email, phone, gender, dob, location, class, province,
    // district, school. The seed already covers name/email/phone/class.
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
}
