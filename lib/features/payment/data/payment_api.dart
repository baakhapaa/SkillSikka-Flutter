import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';

/// One row of the server's `Payment`, as far as the client needs it.
///
/// **The status is the whole point.** `initiated` means the gateway has been
/// asked and has not answered; `successful` means it confirmed to the server and
/// the enrolment is now `active`. Nothing here is decided by the client, and
/// [paymentUrl] is only ever present on the answer to `initiate` — a status read
/// does not echo it.
class CoursePayment {
  const CoursePayment({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.amount,
    required this.provider,
    required this.reference,
    required this.status,
    this.paymentUrl,
  });

  final int id;
  final int courseId;
  final String courseTitle;

  /// The amount the server snapshotted, e.g. `1299.00`. Not the display price —
  /// that one is the course's, and it can change between opening the sheet and
  /// paying. What is charged is this.
  final String amount;

  /// `esewa` or `khalti`.
  final String provider;

  /// eSewa's `transaction_uuid` / Khalti's `purchase_order_id`.
  final String reference;

  /// `initiated | successful | failed | cancelled`.
  final String status;

  /// Where to send the browser. Only on the `initiate` answer.
  final String? paymentUrl;

  bool get isSuccessful => status == 'successful';

  /// Still with the gateway. **Not a failure** — eSewa answers `PENDING` for a
  /// while after a successful payment, and the server keeps the row `initiated`
  /// until its own check comes back `COMPLETE`.
  bool get isPending => status == 'initiated';

  bool get isFailed => status == 'failed' || status == 'cancelled';

  static CoursePayment? tryParse(Object? body, {String? paymentUrl}) {
    if (body is! Map) return null;
    final id = body['id'];
    final course = body['course'];
    if (id is! int || course is! int) return null;
    final status = body['status'];
    return CoursePayment(
      id: id,
      courseId: course,
      courseTitle: body['course_title'] is String
          ? body['course_title'] as String
          : '',
      amount: body['amount'] == null ? '' : '${body['amount']}',
      provider: body['provider'] is String ? body['provider'] as String : '',
      reference: body['transaction_reference'] is String
          ? body['transaction_reference'] as String
          : '',
      status: status is String && status.isNotEmpty ? status : 'initiated',
      // The initiate answer carries it as a sibling field of the serialized
      // payment, so it has to be handed in rather than read off the row.
      paymentUrl:
          paymentUrl ??
          (body['payment_url'] is String
              ? body['payment_url'] as String
              : null),
    );
  }
}

/// `POST /courses/{id}/initiate-payment/` and `GET /payments/{id}/`.
///
/// The gateway itself is never called from here: the server creates the payment,
/// signs the form and hands back a URL, and it is the server that asks eSewa for
/// the outcome. This class only ever reports what the server says.
class PaymentApi {
  const PaymentApi(this._client);

  final ApiClient _client;

  /// Creates the payment and answers where to send the browser.
  ///
  /// **Requires an enrolment in `pending_payment`.** `enroll/` has to have run
  /// first — the server answers 400 `You must enroll in this course before
  /// initiating payment.` otherwise, and 400 for a free course, an unpriced one,
  /// or one already active. Those are all programming errors rather than states
  /// a user can reach, so they surface as the server's own message.
  ///
  /// `503` means the provider is not configured on the server (Khalti today);
  /// `502` means the gateway refused the request. Both are worth showing, because
  /// both are actionable by somebody.
  Future<CoursePayment> initiate(
    int courseId, {
    String provider = 'esewa',
  }) async {
    final body = await _client.post<Object?>(
      '/courses/$courseId/initiate-payment/',
      data: {'provider': provider},
    );
    final payment = CoursePayment.tryParse(body);
    if (payment == null) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'The payment came back in an unexpected shape.',
      );
    }
    return payment;
  }

  /// `GET /payments/{id}/` — the current status.
  ///
  /// The server re-checks with the gateway when the row is still `initiated`, so
  /// calling this is what turns a pending payment into a decided one. It is safe
  /// to call repeatedly: the refresh is idempotent and takes a row lock.
  Future<CoursePayment> status(int paymentId) async {
    final body = await _client.get<Object?>('/payments/$paymentId/');
    final payment = CoursePayment.tryParse(body);
    if (payment == null) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'The payment status came back in an unexpected shape.',
      );
    }
    return payment;
  }
}

final paymentApiProvider = Provider<PaymentApi>(
  (ref) => PaymentApi(ref.watch(apiClientProvider)),
);
