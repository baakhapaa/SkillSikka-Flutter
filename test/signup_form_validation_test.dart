import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:skillsikka/core/location/location_service.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/features/auth/data/auth_repository.dart';
import 'package:skillsikka/features/profile/data/user_profile.dart';
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

/// A real 1x1 PNG. `ProfilePhotoPicker` renders the photo with `Image.memory`,
/// so seeded bytes have to decode — arbitrary bytes throw from the image codec
/// and fail the test for a reason that has nothing to do with the assertion.
final _onePixelPng = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAF'
    'AAH/q842iQAAAABJRU5ErkJggg==',
  ),
);

/// Pumps the student form with the network faked out.
///
/// Returns the fake so a test can set it up to fail, or assert on what the form
/// actually sent. Without the override the real repository would attempt HTTP,
/// which in a widget test means a transport error rather than the code under
/// test.
Future<FakeAuthRepository> _pumpForm(
  WidgetTester tester, {
  List<String>? navigatedTo,
  bool withPhoto = false,
  Duration latency = Duration.zero,
}) async {
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

  final auth = FakeAuthRepository(latency: latency);
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(auth)],
  );
  addTearDown(container.dispose);

  // The form refuses to submit without one, because registration is a multipart
  // request whose photo part is mandatory. It has to be a real image: the picker
  // renders it with `Image.memory`, and arbitrary bytes throw from the codec.
  if (withPhoto) {
    container
        .read(userProfileProvider.notifier)
        .setPhoto(_onePixelPng, 'avatar.png');
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  // The location popup opens on load. Dismiss it so the form is tappable.
  await tester.tapAt(const Offset(8, 8));
  await tester.pumpAndSettle();

  return auth;
}

/// Fills every field with a value the client-side rules accept.
Future<void> _fillValidForm(WidgetTester tester) async {
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
    final auth = await _pumpForm(
      tester,
      navigatedTo: navigated,
      withPhoto: true,
    );

    await _fillValidForm(tester);

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(navigated, ['/signup/verify']);
    expect(find.text('verify step'), findsOneWidget);

    // …and it really did register, with the fields the form holds.
    expect(auth.registrations, hasLength(1));
    final sent = auth.registrations.single;
    expect(sent.fields['name'], 'Sita Rai');
    expect(sent.fields['email'], 'sita@example.com');
    expect(sent.fields['password'], 'Passw0rd');
    expect(sent.fields['gender'], 'Female');
    expect(sent.photo.fileName, 'avatar.png');
  });

  testWidgets('a field error from the server lands on the field', (
    tester,
  ) async {
    final navigated = <String>[];
    final auth = await _pumpForm(
      tester,
      navigatedTo: navigated,
      withPhoto: true,
    );
    auth.failure = const ApiException(
      kind: ApiErrorKind.badRequest,
      statusCode: 400,
      fieldErrors: {'email': 'This email is already registered.'},
    );

    await _fillValidForm(tester);
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    // On the input rather than only in a snack bar: "that email is taken" is
    // useless without saying which box.
    expect(find.text('This email is already registered.'), findsOneWidget);
    expect(
      navigated,
      isEmpty,
      reason: 'a rejected registration must not advance',
    );
    await _drainSnackBar(tester);
  });

  testWidgets('editing a field clears the message the server sent', (
    tester,
  ) async {
    final auth = await _pumpForm(tester, withPhoto: true);
    auth.failure = const ApiException(
      kind: ApiErrorKind.badRequest,
      statusCode: 400,
      fieldErrors: {'email': 'This email is already registered.'},
    );

    await _fillValidForm(tester);
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(find.text('This email is already registered.'), findsOneWidget);
    await _drainSnackBar(tester);

    // The value the server rejected is no longer the value in the box, so
    // leaving the message up would be stale.
    await tester.enterText(_fields.at(_emailField), 'other@example.com');
    await tester.pumpAndSettle();

    expect(find.text('This email is already registered.'), findsNothing);
  });

  testWidgets('a network failure keeps the user on the form', (tester) async {
    final navigated = <String>[];
    final auth = await _pumpForm(
      tester,
      navigatedTo: navigated,
      withPhoto: true,
    );
    auth.failure = const ApiException(
      kind: ApiErrorKind.network,
      message: 'Could not reach the server. Check your connection.',
    );

    await _fillValidForm(tester);
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(navigated, isEmpty);
    expect(
      find.text('Could not reach the server. Check your connection.'),
      findsOneWidget,
    );
    // The button is usable again, so the user can retry.
    expect(find.text('Create Account'), findsOneWidget);
    await _drainSnackBar(tester);
  });

  testWidgets('the button is disabled while a request is in flight', (
    tester,
  ) async {
    final auth = await _pumpForm(
      tester,
      withPhoto: true,
      latency: const Duration(milliseconds: 300),
    );

    await _fillValidForm(tester);
    await tester.tap(find.text('Create Account'));
    await tester.pump();

    // The label is replaced by progress, so the button reads as busy rather than
    // broken on a slow connection.
    expect(find.text('Create Account'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Disabled is the guard that matters, and it is asserted directly rather
    // than by tapping again: Flutter delivers no tap to a disabled button, so a
    // second tap would "pass" whether or not the guard existed.
    expect(find.byType(FilledButton), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(
      button.onPressed,
      isNull,
      reason:
          'a live button here means an impatient second tap registers twice',
    );

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(auth.registrations, hasLength(1));
  });

  testWidgets('a missing photo is reported without sending anything', (
    tester,
  ) async {
    final navigated = <String>[];
    // No photo seeded: registration is multipart and the avatar part is
    // mandatory, so there is no request to make.
    final auth = await _pumpForm(tester, navigatedTo: navigated);

    await _fillValidForm(tester);
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Add a profile photo to continue.'), findsOneWidget);
    expect(auth.registrations, isEmpty, reason: 'nothing should be sent');
    expect(navigated, isEmpty);
    await _drainSnackBar(tester);
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
