import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/payment/data/payment_return.dart';

/// The one thing a payment link may be trusted to say: which payment it is
/// about. `status` in the query is whatever the server saw at redirect time and
/// is usually stale, so it is not read at all.
void main() {
  test('a payment return yields the id it names', () {
    final link = PaymentReturn.tryParse(
      Uri.parse('skillsikka://payment?payment_id=44&status=initiated'),
    );

    expect(link, isNotNull);
    expect(link!.paymentId, 44);
  });

  test('the query is not needed — only the id is', () {
    // The backend sends `status`, but a link without it must still work: the id
    // is the only thing the check needs.
    expect(
      PaymentReturn.tryParse(
        Uri.parse('skillsikka://payment?payment_id=7'),
      )?.paymentId,
      7,
    );
  });

  test('a foreign link is refused', () {
    for (final raw in [
      'https://app.skillsikka.com/paid?payment_id=7',
      'skillsikka://course?payment_id=7',
      'skillsikka://payment/7',
      'otherapp://payment?payment_id=7',
    ]) {
      expect(
        PaymentReturn.tryParse(Uri.parse(raw)),
        isNull,
        reason: 'accepted a link that is not ours: $raw',
      );
    }
  });

  test('a missing or unusable id is refused rather than guessed', () {
    for (final raw in [
      'skillsikka://payment',
      'skillsikka://payment?payment_id=',
      'skillsikka://payment?payment_id=abc',
      'skillsikka://payment?payment_id=0',
      'skillsikka://payment?payment_id=-3',
      'skillsikka://payment?id=7',
    ]) {
      expect(
        PaymentReturn.tryParse(Uri.parse(raw)),
        isNull,
        reason: 'accepted a link with no usable id: $raw',
      );
    }
  });

  test('no link at all is null, not a crash', () {
    expect(PaymentReturn.tryParse(null), isNull);
  });
}
