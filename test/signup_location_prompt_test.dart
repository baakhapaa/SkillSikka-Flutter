import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillsikka/core/location/location_service.dart';
import 'package:skillsikka/core/widgets/location_prompt_dialog.dart';
import 'package:skillsikka/features/profile/data/user_profile.dart';
import 'package:skillsikka/features/signup/presentation/signup_student_form_page.dart';

/// Same channel `geolocator` uses; stubbing it keeps the real service
/// deterministic instead of waiting on a plugin round-trip that never lands.
const _geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');

void _mockGeolocatorPermission(int permission) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_geolocatorChannel, (call) async {
    if (call.method == 'checkPermission') return permission;
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(_geolocatorChannel, null),
  );
}

/// Stands in for the real plugin so the prompt can be driven deterministically.
class _FakeLocationService extends LocationService {
  _FakeLocationService({this.result, this.failure, this.hang = false});

  final DetectedLocation? result;
  final LocationFailure? failure;

  /// When true the lookup never resolves, to hold the loading stage open.
  final bool hang;

  int detectCalls = 0;
  int settingsCalls = 0;

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<DetectedLocation> detectCurrentLocation({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    detectCalls++;
    if (hang) return Completer<DetectedLocation>().future;
    final failure = this.failure;
    if (failure != null) throw failure;
    return result!;
  }

  @override
  Future<void> openSettings({required bool forLocationServices}) async {
    settingsCalls++;
  }
}

const _kathmandu = DetectedLocation(
  label: 'Baneshwor, Kathmandu',
  latitude: 27.6893,
  longitude: 85.3407,
);

Future<void> _showPrompt(
  WidgetTester tester,
  _FakeLocationService service, {
  bool skipIntro = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showLocationPromptDialog(
                context,
                service: service,
                skipIntro: skipIntro,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'signup form opens the location popup on load, no manual option',
    (tester) async {
      // 0 == LocationPermission.denied, i.e. a first-time visitor.
      _mockGeolocatorPermission(0);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SignupStudentFormPage())),
      );
      // The permission check is a platform round-trip, so the popup lands a
      // frame or two after the form paints.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Use your current location?'), findsOneWidget);
      expect(find.text('Allow Location'), findsOneWidget);
      // The manual-entry escape hatch is gone.
      expect(find.text('Enter Manually'), findsNothing);

      // Tapping the scrim dismisses and leaves the form usable.
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(find.text('Use your current location?'), findsNothing);

      // The form kept its identity fields...
      expect(find.text('e.g. Skill Sikka'), findsOneWidget);
      expect(find.text('e.g. skill@email.com'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      // ...exactly six inputs, no more.
      expect(find.byType(TextField), findsNWidgets(6));

      // ...and the fields that moved to Edit Profile are gone, Location
      // included. Asserted through the hints because this form draws its
      // labels with a raw RichText, which the text finders do not match.
      expect(find.text('Enter your current location'), findsNothing);
      expect(find.text('Select your class'), findsNothing);
      expect(find.text('+977 98XXXXXXXX'), findsNothing);
      expect(find.text('Select school or college'), findsNothing);
    },
  );

  testWidgets('allowing location shows the detected place for confirmation', (
    tester,
  ) async {
    final service = _FakeLocationService(result: _kathmandu);
    DetectedLocation? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showLocationPromptDialog(
                    context,
                    service: service,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Use your current location?'), findsOneWidget);

    await tester.tap(find.text('Allow Location'));
    await tester.pumpAndSettle();

    expect(service.detectCalls, 1);
    expect(find.text('Location detected'), findsOneWidget);
    expect(find.text('Baneshwor, Kathmandu'), findsOneWidget);

    await tester.tap(find.text('Use This Location'));
    await tester.pumpAndSettle();

    expect(result?.label, 'Baneshwor, Kathmandu');
  });

  testWidgets('skipIntro detects immediately without the explainer', (
    tester,
  ) async {
    final service = _FakeLocationService(result: _kathmandu);
    await _showPrompt(tester, service, skipIntro: true);

    expect(find.text('Use your current location?'), findsNothing);
    expect(find.text('Location detected'), findsOneWidget);
    expect(service.detectCalls, 1);
  });

  testWidgets('loading offers Cancel and never a manual option', (
    tester,
  ) async {
    final service = _FakeLocationService(hang: true);
    // No pumpAndSettle: the spinner animates forever while we hold this stage.
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showLocationPromptDialog(
                  context,
                  service: service,
                  skipIntro: true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Finding you…'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Enter Manually'), findsNothing);
    expect(find.text('Allow Location'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Finding you…'), findsNothing);
  });

  testWidgets('blocked permission offers a route to settings', (tester) async {
    final service = _FakeLocationService(
      failure: const LocationFailure(
        LocationFailureReason.permissionDeniedForever,
        'blocked',
      ),
    );
    await _showPrompt(tester, service);

    await tester.tap(find.text('Allow Location'));
    await tester.pumpAndSettle();

    expect(find.text('Open Settings'), findsOneWidget);
    expect(find.text('Enter Manually'), findsNothing);
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    expect(service.settingsCalls, 1);
  });

  testWidgets('turned-off location services ask the user to enable them', (
    tester,
  ) async {
    final service = _FakeLocationService(
      failure: const LocationFailure(
        LocationFailureReason.serviceDisabled,
        'off',
      ),
    );
    await _showPrompt(tester, service);

    await tester.tap(find.text('Allow Location'));
    await tester.pumpAndSettle();

    expect(find.text('Turn on location services'), findsOneWidget);
    expect(find.text('Turn On Location'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('the detected location goes to the draft, not to a form field', (
    tester,
  ) async {
    final service = _FakeLocationService(result: _kathmandu);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SignupStudentFormPage(locationService: service),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Use your current location?'), findsOneWidget);

    await tester.tap(find.text('Allow Location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use This Location'));
    await tester.pumpAndSettle();

    // The Location field lives on Edit Profile now, so signup keeps the value
    // on the draft and acknowledges it with a snack bar rather than a field.
    expect(
      container.read(userProfileProvider).valueFor('location'),
      'Baneshwor, Kathmandu',
    );
    expect(find.textContaining('Location saved'), findsOneWidget);

    // Let the snack bar expire so no timer outlives the test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
