import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/network/api_client.dart';
import 'package:skillsikka/core/network/api_error.dart';
import 'package:skillsikka/features/payment/data/payment_api.dart';

/// The two payment endpoints, against canned bodies.
///
/// The sheet's tests fake [PaymentApi] itself, so this is the only place the
/// wire shape is checked — and the shape is the thing that breaks: `payment_url`
/// is a sibling of the serialized payment, not a field on it, so a parser that
/// looked for it inside the row would silently return null and the sheet would
/// report "the gateway did not return a checkout link" on a perfectly good
/// payment.
void main() {
  Map<String, dynamic> row({
    int id = 7,
    String status = 'initiated',
    Object? amount = '1299.00',
  }) {
    return {
      'id': id,
      'course': 99,
      'course_title': 'Drawing from Observation',
      'enrollment': 3,
      'amount': amount,
      'provider': 'esewa',
      'transaction_reference': 'ref-$id',
      'status': status,
      'gateway_transaction_id': '',
      'created_at': '2026-10-29T06:00:00Z',
      'verified_at': null,
    };
  }

  PaymentApi api(_StubAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1/'))
      ..httpClientAdapter = adapter;
    return PaymentApi(ApiClient(dio));
  }

  test(
    'initiate posts the provider and reads payment_url from the answer',
    () async {
      final adapter = _StubAdapter([
        (
          jsonEncode({...row(), 'payment_url': 'http://test/checkout/ref-7'}),
          201,
        ),
      ]);

      final payment = await api(adapter).initiate(99);

      expect(payment.id, 7);
      expect(payment.courseId, 99);
      expect(payment.status, 'initiated');
      expect(payment.paymentUrl, 'http://test/checkout/ref-7');
      expect(
        adapter.requests.single.path,
        '/api/v1/courses/99/initiate-payment/',
      );
      expect(jsonDecode(adapter.requests.single.body!), {'provider': 'esewa'});
    },
  );

  test('a status read has no payment_url and keeps the row as it is', () async {
    final adapter = _StubAdapter([
      (jsonEncode(row(status: 'successful', amount: 1299)), 200),
    ]);

    final payment = await api(adapter).status(7);

    expect(payment.status, 'successful');
    expect(payment.isSuccessful, isTrue);
    // The status answer does not echo the URL — the sheet must keep the one it
    // was given by `initiate`, not overwrite it with null.
    expect(payment.paymentUrl, isNull);
    expect(adapter.requests.single.path, '/api/v1/payments/7/');
  });

  test(
    'a failed gateway configuration surfaces as the server phrased it',
    () async {
      final adapter = _StubAdapter([
        (
          jsonEncode({'detail': 'Khalti is not configured on the server.'}),
          503,
        ),
      ]);

      await expectLater(
        api(adapter).initiate(99, provider: 'khalti'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 503)
              .having(
                (e) => e.message,
                'message',
                'Khalti is not configured on the server.',
              ),
        ),
      );
    },
  );

  group('CoursePayment.tryParse', () {
    test('an unknown status is treated as pending, not as success', () {
      final payment = CoursePayment.tryParse(row(status: 'something_new'));

      expect(payment!.isSuccessful, isFalse);
      expect(payment.isFailed, isFalse);
      expect(payment.isPending, isFalse);
    });

    test('a missing status is pending', () {
      final body = row()..remove('status');
      expect(CoursePayment.tryParse(body)!.status, 'initiated');
    });

    test('a body with no id is not a payment', () {
      expect(CoursePayment.tryParse({'status': 'initiated'}), isNull);
      expect(CoursePayment.tryParse('nope'), isNull);
    });

    test('cancelled and failed both count as failed', () {
      expect(
        CoursePayment.tryParse(row(status: 'cancelled'))!.isFailed,
        isTrue,
      );
      expect(CoursePayment.tryParse(row(status: 'failed'))!.isFailed, isTrue);
    });
  });
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.answers);

  final List<(String, int)> answers;
  final List<({String path, String? body})> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((
      path: options.uri.path,
      body: options.data is Map ? jsonEncode(options.data) : null,
    ));
    final (body, status) =
        answers[(requests.length - 1).clamp(0, answers.length - 1)];
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
