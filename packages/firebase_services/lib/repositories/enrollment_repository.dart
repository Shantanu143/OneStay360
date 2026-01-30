import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class EnrollmentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submit an enrollment request to Firestore
  /// Saves to: /enrollmentRequests/{requestId}
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
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final requestId = _firestore.collection('enrollmentRequests').doc().id;

      await _firestore.collection('enrollmentRequests').doc(requestId).set({
        'requestId': requestId,
        'tenantId': user.uid,
        'tenantName': tenantName,
        'tenantPhone': tenantPhone,
        'propertyId': propertyId,
        'businessId': businessId,
        'propertyName': propertyName ?? '',
        'moveInDate': moveInDate,
        'roomType': roomType ?? '',
        'sharingType': sharingType ?? '',
        'notes': notes ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Enrollment request submitted: $requestId');
      return requestId;
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
