// lib/presentation/providers/business_state_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessStateProvider with ChangeNotifier {
  String _fullName = '';
  String _businessName = '';
  String _businessId = '';
  int _pendingRequestsCount = 0;

  String get fullName => _fullName;
  String get businessName => _businessName;
  String get businessId => _businessId;
  int get pendingRequestsCount => _pendingRequestsCount;

  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        _fullName = data['fullName'] ?? '';
        _businessName = data['businessName'] ?? '';
        _businessId = data['businessId'] ?? user.uid; // Get business ID from user doc, fallback to UID
        notifyListeners();
      }
    }
  }

  void updatePendingRequestsCount(int count) {
    _pendingRequestsCount = count;
    notifyListeners();
  }
}