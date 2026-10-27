// lib/presentation/payment_methods/firestore_razorpay_gateway.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'method_form_viewmodel.dart';

/// Razorpay credentials are kept per business under `settings/`: the secret
/// in `razorpay_private`, a non-secret summary in `razorpay`.
class FirestoreRazorpayGateway implements RazorpayGateway {
  FirestoreRazorpayGateway({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _fs = firestore ?? FirebaseFirestore.instance,
        _functions = functions;

  final FirebaseFirestore _fs;
  final FirebaseFunctions? _functions;

  @override
  Future<void> saveCredentials(
    String businessId, {
    required String keyId,
    required String keySecret,
    required String webhookSecret,
  }) async {
    final settings = _fs.collection('businesses').doc(businessId).collection('settings');
    await settings.doc('razorpay_private').set({
      'keyId': keyId,
      'keySecret': keySecret,
      'webhookSecret': webhookSecret,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await settings.doc('razorpay').set({
      'paymentsEnabled': true,
      'keyIdHint': keyId.length >= 4 ? '••••${keyId.substring(keyId.length - 4)}' : 'configured',
      'hasSecret': keySecret.isNotEmpty,
      'hasWebhookSecret': webhookSecret.isNotEmpty,
      // Verification belonged to the previous keys; the owner verifies again.
      'verified': false,
      'verifiedAt': FieldValue.delete(),
      'merchantId': FieldValue.delete(),
      'merchantName': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<RazorpayStatus> status(String businessId) async {
    final doc = await _fs.doc('businesses/$businessId/settings/razorpay').get();
    final d = doc.data();
    if (!doc.exists || d == null) return const RazorpayStatus.notSet();
    return RazorpayStatus(
      configured: true,
      enabled: d['paymentsEnabled'] == true,
      verified: d['verified'] == true,
      kycStatus: (d['kycStatus'] ?? '').toString(),
    );
  }

  @override
  Future<void> verify(String businessId) async {
    await (_functions ?? FirebaseFunctions.instance)
        .httpsCallable('verifyRazorpaySetup')
        .call<Object?>({'businessId': businessId});
  }
}
