// lib/presentation/providers/business_state_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/business_membership_service.dart';
import '../../models/business_membership_model.dart';

class BusinessStateProvider with ChangeNotifier {
  String _fullName = '';
  String _businessName = '';
  String? _businessId; // nullable: null if no active membership
  String _role = 'staff';
  int _pendingRequestsCount = 0;
  bool _profileCompleted = false;

  late final BusinessMembershipService _membershipService;
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;

  BusinessStateProvider({
    BusinessMembershipService? membershipService,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) {
    _membershipService =
        membershipService ?? BusinessMembershipService();
    _auth = auth ?? FirebaseAuth.instance;
    _firestore = firestore ?? FirebaseFirestore.instance;
  }

  String get fullName => _fullName;
  String get businessName => _businessName;
  String? get businessId => _businessId;
  String get role => _role;
  bool get hasActiveMembership => _businessId != null && _businessId!.isNotEmpty;
  int get pendingRequestsCount => _pendingRequestsCount;
  bool get profileCompleted => _profileCompleted;

  /// Load user data and validate business membership.
  /// 
  /// CRITICAL: This must ONLY be called AFTER EnsureUserDocumentService.ensureUserDocumentExists()
  /// has completed. This guarantees /users/{uid} exists before any read operations.
  /// 
  /// This is a PASSIVE method, triggered only during explicit login flow.
  /// It does NOT auto-initialize on app startup or widget creation.
  /// 
  /// MEMBERSHIP VALIDATION FLOW:
  /// 1. Load user profile from users/{uid}
  /// 2. Extract businessId from user document
  /// 3. Validate active membership via business_memberships collection
  /// 4. Only grant business access if active membership exists
  /// 5. Fallback to user doc businessId is treated as derived/informational
  ///
  /// This supports multi-member businesses in future phases.
  /// If membership validation fails, business access is blocked.
  Future<void> loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        print('🔄 [BusinessStateProvider.loadUserData] Starting for uid: ${user.uid}');
        
        // Step 1: Load user profile
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          print('❌ [BusinessStateProvider.loadUserData] User doc not found for ${user.uid}');
          _businessId = null;
          _profileCompleted = false;
          notifyListeners();
          return;
        }

        final data = userDoc.data()!;
        _fullName = data['fullName'] ?? '';
        _businessName = data['businessName'] ?? '';
        _profileCompleted = data['profileCompleted'] ?? false;
        print('✅ [BusinessStateProvider.loadUserData] User doc loaded. fullName=$_fullName, businessName=$_businessName');
        print('📋 [BusinessStateProvider.loadUserData] Full user doc data: $data');

        // Step 2: Extract businessId from user document
        // This is treated as fallback/derived information
        final derivedBusinessId = data['businessId'] as String?;
        print('🔍 [BusinessStateProvider.loadUserData] Derived businessId from user doc: $derivedBusinessId');
        
        if (derivedBusinessId == null || derivedBusinessId.isEmpty) {
          print('❌ [BusinessStateProvider.loadUserData] No businessId found in user doc');
          _businessId = null;
          notifyListeners();
          return;
        }

        // Step 3: Validate active membership with retry
        // REQUIRED: User must have explicit active membership in business_memberships
        print('🔄 [BusinessStateProvider.loadUserData] Validating membership for uid=$user.uid, businessId=$derivedBusinessId');
        BusinessMembership? membership;
        
        // Retry logic: membership document might have replication delay
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            membership = await _membershipService.getActiveMembership(
              user.uid,
              derivedBusinessId,
            );
            
            if (membership != null) {
              print('✅ [BusinessStateProvider.loadUserData] Membership found on attempt $attempt');
              break;
            } else {
              print('⏳ [BusinessStateProvider.loadUserData] Membership not found on attempt $attempt, retrying...');
              if (attempt < 3) {
                await Future.delayed(Duration(milliseconds: 500 * attempt));
              }
            }
          } catch (retryError) {
            print('⚠️  [BusinessStateProvider.loadUserData] Retry attempt $attempt failed: $retryError');
            if (attempt == 3) rethrow;
            if (attempt < 3) {
              await Future.delayed(Duration(milliseconds: 500 * attempt));
            }
          }
        }

        if (membership == null) {
          print('❌ [BusinessStateProvider.loadUserData] No active membership found after retries');
          _businessId = null;
          notifyListeners();
          return;
        }

        // Step 4: Membership validated – grant business access
        _businessId = membership.businessId;
        _role = membership.role;
        print('✅ [BusinessStateProvider.loadUserData] Active membership validated: uid=${user.uid}, businessId=$_businessId, role=${membership.role}');
      } catch (e) {
        print('❌ [BusinessStateProvider.loadUserData] Error: $e');
        _businessId = null;
        _profileCompleted = false;
      }

      notifyListeners();
    }
  }

  void updatePendingRequestsCount(int count) {
    _pendingRequestsCount = count;
    notifyListeners();
  }
}
