import 'package:cloud_firestore/cloud_firestore.dart';

class TenantSearchResult {
  final String tenantId;
  final String name;
  final String phone;
  final String? email;
  final String? profileImage;
  final Map<String, dynamic>? fullData;

  TenantSearchResult({
    required this.tenantId,
    required this.name,
    required this.phone,
    this.email,
    this.profileImage,
    this.fullData,
  });
}

class TenantSearchService {
  final FirebaseFirestore _firestore;

  TenantSearchService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Search tenants by name or phone
  Future<List<TenantSearchResult>> searchTenants(String query) async {
    if (query.trim().isEmpty) return [];

    final queryLower = query.toLowerCase().trim();

    try {
      // Search in tenants collection by name
      final tenantsByName = await _firestore
          .collection('tenants')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get();

      // Search by phone (exact match or partial)
      final tenantsByPhone = await _firestore
          .collection('tenants')
          .where('phone', isEqualTo: query.replaceAll(RegExp(r'[^\d]'), ''))
          .limit(10)
          .get();

      // Also search in users collection for tenantId
      final usersByName = await _firestore
          .collection('users')
          .where('tenantId', isNotEqualTo: null)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get();

      final results = <String, TenantSearchResult>{};

      // Process tenants collection results
      for (final doc in tenantsByName.docs) {
        final data = doc.data();
        final tenantId = doc.id;
        results[tenantId] = TenantSearchResult(
          tenantId: tenantId,
          name: data['name']?.toString() ?? '',
          phone: data['phone']?.toString() ?? '',
          email: data['email']?.toString(),
          profileImage: data['profileImage']?.toString(),
          fullData: data,
        );
      }

      // Process phone search results
      for (final doc in tenantsByPhone.docs) {
        final data = doc.data();
        final tenantId = doc.id;
        if (!results.containsKey(tenantId)) {
          results[tenantId] = TenantSearchResult(
            tenantId: tenantId,
            name: data['name']?.toString() ?? '',
            phone: data['phone']?.toString() ?? '',
            email: data['email']?.toString(),
            profileImage: data['profileImage']?.toString(),
            fullData: data,
          );
        }
      }

      // Process users collection results
      for (final doc in usersByName.docs) {
        final data = doc.data();
        final tenantId = data['tenantId']?.toString();
        if (tenantId != null && !results.containsKey(tenantId)) {
          // Fetch tenant document
          final tenantDoc = await _firestore
              .collection('tenants')
              .doc(tenantId)
              .get();

          if (tenantDoc.exists) {
            final tenantData = tenantDoc.data()!;
            results[tenantId] = TenantSearchResult(
              tenantId: tenantId,
              name: data['name']?.toString() ?? 
                    data['fullName']?.toString() ?? 
                    tenantData['name']?.toString() ?? '',
              phone: data['phone']?.toString() ?? 
                     data['mobileNumber']?.toString() ?? 
                     tenantData['phone']?.toString() ?? '',
              email: data['email']?.toString() ?? tenantData['email']?.toString(),
              profileImage: data['profileImage']?.toString() ?? 
                           tenantData['profileImage']?.toString(),
              fullData: {...data, ...tenantData},
            );
          }
        }
      }

      // Filter by query (case-insensitive)
      return results.values
          .where((result) =>
              result.name.toLowerCase().contains(queryLower) ||
              result.phone.contains(query.replaceAll(RegExp(r'[^\d]'), '')))
          .toList();
    } catch (e) {
      print('Error searching tenants: $e');
      return [];
    }
  }

  /// Get tenant by ID
  Future<TenantSearchResult?> getTenantById(String tenantId) async {
    try {
      final tenantDoc = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .get();

      if (!tenantDoc.exists) return null;

      final data = tenantDoc.data()!;

      // Also get user document for complete data
      final userDoc = await _firestore
          .collection('users')
          .where('tenantId', isEqualTo: tenantId)
          .limit(1)
          .get();

      Map<String, dynamic> fullData = {...data};
      if (userDoc.docs.isNotEmpty) {
        fullData = {...fullData, ...userDoc.docs.first.data()};
      }

      return TenantSearchResult(
        tenantId: tenantId,
        name: data['name']?.toString() ?? '',
        phone: data['phone']?.toString() ?? '',
        email: data['email']?.toString(),
        profileImage: data['profileImage']?.toString(),
        fullData: fullData,
      );
    } catch (e) {
      print('Error getting tenant by ID: $e');
      return null;
    }
  }
}

