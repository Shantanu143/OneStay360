// lib/presentation/property_detail/firestore_property_detail_source.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:firebase_services/services/property_room_service.dart';
import 'package:flutter/foundation.dart';
import 'package:models/business/property/property_model.dart';
import 'package:models/business/property/property_room_model.dart';
import 'package:models/tenant/tenant_request_model.dart';

import 'property_detail_models.dart';
import 'property_detail_source.dart';

class FirestorePropertyDetailSource implements PropertyDetailSource {
  FirestorePropertyDetailSource({
    required PropertyRepository repository,
    FirebaseFirestore? firestore,
    PropertyRoomService? rooms,
  })  : _repo = repository,
        _fs = firestore ?? FirebaseFirestore.instance,
        _rooms = rooms ?? PropertyRoomService(firestore: firestore);

  final PropertyRepository _repo;
  final FirebaseFirestore _fs;
  final PropertyRoomService _rooms;

  /// How many tenants' invoices are read at once.
  static const _concurrency = 10;

  @override
  Future<Property?> property(String propertyId) async {
    try {
      return await _repo.getPropertyById(propertyId);
    } catch (e) {
      // The repository throws for a missing property; other errors surface
      // as "couldn't load" because the caller sees null only when absent.
      if (e.toString().toLowerCase().contains('not found')) return null;
      rethrow;
    }
  }

  @override
  Future<List<PropertyRoom>> rooms(Property property) async {
    if (property.id == null) return property.rooms;
    final fromCollection = await _rooms.getRoomsForProperty(property.businessId, property.id!);
    return fromCollection.isNotEmpty ? fromCollection : property.rooms;
  }

  @override
  Future<List<PropertyTenant>> activeTenants(String businessId, String propertyId) async {
    final snap = await _fs
        .collection('businesses')
        .doc(businessId)
        .collection('tenants')
        .where('propertyId', isEqualTo: propertyId)
        .where('status', isEqualTo: 'active')
        .get();
    return [for (final d in snap.docs) PropertyTenant.fromDoc(d.id, d.data())];
  }

  @override
  Stream<List<TenantRequest>> requests(String propertyId) {
    return _fs
        .collection('enrollmentRequests')
        .where('propertyId', isEqualTo: propertyId)
        .snapshots()
        .map((snap) {
      final out = <TenantRequest>[];
      for (final d in snap.docs) {
        try {
          out.add(TenantRequest.fromMap(d.data(), d.id));
        } catch (e) {
          // One malformed request must not hide all the others.
          debugPrint('⚠️ skipping unreadable request ${d.id}: $e');
        }
      }
      return out;
    });
  }

  @override
  Future<List<Map<String, dynamic>>> billingPayments(String businessId, String propertyId) async {
    final snap = await _fs
        .collection('businesses')
        .doc(businessId)
        .collection('payments_to_onestay360')
        .where('propertyId', isEqualTo: propertyId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();
    return [
      for (final d in snap.docs) {...d.data(), 'id': d.id},
    ];
  }

  @override
  Future<String?> unpaidInvoiceId(String businessId, String propertyId) =>
      _repo.getUnpaidInvoiceId(businessId: businessId, propertyId: propertyId);

  @override
  Future<List<InvoiceSummary>> invoicesFor(
    String businessId,
    List<String> tenantIds,
    String period,
  ) async {
    DateTime? date(Object? v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);
    final tenants = _fs.collection('businesses').doc(businessId).collection('tenants');
    final out = <InvoiceSummary>[];

    for (var i = 0; i < tenantIds.length; i += _concurrency) {
      final batch = tenantIds.skip(i).take(_concurrency).toList();
      final results = await Future.wait(batch.map((id) =>
          tenants.doc(id).collection('rent_invoices').where('periodMonth', isEqualTo: period).get()));
      for (var j = 0; j < batch.length; j++) {
        for (final d in results[j].docs) {
          final data = d.data();
          out.add(InvoiceSummary(
            tenantId: batch[j],
            amount: (data['amount'] as num?)?.toDouble() ?? 0,
            status: (data['status'] as String?) ?? 'unpaid',
            dueDate: date(data['dueDate']),
          ));
        }
      }
    }
    return out;
  }
}
