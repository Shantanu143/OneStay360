import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:models/business/property/property_room_model.dart';

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

  /// Returns beds for a specific room with tenant information
  /// Returns map with bedNumber as key and bed data as value
  Future<Map<String, dynamic>> getBedsForRoom(String businessId, String propertyId, String roomId) async {
    if (businessId.isEmpty || propertyId.isEmpty || roomId.isEmpty) return {};

    try {
      final bedsCol = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('properties')
          .doc(propertyId)
          .collection('rooms')
          .doc(roomId)
          .collection('beds');

      final bedsSnapshot = await bedsCol.get();
      final bedsMap = <String, dynamic>{};
      
      for (final doc in bedsSnapshot.docs) {
        final bedData = Map<String, dynamic>.from(doc.data());
        bedsMap[doc.id] = bedData;
      }
      
      return bedsMap;
    } catch (e) {
      // Return empty if beds subcollection doesn't exist
      return {};
    }
  }
}

