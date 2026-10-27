// lib/presentation/requests/firestore_request_source.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'request_models.dart';
import 'request_source.dart';

/// Status changes go straight to the request document; the
/// `onEnrollmentStatusChanged` trigger does the rest (creating the tenant,
/// occupying the bed, notifying people).
class FirestoreRequestSource implements RequestSource {
  FirestoreRequestSource({FirebaseFirestore? firestore})
      : _fs = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _fs;

  DocumentReference<Map<String, dynamic>> _doc(String id) =>
      _fs.collection('enrollmentRequests').doc(id);

  @override
  Stream<EnrollmentRequest?> watch(String requestId) {
    return _doc(requestId).snapshots().map((snap) {
      final data = snap.data();
      return snap.exists && data != null ? EnrollmentRequest.fromMap(snap.id, data) : null;
    });
  }

  @override
  Future<void> reject(String requestId) => _doc(requestId).update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> confirmPayment(String requestId) => _doc(requestId).update({
        'status': 'confirmed',
        'confirmedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> rejectPayment(String requestId, String reason) => _doc(requestId).update({
        'status': 'bill_sent',
        'paymentRejectionReason': reason,
        'paymentRejectedAt': FieldValue.serverTimestamp(),
        'transactionId': FieldValue.delete(),
        'paymentSubmittedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
}

class FirestoreRequestListSource implements RequestListSource {
  FirestoreRequestListSource({FirebaseFirestore? firestore})
      : _fs = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _fs;

  /// Plenty for a busy property; the list is not paged.
  static const _limit = 100;

  @override
  Stream<List<EnrollmentRequest>> watchAll(String businessId) {
    return _fs
        .collection('enrollmentRequests')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .limit(_limit)
        .snapshots()
        .map((snap) => [for (final d in snap.docs) EnrollmentRequest.fromMap(d.id, d.data())]);
  }
}
