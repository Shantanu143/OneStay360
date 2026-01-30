import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_services/services/id_generation_service.dart';

/// Service to bootstrap a new business and make user the owner.
/// Handles the complete creation flow with membership validation.
class CreateBusinessService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final IdGenerationService _idService;

  CreateBusinessService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    IdGenerationService? idService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _idService = idService ?? IdGenerationService();

  /// Create a new business with the current user as owner using atomic batch write.
  /// 
  /// Atomic operations (all succeed or all fail):
  /// 1. Create business document at /businesses/{businessId}
  ///    - ownerUid: required by Firestore rule for first-time creation
  ///    - name: business name
  ///    - createdAt: server timestamp
  /// 
  /// 2. Create owner membership at /businesses/{businessId}/members/{uid}
  ///    - role: "owner" (required by bootstrap rule)
  ///    - status: "active" (required by bootstrap rule)
  ///    - createdAt: server timestamp
  /// 
  /// 3. Update /users/{uid} with:
  ///    - businessId: newly created business
  ///    - businessName: for display (optional but useful)
  /// 
  /// Firestore Rules Reference:
  /// - /businesses/{businessId} create: isAuth && !exists && request.resource.data.ownerUid == request.auth.uid
  /// - /businesses/{businessId}/members/{uid} bootstrap create: isAuth && request.auth.uid == uid && 
  ///   exists(business) && business.ownerUid == request.auth.uid && role=="owner" && status=="active"
  /// 
  /// Returns the newly created businessId on success.
  /// Throws exception with descriptive message on failure.
  Future<String> createBusiness({
    required String businessName,
  }) async {
    print('🟡 [CreateBusinessService] createBusiness() called');
    
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to create a business');
    }
    print('🟡 [CreateBusinessService] User authenticated: ${user.uid}');

    // Determine contact info based on signup method
    final providers = _deriveProviders(user);
    final usesPhone = providers.contains('phone');
    final usesGoogle = providers.contains('google');
    final contactPhone = usesPhone ? (user.phoneNumber ?? '') : '';
    final contactEmail = usesGoogle ? (user.email ?? '') : '';

    if (businessName.trim().isEmpty) {
      throw Exception('Business name cannot be empty');
    }
    print('🟡 [CreateBusinessService] Business name valid: $businessName');

    try {
      // Step 1: Generate unique businessId
      print('🟡 [CreateBusinessService] Generating business ID...');
      final businessId = await _idService.generateBusinessId();
      if (businessId.isEmpty) {
        throw Exception('Failed to generate business ID');
      }
      print('🟡 [CreateBusinessService] Generated businessId: $businessId');

      debugPrint('📝 Creating business: $businessId');

      // Step 2: Use batch write for atomic operations
      print('🟡 [CreateBusinessService] Creating batch write object...');
      final batch = _firestore.batch();

      // ─────────────────────────────────────────────────────────────
      // BATCH OPERATION 1: Create business document
      // ─────────────────────────────────────────────────────────────
      // Rule: allow create: if isBootstrapOwner() && !exists(business)
      print('🟡 [CreateBusinessService] Adding business create operation...');
      final businessRef = _firestore.collection('businesses').doc(businessId);
      batch.set(businessRef, {
        'id': businessId,
        'name': businessName.trim(),
        'ownerUid': user.uid,  // ← CRITICAL: Must be current user
        'createdAt': FieldValue.serverTimestamp(),
        // Contact point captured from signup method
        if (contactPhone.isNotEmpty) 'contactPhone': contactPhone,
        if (contactEmail.isNotEmpty) 'contactEmail': contactEmail,
      });
      print('🟡 [CreateBusinessService] Business operation added');

      // ─────────────────────────────────────────────────────────────
      // BATCH OPERATION 2: Create owner membership
      // ─────────────────────────────────────────────────────────────
      // Rule: allow create: if isAuth()
      //   && (
      //     (request.auth.uid == uid && request.resource.data.role == "owner" && request.resource.data.status == "active")
      //     || isBusinessOwner(businessId)
      //   )
      //
      // Bootstrap path: request.auth.uid == uid AND role=="owner" AND status=="active"
      // No need to check exists(business) - atomic batch safe!
      //
      // Fields required:
      // - uid: user.uid (for the doc path)
      // - businessId: the business being created (for model deserialization)
      // - role: "owner" (CRITICAL: Rule requires "owner")
      // - status: "active" (CRITICAL: Rule requires "active")
      // - createdAt: server timestamp
      final memberRef = businessRef.collection('members').doc(user.uid);
      batch.set(memberRef, {
        'uid': user.uid,
        'businessId': businessId,  // ← REQUIRED: Model expects this field
        'role': 'owner',           // ← CRITICAL: Rule requires "owner"
        'status': 'active',        // ← CRITICAL: Rule requires "active"
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ─────────────────────────────────────────────────────────────
      // BATCH OPERATION 3: Update user document with businessId
      // ─────────────────────────────────────────────────────────────
      // Rule: allow read, write: if isAuth() && request.auth.uid == uid
      // (User can write to own document)
      //
      // Note: Using set with merge (not update) for better atomicity.
      // The user document was created by EnsureUserDocumentService, so this
      // safely updates it without requiring pre-existing fields.
      final userRef = _firestore.collection('users').doc(user.uid);
      batch.set(userRef, {
        'businessId': businessId,
        'businessName': businessName.trim(),  // Optional: for display
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));  // ← merge: true allows partial updates

      // ─────────────────────────────────────────────────────────────
      // COMMIT: All three operations succeed or all fail
      // ─────────────────────────────────────────────────────────────
      print('🔴 DEBUG: About to commit batch');
      print('🔴 DEBUG: businessId=$businessId');
      print('🔴 DEBUG: userId=${user.uid}');
      print('🔴 DEBUG: businessName=$businessName');
      
      debugPrint('💾 Committing batch write (3 operations)...');
      debugPrint('  Op 1: Create /businesses/$businessId with ownerUid=${user.uid}');
      debugPrint('  Op 2: Create /businesses/$businessId/members/${user.uid} with role=owner, status=active');
      debugPrint('  Op 3: Merge /users/${user.uid} with businessId=$businessId');
      
      try {
        await batch.commit();
        print('🟢 BATCH COMMITTED SUCCESSFULLY');
        print('📝 Batch Contents:');
        print('   - Business doc: /businesses/$businessId');
        print('   - Member doc: /businesses/$businessId/members/${user.uid}');
        print('   - User doc: /users/${user.uid}');
        debugPrint('✅ Business created successfully: $businessId');
      } catch (batchError) {
        print('🔴 BATCH FAILED: $batchError');
        print('❌ Batch Error Details: ${batchError.toString()}');
        rethrow;
      }

      return businessId;
    } on FirebaseException catch (e) {
      debugPrint('❌ Firestore error creating business: ${e.code} - ${e.message}');
      throw Exception('Firestore error creating business: ${e.message} (${e.code})');
    } catch (e) {
      debugPrint('❌ Error creating business: $e');
      throw Exception('Error creating business: $e');
    }
  }

  Set<String> _deriveProviders(User user) {
    final providers = <String>{};

    for (final info in user.providerData) {
      final pid = info.providerId;
      if (pid == 'google.com') providers.add('google');
      if (pid == 'phone') providers.add('phone');
      if (pid == 'password') providers.add('password');
    }

    if (providers.isEmpty && (user.phoneNumber?.isNotEmpty ?? false)) {
      providers.add('phone');
    }
    if (providers.isEmpty && (user.email?.isNotEmpty ?? false)) {
      providers.add('password');
    }

    if (providers.isEmpty) {
      providers.add('unknown');
    }

    return providers;
  }
}
