import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_membership_model.dart';

/// Service for validating user-business relationships via memberships.
/// Memberships are stored as nested documents: businesses/{businessId}/members/{uid}
/// Supports multi-member businesses (intentionally minimal for Phase 1).
///
/// DESIGN CONSTRAINTS:
/// - This service only validates self-access (uid vs businessId).
/// - Admin member listing and staff management are intentionally NOT supported yet.
/// - No staff roles, permissions, or member mutations in Phase 1.
/// - Only one owner per business today.
/// - Reads membership from nested path only: businesses/{businessId}/members/{uid}
class BusinessMembershipService {
  final FirebaseFirestore _firestore;

  BusinessMembershipService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get the active membership for a user in a specific business.
  /// Reads from: businesses/{businessId}/members/{uid}
  /// Returns null if no active membership exists.
  Future<BusinessMembership?> getActiveMembership(
    String uid,
    String businessId,
  ) async {
    if (uid.isEmpty || businessId.isEmpty) {
      throw ArgumentError('uid and businessId must not be empty');
    }

    try {
      print('🔍 [BusinessMembershipService.getActiveMembership] Reading membership: businesses/$businessId/members/$uid');
      
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('members')
          .doc(uid)
          .get();

      if (!snapshot.exists) {
        print('❌ [BusinessMembershipService.getActiveMembership] Membership doc does not exist');
        return null;
      }

      print('✅ [BusinessMembershipService.getActiveMembership] Membership doc exists');
      
      final data = snapshot.data()!;
      final status = data['status'] as String?;
      print('🔍 [BusinessMembershipService.getActiveMembership] Status: $status');
      
      if (status != 'active') {
        print('❌ [BusinessMembershipService.getActiveMembership] Status is not active: $status');
        return null;
      }

      print('✅ [BusinessMembershipService.getActiveMembership] Membership is active, returning');
      return BusinessMembership.fromFirestore(snapshot);
    } catch (e) {
      print('❌ [BusinessMembershipService.getActiveMembership] Error: $e');
      throw Exception('Failed to fetch active membership: $e');
    }
  }

  /// Check if a user has an active membership in a business.
  /// Thin wrapper around getActiveMembership for boolean checks.
  /// Returns false if no active membership exists.
  Future<bool> isActiveMember(String uid, String businessId) async {
    final membership = await getActiveMembership(uid, businessId);
    return membership != null;
  }

  /// Stream active membership for a user in a business.
  /// Reads from: businesses/{businessId}/members/{uid}
  /// Used for real-time validation and reactive UI updates.
  Stream<BusinessMembership?> streamActiveMembership(
    String uid,
    String businessId,
  ) {
    if (uid.isEmpty || businessId.isEmpty) {
      return Stream.empty();
    }

    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('members')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data()!;
      if (data['status'] != 'active') {
        return null;
      }

      return BusinessMembership.fromFirestore(snapshot);
    });
  }
}
