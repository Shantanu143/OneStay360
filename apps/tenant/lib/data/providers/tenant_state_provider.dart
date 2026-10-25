import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TenantStateProvider with ChangeNotifier {
  String _fullName = '';
  String _email = '';
  String _phone = '';
  String _tenantId = '';
  String _currentPG = '';
  String _propertyId = '';
  String _businessId = '';
  String _roomId = '';
  String _bedId = '';
  int _unreadNotificationsCount = 0;
  Map<String, dynamic> _tenantData = {};
  bool _isDisposed = false;

  // Getters
  String get fullName => _fullName;
  String get email => _email;
  String get phone => _phone;
  String get tenantId => _tenantId;
  String get currentPG => _currentPG;
  String get propertyId => _propertyId;
  String get businessId => _businessId;
  String get roomId => _roomId;
  String get bedId => _bedId;
  int get unreadNotificationsCount => _unreadNotificationsCount;
  Map<String, dynamic> get tenantData => _tenantData;

  StreamSubscription<DocumentSnapshot>? _userSub;
  StreamSubscription<QuerySnapshot>? _tenantSub;

  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _userSub?.cancel();
    await _tenantSub?.cancel();

    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;

      final data = doc.data()!;
      _tenantId = data['tenantId'] ?? '';
      _fullName = data['fullName'] ?? data['name'] ?? '';
      _email = data['email'] ?? _email;
      _phone = data['phone'] ?? data['mobileNumber'] ?? '';
      
      notifyListeners();

      // If we have a tenantId, start listening to the global tenant document for PG details
      if (_tenantId.isNotEmpty) {
        _startTenantListener(_tenantId);
      }
    });
  }

  void _startTenantListener(String tId) {
    _tenantSub?.cancel();
    _tenantSub = FirebaseFirestore.instance
        .collection('tenants')
        .doc(tId)
        .collection('stays')
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) {
        debugPrint("⚠️ No active stay found in stays subcollection for $tId");
        bool changed = false;
        changed |= _updateField(() => _currentPG, (v) => _currentPG = v, '');
        changed |= _updateField(() => _propertyId, (v) => _propertyId = v, '');
        changed |= _updateField(() => _businessId, (v) => _businessId = v, '');
        changed |= _updateField(() => _roomId, (v) => _roomId = v, '');
        changed |= _updateField(() => _bedId, (v) => _bedId = v, '');
        if (changed) notifyListeners();
        return;
      }

      final data = snapshot.docs.first.data();
      _tenantData = data;
      bool changed = false;

      changed |= _updateField(() => _currentPG, (v) => _currentPG = v, data['propertyName'] ?? '');
      changed |= _updateField(() => _propertyId, (v) => _propertyId = v, data['propertyId'] ?? '');
      changed |= _updateField(() => _businessId, (v) => _businessId = v, data['businessId'] ?? '');
      changed |= _updateField(() => _roomId, (v) => _roomId = v, data['roomId'] ?? data['roomNumber'] ?? '');
      changed |= _updateField(() => _bedId, (v) => _bedId = v, data['bedId'] ?? data['bedNumber'] ?? '');

      if (changed) {
        debugPrint("🔄 TenantStateProvider Shared Data Updated from stays subcollection: businessId=$_businessId propertyId=$_propertyId roomId=$_roomId bedId=$_bedId");
        notifyListeners();
      }
    });
  }

  bool _updateField(String Function() getter, void Function(String) setter, String newValue) {
    if (newValue != getter()) {
      setter(newValue);
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _userSub?.cancel();
    _tenantSub?.cancel();
    super.dispose();
  }

  void updateUnreadNotificationsCount(int count) {
    if (count != _unreadNotificationsCount) {
      _unreadNotificationsCount = count;
      if (!_isDisposed) notifyListeners();
    }
  }
}
