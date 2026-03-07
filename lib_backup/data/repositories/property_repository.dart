import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onestay360/data/models/business/property/property_model.dart';
import 'package:onestay360/data/services/id_generation_service.dart';

abstract class PropertyRepository {
  Future<void> addProperty(Property property);
  Future<String> generatePropertyId(String businessId, String cityCode);
  Future<List<Property>> getPropertiesByBusiness(String businessId);
  Future<List<Property>> getPropertiesByCity(String city);
  Future<List<Property>> searchProperties({
    required String city,
    int? minPrice,
    int? maxPrice,
    String? genderAllowed,
    List<String>? amenities,
  });
  Future<Property> getPropertyById(String propertyId);
  Future<void> updateProperty(Property property);
  Future<void> deleteProperty(String propertyId);
  Future<List<Property>> getFeaturedProperties(String city);
  Future<String?> getCurrentUserBusinessId(); // ADDED THIS METHOD
}

class FirebasePropertyRepository implements PropertyRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final IdGenerationService _idService;

  FirebasePropertyRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    IdGenerationService? idService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _idService = idService ?? IdGenerationService();

  @override
  Future<String> generatePropertyId(String businessId, String cityCode) async {
    return await _idService.generatePropertyId(businessId, cityCode);
  }

  // Helper method to get current user's business ID
  Future<String?> _getCurrentUserBusinessId() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final businessId = userDoc.data()?['businessId'] as String?;
      debugPrint('🔍 User Business ID from Firestore: $businessId');
      return businessId ?? user.uid; // Fallback to user ID if no businessId
    } catch (e) {
      debugPrint('❌ Error getting business ID: $e');
      return null;
    }
  }

  // Public method to get current user's business ID - ADDED THIS METHOD
  @override
  Future<String?> getCurrentUserBusinessId() async {
    return await _getCurrentUserBusinessId();
  }

  // Helper method to safely convert DocumentSnapshot to Property
  Property _documentToProperty(DocumentSnapshot doc) {
    try {
      final data = doc.data();
      if (data == null) {
        throw Exception('Document data is null for property ${doc.id}');
      }
      if (data is! Map<String, dynamic>) {
        throw Exception('Document data is not Map<String, dynamic> for property ${doc.id}');
      }

      debugPrint('🔄 Converting document to property: ${doc.id}');
      debugPrint('📋 Document data: $data');

      return Property.fromMap(data, doc.id);
    } catch (e, stack) {
      debugPrint('❌ Error converting document ${doc.id} to Property: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  // Helper method to safely convert QuerySnapshot to List<Property>
  List<Property> _querySnapshotToProperties(QuerySnapshot snapshot) {
    debugPrint('📊 Converting ${snapshot.docs.length} documents to properties');
    return snapshot.docs.map((doc) => _documentToProperty(doc)).toList();
  }

  @override
  Future<void> addProperty(Property property) async {
    if (property.businessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty');
    }

    // Verify the current user owns this business
    final userBusinessId = await _getCurrentUserBusinessId();
    if (userBusinessId != property.businessId) {
      throw Exception('User can only add properties to their own business. User Business: $userBusinessId, Property Business: ${property.businessId}');
    }

    // Determine property ID: use provided id if present, otherwise generate
    final propertyId = (property.id != null && property.id!.isNotEmpty)
        ? property.id!
        : await _idService.generatePropertyId(
            property.businessId,
            property.cityCode.isNotEmpty ? property.cityCode : 'GEN',
          );

    // Prepare property data with determined ID
    final propertyWithId = property.copyWith(id: propertyId);
    final propertyData = propertyWithId.toMap()
      ..['propertyId'] = propertyId
      ..['id'] = propertyId
      ..['businessId'] = property.businessId
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();

    // Validate the property data
    if (propertyData['name'] == null || propertyData['name'].toString().isEmpty) {
      throw ArgumentError('Property name cannot be empty');
    }

    debugPrint('🔐 Security Check:');
    debugPrint('  User Business ID: $userBusinessId');
    debugPrint('  Property Business ID: ${property.businessId}');
    debugPrint('  City: ${property.city}');
    debugPrint('  Generated Property ID: $propertyId');

    try {
      // Remove rooms array from the top-level doc (we'll store rooms as subcollection)
      final rooms = property.rooms;
      propertyData.remove('rooms');

      // 1. First write property documents (business and city) immediately
      final businessPropRef = _firestore
          .collection('businesses')
          .doc(property.businessId)
          .collection('properties')
          .doc(propertyId);

      final cityPropRef = _firestore
          .collection('properties_by_city')
          .doc(property.city)
          .collection('properties')
          .doc(propertyId);

      debugPrint('💾 Writing property doc to ${businessPropRef.path} and ${cityPropRef.path}');
      await businessPropRef.set(propertyData);
      await cityPropRef.set(propertyData);

      // 2. Prepare per-room writes (room doc + bed docs) and commit in chunks
      List<Function(WriteBatch)> pendingWrites = [];

      for (final room in rooms) {
        pendingWrites.add((WriteBatch b) {
          final roomId = (room.roomNumber.isNotEmpty) ? room.roomNumber : null;
          final roomRef = (roomId != null)
              ? businessPropRef.collection('rooms').doc(roomId)
              : businessPropRef.collection('rooms').doc();
          b.set(roomRef, room.toMap());

          final sharingType = room.sharingType ?? 1;
          for (int i = 1; i <= sharingType; i++) {
            final bedId = i.toString();
            final bedRef = roomRef.collection('beds').doc(bedId);
            final bedData = {'bedNumber': bedId, 'isOccupied': false};
            b.set(bedRef, bedData);
          }
        });
      }

      // Commit pending writes in chunks
      int writeCount = 0;
      WriteBatch batch = _firestore.batch();
      for (final writeOp in pendingWrites) {
        // We approximate chunk size by number of rooms to avoid exceeding limits
        writeOp(batch);
        writeCount += 1; // counting rooms as unit

        if (writeCount >= 40) {
          await batch.commit();
          debugPrint('✅ Committed a chunk of room writes (~$writeCount rooms) for property $propertyId');
          batch = _firestore.batch();
          writeCount = 0;
        }
      }

      // Commit any remaining writes
      if (writeCount > 0) {
        await batch.commit();
        debugPrint('✅ Committed final chunk of room writes (~$writeCount rooms) for property $propertyId');
      }

      debugPrint('✅ Property and rooms created successfully: $propertyId');
    } catch (e, stack) {
      debugPrint('❌ Firestore error while creating property and rooms: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  @override
  Future<List<Property>> getPropertiesByBusiness(String businessId) async {
    if (businessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty');
    }

    // Verify the current user owns this business
    final userBusinessId = await _getCurrentUserBusinessId();
    if (userBusinessId != businessId) {
      throw Exception('User does not have permission to access this business data. User: $userBusinessId, Requested: $businessId');
    }

    try {
      debugPrint('🔍 Querying properties for business: $businessId');
      debugPrint('📋 Path: businesses/$businessId/properties');

      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('properties')
          .orderBy('createdAt', descending: true)
          .get();

      debugPrint('✅ Successfully loaded ${snapshot.docs.length} properties for business $businessId');

      // Debug each document
      for (final doc in snapshot.docs) {
        debugPrint('📄 Document: ${doc.id} | Exists: ${doc.exists}');
        debugPrint('   Data: ${doc.data()}');
      }

      final properties = _querySnapshotToProperties(snapshot);
      debugPrint('🎯 Converted to ${properties.length} Property objects');

      return properties;
    } catch (e, stack) {
      debugPrint('❌ Firestore query error: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  @override
  Future<List<Property>> getPropertiesByCity(String city) async {
    if (city.isEmpty) {
      throw ArgumentError('City cannot be empty');
    }

    try {
      final snapshot = await _firestore
          .collection('properties_by_city')
          .doc(city)
          .collection('properties')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .get();

      debugPrint('✅ Successfully loaded ${snapshot.docs.length} properties in $city');

      return _querySnapshotToProperties(snapshot);
    } catch (e) {
      debugPrint('❌ Firestore query error: $e');
      rethrow;
    }
  }

  @override
  Future<List<Property>> searchProperties({
    required String city,
    int? minPrice,
    int? maxPrice,
    String? genderAllowed,
    List<String>? amenities,
  }) async {
    if (city.isEmpty) {
      throw ArgumentError('City cannot be empty');
    }

    try {
      Query query = _firestore
          .collection('properties_by_city')
          .doc(city)
          .collection('properties')
          .where('status', isEqualTo: 'active');

      // Add price filters if provided
      if (minPrice != null || maxPrice != null) {
        query = query.where('pricing.startingFrom', isGreaterThanOrEqualTo: minPrice ?? 0);
        if (maxPrice != null) {
          query = query.where('pricing.startingFrom', isLessThanOrEqualTo: maxPrice);
        }
      }

      // Add gender filter if provided
      if (genderAllowed != null && genderAllowed.isNotEmpty) {
        query = query.where('rules.genderAllowed', isEqualTo: genderAllowed);
      }

      final snapshot = await query.orderBy('createdAt', descending: true).get();

      List<Property> properties = _querySnapshotToProperties(snapshot);

      // Filter by amenities client-side
      if (amenities != null && amenities.isNotEmpty) {
        properties = properties.where((property) {
          final propertyAmenities = property.amenities;
          return amenities.every((amenity) {
            switch (amenity) {
              case 'wifi':
                return propertyAmenities.wifi;
              case 'ac':
                return propertyAmenities.ac;
              case 'food':
                return propertyAmenities.foodIncluded;
              case 'parking':
                return propertyAmenities.parking;
              case 'laundry':
                return propertyAmenities.laundry;
              default:
                return false;
            }
          });
        }).toList();
      }

      debugPrint('✅ Search found ${properties.length} properties in $city');
      return properties;
    } catch (e) {
      debugPrint('❌ Search error: $e');
      rethrow;
    }
  }

  @override
  Future<Property> getPropertyById(String propertyId) async {
    if (propertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty');
    }

    try {
      // Try to get from any city collection
      final cities = ['Pune', 'Mumbai', 'Bangalore', 'Delhi', 'Chennai', 'Kolkata'];

      for (final city in cities) {
        try {
          final doc = await _firestore
              .collection('properties_by_city')
              .doc(city)
              .collection('properties')
              .doc(propertyId)
              .get();

          if (doc.exists) {
            return _documentToProperty(doc);
          }
        } catch (e) {
          continue;
        }
      }

      // Fallback to business subcollection
      QuerySnapshot querySnapshot;
      if (propertyId.contains('/')) {
        querySnapshot = await _firestore
            .collectionGroup('properties')
            .where(FieldPath.documentId, isEqualTo: propertyId)
            .limit(1)
            .get();
      } else {
        querySnapshot = await _firestore
            .collectionGroup('properties')
            .where('id', isEqualTo: propertyId)
            .limit(1)
            .get();
      }

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Property not found: $propertyId');
      }

      return _documentToProperty(querySnapshot.docs.first);
    } catch (e) {
      debugPrint('❌ Error getting property: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateProperty(Property property) async {
    if (property.id == null || property.id!.isEmpty) {
      throw ArgumentError('Property ID is required for update');
    }
    if (property.businessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty');
    }

    // Verify the current user owns this business
    final userBusinessId = await _getCurrentUserBusinessId();
    if (userBusinessId != property.businessId) {
      throw Exception('User can only update properties in their own business');
    }

    final updateData = property.toMap()
      ..['updatedAt'] = FieldValue.serverTimestamp();

    try {
      // Update in business subcollection
      await _firestore
          .collection('businesses')
          .doc(property.businessId)
          .collection('properties')
          .doc(property.id)
          .update(updateData);

      // Update in city-wise collection
      await _firestore
          .collection('properties_by_city')
          .doc(property.city)
          .collection('properties')
          .doc(property.id)
          .update(updateData);

      debugPrint('✅ Property updated successfully: ${property.id}');
    } catch (e) {
      debugPrint('❌ Firestore update error: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteProperty(String propertyId) async {
    if (propertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty');
    }

    // Get property to find its businessId and city
    final property = await getPropertyById(propertyId);

    // Verify the current user owns this business
    final userBusinessId = await _getCurrentUserBusinessId();
    if (userBusinessId != property.businessId) {
      throw Exception('User can only delete properties from their own business');
    }

    try {
      // Delete from business subcollection
      await _firestore
          .collection('businesses')
          .doc(property.businessId)
          .collection('properties')
          .doc(propertyId)
          .delete();

      // Delete from city-wise collection
      await _firestore
          .collection('properties_by_city')
          .doc(property.city)
          .collection('properties')
          .doc(propertyId)
          .delete();

      debugPrint('✅ Property deleted successfully: $propertyId');
    } catch (e) {
      debugPrint('❌ Firestore delete error: $e');
      rethrow;
    }
  }

  @override
  Future<List<Property>> getFeaturedProperties(String city) async {
    try {
      final snapshot = await _firestore
          .collection('properties_by_city')
          .doc(city)
          .collection('properties')
          .where('status', isEqualTo: 'active')
          .where('featured', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      return _querySnapshotToProperties(snapshot);
    } catch (e) {
      debugPrint('❌ Error getting featured properties: $e');
      rethrow;
    }
  }
}