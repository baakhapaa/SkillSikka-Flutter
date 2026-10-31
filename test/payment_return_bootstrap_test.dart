import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/core/network/session.dart';
import 'package:skillsikka/core/payment_return_bootstrap.dart';
import 'package:skillsikka/features/payment/data/payment_api.dart';

import 'support/payment_test_scope.dart';

/// The app-level payment-return handler.
///
/// **What this covers that the checkout sheet cannot:** a link that arrives when
/// no sheet is open — the cold start after the OS killed the app while the
/// browser was in front, and a link that lands after the student dismissed the
/// sheet. Both used to leave a paid course at `pending_payment` with nothing to
/// notice it.
///
/// `AppLinks` is replaced by [FakeLinks] because the platform channel does not
/// exist under `flutter test`; everything else is the real provider graph.
class FakeLinks implements PaymentLinks {
  FakeLinks({this.initial});

  /// The link that "launched" the app.
  Uri? initial;

  final controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> initialLink() async => initial;

  @override
  Stream<Uri> get stream => controller.stream;
}

Uri paymentLink([int id = 44]) =>
    Uri.parse('skillsikka://payment?payment_id=$id&status=initiated');

void main() {
  late FakeLinks links;
  late FakePaymentApi api;
  late ProviderContainer container;

  setUp(() {
    links = FakeLinks();
    api = FakePaymentApi()..statusResults = [payment(status: 'successful')];
  });

  tearDown(() {
    container.dispose();
    links.controller.close();
  });

  /// Builds the container and starts the handler the way `app.dart` does.
  ///
  /// [signedIn] is what the session restore has done by the time the link
  /// arrives — false is the cold-start race this handler has to survive.
  ProviderContainer start({bool signedIn = true}) {
    container = ProviderContainer(
      overrides: [
        paymentLinksProvider.overrideWithValue(links),
        paymentApiProvider.overrideWithValue(api),
        if (signedIn)
          sessionProvider.overrideWith((ref) => const Session(access: 'token')),
      ],
    );
    // The app watches this once; reading it here is the same thing.
    container.read(paymentReturnListenerProvider);
    return container;
  }

  test('a link that launched the app settles the payment it names', () async {
    links.initial = paymentLink(44);
    start();
    await pumpEventQueue();

    expect(api.statusCalls, [44]);
  });

  test('a link that arrives while the app is running is settled too', () async {
    start();
    await pumpEventQueue();
    expect(api.statusCalls, isEmpty);

    links.controller.add(paymentLink(51));
    await pumpEventQueue();

    expect(api.statusCalls, [51]);
  });

  test('a link that is not a payment return never asks the server', () async {
    // A deep link is untrusted input from outside the app. An unrelated one must
    // not refresh a payment, and must not throw.
    links.initial = Uri.parse('https://app.skillsikka.com/paid?payment_id=44');
    start();
    await pumpEventQueue();

    links.controller.add(Uri.parse('skillsikka://course?payment_id=44'));
    await pumpEventQueue();

    expect(api.statusCalls, isEmpty);
  });

  test('a cold-start link is retried once the session is restored', () async {
    // The race that made the cold start useless: the link is delivered before
    // the saved token is back, so the first ask cannot be authenticated.
    links.initial = paymentLink(44);
    start(signedIn: false);
    await pumpEventQueue();

    expect(api.statusCalls, isEmpty, reason: 'asked without a token');

    container.read(sessionProvider.notifier).state = const Session(
      access: 'token',
    );
    await pumpEventQueue();

    expect(api.statusCalls, [44]);
  });

  test(
    'a failed refresh is not a failed payment, and does not throw',
    () async {
      api.statusFailure = const ApiException(
        kind: ApiErrorKind.network,
        message: 'offline',
      );
      links.initial = paymentLink(44);
      start();

      await expectLater(pumpEventQueue(), completes);
      expect(api.statusCalls, [44]);
    },
  );
}
