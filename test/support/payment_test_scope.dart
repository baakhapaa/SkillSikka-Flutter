import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skillsikka/core/network/api_client.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/features/payment/data/payment_api.dart';
import 'package:skillsikka/features/payment/presentation/checkout_sheet.dart';

/// A stand-in for the two payment endpoints, plus the two things the sheet
/// reaches the outside world with.
///
/// **The browser and the deep link have to be faked, not mocked.** `launchUrl`
/// and `AppLinks` both talk to platform channels that do not exist under
/// `flutter test`; leaving them real would make every checkout test throw a
/// `MissingPluginException` instead of asserting anything.
class FakePaymentApi extends PaymentApi {
  FakePaymentApi() : super(ApiClient(Dio()));

  /// What [initiate] answers. Defaults to an eSewa checkout for course 99.
  CoursePayment? initiateResult;

  /// Thrown from [initiate] instead of answering — a 503 from an unconfigured
  /// gateway, for instance.
  ApiException? initiateFailure;

  /// Every course id passed to [initiate], in order.
  final List<int> initiateCalls = [];

  /// What [status] answers, consumed in order; the last entry repeats so a poll
  /// can ask more times than the test listed.
  List<CoursePayment> statusResults = const [];

  /// Thrown from [status] instead of answering.
  ApiException? statusFailure;

  /// Every payment id passed to [status], in order.
  final List<int> statusCalls = [];

  @override
  Future<CoursePayment> initiate(
    int courseId, {
    String provider = 'esewa',
  }) async {
    initiateCalls.add(courseId);
    final error = initiateFailure;
    if (error != null) throw error;
    return initiateResult ?? payment();
  }

  @override
  Future<CoursePayment> status(int paymentId) async {
    statusCalls.add(paymentId);
    final error = statusFailure;
    if (error != null) throw error;
    if (statusResults.isEmpty) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'no status scripted for this test',
      );
    }
    final index = statusCalls.length - 1;
    return statusResults[index < statusResults.length
        ? index
        : statusResults.length - 1];
  }
}

/// One payment row, defaulting to the answer `initiate` gives.
CoursePayment payment({
  int id = 7,
  int courseId = 99,
  String status = 'initiated',
  String amount = '1299.00',
  String? paymentUrl = 'https://rc-epay.esewa.com.np/checkout/abc',
}) {
  return CoursePayment(
    id: id,
    courseId: courseId,
    courseTitle: 'Drawing from Observation',
    amount: amount,
    provider: 'esewa',
    reference: 'ref-$id',
    status: status,
    paymentUrl: paymentUrl,
  );
}

/// The three overrides the checkout sheet needs, and a recorder for the links
/// the test sends it.
///
/// Returns the controller alongside so a test can push a deep link the way the
/// browser would.
({List<Override> overrides, StreamController<Uri> links}) paymentOverrides({
  FakePaymentApi? api,
  List<Uri>? opened,
  bool opens = true,
}) {
  final controller = StreamController<Uri>.broadcast();
  return (
    overrides: [
      paymentApiProvider.overrideWithValue(api ?? FakePaymentApi()),
      urlOpenerProvider.overrideWithValue((url) async {
        opened?.add(url);
        return opens;
      }),
      paymentLinkStreamProvider.overrideWithValue(controller.stream),
    ],
    links: controller,
  );
}
