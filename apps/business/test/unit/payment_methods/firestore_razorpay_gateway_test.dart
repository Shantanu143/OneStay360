import 'package:business/presentation/payment_methods/firestore_razorpay_gateway.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore fs;
  late FirestoreRazorpayGateway gateway;

  setUp(() {
    fs = FakeFirebaseFirestore();
    gateway = FirestoreRazorpayGateway(firestore: fs);
  });

  Future<Map<String, dynamic>?> doc(String name) async =>
      (await fs.doc('businesses/BUS1/settings/$name').get()).data();

  test('nothing saved means not set up', () async {
    final status = await gateway.status('BUS1');

    expect(status.configured, isFalse);
  });

  test('keeps the secret in the private doc and only a hint in the public one', () async {
    await gateway.saveCredentials('BUS1',
        keyId: 'rzp_live_AbCd1234', keySecret: 'topsecret', webhookSecret: 'hook');

    final private = await doc('razorpay_private');
    final public = await doc('razorpay');
    expect(private!['keySecret'], 'topsecret');
    expect(private['keyId'], 'rzp_live_AbCd1234');
    expect(public!['keyIdHint'], '••••1234');
    expect(public['paymentsEnabled'], isTrue);
    expect(public.containsKey('keySecret'), isFalse);
    expect(public.containsKey('keyId'), isFalse);
    expect(public['hasWebhookSecret'], isTrue);
  });

  test('new keys have not been verified yet, even if the old ones were', () async {
    await fs.doc('businesses/BUS1/settings/razorpay').set({
      'paymentsEnabled': true,
      'verified': true,
      'verifiedAt': DateTime(2026, 7, 28),
      'merchantId': 'acc_OLD',
      'merchantName': 'Old Merchant',
      'kycStatus': 'activated',
    });

    await gateway.saveCredentials('BUS1',
        keyId: 'rzp_test_NewKey9999', keySecret: 's', webhookSecret: '');

    final status = await gateway.status('BUS1');
    final public = await doc('razorpay');
    expect(status.verified, isFalse, reason: 'the old keys were verified, not these');
    expect(public!.containsKey('verifiedAt'), isFalse);
    expect(public.containsKey('merchantId'), isFalse);
    expect(public.containsKey('merchantName'), isFalse);
    expect(public['kycStatus'], 'activated', reason: 'unrelated settings are left alone');
    expect(status.enabled, isTrue);
  });
}
