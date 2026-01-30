import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:models/business/business_notification_model.dart';

/// Shared backend access layer for business notifications.
class BusinessNotificationService {
  final FirebaseFirestore _firestore;

  BusinessNotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String businessId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('notifications');
  }

  Stream<List<BusinessNotification>> streamNotifications(
    String businessId, {
    int limit = 50,
  }) {
    return _collection(businessId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BusinessNotification.fromDocument(doc))
              .toList(),
        );
  }

  Future<List<BusinessNotification>> fetchNotifications(
    String businessId, {
    int limit = 50,
  }) async {
    final snapshot = await _collection(businessId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => BusinessNotification.fromDocument(doc))
        .toList();
  }

  Future<void> markAsRead({
    required String businessId,
    required String notificationId,
  }) async {
    try {
      await _collection(businessId).doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to mark notification as read: $e');
      rethrow;
    }
  }

  Future<void> markAllAsRead(String businessId) async {
    try {
      final unreadSnapshot = await _collection(businessId)
          .where('read', isEqualTo: false)
          .limit(100)
          .get();

      if (unreadSnapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();
      for (final doc in unreadSnapshot.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Failed to mark all notifications as read: $e');
      rethrow;
    }
  }
}
