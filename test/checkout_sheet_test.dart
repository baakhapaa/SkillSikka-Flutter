import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/core/widgets/course_detail_view.dart';
import 'package:skillsikka/features/courses/data/course_adapter.dart';
import 'package:skillsikka/features/payment/presentation/checkout_sheet.dart';

import 'support/payment_test_scope.dart';

/// The checkout sheet, driven the way the student drives it.
///
/// The rule every test here is really about: **the app never decides that a
/// payment succeeded.** It reports what `GET /payments/{id}/` says, and only
/// `successful` closes the sheet with `true`.
void main() {
  CourseDetailData course({String price = '1299.00'}) => CourseMapper.detail(
    course: {
      'id': 99,
      'title': 'Drawing from Observation',
      'description': 'Learn by doing.',
      'course_type': 'skill',
      'skill_category': 13,
      'skill_category_name': 'Drawing',
      'is_paid': true,
      'price': price,
      'thumbnail_url': '',
      'is_published': true,
      'average_rating': null,
      'review_count': 0,
      'students_enrolled': 0,
      'lessons_count': 1,
      'total_duration_seconds': 300,
      'instructor': 4,
      'instructor_name': 'Test Instructor',
      'learning_outcomes': <String>[],
      'requirements': <String>[],
      'updated_at': '2026-10-27T06:04:13.639481Z',
    },
    lessons: const [],
  );

  /// A page with one button, so the sheet has a route to be pushed onto and a
  /// result to report. `showModalBottomSheet` popping the root route would leave
  /// nothing to assert against.
  Future<void> openSheet(
    WidgetTester tester, {
    required FakePaymentApi api,
    required List<Uri> opened,
    required ValueNotifier<bool> canOpen,
    required StreamController<Uri> links,
    required List<bool> results,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  final paid = await showCheckoutSheet(
                    context,
                    course: course(),
                    api: api,
                    openUrl: (url) async {
                      if (!canOpen.value) return false;
                      opened.add(url);
                      return true;
                    },
                    links: links.stream,
                  );
                  results.add(paid);
                },
                child: const Text('buy'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buy'));
    await tester.pumpAndSettle();
  }

  late FakePaymentApi api;
  late List<Uri> opened;
  late ValueNotifier<bool> canOpen;
  late StreamController<Uri> links;
  late List<bool> results;

  setUp(() {
    api = FakePaymentApi();
    opened = [];
    canOpen = ValueNotifier(true);
    links = StreamController<Uri>.broadcast();
    results = [];
  });

  tearDown(() => links.close());

  testWidgets('shows the price and the provider before anything starts', (
    tester,
  ) async {
    await openSheet(
      tester,
      api: api,
      opened: opened,
      canOpen: canOpen,
      links: links,
      results: results,
    );

    expect(find.text('Complete your purchase'), findsOneWidget);
    expect(find.text('Drawing from Observation'), findsOneWidget);
    expect(find.text('Rs. 1,299'), findsOneWidget);
    expect(find.text('eSewa'), findsOneWidget);
    expect(find.text('Pay Rs. 1,299'), findsOneWidget);
    // Nothing is created until the student taps Pay — opening the sheet is not
    // a commitment, and a `Payment` row per curious tap would be noise.
    expect(api.initiateCalls, isEmpty);
  });

  testWidgets('paying opens the gateway in the browser', (tester) async {
    api.initiateResult = payment(paymentUrl: 'http://test/checkout/ref-7');
    api.statusResults = [payment(status: 'initiated')];

    await openSheet(
      tester,
      api: api,
      opened: opened,
      canOpen: canOpen,
      links: links,
      results: results,
    );

    await tester.tap(find.text('Pay Rs. 1,299'));
    await tester.pump();
    await tester.pump();

    expect(api.initiateCalls, [99]);
    expect(opened.single.toString(), 'http://test/checkout/ref-7');
    expect(find.text('Waiting for eSewa to confirm…'), findsOneWidget);
    // Still open, still undecided: the browser has the money, not the app.
    expect(results, isEmpty);
  });

  testWidgets('a confirmed payment closes the sheet and answers true', (
    tester,
  ) async {
    api.statusResults = [payment(status: 'successful')];

    await openSheet(
      tester,
      api: api,
      opened: opened,
      canOpen: canOpen,
      links: links,
      results: results,
    );
    await tester.tap(find.text('Pay Rs. 1,299'));
    await tester.pump();
    await tester.pump();

    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    expect(find.text('Payment successful'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(results, [true]);
    expect(find.text('Complete your purchase'), findsNothing);
  });

  testWidgets('still pending is not a failure, and can be checked again', (
    tester,
  ) async {
    // eSewa answers PENDING for a while after a real payment. Calling that a
    // failure would put a red error over money that has already left the
    // account.
    api.statusResults = [payment(status: 'initiated')];

    await openSheet(
      tester,
      api: api,
      opened: opened,
      canOpen: canOpen,
      links: links,
      results: results,
    );
    await tester.tap(find.text('Pay Rs. 1,299'));
    await tester.pump();
    await tester.pump();

    // Past the poll window: the copy changes, nothing turns red, and the sheet
    // stays open.
    for (var i = 0; i < 31; i++) {
      await tester.pump(const Duration(seconds: 2));
    }
    await tester.pump();

    expect(find.text('eSewa has not confirmed yet.'), findsOneWidget);
    expect(find.text('Check now'), findsOneWidget);
    expect(find.textContaining('did not accept'), findsNothing);
    expect(results, isEmpty);

    // The gateway confirms later; asking again is enough.
    api.statusResults = [payment(status: 'successful')];
    await tester.tap(find.text('Check now'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(results, [true]);
  });

  testWidgets('a cancelled payment stays open with a retry', (tester) async {
    api.statusResults = [payment(status: 'cancelled')];

    await openSheet(
      tester,
      api: api,
      opened: opened,
      canOpen: canOpen,
      links: links,
      results: results,
    );
    await tester.tap(find.text('Pay Rs. 1,299'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    expect(
      find.text('The payment was cancelled. Nothing has been charged.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(results, isEmpty);

    // Retrying a settled payment must create a new one. Re-opening the old
    // checkout URL would bounce straight back: the server's checkout view sends
    // any payment that is not `initiated` to the result page.
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();

    expect(api.initiateCalls, hasLength(2));
    expect(opened, hasLength(2));
  });

  testWidgets('a gateway that is not configured says so', (tester) async {
    api.initiateFailure = const ApiException(
      kind: ApiErrorKind.unknown,
      statusCode: 503,
      message: 'Khalti is not configured on the server.',
    );

    await openSheet(
      tester,
      api: api,
      opened: opened,
      canOpen: canOpen,
      links: links,
      results: results,
    );
    await tester.tap(find.text('Pay Rs. 1,299'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Khalti is not configured on the server.'),
      findsOneWidget,
    );
    expect(opened, isEmpty);
    expect(results, isEmpty);
  });

  testWidgets('a deep link is a prompt to ask, never the answer', (
    tester,
  ) async {
    api.statusResults = [payment(status: 'initiated')];

    await openSheet(
      tester,
      api: api,
      opened: opened,
      canOpen: canOpen,
      links: links,
      results: results,
    );
    await tester.tap(find.text('Pay Rs. 1,299'));
    await tester.pump();
    await tester.pump();

    final before = api.statusCalls.length;

    // The backend redirects with `status=successful`, but that value is whatever
    // it saw at redirect time. The app must still ask.
    api.statusResults = [payment(status: 'successful')];
    links.add(Uri.parse('skillsikka://payment?payment_id=7&status=successful'));
    await tester.pump();
    await tester.pump();

    expect(api.statusCalls.length, greaterThan(before));
    expect(find.text('Payment successful'), findsOneWidget);
  });

  testWidgets(
    'a browser that never opened can be retried without paying twice',
    (tester) async {
      canOpen.value = false;

      await openSheet(
        tester,
        api: api,
        opened: opened,
        canOpen: canOpen,
        links: links,
        results: results,
      );
      await tester.tap(find.text('Pay Rs. 1,299'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Could not open your browser. Check that one is installed.'),
        findsOneWidget,
      );
      // The payment row exists and still points at the same signed checkout.
      expect(api.initiateCalls, [99]);

      canOpen.value = true;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();

      // No second `Payment` — the retry re-opens the one already created.
      expect(api.initiateCalls, [99]);
      expect(opened, hasLength(1));
      expect(find.text('Waiting for eSewa to confirm…'), findsOneWidget);
    },
  );
}
