// lib/presentation/payments/firestore_pending_source.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../requests/request_models.dart';
import 'pending_models.dart';
import 'pending_source.dart';

class FirestorePendingSource implements PendingPaymentsSource {
  FirestorePendingSource({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    Set<String>? Function()? propertyScope,
  })  : _fs = firestore ?? FirebaseFirestore.instance,
        _functions = functions,
        _propertyScope = propertyScope;

  /// The ids of the properties this person can open; null means all (owner).
  final Set<String>? Function()? _propertyScope;

  bool _inScope(Object? propertyId) {
    final scope = _propertyScope?.call();
    return scope == null || (propertyId is String && scope.contains(propertyId));
  }

  final FirebaseFirestore _fs;
  final FirebaseFunctions? _functions;

  /// How many tenants' payments are read at once.
  static const _concurrency = 10;

  /// Reads each tenant's own payments: the rules allow that but not a query
  /// across every tenant's payments.
  @override
  Future<List<PendingRent>> rentPayments(String businessId, {String? propertyId}) async {
    Query<Map<String, dynamic>> query = _fs
        .collection('businesses')
        .doc(businessId)
        .collection('tenants')
        .where('status', isEqualTo: 'active');
    if (propertyId != null) query = query.where('propertyId', isEqualTo: propertyId);

    final tenants = [for (final t in (await query.get()).docs) if (_inScope(t.data()['propertyId'])) t];
    final out = <PendingRent>[];
    for (var i = 0; i < tenants.length; i += _concurrency) {
      final batch = tenants.skip(i).take(_concurrency);
      final results = await Future.wait(
        batch.map((t) => t.reference
            .collection('payments')
            .where('status', isEqualTo: 'pending_verification')
            .get()
            .then((snap) => (t, snap))),
      );
      for (final (tenant, snap) in results) {
        for (final doc in snap.docs) {
          final data = doc.data();
          out.add(PendingRent.fromMap(
            doc.id,
            tenant.id,
            {'tenantName': tenant.data()['name'], 'roomNumber': tenant.data()['roomId'], ...data},
          ));
        }
      }
    }
    return out;
  }

  /// Newest first is applied by the caller; filtering and ordering here would
  /// need a composite index.
  @override
  Stream<List<EnrollmentRequest>> deposits(String businessId, {String? propertyId}) {
    Query<Map<String, dynamic>> query = _fs
        .collection('enrollmentRequests')
        .where('businessId', isEqualTo: businessId)
        .where('status', isEqualTo: 'payment_submitted');
    if (propertyId != null) query = query.where('propertyId', isEqualTo: propertyId);
    return query.snapshots().map(
          (snap) => [
            for (final d in snap.docs)
              if (_inScope(d.data()['propertyId'])) EnrollmentRequest.fromMap(d.id, d.data()),
          ],
        );
  }

  @override
  Future<void> verifyRent({
    required String businessId,
    required String tenantId,
    required String paymentId,
    required bool confirm,
    String? reason,
  }) async {
    final callable = (_functions ?? FirebaseFunctions.instance).httpsCallable('verifyRentPayment');
    await callable.call<Object?>({
      'businessId': businessId,
      'tenantId': tenantId,
      'paymentId': paymentId,
      'action': confirm ? 'confirm' : 'reject',
      if (reason != null) 'rejectionReason': reason,
    });
  }
}
