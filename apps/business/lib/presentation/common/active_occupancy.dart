// lib/presentation/common/active_occupancy.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Beds in use per property: one per active tenant.
///
/// The `totals.availableBeds` stored on a property is set when it is created
/// and nothing keeps it current as tenants move in and out, so counting the
/// tenants themselves is the figure that can be trusted (it is also what Home
/// and the property page show).
Map<String, int> countActiveTenants(Iterable<Map<String, dynamic>> tenants) {
  final counts = <String, int>{};
  for (final t in tenants) {
    if (t['status'] != 'active') continue;
    final property = (t['propertyId'] ?? '').toString();
    if (property.isEmpty) continue;
    counts.update(property, (n) => n + 1, ifAbsent: () => 1);
  }
  return counts;
}

/// [countActiveTenants] for one business, reading only its active tenants.
Future<Map<String, int>> loadActiveOccupancy(FirebaseFirestore firestore, String businessId) async {
  final snap = await firestore
      .collection('businesses')
      .doc(businessId)
      .collection('tenants')
      .where('status', isEqualTo: 'active')
      .get();
  return countActiveTenants(snap.docs.map((d) => d.data()));
}
