import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/course_detail_view.dart';
import '../../../core/widgets/course_image.dart';
import '../../courses/presentation/widgets/builder_tokens.dart';
import '../data/payment_api.dart';
import '../data/payment_return.dart';

/// Opens [url] outside the app.
///
/// A seam rather than a direct `launchUrl` call: the platform channel does not
/// exist under `flutter test`, so without this the whole checkout path would be
/// untestable — the same reason `CourseBuilderPage.pickCover` exists.
typedef UrlOpener = Future<bool> Function(Uri url);

final urlOpenerProvider = Provider<UrlOpener>(
  (ref) =>
      (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);

/// The `skillsikka://payment?payment_id=…&status=…` links the backend redirects
/// the browser to once the gateway returns.
///
/// `PAYMENT_APP_RETURN_URL` on the server holds that URL. The query's `status` is
/// **a hint, not the truth** — it is whatever the server saw at redirect time and
/// is very often still `initiated` — so a link is only ever a prompt to ask
/// `GET /payments/{id}/`.
final paymentLinkStreamProvider = Provider<Stream<Uri>>(
  (ref) => AppLinks().uriLinkStream,
);

/// The checkout sheet, as a boolean: `true` means the course is paid for.
Future<bool> showCheckoutSheet(
  BuildContext context, {
  required CourseDetailData course,
  required PaymentApi api,
  required UrlOpener openUrl,
  required Stream<Uri> links,
}) async {
  final paid = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        CheckoutSheet(course: course, api: api, openUrl: openUrl, links: links),
  );
  return paid == true;
}

enum _Phase { ready, starting, waiting, succeeded, failed }

/// Buy one course with eSewa.
///
/// **The app never decides that a payment succeeded.** It starts one, sends the
/// browser to the gateway, and then asks `GET /payments/{id}/` until the server
/// says `successful` — which is also the moment the server flips the enrolment to
/// `active`. Everything on screen here is a report of that row.
///
/// Three things wake the check up, because any one of them can be the first:
/// the deep link the gateway redirects to, the app coming back to the foreground
/// after the browser closes, and the poll running while the sheet is open. The
/// poll gives up after a minute and says so rather than calling it a failure:
/// eSewa answers `PENDING` for a while after a real payment, and a red error over
/// money that has already left the account is the worst possible copy.
class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({
    super.key,
    required this.course,
    required this.api,
    required this.openUrl,
    required this.links,
  });

  final CourseDetailData course;
  final PaymentApi api;
  final UrlOpener openUrl;
  final Stream<Uri> links;

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 2);
  static const _pollWindow = Duration(seconds: 60);
  static const _successPause = Duration(milliseconds: 1200);

  /// How long to leave the gateway alone before asking about the payment.
  ///
  /// Every check is a round-trip to eSewa from the server. Starting the poll the
  /// instant the browser opens spends thirty of them on a student who has not
  /// reached the login form yet — and before the backend stopped treating
  /// eSewa's `NOT_FOUND` as final, the first one also killed the payment. Six
  /// seconds is longer than a page load and shorter than a login.
  static const _firstCheck = Duration(seconds: 6);

  _Phase _phase = _Phase.ready;
  String? _error;
  CoursePayment? _payment;
  String? _pendingUrl;
  Timer? _poll;
  Timer? _autoClose;
  StreamSubscription<Uri>? _linkSub;
  Duration _waited = Duration.zero;

  bool get _slow => _phase == _Phase.waiting && _waited >= _pollWindow;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _linkSub = widget.links.listen(_onLink);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _autoClose?.cancel();
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The browser closed and the user came back. This is the common case when
    // the gateway's redirect never reaches the app (a cancelled payment, or a
    // browser that swallowed the custom scheme), so it must check too.
    if (state == AppLifecycleState.resumed && _phase == _Phase.waiting) {
      _check();
    }
  }

  void _onLink(Uri uri) {
    // Host and scheme only — the query is a hint, and a malformed one must not
    // stop the check from running. Parsed by the shared [PaymentReturn] so this
    // and the app-level handler agree on what counts as one of our links.
    if (PaymentReturn.tryParse(uri) == null) return;
    if (_phase == _Phase.waiting || _phase == _Phase.ready) _check();
  }

  Future<void> _pay() async {
    final id = widget.course.id;
    if (id == null) return;
    setState(() {
      _phase = _Phase.starting;
      _error = null;
      _waited = Duration.zero;
    });

    try {
      final payment = await widget.api.initiate(id);
      if (!mounted) return;
      _payment = payment;
      final url = payment.paymentUrl;
      if (url == null || url.trim().isEmpty) {
        _fail('The gateway did not return a checkout link. Please try again.');
        return;
      }
      _pendingUrl = url;
      await _openBrowser(Uri.parse(url));
    } on ApiException catch (error) {
      _fail(error.message ?? 'The payment could not be started.');
    }
  }

  /// Sends the browser to the gateway and starts waiting.
  ///
  /// Kept separate from [_pay] so a failed launch can be retried without creating
  /// a second `Payment` row: the first one is already `initiated` and still
  /// points at the same signed checkout.
  Future<void> _openBrowser(Uri url) async {
    var opened = false;
    try {
      opened = await widget.openUrl(url);
    } on Exception {
      opened = false;
    }
    if (!mounted) return;
    if (!opened) {
      _fail('Could not open your browser. Check that one is installed.');
      return;
    }
    setState(() => _phase = _Phase.waiting);
    _startPolling();
  }

  void _startPolling() {
    _poll?.cancel();
    _waited = Duration.zero;
    _poll = Timer.periodic(_pollInterval, (timer) {
      _waited += _pollInterval;
      if (_waited > _pollWindow) {
        timer.cancel();
        if (mounted) setState(() {});
        return;
      }
      if (_waited < _firstCheck) return;
      _check();
    });
  }

  Future<void> _check() async {
    final payment = _payment;
    if (payment == null) return;
    try {
      final fresh = await widget.api.status(payment.id);
      if (!mounted) return;
      _apply(fresh);
    } on ApiException {
      // A dropped connection during a poll is not a failed payment. The next
      // tick, the resume, or the user's own "Check now" will ask again.
    }
  }

  void _apply(CoursePayment payment) {
    if (payment.isSuccessful) {
      _poll?.cancel();
      setState(() {
        _payment = payment;
        _phase = _Phase.succeeded;
      });
      // Land the user in the course rather than on a receipt: the player is the
      // confirmation. The pause is only long enough to read the word.
      _autoClose?.cancel();
      _autoClose = Timer(_successPause, () {
        if (mounted) Navigator.of(context).pop(true);
      });
      return;
    }
    if (payment.isFailed) {
      _poll?.cancel();
      // The checkout page refuses a settled payment (`_finish` in
      // `payment_views.py` sends it straight back), so re-opening it would loop.
      // Clearing this makes `Try again` create a new payment row instead.
      _pendingUrl = null;
      setState(() {
        _payment = payment;
        _phase = _Phase.failed;
        _error = payment.status == 'cancelled'
            ? 'The payment was cancelled. Nothing has been charged.'
            : 'The gateway did not accept the payment. Nothing has been charged.';
      });
      return;
    }
    // Still initiated. Keep waiting, and keep the row for the next check.
    setState(() => _payment = payment);
  }

  void _fail(String message) {
    _poll?.cancel();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.failed;
      _error = message;
    });
  }

  void _retry() {
    // Re-opening the same signed checkout is cheaper than a new payment row, and
    // it is the right retry when the browser never opened.
    final url = _pendingUrl;
    if (url != null && _payment != null) {
      setState(() {
        _phase = _Phase.starting;
        _error = null;
      });
      _openBrowser(Uri.parse(url));
      return;
    }
    _pay();
  }

  void _checkNow() {
    setState(() {
      _phase = _Phase.waiting;
      _error = null;
      _waited = Duration.zero;
    });
    _startPolling();
    _check();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: builderBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_phase == _Phase.succeeded)
              _success()
            else ...[
              Text(
                'Complete your purchase',
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: builderInk,
                ),
              ),
              const SizedBox(height: 14),
              _courseRow(),
              const SizedBox(height: 16),
              _providerRow(),
              const SizedBox(height: 14),
              _body(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _courseRow() {
    final course = widget.course;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CourseImage(
            course.image,
            width: 56,
            height: 56,
            fallback: Container(
              width: 56,
              height: 56,
              color: builderPillFill,
              alignment: Alignment.center,
              child: const Icon(
                Icons.menu_book_outlined,
                size: 20,
                color: builderBrown,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: builderInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                course.instructorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.figtree(fontSize: 11, color: builderGray),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          course.price,
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: builderInk,
          ),
        ),
      ],
    );
  }

  Widget _providerRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: builderCream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: builderYellow.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFF60BB46),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.account_balance_wallet,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'eSewa',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: builderInk,
              ),
            ),
          ),
          const Icon(Icons.check_circle, size: 16, color: builderSuccess),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_phase) {
      case _Phase.succeeded:
        return const SizedBox.shrink();
      case _Phase.ready:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You will finish paying in your browser, then come back here.',
              style: GoogleFonts.figtree(
                fontSize: 12,
                height: 1.4,
                color: builderGray,
              ),
            ),
            const SizedBox(height: 14),
            _primary(
              label: widget.course.price.isEmpty
                  ? 'Pay now'
                  : 'Pay ${widget.course.price}',
              onTap: _pay,
            ),
          ],
        );
      case _Phase.starting:
        return Column(
          children: [
            const SizedBox(height: 6),
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Opening eSewa…',
                style: GoogleFonts.figtree(fontSize: 12, color: builderGray),
              ),
            ),
            const SizedBox(height: 6),
          ],
        );
      case _Phase.waiting:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _slow
                        ? 'eSewa has not confirmed yet.'
                        : 'Waiting for eSewa to confirm…',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: builderInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _slow
                  ? 'If money has left your account, the course unlocks as soon '
                        'as eSewa confirms — usually within a minute. Nothing is '
                        'charged twice by checking again.'
                  : 'This usually takes a few seconds. You can leave this sheet '
                        'open, or come back to it.',
              style: GoogleFonts.figtree(
                fontSize: 12,
                height: 1.45,
                color: builderGray,
              ),
            ),
            const SizedBox(height: 14),
            _secondary(label: 'Check now', onTap: _checkNow),
          ],
        );
      case _Phase.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, size: 16, color: builderDanger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error ?? 'The payment did not go through.',
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      height: 1.45,
                      color: builderInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _primary(label: 'Try again', onTap: _retry),
          ],
        );
    }
  }

  Widget _success() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Color(0xFFE7F6EC),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.check_rounded,
            size: 26,
            color: builderSuccess,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Payment successful',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: builderInk,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Opening ${widget.course.title}…',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.figtree(fontSize: 12, color: builderGray),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _primary({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: builderYellow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: builderBrown,
          ),
        ),
      ),
    );
  }

  Widget _secondary({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: builderFieldBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: builderInk,
          ),
        ),
      ),
    );
  }
}
