/// The `skillsikka://payment?payment_id=…&status=…` link the backend redirects
/// the browser to once the gateway returns.
///
/// `PAYMENT_APP_RETURN_URL` on the server holds that URL. **`status` is a hint,
/// not the truth** — it is whatever the server saw at redirect time, and is very
/// often still `initiated` — so a link is only ever a prompt to ask
/// `GET /payments/{id}/`. Only [paymentId] is trusted here.
///
/// Parsed in one place because two different listeners receive the same link:
/// the checkout sheet while it is open, and the app-level handler that covers a
/// cold start, when there is no sheet to receive anything.
class PaymentReturn {
  const PaymentReturn(this.paymentId);

  /// The `Payment` row to re-ask about.
  final int paymentId;

  /// The link, or **null** for anything that is not a well-formed payment
  /// return. A foreign scheme, another `skillsikka://` host, a missing id or a
  /// non-numeric one all come back null: a deep link is untrusted input from
  /// outside the app, and guessing at a half-parsed one is how an unrelated
  /// link ends up refreshing a payment.
  static PaymentReturn? tryParse(Uri? uri) {
    if (uri == null) return null;
    if (uri.scheme != 'skillsikka' || uri.host != 'payment') return null;
    final id = int.tryParse(uri.queryParameters['payment_id'] ?? '');
    if (id == null || id <= 0) return null;
    return PaymentReturn(id);
  }
}
