// lib/presentation/maintenance/firestore_maintenance_source.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'maintenance_models.dart';
import 'maintenance_source.dart';

class FirestoreMaintenanceSource implements MaintenanceSource {
  FirestoreMaintenanceSource({FirebaseFirestore? firestore}) : _fs = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _fs;

  @override
  Stream<List<MaintenanceItem>> watch(String businessId) => _fs
      .collection('maintenanceRequests')
      .where('businessId', isEqualTo: businessId)
      .snapshots()
      .map((s) => s.docs.map((d) => MaintenanceItem.fromMap(d.id, d.data())).toList());

  @override
  Future<void> update(String id, {required MaintenanceState status, String? note, required String by}) {
    // Only status, ownerNote, updatedAt, updatedBy and resolvedAt may change
    // (firestore.rules).
    return _fs.collection('maintenanceRequests').doc(id).update({
      'status': status.wire,
      'ownerNote': ?note,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': by,
      if (status == MaintenanceState.resolved) 'resolvedAt': FieldValue.serverTimestamp(),
    });
  }
}
