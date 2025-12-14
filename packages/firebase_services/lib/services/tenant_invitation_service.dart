import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:models/business/tenant_invitation_model.dart';
import 'package:models/business/tenant_model.dart';
import 'package:firebase_services/services/approval_function_client.dart';

class TenantInvitationService {
  final FirebaseFirestore _firestore;

  TenantInvitationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Create a tenant invitation
  Future<String> createInvitation(TenantInvitation invitation) async {
    try {
      // Verify businessId is set
      if (invitation.businessId.isEmpty) {
        throw Exception('Business ID is required to create an invitation');
      }

      final docRef = _firestore
          .collection('tenant_invitations')
          .doc();
      
      final invitationData = invitation.toMap();
      
      // Ensure businessId is in the data being written
      invitationData['businessId'] = invitation.businessId;
      
      // Debug logging
      debugPrint('[DEBUG] Creating invitation with data:');
      debugPrint('[DEBUG] - businessId: ${invitationData['businessId']}');
      debugPrint('[DEBUG] - tenantId: ${invitationData['tenantId']}');
      debugPrint('[DEBUG] - tenantName: ${invitationData['tenantName']}');
      debugPrint('[DEBUG] - Full data keys: ${invitationData.keys.toList()}');
      
      await docRef.set(invitationData);
      
      debugPrint('[DEBUG] Invitation created successfully with ID: ${docRef.id}');
      
      // Create notification for tenant
      await _createNotification(
        tenantId: invitation.tenantId,
        invitationId: docRef.id,
        propertyName: invitation.propertyName,
        roomNumber: invitation.roomNumber,
        bedNumber: invitation.bedNumber,
      );
      
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating invitation: $e');
      rethrow;
    }
  }

  /// Create notification for tenant
  Future<void> _createNotification({
    required String tenantId,
    required String invitationId,
    required String propertyName,
    required String roomNumber,
    required String bedNumber,
  }) async {
    try {
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('notifications')
          .add({
        'type': 'tenant_invitation',
        'invitationId': invitationId,
        'title': 'New PG Invitation',
        'message': 'You have been invited to join $propertyName, Room $roomNumber, Bed $bedNumber',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
      // Don't rethrow - notification failure shouldn't block invitation
    }
  }

  /// Get pending invitations for a tenant
  Stream<List<TenantInvitation>> getPendingInvitationsForTenant(String tenantId) {
    return _firestore
        .collection('tenant_invitations')
        .where('tenantId', isEqualTo: tenantId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TenantInvitation.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Approve invitation and create tenant
  Future<void> approveInvitation(String invitationId) async {
    try {
      final client = ApprovalFunctionClient();
      final success = await client.approveInvitation(invitationId);
      if (!success) {
        throw Exception('Approval function returned failure');
      }
      debugPrint('[DEBUG] approveInvitation: cloud function executed successfully for $invitationId');
    } catch (e) {
      debugPrint('Error approving invitation via Cloud Function: $e');
      rethrow;
    }
  }

  /// Update room bed occupancy and enforce gender rules
  Future<void> _updateRoomBedOccupancy({
    required WriteBatch batch,
    required String businessId,
    required String propertyId,
    required String propertyName,
    required String roomId,
    required int bedIndex,
    required String tenantId,
    required String tenantName,
    String? gender,
  }) async {
    // Try to get property document at expected path
    QueryDocumentSnapshot<Map<String, dynamic>>? fallbackDoc;
    DocumentSnapshot<Map<String, dynamic>> propertyDocSnapshot;

    propertyDocSnapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('properties')
        .doc(propertyId)
        .get();

    if (!propertyDocSnapshot.exists) {
      debugPrint('[WARN] Property not found at businesses/$businessId/properties/$propertyId - attempting fallback search');
      try {
        // Try collectionGroup search by document id only if we have a non-empty id
        if (propertyId.trim().isNotEmpty) {
          // If caller passed a full document path (contains '/'), we can use
          // FieldPath.documentId with the full path. Otherwise query by the
          // indexed `id` field on property documents which is safer for
          // collectionGroup queries across different parent paths.
          if (propertyId.contains('/')) {
            try {
              final byId = await _firestore
                  .collectionGroup('properties')
                  .where(FieldPath.documentId, isEqualTo: propertyId)
                  .limit(1)
                  .get();
              if (byId.docs.isNotEmpty) {
                fallbackDoc = byId.docs.first;
                debugPrint('[INFO] Found property by collectionGroup document path at ${fallbackDoc.reference.path}');
              }
            } catch (e) {
              debugPrint('[WARN] collectionGroup documentId query failed: $e');
            }
          }

          // If we haven't found it yet, try searching by the explicit `id`
          // field on property documents. This avoids native parsing errors
          // when only a short id like 'p1' is provided.
          if (fallbackDoc == null) {
            final byIdField = await _firestore
                .collectionGroup('properties')
                .where('id', isEqualTo: propertyId)
                .limit(1)
                .get();
            if (byIdField.docs.isNotEmpty) {
              fallbackDoc = byIdField.docs.first;
              debugPrint('[INFO] Found property by collectionGroup id-field at ${fallbackDoc.reference.path}');
            }
          }
        }

        // Try find by property name if provided and fallback not found
        if (fallbackDoc == null && propertyName.trim().isNotEmpty) {
          final byName = await _firestore
              .collectionGroup('properties')
              .where('name', isEqualTo: propertyName)
              .limit(1)
              .get();
          if (byName.docs.isNotEmpty) {
            fallbackDoc = byName.docs.first;
            debugPrint('[INFO] Found property by name at ${fallbackDoc.reference.path}');
          }
        }

        if (fallbackDoc == null) {
          debugPrint('[WARN] Fallback search did not find property; skipping room/beds update');
          return; // don't block approval; skip occupancy update
        }

        // Use fallbackDoc as the property document
        propertyDocSnapshot = await fallbackDoc.reference.get();
      } catch (e, st) {
        // Likely a native parsing error occurred (bad query args). Log and skip occupancy update
        debugPrint('[ERROR] Exception while searching for property fallback: $e');
        debugPrint(st.toString());
        debugPrint('[WARN] Skipping room/beds update due to search error');
        return;
      }
    }

    // Locate the room document in subcollection `rooms`
    final businessPropRef = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('properties')
        .doc(propertyDocSnapshot.id);

    final roomsCol = businessPropRef.collection('rooms');

    DocumentSnapshot<Map<String, dynamic>> roomDoc;
    // Try direct doc id (roomId used as doc id)
    roomDoc = await roomsCol.doc(roomId).get();
    if (!roomDoc.exists) {
      // Try query by roomNumber field
      final q = await roomsCol.where('roomNumber', isEqualTo: roomId).limit(1).get();
      if (q.docs.isEmpty) {
        throw Exception('Room not found');
      }
      roomDoc = q.docs.first;
    }

    final room = roomDoc.data()!;

    // Check if room is completely empty
    final existingTenants = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('tenants')
        .where('propertyId', isEqualTo: propertyId)
        .where('roomId', isEqualTo: roomId)
        .where('status', isEqualTo: 'active')
        .get();

    final isRoomEmpty = existingTenants.docs.isEmpty;

    String? roomGender;

    if (isRoomEmpty && gender != null) {
      roomGender = gender;
      // Persist the chosen gender on the room document
      batch.update(roomDoc.reference, {'gender': gender});
    } else if (!isRoomEmpty) {
      // Derive existing room gender from room doc or from first tenant
      roomGender = room['gender']?.toString();
      if (roomGender == null && existingTenants.docs.isNotEmpty) {
        final firstTenant = existingTenants.docs.first.data();
        roomGender = firstTenant['gender']?.toString();
      }

      // Validate gender matches
      if (gender != null && roomGender != null && gender != roomGender) {
        throw Exception(
          'Room is already assigned to ${roomGender == 'Male' ? 'males' : 'females'}. '
          'Cannot assign ${gender == 'Male' ? 'male' : 'female'} tenant to this room.',
        );
      }
    }

    // Mark the bed as occupied in the room's beds subcollection
    try {
      final bedId = (bedIndex + 1).toString();
      final bedRef = roomDoc.reference.collection('beds').doc(bedId);
      final bedData = {
        'bedNumber': bedId,
        'isOccupied': true,
        'tenantId': tenantId,
        'tenantName': tenantName,
        'occupiedAt': FieldValue.serverTimestamp(),
      };
      batch.set(bedRef, bedData);
    } catch (e) {
      debugPrint('Warning: failed to update bed doc in beds subcollection: $e');
    }
  }

  /// Reject invitation
  Future<void> rejectInvitation(
    String invitationId,
    String? reason,
  ) async {
    await _firestore
        .collection('tenant_invitations')
        .doc(invitationId)
        .update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason,
    });
  }

  /// Get room gender (if set)
  Future<String?> getRoomGender({
    required String businessId,
    required String propertyId,
    required String roomId,
  }) async {
    // Prefer rooms subcollection (new schema)
    try {
      final businessPropRef = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('properties')
          .doc(propertyId);

      final roomsCol = businessPropRef.collection('rooms');

      // Try direct doc id first
      final roomDoc = await roomsCol.doc(roomId).get();
      if (roomDoc.exists) {
        return roomDoc.data()?['gender']?.toString();
      }

      // Try querying by roomNumber
      final q = await roomsCol.where('roomNumber', isEqualTo: roomId).limit(1).get();
      if (q.docs.isNotEmpty) {
        return q.docs.first.data()['gender']?.toString();
      }
    } catch (e) {
      // If any error occurs while querying subcollection, fall back to legacy array below
      debugPrint('[WARN] getRoomGender: error querying rooms subcollection: $e');
    }

    // Legacy fallback: read top-level property document's rooms array
    final propertyDoc = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('properties')
        .doc(propertyId)
        .get();

    if (!propertyDoc.exists) return null;

    final rooms = propertyDoc.data()?['rooms'] as List<dynamic>? ?? [];
    final room = rooms.firstWhere(
      (r) => r['roomNumber']?.toString() == roomId || r['id']?.toString() == roomId,
      orElse: () => null,
    );

    return room?['gender']?.toString();
  }

  /// Check if room is completely empty
  Future<bool> isRoomEmpty({
    required String businessId,
    required String propertyId,
    required String roomId,
  }) async {
    final tenants = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('tenants')
        .where('propertyId', isEqualTo: propertyId)
        .where('roomId', isEqualTo: roomId)
        .where('status', isEqualTo: 'active')
        .get();

    return tenants.docs.isEmpty;
  }
}


