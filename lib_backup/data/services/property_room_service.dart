import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onestay360/data/models/business/property/property_room_model.dart';

class PropertyRoomService {
  final FirebaseFirestore _firestore;

  PropertyRoomService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Returns list of rooms for a property from `rooms` subcollection.
  /// Falls back to reading legacy `rooms` array on the property document if subcollection is empty.
  Future<List<PropertyRoom>> getRoomsForProperty(String businessId, String propertyId) async {
    if (businessId.isEmpty || propertyId.isEmpty) return [];

    try {
      final roomsCol = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('properties')
          .doc(propertyId)
          .collection('rooms');

      final roomsSnapshot = await roomsCol.get();
      if (roomsSnapshot.docs.isNotEmpty) {
        return roomsSnapshot.docs.map((d) => PropertyRoom.fromMap(Map<String, dynamic>.from(d.data()))).toList();
      }
    } catch (e) {
      // ignore and fallback
    }

    // Fallback to legacy array
    try {
      final propDoc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('properties')
          .doc(propertyId)
          .get();

      if (!propDoc.exists) return [];
      final rooms = propDoc.data()?['rooms'] as List<dynamic>? ?? [];
      return rooms.map((r) => PropertyRoom.fromMap(Map<String, dynamic>.from(r as Map))).toList();
    } catch (e) {
      return [];
    }
  }
}
