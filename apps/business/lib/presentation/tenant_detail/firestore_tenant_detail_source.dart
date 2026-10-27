// lib/presentation/tenant_detail/firestore_tenant_detail_source.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'tenant_detail_models.dart';
import 'tenant_detail_source.dart';

class FirestoreTenantDetailSource implements TenantDetailSource {
  FirestoreTenantDetailSource({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    String? Function()? currentUid,
  })  : _fs = firestore ?? FirebaseFirestore.instance,
        _functions = functions,
        _uid = currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final FirebaseFirestore _fs;
  final FirebaseFunctions? _functions;
  final String? Function() _uid;

  /// Enough for years of monthly rent; keeps the live query small.
  static const _historyLimit = 60;

  DocumentReference<Map<String, dynamic>> _tenant(String businessId, String tenantId) =>
      _fs.collection('businesses').doc(businessId).collection('tenants').doc(tenantId);

  @override
  Stream<List<TenantPayment>> payments(String businessId, String tenantId) {
    return _tenant(businessId, tenantId)
        .collection('payments')
        .orderBy('date', descending: true)
        .limit(_historyLimit)
        .snapshots()
        .map((snap) => [for (final d in snap.docs) TenantPayment.fromMap(d.id, d.data())]);
  }

  @override
  Future<void> updateContact(
    String businessId,
    String tenantId, {
    required String name,
    required String phone,
    required String email,
  }) {
    final uid = _uid();
    if (uid == null) throw StateError('Not signed in');
    // Firestore rules require `updatedBy` to be the caller.
    return _tenant(businessId, tenantId).update({
      'name': name,
      'phone': phone,
      'email': email,
      'updatedBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> vacate({
    required String businessId,
    required String tenantId,
    required String propertyId,
    required String roomId,
    required String bedId,
  }) async {
    final callable = (_functions ?? FirebaseFunctions.instance).httpsCallable('vacateTenant');
    final result = await callable.call<Map<Object?, Object?>>({
      'tenantId': tenantId,
      'businessId': businessId,
      'propertyId': propertyId,
      'roomId': roomId,
      'bedId': bedId,
    });
    if (result.data['success'] != true) {
      throw StateError('${result.data['message'] ?? 'vacateTenant failed'}');
    }
  }
}
