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

  StreamSubscription<DocumentSnapshot>? _sub;

  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _sub?.cancel();

    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;

      final data = doc.data()!;
      final updated = _applyUserData(data);

      if (updated) {
        debugPrint("🔄 TenantStateProvider Updated: businessId=$_businessId propertyId=$_propertyId roomId=$_roomId bedId=$_bedId");
        notifyListeners();
      }
    });
  }

  bool _applyUserData(Map<String, dynamic> data) {
    bool changed = false;

    changed |= _updateField(() => _fullName, (v) => _fullName = v, data['fullName'] ?? data['name'] ?? '');
    changed |= _updateField(() => _email, (v) => _email = v, data['email'] ?? _email);
    changed |= _updateField(() => _phone, (v) => _phone = v, data['phone'] ?? data['mobileNumber'] ?? '');
    changed |= _updateField(() => _tenantId, (v) => _tenantId = v, data['tenantId'] ?? '');
    changed |= _updateField(() => _currentPG, (v) => _currentPG = v, data['currentPG'] ?? '');
    changed |= _updateField(() => _propertyId, (v) => _propertyId = v, data['propertyId'] ?? '');
    changed |= _updateField(() => _businessId, (v) => _businessId = v, data['businessId'] ?? '');
    changed |= _updateField(() => _roomId, (v) => _roomId = v, data['roomId'] ?? '');
    changed |= _updateField(() => _bedId, (v) => _bedId = v, data['bedId'] ?? '');

    return changed;
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
    _sub?.cancel();
    super.dispose();
  }

  void updateUnreadNotificationsCount(int count) {
    if (count != _unreadNotificationsCount) {
      _unreadNotificationsCount = count;
      notifyListeners();
    }
  }
}
