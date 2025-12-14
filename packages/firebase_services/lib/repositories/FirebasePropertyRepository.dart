// lib/data/repositories/FirebasePropertyRepository.dart
/*import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:models/business/property/property_model.dart';
import 'package:firebase_services/repositories/property_repository.dart'; // ✅ Import from the main file

class FirebasePropertyRepository implements PropertyRepository {
  final FirebaseFirestore _firestore;

  FirebasePropertyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> addProperty(Property property) async {
    if (property.businessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty');
    }

    final batch = _firestore.batch();

    // Generate a new document reference with auto ID
    final businessPropertyRef = _firestore
        .collection('businesses')
        .doc(property.businessId)
        .collection('properties')
        .doc();

    final mainPropertyRef = _firestore
        .collection('properties')
        .doc(businessPropertyRef.id);

    // Prepare property data with generated ID
    final propertyData = property.toMap()
      ..['id'] = businessPropertyRef.id // ✅ Use 'id' instead of 'propertyId'
      ..['businessId'] = property.businessId
      ..['businessRef'] = _firestore.collection('businesses').doc(property.businessId).path // ✅ Store path instead of reference
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();

    // Validate the property data
    if (propertyData['name'] == null || propertyData['name'].toString().isEmpty) {
      throw ArgumentError('Property name cannot be empty');
    }

    batch.set(businessPropertyRef, propertyData);
    batch.set(mainPropertyRef, propertyData);

    await batch.commit();
  }

  @override
  Future<List<Property>> getPropertiesByBusiness(String businessId) async {
    if (businessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty');
    }

    final snapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('properties')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Property.fromMap(doc.data(), doc.id)) // ✅ Pass doc.id as second parameter
        .toList();
  }

  @override
  Future<Property> getPropertyById(String propertyId) async {
    if (propertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty');
    }

    final doc = await _firestore
        .collection('properties')
        .doc(propertyId)
        .get();

    if (!doc.exists) {
      throw Exception('Property not found');
    }

    return Property.fromMap(doc.data()!, doc.id); // ✅ Pass doc.id as second parameter
  }

  @override
  Future<void> updateProperty(Property property) async {
    if (property.id == null || property.id!.isEmpty) {
      throw ArgumentError('Property ID is required for update');
    }
    if (property.businessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty');
    }

    final updateData = property.toMap()
      ..['updatedAt'] = FieldValue.serverTimestamp();

    // Remove id from update data to avoid overwriting
    updateData.remove('id');

    await _firestore
        .collection('properties')
        .doc(property.id)
        .update(updateData);

    await _firestore
        .collection('businesses')
        .doc(property.businessId)
        .collection('properties')
        .doc(property.id)
        .update(updateData);
  }

  @override
  Future<void> deleteProperty(String propertyId) async {
    if (propertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty');
    }

    // First get the property to know the businessId
    final propertyDoc = await _firestore
        .collection('properties')
        .doc(propertyId)
        .get();

    if (!propertyDoc.exists) {
      throw Exception('Property not found');
    }

    final businessId = propertyDoc.data()!['businessId'] as String;

    final batch = _firestore.batch();

    batch.delete(_firestore
        .collection('properties')
        .doc(propertyId));

    batch.delete(_firestore
        .collection('businesses')
        .doc(businessId)
        .collection('properties')
        .doc(propertyId));

    await batch.commit();
  }
}*/
