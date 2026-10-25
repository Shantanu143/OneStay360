// data/services/id_generation_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class IdGenerationService {
  final FirebaseFirestore _firestore;

  IdGenerationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Generate tenant ID: TEN0000001, TEN0000002, etc.
  Future<String> generateTenantId() async {
    return _generateSequentialId('TEN', 'tenant_counter');
  }

  // Generate business ID: BUS0000001, BUS0000002, etc.
  Future<String> generateBusinessId() async {
    return _generateSequentialId('BUS', 'business_counter');
  }

  // Generate property ID: BUS0000001PNQ001, BUS0000001PNQ002, etc.
  Future<String> generatePropertyId(String businessId, String cityCode) async {
    final docRef = _firestore
        .collection('counters')
        .doc('property_${businessId}_$cityCode');

    final nextNumber = await _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(docRef);
      final current = (snapshot.exists && snapshot.data() != null)
          ? (snapshot.data()!['count'] as num?)?.toInt() ?? 0
          : 0;
      final next = current + 1;
      transaction.set(
        docRef,
        {'count': next, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      return next;
    });

    return '$businessId$cityCode${nextNumber.toString().padLeft(3, '0')}';
  }

  Future<String> _generateSequentialId(String prefix, String counterName) async {
    final docRef = _firestore.collection('counters').doc(counterName);

    final nextNumber = await _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(docRef);
      final current = (snapshot.exists && snapshot.data() != null)
          ? (snapshot.data()!['count'] as num?)?.toInt() ?? 0
          : 0;
      final next = current + 1;
      transaction.set(
        docRef,
        {'count': next, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      return next;
    });

    return '$prefix${nextNumber.toString().padLeft(7, '0')}';
  }

  // DEPRECATED: Removed eager initialization to prevent Firestore permission deadlock.
  // Counters are now auto-created on first access during authorized operations.
  @deprecated
  Future<void> initializeCounters() async {
    print('⚠️ initializeCounters() is deprecated and does nothing. '
        'Counters auto-initialize on first write.');
  }
}
