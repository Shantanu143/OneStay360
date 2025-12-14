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
    final counterDoc = await _firestore
        .collection('counters')
        .doc('property_${businessId}_$cityCode')
        .get();

    int nextNumber = 1;
    if (counterDoc.exists) {
      nextNumber = (counterDoc.data()?['count'] ?? 0) + 1;
    }

    // Update counter
    await _firestore
        .collection('counters')
        .doc('property_${businessId}_$cityCode')
        .set({'count': nextNumber});

    return '$businessId$cityCode${nextNumber.toString().padLeft(3, '0')}';
  }

  Future<String> _generateSequentialId(String prefix, String counterName) async {
    final counterDoc = await _firestore
        .collection('counters')
        .doc(counterName)
        .get();

    int nextNumber = 1;
    if (counterDoc.exists) {
      nextNumber = (counterDoc.data()?['count'] ?? 0) + 1;
    } else {
      // Auto-initialize counter if it doesn't exist
      await _firestore
          .collection('counters')
          .doc(counterName)
          .set({'count': 0});
    }

    // Update counter
    await _firestore
        .collection('counters')
        .doc(counterName)
        .set({'count': nextNumber});

    return '$prefix${nextNumber.toString().padLeft(7, '0')}';
  }

  // Initialize counters (run once)
  Future<void> initializeCounters() async {
    try {
      final counters = ['tenant_counter', 'business_counter'];

      for (final counter in counters) {
        final doc = await _firestore.collection('counters').doc(counter).get();
        if (!doc.exists) {
          await _firestore.collection('counters').doc(counter).set({'count': 0});
        }
      }
    } catch (e) {
      print('Error initializing counters: $e');
    }
  }
}
