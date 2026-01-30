import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Ensures /users/{uid} document exists immediately after authentication.
///
/// On first login, this creates the user document with:
/// - uid
/// - createdAt (server timestamp)
/// - businessId: null
/// - authProviders: derived from current auth session (e.g., ["google"], ["phone"], ["google","phone"])
/// - profileCompleted: false
///
/// On subsequent logins, it merges in any newly-seen auth providers and backfills profileCompleted if missing.
/// This NEVER creates a business or membership.
/// Call this BEFORE BusinessStateProvider.loadUserData()
class EnsureUserDocumentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Ensures the user document exists. If it doesn't, creates it.
  /// Returns true if document was created, false if it already existed.
  Future<bool> ensureUserDocumentExists(User user) async {
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await userRef.get();

      final derivedProviders = _deriveProviders(user);

      if (docSnapshot.exists) {
        final data = docSnapshot.data() ?? {};
        final existing = (data['authProviders'] as List?)?.cast<String>() ?? <String>[];
        final merged = {...existing, ...derivedProviders}.toList();

        final updates = <String, dynamic>{};
        if (merged.toSet().difference(existing.toSet()).isNotEmpty) {
          updates['authProviders'] = merged;
        }
        if (!data.containsKey('profileCompleted')) {
          updates['profileCompleted'] = false;
        }

        if (updates.isNotEmpty) {
          await userRef.set(updates, SetOptions(merge: true));
        }

        print('✅ User document already exists: ${user.uid}');
        return false;
      }

      // Document doesn't exist - create it
      await userRef.set({
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'businessId': null,
        'authProviders': derivedProviders.toList(),
        'profileCompleted': false,
        // No userType, no business creation, no memberships
      });

      print('✅ User document created: ${user.uid}');
      return true;
    } catch (e) {
      print('❌ Error ensuring user document: $e');
      rethrow;
    }
  }

  /// Derive a normalized list of auth providers from the current user session.
  Set<String> _deriveProviders(User user) {
    final providers = <String>{};

    // Prefer providerData for accurate mapping; fall back to providerId if empty.
    if (user.providerData.isNotEmpty) {
      for (final info in user.providerData) {
        final pid = info.providerId;
        if (pid == 'google.com') providers.add('google');
        if (pid == 'phone') providers.add('phone');
        if (pid == 'password') providers.add('password');
      }
    }

    // Fallbacks when providerData is empty (can happen on some phone flows)
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
