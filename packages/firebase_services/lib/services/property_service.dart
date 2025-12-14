import 'package:image_picker/image_picker.dart';
import 'package:models/business/property/property_model.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:firebase_services/services/image_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PropertyService {
  final PropertyRepository _repository;
  final ImageService _imageService;
  final FirebaseFirestore _firestore;

  PropertyService({
    required PropertyRepository repository,
    required ImageService imageService,
    FirebaseFirestore? firestore,
  }) : _repository = repository,
        _imageService = imageService,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Property> createProperty({
    required Property property,
    List<XFile>? images,
  }) async {
    // Validate required fields
    if (property.businessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty');
    }

    // Verify user owns this business
    final user = FirebaseAuth.instance.currentUser;
    if (user?.uid != property.businessId) {
      throw Exception('User can only create properties for their own business');
    }

    List<String> imageUrls = [];
    if (images != null && images.isNotEmpty) {
      try {
        imageUrls = await _imageService.uploadPropertyImages(
          images,
          'property_${property.businessId}_${DateTime.now().millisecondsSinceEpoch}',
        );
      } catch (e) {
        throw Exception('Failed to upload images: $e');
      }
    }

    // Create new property with image URLs
    final newProperty = Property(
      id: property.id,
      name: property.name,
      address: property.address,
      city: property.city,
      cityCode: property.cityCode,
      pincode: property.pincode,
      numberOfFloors: property.numberOfFloors,
      description: property.description,
      landmarks: property.landmarks,
      googleMapsLink: property.googleMapsLink,
      pricing: property.pricing,
      rooms: property.rooms,
      amenities: property.amenities,
      foodPlan: property.foodPlan,
      rules: property.rules,
      totals: property.totals,
      images: imageUrls,
      rating: property.rating,
      status: property.status,
      businessId: property.businessId,
      businessName: property.businessName,
      businessPhone: property.businessPhone,
      createdAt: property.createdAt,
      updatedAt: property.updatedAt,
      featured: property.featured,
    );

    await _repository.addProperty(newProperty);
    return newProperty;
  }

  Future<List<Property>> getBusinessProperties(String businessId) {
    if (businessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty');
    }

    // Verify user owns this business
    final user = FirebaseAuth.instance.currentUser;
    if (user?.uid != businessId) {
      throw Exception('User can only access properties from their own business');
    }

    return _repository.getPropertiesByBusiness(businessId);
  }

  Future<void> updatePropertyImages({
    required String propertyId,
    required List<String> existingImages,
    required List<XFile> newImages,
    required List<String> imagesToDelete,
  }) async {
    if (propertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty');
    }

    // Get the property first to verify ownership
    final property = await getPropertyById(propertyId);
    if (property == null) {
      throw Exception('Property not found');
    }

    // Verify user owns this property
    final user = FirebaseAuth.instance.currentUser;
    if (user?.uid != property.businessId) {
      throw Exception('User can only update images for their own properties');
    }

    // Delete images first
    if (imagesToDelete.isNotEmpty) {
      await _imageService.deleteImages(imagesToDelete);
    }

    // Upload new images
    List<String> newImageUrls = [];
    if (newImages.isNotEmpty) {
      newImageUrls = await _imageService.uploadPropertyImages(
        newImages,
        'property_${propertyId}_${DateTime.now().millisecondsSinceEpoch}',
      );
    }

    // Update property with new image list
    final updatedImages = [
      ...existingImages.where((img) => !imagesToDelete.contains(img)),
      ...newImageUrls,
    ];

    final updatedProperty = Property(
      id: property.id,
      name: property.name,
      address: property.address,
      city: property.city,
      cityCode: property.cityCode,
      pincode: property.pincode,
      numberOfFloors: property.numberOfFloors,
      description: property.description,
      landmarks: property.landmarks,
      googleMapsLink: property.googleMapsLink,
      pricing: property.pricing,
      rooms: property.rooms,
      amenities: property.amenities,
      foodPlan: property.foodPlan,
      rules: property.rules,
      totals: property.totals,
      images: updatedImages,
      rating: property.rating,
      status: property.status,
      businessId: property.businessId,
      businessName: property.businessName,
      businessPhone: property.businessPhone,
      createdAt: property.createdAt,
      updatedAt: DateTime.now(),
      featured: property.featured,
    );

    await _repository.updateProperty(updatedProperty);
  }

  Future<Property?> getPropertyById(String propertyId) async {
    if (propertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty');
    }

    try {
      return await _repository.getPropertyById(propertyId);
    } catch (e) {
      print('Error getting property by ID: $e');
      return null;
    }
  }

  // Get property by ID from any business (for public viewing)
  Future<Property?> getPublicPropertyById(String propertyId) async {
    if (propertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty');
    }

    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot;
      // If caller provided a full document path, use documentId. Otherwise
      // query by the explicit `id` field to avoid native parsing errors
      // when only a short id (e.g. 'p1') is provided.
      if (propertyId.contains('/')) {
        querySnapshot = await _firestore
            .collectionGroup('properties')
            .where(FieldPath.documentId, isEqualTo: propertyId)
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();
      } else {
        querySnapshot = await _firestore
            .collectionGroup('properties')
            .where('id', isEqualTo: propertyId)
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();
      }

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doc = querySnapshot.docs.first;
      return Property.fromMap(doc.data(), doc.id);
    } catch (e) {
      print('Error getting public property: $e');
      return null;
    }
  }
}
