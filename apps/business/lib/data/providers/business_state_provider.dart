// lib/data/providers/business_state_provider.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/business_membership_service.dart';
import '../../models/business_membership_model.dart';

/// Where the signed-in user's business session stands.
enum SessionStatus {
  /// Nothing loaded (signed out, or not started).
  idle,

  /// Reading the user profile and validating membership.
  loading,

  /// Active membership validated: [BusinessStateProvider.businessId] is set.
  ready,

  /// Signed in, but belongs to no business yet (create or join one).
  noBusiness,

  /// The owner turned this person's access off (or removed them). Distinct
  /// from [noBusiness]: they do belong to a business, and are told which.
  accessOff,

  /// Loading failed (offline, permission, App Check...). Distinct from
  /// [noBusiness]: the user may well have a business we couldn't read.
  error,
}

/// The ids of the properties [uid] can open in [businessId], or null for all
/// of them. Only asked for people who are not the owner.
typedef PropertyScopeLoader = Future<Set<String>?> Function(String businessId, String uid, String role);

class BusinessStateProvider with ChangeNotifier {
  String _fullName = '';
  String _businessName = '';
  String? _businessId; // nullable: null if no active membership
  String _role = 'staff';
  int _pendingRequestsCount = 0;
  bool _profileCompleted = false;
  SessionStatus _status = SessionStatus.idle;
  String? _loadError;
  Future<void>? _inflight;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _requestsSub;
  String? _watchedBusinessId;
  StreamSubscription<BusinessMembership?>? _membershipSub;
  Set<String>? _propertyScope;
  PropertyScopeLoader? _scopeLoader;

  late final BusinessMembershipService _membershipService;
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;

  /// Memberships can lag the user document by a moment right after sign-up or
  /// accepting an invite, so a missing membership is retried (500ms, 1s).
  final Duration _retryUnit;

  BusinessStateProvider({
    BusinessMembershipService? membershipService,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    Duration membershipRetryDelay = const Duration(milliseconds: 500),
    PropertyScopeLoader? propertyScopeLoader,
  }) : _retryUnit = membershipRetryDelay,
       _scopeLoader = propertyScopeLoader {
    _membershipService = membershipService ?? BusinessMembershipService();
    _auth = auth ?? FirebaseAuth.instance;
    _firestore = firestore ?? FirebaseFirestore.instance;
  }

  String get fullName => _fullName;
  String get businessName => _businessName;
  String? get businessId => _businessId;
  String get role => _role;

  /// The ids of the properties this person can open, or null when that is all
  /// of them (the owner). Never null for anyone else: until it is read it is
  /// empty, so nothing shows that should not.
  Set<String>? get propertyScope => _propertyScope == null ? null : Set.unmodifiable(_propertyScope!);

  bool canOpenProperty(String? propertyId) =>
      _propertyScope == null || (propertyId != null && _propertyScope!.contains(propertyId));
  bool get hasActiveMembership => _businessId != null && _businessId!.isNotEmpty;
  int get pendingRequestsCount => _pendingRequestsCount;
  bool get profileCompleted => _profileCompleted;
  SessionStatus get status => _status;
  String? get loadError => _loadError;
  bool get isReady => _status == SessionStatus.ready;

  /// Load the user profile and validate business membership.
  ///
  /// MUST run after `EnsureUserDocumentService.ensureUserDocumentExists()` so
  /// `/users/{uid}` exists. Concurrent calls share one request.
  ///
  /// A *failed* load leaves any previously loaded business in place and moves
  /// to [SessionStatus.error]; only a successful read that finds no membership
  /// moves to [SessionStatus.noBusiness].
  Future<void> loadUserData() {
    return _inflight ??= _load().whenComplete(() => _inflight = null);
  }

  Future<void> _load() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _setStatus(SessionStatus.loading);

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        _businessId = null;
        _profileCompleted = false;
        _setStatus(SessionStatus.noBusiness);
        return;
      }

      final data = userDoc.data()!;
      _fullName = data['fullName'] ?? '';
      _businessName = data['businessName'] ?? '';
      _profileCompleted = data['profileCompleted'] ?? false;

      final derivedBusinessId = data['businessId'] as String?;
      if (derivedBusinessId == null || derivedBusinessId.isEmpty) {
        _businessId = null;
        _setStatus(SessionStatus.noBusiness);
        return;
      }

      BusinessMembership? membership;
      for (var attempt = 1; attempt <= 3; attempt++) {
        membership = await _membershipService.getActiveMembership(
          user.uid,
          derivedBusinessId,
        );
        if (membership != null) break;
        // A membership that exists but is switched off will not appear by
        // waiting: say so now instead of retrying.
        if (await _isSwitchedOff(derivedBusinessId, user.uid)) {
          _businessId = null;
          _stopWatchingMembership();
          _setStatus(SessionStatus.accessOff);
          return;
        }
        if (attempt < 3) await Future.delayed(_retryUnit * attempt);
      }

      if (membership == null) {
        _businessId = null;
        _setStatus(SessionStatus.noBusiness);
        return;
      }

      _businessId = membership.businessId;
      _role = membership.role;
      if (_role == 'owner') {
        _propertyScope = null;
      } else {
        // Fail closed: nothing is shown until the access list has been read.
        _propertyScope = {};
        final loader = _scopeLoader ?? _loadScopeFromFirestore;
        _propertyScope = await loader(membership.businessId, user.uid, _role);
      }
      _watchPendingRequests(membership.businessId);
      _watchMembership(membership.businessId, user.uid);
      _setStatus(SessionStatus.ready);
    } catch (e) {
      debugPrint('❌ [BusinessStateProvider.loadUserData] $e');
      _loadError = _describe(e);
      _setStatus(SessionStatus.error, keepError: true);
    }
  }

  /// Reads which properties [uid] was given: the business's properties are
  /// readable by any member, and each has an `access/{uid}` doc if they can
  /// open it.
  Future<Set<String>?> _loadScopeFromFirestore(String businessId, String uid, String role) async {
    final properties = await _firestore.collection('businesses').doc(businessId).collection('properties').get();
    final grants = await Future.wait([for (final p in properties.docs) p.reference.collection('access').doc(uid).get()]);
    return {
      for (var i = 0; i < properties.docs.length; i++)
        if (grants[i].exists) properties.docs[i].id,
    };
  }

  Future<bool> _isSwitchedOff(String businessId, String uid) async {
    try {
      final doc = await _firestore.collection('businesses').doc(businessId).collection('members').doc(uid).get();
      final status = doc.data()?['status'];
      return doc.exists && status != null && status != 'active';
    } catch (_) {
      return false;
    }
  }

  /// If the owner turns this person's access off while they are working, say
  /// so at once rather than at the next launch.
  void _watchMembership(String businessId, String uid) {
    _stopWatchingMembership();
    try {
      _membershipSub = _membershipService.streamActiveMembership(uid, businessId).listen(
        (m) {
          if (m == null && _status == SessionStatus.ready) {
            _setStatus(SessionStatus.accessOff);
          }
        },
        onError: (Object e) => debugPrint('⚠️ membership listener: $e'),
      );
    } catch (e) {
      debugPrint('⚠️ could not watch membership: $e');
    }
  }

  void _stopWatchingMembership() {
    _membershipSub?.cancel();
    _membershipSub = null;
  }

  /// Keeps [pendingRequestsCount] live for the business. Started once per
  /// business, however many times the profile is reloaded.
  void _watchPendingRequests(String businessId) {
    if (_watchedBusinessId == businessId) return;
    _stopWatchingRequests();
    _watchedBusinessId = businessId;
    _requestsSub = _firestore
        .collection('enrollmentRequests')
        .where('businessId', isEqualTo: businessId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(
          (snapshot) => updatePendingRequestsCount(
            snapshot.docs.where((d) => canOpenProperty(d.data()['propertyId'] as String?)).length,
          ),
          onError: (Object e) => debugPrint('⚠️ pending requests listener: $e'),
        );
  }

  void _stopWatchingRequests() {
    _requestsSub?.cancel();
    _requestsSub = null;
    _watchedBusinessId = null;
  }

  void _setStatus(SessionStatus status, {bool keepError = false}) {
    _status = status;
    if (!keepError) _loadError = null;
    notifyListeners();
  }

  static String _describe(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return "We couldn't verify your access. Check your connection and try again.";
        case 'unavailable':
          return "You appear to be offline. Check your connection and try again.";
      }
    }
    return "We couldn't load your business. Try again in a moment.";
  }

  /// Forget everything (sign-out / account switch).
  void reset() {
    _stopWatchingRequests();
    _stopWatchingMembership();
    _fullName = '';
    _businessName = '';
    _businessId = null;
    _role = 'staff';
    _propertyScope = null;
    _pendingRequestsCount = 0;
    _profileCompleted = false;
    _loadError = null;
    _status = SessionStatus.idle;
    _inflight = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopWatchingRequests();
    _stopWatchingMembership();
    super.dispose();
  }

  void updatePendingRequestsCount(int count) {
    if (_pendingRequestsCount == count) return;
    _pendingRequestsCount = count;
    notifyListeners();
  }
}
