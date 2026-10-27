// lib/presentation/view_models/tenant_wizard/assignment_data_source.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_services/services/property_room_service.dart';
import 'package:models/business/property/property_model.dart';
import 'package:models/business/property/property_room_model.dart';

/// Where the wizard reads the properties, rooms and bed occupancy from.
abstract class AssignmentDataSource {
  /// Properties a tenant can be placed in (drafts excluded).
  Future<List<Property>> propertiesFor(String businessId);
  Future<List<PropertyRoom>> roomsFor(String businessId, Property property);

  /// Room id (its number) -> bed numbers that are taken.
  Future<Map<String, Set<String>>> occupiedBeds(
    String businessId,
    String propertyId,
  );
}

class FirestoreAssignmentSource implements AssignmentDataSource {
  FirestoreAssignmentSource({
    FirebaseFirestore? firestore,
    PropertyRoomService? rooms,
    Set<String>? Function()? propertyScope,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _rooms = rooms ?? PropertyRoomService(),
       _propertyScope = propertyScope;

  /// The ids of the properties this person can open; null means all (owner).
  final Set<String>? Function()? _propertyScope;

  final FirebaseFirestore _firestore;
  final PropertyRoomService _rooms;

  @override
  Future<List<Property>> propertiesFor(String businessId) async {
    final snap = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('properties')
        .get();
    final scope = _propertyScope?.call();
    return snap.docs
        .map((d) => Property.fromMap({...d.data()}, d.id))
        .where((p) => p.status != 'draft')
        .where((p) => scope == null || (p.id != null && scope.contains(p.id)))
        .toList();
  }

  @override
  Future<List<PropertyRoom>> roomsFor(
    String businessId,
    Property property,
  ) async {
    if (property.id == null) return property.rooms;
    final fromCollection = await _rooms.getRoomsForProperty(
      businessId,
      property.id!,
    );
    return fromCollection.isNotEmpty ? fromCollection : property.rooms;
  }

  @override
  Future<Map<String, Set<String>>> occupiedBeds(
    String businessId,
    String propertyId,
  ) async {
    final occupied = <String, Set<String>>{};
    final snap = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('tenants')
        .where('propertyId', isEqualTo: propertyId)
        .where('status', isEqualTo: 'active')
        .get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final roomId = data['roomId']?.toString() ?? '';
      final bedId = data['bedId']?.toString() ?? '';
      if (roomId.isNotEmpty && bedId.isNotEmpty) {
        occupied.putIfAbsent(roomId, () => <String>{}).add(bedId);
      }
    }
    return occupied;
  }
}
