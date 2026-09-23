import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:skillsikka/core/location/location_service.dart';
import 'package:skillsikka/features/signup/presentation/signup_student_form_page.dart';

/// Keeps the real geolocator plugin out of the test. `hasPermission() == false`
/// puts the popup on its explainer stage, which [_pumpForm] then dismisses.
class _StubLocationService extends LocationService {
  const _StubLocationService();

  @override
  Future<bool> hasPermission() async => false;
}

/// The form's fields, in build order.
const _nameField = 0;
const _emailField = 1;
const _passwordField = 2;
const _confirmField = 3;
const _genderField = 4;
const _dobField = 5;

Finder get _fields => find.byType(TextFormField);

Future<void> _pumpForm(WidgetTester tester, {List<String>? navigatedTo}) async {
  // The form is taller than the 800x600 default surface, which would put the
  // picker fields out of reach of a tap.
  await tester.binding.setSurfaceSize(const Size(360, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final router = GoRouter(
    initialLocation: '/signup/student',
    routes: [
      GoRoute(
        path: '/signup/student',
        builder: (_, _) => const SignupStudentFormPage(
          locationService: _StubLocationService(),
        ),
      ),
      GoRoute(
        path: '/signup/verify',
        builder: (_, _) {
          navigatedTo?.add('/signup/verify');
          return const Scaffold(body: Text('verify step'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();

  // The location popup opens on load. Dismiss it so the form is tappable.
  await tester.tapAt(const Offset(8, 8));
  await tester.pumpAndSettle();
}

/// A failed submit shows a summary snack bar, which leaves a timer behind.
Future<void> _drainSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty form is rejected field by field', (tester) async {
    final navigated = <String>[];
    await _pumpForm(tester, navigatedTo: navigated);

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    // Every failing field is marked at once, rather than one snack bar at a time.
    expect(find.text('Please enter your full name.'), findsOneWidget);
    expect(find.text('Please enter your email address.'), findsOneWidget);
    expect(find.text('Please enter a password.'), findsOneWidget);
    expect(find.text('Please re-enter your password.'), findsOneWidget);
    expect(find.text('Please select your gender.'), findsOneWidget);
    expect(find.text('Please select your date of birth.'), findsOneWidget);
    expect(find.text('Please check the highlighted fields.'), findsOneWidget);

    expect(navigated, isEmpty, reason: 'an invalid form must not advance');
    await _drainSnackBar(tester);
  });

  testWidgets(
    'a malformed email gets the format message, not the required one',
    (tester) async {
      await _pumpForm(tester);

      await tester.enterText(_fields.at(_emailField), 'skill@email');
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a valid email address, e.g. name@example.com.'),
        findsOneWidget,
      );
      expect(
        find.text('Please enter your email address.'),
        findsNothing,
        reason:
            'the field is not empty, so the required message would be wrong',
      );
      await _drainSnackBar(tester);
    },
  );

  testWidgets('mismatched passwords are caught and the error clears on fix', (
    tester,
  ) async {
    await _pumpForm(tester);

    await tester.enterText(_fields.at(_passwordField), 'Passw0rd');
    await tester.enterText(_fields.at(_confirmField), 'Passw0rdX');
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);

    // After the first failed submit the form re-validates as the user types.
    await tester.enterText(_fields.at(_confirmField), 'Passw0rd');
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsNothing);

    await _drainSnackBar(tester);
  });

  testWidgets('editing the password re-checks the confirmation', (
    tester,
  ) async {
    await _pumpForm(tester);

    await tester.enterText(_fields.at(_passwordField), 'Passw0rd');
    await tester.enterText(_fields.at(_confirmField), 'Passw0rd');
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsNothing);
    await _drainSnackBar(tester);

    // Change the password out from under the matching confirmation. The
    // confirmation rule depends on this value, so it has to be re-checked.
    await tester.enterText(_fields.at(_passwordField), 'Passw0rd2');
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsOneWidget);

    await _drainSnackBar(tester);
  });

  testWidgets('a weak password is rejected with the rule it broke', (
    tester,
  ) async {
    await _pumpForm(tester);

    await tester.enterText(_fields.at(_passwordField), 'abcdefgh');
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(find.text('Include at least one number.'), findsOneWidget);
    await _drainSnackBar(tester);

    await tester.enterText(_fields.at(_passwordField), 'abcd');
    await tester.pumpAndSettle();
    expect(find.text('Use at least 8 characters.'), findsOneWidget);

    await _drainSnackBar(tester);
  });

  testWidgets('a complete, well-formed form advances to verification', (
    tester,
  ) async {
    final navigated = <String>[];
    await _pumpForm(tester, navigatedTo: navigated);

    await tester.enterText(_fields.at(_nameField), 'Sita Rai');
    await tester.enterText(_fields.at(_emailField), 'sita@example.com');
    await tester.enterText(_fields.at(_passwordField), 'Passw0rd');
    await tester.enterText(_fields.at(_confirmField), 'Passw0rd');

    // Gender and date of birth are pickers rather than keyboards.
    await tester.tap(_fields.at(_genderField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();

    await tester.tap(_fields.at(_dobField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(navigated, ['/signup/verify']);
    expect(find.text('verify step'), findsOneWidget);
  });

  testWidgets('a picker selection clears the error it was showing', (
    tester,
  ) async {
    await _pumpForm(tester);

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(find.text('Please select your gender.'), findsOneWidget);

    // The summary snack bar floats over the lower half of the form and would
    // swallow the tap, so let it expire first.
    await _drainSnackBar(tester);

    // A programmatic controller write does not fire FormField.didChange, so the
    // form has to re-check itself after a picker returns.
    await tester.tap(_fields.at(_genderField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();

    expect(find.text('Please select your gender.'), findsNothing);
  });
}
