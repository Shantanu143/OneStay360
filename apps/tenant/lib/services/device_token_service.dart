import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Service to handle FCM device token registration and management for tenant app
class DeviceTokenService {
  static final DeviceTokenService _instance = DeviceTokenService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _initialized = false;

  // Navigation key for accessing navigator from service
  static GlobalKey<NavigatorState>? navigatorKey;

  DeviceTokenService._internal();

  factory DeviceTokenService() {
    return _instance;
  }

  /// Initialize FCM and register device token
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request notification permissions (iOS)
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
        '🔔 FCM Permission Status (Tenant): ${settings.authorizationStatus}',
      );

      // Get initial token
      final token = await _messaging.getToken();
      if (token != null) {
        await registerDeviceToken(token);
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔄 FCM Token Refreshed (Tenant): $newToken');
        await registerDeviceToken(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📬 Foreground message received (Tenant):');
        debugPrint('Title: ${message.notification?.title}');
        debugPrint('Body: ${message.notification?.body}');
        debugPrint('Data: ${message.data}');

        _handleNotificationMessage(message);
      });

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🔔 Notification tapped (app in background):');
        debugPrint('Data: ${message.data}');
        _handleNotificationMessage(message);
      });

      // Handle notification tap when app is terminated
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🔔 Notification tapped (app was terminated):');
        debugPrint('Data: ${initialMessage.data}');
        _handleNotificationMessage(initialMessage);
      }

      _initialized = true;
      debugPrint('✅ FCM Service initialized (Tenant)');
    } catch (e) {
      debugPrint('❌ Error initializing FCM (Tenant): $e');
    }
  }

  /// Register device token with Firestore
  Future<void> registerDeviceToken(String deviceToken) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ User not authenticated, skipping token registration');
        return;
      }

      // Get device info
      const deviceName = 'Tenant App';
      const deviceModel = 'Mobile Device';

      // Register token under users collection
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('deviceTokens')
          .doc(deviceToken)
          .set({
            'token': deviceToken,
            'active': true,
            'registeredAt': FieldValue.serverTimestamp(),
            'lastSeenAt': FieldValue.serverTimestamp(),
            'deviceName': deviceName,
            'deviceModel': deviceModel,
            'appType': 'tenant', // Identify this is from tenant app
          }, SetOptions(merge: true));

      debugPrint('✅ Device token registered (Tenant): $deviceToken');
    } catch (e) {
      debugPrint('❌ Error registering device token (Tenant): $e');
    }
  }

  /// Unregister device token (call on logout)
  Future<void> unregisterDeviceToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('deviceTokens')
            .doc(token)
            .update({
              'active': false,
              'deactivatedAt': FieldValue.serverTimestamp(),
            });

        debugPrint('✅ Device token unregistered (Tenant): $token');
      }
    } catch (e) {
      debugPrint('❌ Error unregistering device token (Tenant): $e');
    }
  }

  /// Handle notification messages (both foreground and background)
  void _handleNotificationMessage(RemoteMessage message) {
    try {
      final data = message.data;
      final type = data['type'] ?? '';

      debugPrint('📨 Processing notification of type: $type');

      // Handle different notification types
      switch (type) {
        case 'bill_sent':
          _handleBillSentNotification(data);
          break;
        case 'enrollment_approved':
          _handleEnrollmentApprovedNotification(data);
          break;
        case 'enrollment_rejected':
          _handleEnrollmentRejectedNotification(data);
          break;
        default:
          debugPrint('Unknown notification type: $type');
      }
    } catch (e) {
      debugPrint('Error handling notification: $e');
    }
  }

  void _handleBillSentNotification(Map<String, dynamic> data) {
    debugPrint('📝 Bill sent notification:');
    debugPrint('  Request ID: ${data['requestId']}');
    debugPrint('  Property: ${data['propertyName']}');
    debugPrint('  Amount: ${data['totalAmount']}');

    // Navigate to bill payment screen if navigator key is available
    if (navigatorKey?.currentState != null) {
      // TODO: Navigate to enrollment payment screen
      debugPrint('🚀 Would navigate to payment screen');
    }
  }

  void _handleEnrollmentApprovedNotification(Map<String, dynamic> data) {
    debugPrint('✅ Enrollment approved notification:');
    debugPrint('  Request ID: ${data['requestId']}');
    debugPrint('  Property: ${data['propertyName']}');
  }

  void _handleEnrollmentRejectedNotification(Map<String, dynamic> data) {
    debugPrint('❌ Enrollment rejected notification:');
    debugPrint('  Request ID: ${data['requestId']}');
    debugPrint('  Property: ${data['propertyName']}');
  }

  /// Update last seen timestamp
  Future<void> updateLastSeen() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('deviceTokens')
            .doc(token)
            .update({'lastSeenAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      // Silently fail
    }
  }
}
