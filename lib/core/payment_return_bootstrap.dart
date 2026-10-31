import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/learning/data/learning_api.dart';
import '../features/payment/data/payment_api.dart';
import '../features/payment/data/payment_return.dart';
import 'network/api_error.dart';
import 'network/session.dart';

/// Where a payment return can arrive from.
///
/// An interface rather than a direct `AppLinks` call so the handler can be
/// tested: `AppLinks` talks to a platform channel that does not exist under
/// `flutter test`, and a test that cannot deliver a link cannot prove anything
/// about what happens when one arrives.
abstract class PaymentLinks {
  /// The link that launched the app, or null on a normal launch.
  ///
  /// **The stream never replays it.** `uriLinkStream` only reports links that
  /// arrive while the app is running, so without this a cold start from the
  /// payment redirect is silently dropped — which is exactly the case that
  /// matters, because the browser is what the OS had in front when the app was
  /// killed.
  Future<Uri?> initialLink();

  /// Links that arrive while the app is running.
  Stream<Uri> get stream;
}

class PlatformPaymentLinks implements PaymentLinks {
  PlatformPaymentLinks([AppLinks? links]) : _links = links ?? AppLinks();

  final AppLinks _links;

  @override
  Future<Uri?> initialLink() => _links.getInitialLink();

  @override
  Stream<Uri> get stream => _links.uriLinkStream;
}

final paymentLinksProvider = Provider<PaymentLinks>(
  (ref) => PlatformPaymentLinks(),
);

/// Turns a payment link into a settled payment row.
///
/// **It never decides that a payment succeeded.** It asks
/// `GET /payments/{id}/`, which is the endpoint that re-checks with the gateway
/// and flips the enrolment to `active`; the answer is whatever the server says.
/// Returns true when a payment was asked about, false when the link was not one
/// of ours or the request failed — the return value is for tests, the app
/// ignores it.
class PaymentReturnBootstrap {
  PaymentReturnBootstrap(this._ref);

  final Ref _ref;

  Future<bool> adopt(Uri? uri) async {
    final link = PaymentReturn.tryParse(uri);
    if (link == null) return false;

    // **A cold start can beat the session restore.** The token is what makes the
    // request authenticated, and restoring it is async, so asking now would 401
    // and lose the link. `paymentReturnListenerProvider` retries once a session
    // appears; this early return is the honest answer for the moment.
    if (_ref.read(sessionProvider) == null) return false;

    try {
      await _ref.read(paymentApiProvider).status(link.paymentId);
    } on ApiException {
      // A dropped connection is not a failed payment. The My Learning card for
      // this enrolment keeps its "Check payment" action, so nothing is lost.
      return false;
    }

    // The enrolment the payment settled is what My Learning renders, and it was
    // fetched before this ran.
    _ref.invalidate(myLearningProvider);
    return true;
  }
}

final paymentReturnBootstrapProvider = Provider<PaymentReturnBootstrap>(
  (ref) => PaymentReturnBootstrap(ref),
);

/// The app-level payment-return handler. Watched once, from `SkillSikkaApp`.
///
/// **Why the app and not the checkout sheet.** The sheet already listens, and
/// that covers the normal path. This covers the two it cannot: a link that
/// launched the app (no sheet exists yet), and a link that arrives after the
/// sheet was dismissed. Both would otherwise leave a paid course sitting at
/// `pending_payment` with nothing to notice it.
final paymentReturnListenerProvider = Provider<void>((ref) {
  final links = ref.watch(paymentLinksProvider);
  final bootstrap = ref.watch(paymentReturnBootstrapProvider);

  // The last payment link seen, so a cold-start link can be retried once the
  // session it needs has been restored.
  Uri? pending;

  void adopt(Uri? uri) {
    if (uri == null) return;
    pending = uri;
    bootstrap.adopt(uri);
  }

  links.initialLink().then(adopt, onError: (Object _) {});
  final subscription = links.stream.listen(adopt, onError: (Object _) {});
  ref.onDispose(subscription.cancel);

  ref.listen(sessionProvider, (previous, next) {
    if (previous == null && next != null && pending != null) {
      bootstrap.adopt(pending);
    }
  });
});
