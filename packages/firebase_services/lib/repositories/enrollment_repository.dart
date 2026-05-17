import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class EnrollmentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submit an enrollment request to Firestore via Callable Cloud Function
  Future<String> submitEnrollmentRequest({
    required String propertyId,
    required String businessId,
    required String tenantName,
    required String tenantPhone,
    required DateTime moveInDate,
    String? propertyName,
    String? roomType,
    String? sharingType,
    String? notes,
    String? kycDocumentUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final callable = FirebaseFunctions.instance.httpsCallable('submitEnrollmentRequest');
      final result = await callable.call({
        'propertyId': propertyId,
        'businessId': businessId,
        'tenantName': tenantName,
        'tenantPhone': tenantPhone,
        'moveInDate': moveInDate.toIso8601String(),
        'propertyName': propertyName ?? '',
        'roomType': roomType ?? '',
        'sharingType': sharingType ?? '',
        'notes': notes ?? '',
        'kycDocumentUrl': kycDocumentUrl ?? '',
      });

      final requestId = result.data['requestId'] as String;
      debugPrint('✅ Enrollment request submitted securely: $requestId');
      return requestId;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Firebase Functions Error: \${e.code} - \${e.message}');
      throw Exception(e.message ?? 'Failed to submit enrollment request');
    } catch (e) {
      debugPrint('❌ Error submitting enrollment request: $e');
      rethrow;
    }
  }

  /// Get current user's enrollment requests
  Future<List<Map<String, dynamic>>> getUserEnrollmentRequests() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final snapshot = await _firestore
          .collection('enrollmentRequests')
          .where('tenantId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Error fetching enrollment requests: $e');
      rethrow;
    }
  }

  /// Get enrollment requests for a specific property
  Future<List<Map<String, dynamic>>> getPropertyEnrollmentRequests(
      String propertyId) async {
    try {
      final snapshot = await _firestore
          .collection('enrollmentRequests')
          .where('propertyId', isEqualTo: propertyId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Error fetching property enrollment requests: $e');
      rethrow;
    }
  }

  /// Update enrollment request status (for business owners)
  Future<void> updateEnrollmentStatus(
    String requestId,
    String status,
  ) async {
    try {
      await _firestore.collection('enrollmentRequests').doc(requestId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Enrollment request status updated: $requestId -> $status');
    } catch (e) {
      debugPrint('❌ Error updating enrollment request: $e');
      rethrow;
    }
  }
}
