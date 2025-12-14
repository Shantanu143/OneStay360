// lib/presentation/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_services/services/id_generation_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;
  final IdGenerationService _idService;

  FirestoreService()
      : _firestore = FirebaseFirestore.instance,
        _idService = IdGenerationService();

  // Initialize user in Firestore with custom IDs - UPDATED WITH EXISTENCE CHECK
  Future<void> initializeUser(User user, String userType) async {
    try {
      // ✅ ADD EXISTENCE CHECK AT THE BEGINNING
      final existingUser = await getUserData(user.uid);
      if (existingUser != null && existingUser.isNotEmpty) {
        print('⚠️ User already initialized in Firestore, skipping...');
        return;
      }

      String customId;
      Map<String, dynamic> baseUserData = {
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'photoURL': user.photoURL ?? '',
        'userType': userType,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'profileComplete': false,
      };

      if (userType == 'tenant') {
        customId = await _idService.generateTenantId();

        // Create in users collection
        await _firestore.collection('users').doc(user.uid).set({
          ...baseUserData,
          'tenantId': customId,
        });

        // Create in tenants collection with custom ID
        await _firestore.collection('tenants').doc(customId).set({
          ...baseUserData,
          'tenantId': customId,
          'userId': user.uid, // Reference to users collection
        });

        print('✅ Tenant created: $customId for user: ${user.uid}');

      } else if (userType == 'business') {
        customId = await _idService.generateBusinessId();

        // Create in users collection
        await _firestore.collection('users').doc(user.uid).set({
          ...baseUserData,
          'businessId': customId,
        });

        // Create in businesses collection with custom ID
        await _firestore.collection('businesses').doc(customId).set({
          ...baseUserData,
          'businessId': customId,
          'userId': user.uid, // Reference to users collection
          'properties': [], // Initialize empty properties array
        });

        print('✅ Business created: $customId for user: ${user.uid}');
      }
    } catch (e) {
      print('❌ Error initializing user: $e');
      rethrow;
    }
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Check if user profile is complete
  Future<bool> isProfileComplete(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data()?['profileComplete'] ?? false;
    } catch (e) {
      print('Error checking profile completion: $e');
      return false;
    }
  }

  // Get business ID from user UID
  Future<String?> getBusinessId(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      String? businessId = data?['businessId'] as String?;

      // If businessId is missing on the user doc, try to recover it by
      // looking for a business document that references this user (userId).
      if ((businessId == null || businessId.isEmpty) && doc.exists) {
        try {
          final q = await _firestore
              .collection('businesses')
              .where('userId', isEqualTo: uid)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            businessId = q.docs.first.id;
            // Persist recovered businessId back to the users document for future calls
            await _firestore.collection('users').doc(uid).set({'businessId': businessId}, SetOptions(merge: true));
            print('🔧 Recovered businessId for user $uid: $businessId');
          }
        } catch (e) {
          print('Error recovering businessId for user $uid: $e');
        }
      }

      return businessId;
    } catch (e) {
      print('Error getting business ID: $e');
      return null;
    }
  }

  // Get tenant ID from user UID
  Future<String?> getTenantId(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data()?['tenantId'] as String?;
    } catch (e) {
      print('Error getting tenant ID: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String uid, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
        'profileComplete': true,
      });

      // Also update the specific collection (tenant/business)
      final userData = await getUserData(uid);
      final userType = userData?['userType'];

      String? customId;
      if (userType == 'tenant') {
        customId = userData?['tenantId'];
      } else if (userType == 'business') {
        customId = userData?['businessId'];
      }

      if (customId != null && userType != null) {
        final collection = userType == 'tenant' ? 'tenants' : 'businesses';
        await _firestore.collection(collection).doc(customId).update({
          ...updates,
          'updatedAt': FieldValue.serverTimestamp(),
          'profileComplete': true,
        });
      }
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // Generate unique username
  Future<String> generateUsername(String userType, String cityCode) async {
    try {
      String baseUsername = '${userType.toLowerCase()}_${cityCode.toLowerCase()}';
      String username = baseUsername;
      int counter = 1;

      // Check if username exists and find an available one
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      while (querySnapshot.docs.isNotEmpty) {
        username = '${baseUsername}_$counter';
        final newQuerySnapshot = await _firestore
            .collection('users')
            .where('username', isEqualTo: username)
            .get();

        if (newQuerySnapshot.docs.isEmpty) {
          break;
        }
        counter++;
      }

      return username;
    } catch (e) {
      // Fallback username with timestamp
      return '${userType.toLowerCase()}_${cityCode.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // Save user data (for profile setup)
  Future<void> saveUserData(String uid, Map<String, dynamic> userData) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        ...userData,
        'updatedAt': FieldValue.serverTimestamp(),
        'profileComplete': true,
      });

      // Also update the specific collection
      final existingUserData = await getUserData(uid);
      final userType = existingUserData?['userType'];

      String? customId;
      if (userType == 'tenant') {
        customId = existingUserData?['tenantId'];
      } else if (userType == 'business') {
        customId = existingUserData?['businessId'];
      }

      if (customId != null && userType != null) {
        final collection = userType == 'tenant' ? 'tenants' : 'businesses';
        await _firestore.collection(collection).doc(customId).update({
          ...userData,
          'updatedAt': FieldValue.serverTimestamp(),
          'profileComplete': true,
        });
      }
    } catch (e) {
      print('Error saving user data: $e');
      rethrow;
    }
  }

  // Get user identifier (tenantId or businessId)
  String? getUserIdentifier(Map<String, dynamic>? userData) {
    if (userData == null) return null;

    final userType = userData['userType'];
    if (userType == 'tenant') {
      return userData['tenantId']?.toString();
    } else if (userType == 'business') {
      return userData['businessId']?.toString();
    }
    return null;
  }

  // Check if username already exists
  Future<bool> doesUsernameExist(String username) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking username existence: $e');
      return false;
    }
  }

  // Get business data by businessId
  Future<Map<String, dynamic>?> getBusinessData(String businessId) async {
    try {
      final doc = await _firestore.collection('businesses').doc(businessId).get();
      return doc.data();
    } catch (e) {
      print('Error getting business data: $e');
      return null;
    }
  }

  // Get tenant data by tenantId
  Future<Map<String, dynamic>?> getTenantData(String tenantId) async {
    try {
      final doc = await _firestore.collection('tenants').doc(tenantId).get();
      return doc.data();
    } catch (e) {
      print('Error getting tenant data: $e');
      return null;
    }
  }

  // Get user by custom ID (tenantId or businessId)
  Future<Map<String, dynamic>?> getUserByCustomId(String customId, String userType) async {
    try {
      final collection = userType == 'tenant' ? 'tenants' : 'businesses';
      final doc = await _firestore.collection(collection).doc(customId).get();
      return doc.data();
    } catch (e) {
      print('Error getting user by custom ID: $e');
      return null;
    }
  }

  // Update specific field in user document
  Future<void> updateUserField(String uid, String field, dynamic value) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also update in specific collection
      final userData = await getUserData(uid);
      final userType = userData?['userType'];

      String? customId;
      if (userType == 'tenant') {
        customId = userData?['tenantId'];
      } else if (userType == 'business') {
        customId = userData?['businessId'];
      }

      if (customId != null && userType != null) {
        final collection = userType == 'tenant' ? 'tenants' : 'businesses';
        await _firestore.collection(collection).doc(customId).update({
          field: value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating user field: $e');
      rethrow;
    }
  }

  // Delete user data (for account deletion)
  Future<void> deleteUserData(String uid) async {
    try {
      final userData = await getUserData(uid);
      final userType = userData?['userType'];

      String? customId;
      if (userType == 'tenant') {
        customId = userData?['tenantId'];
      } else if (userType == 'business') {
        customId = userData?['businessId'];
      }

      // Delete from users collection
      await _firestore.collection('users').doc(uid).delete();

      // Delete from specific collection
      if (customId != null && userType != null) {
        final collection = userType == 'tenant' ? 'tenants' : 'businesses';
        await _firestore.collection(collection).doc(customId).delete();
      }
    } catch (e) {
      print('Error deleting user data: $e');
      rethrow;
    }
  }

  // Stream user data for real-time updates
  Stream<DocumentSnapshot> getUserDataStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  // Stream business data for real-time updates
  Stream<DocumentSnapshot> getBusinessDataStream(String businessId) {
    return _firestore.collection('businesses').doc(businessId).snapshots();
  }

  // Stream tenant data for real-time updates
  Stream<DocumentSnapshot> getTenantDataStream(String tenantId) {
    return _firestore.collection('tenants').doc(tenantId).snapshots();
  }

  // Check if email already exists
  Future<bool> doesEmailExist(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking email existence: $e');
      return false;
    }
  }

  // Get all businesses (for admin/listing purposes)
  Future<List<Map<String, dynamic>>> getAllBusinesses() async {
    try {
      final querySnapshot = await _firestore.collection('businesses').get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting all businesses: $e');
      return [];
    }
  }

  // Get all tenants (for admin/listing purposes)
  Future<List<Map<String, dynamic>>> getAllTenants() async {
    try {
      final querySnapshot = await _firestore.collection('tenants').get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting all tenants: $e');
      return [];
    }
  }

  // Generate property ID using your IdGenerationService
  Future<String> generatePropertyId(String businessId, String cityCode) async {
    return _idService.generatePropertyId(businessId, cityCode);
  }

  // Initialize counters (call this once when app starts)
  Future<void> initializeCounters() async {
    return _idService.initializeCounters();
  }
}
