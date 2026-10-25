import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../presentation/views/view_property_screen.dart';

/// Service to handle FCM device token registration and management
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
        '🔔 FCM Permission Status: ${settings.authorizationStatus}',
      );

      // Get initial token
      final token = await _messaging.getToken();
      if (token != null) {
        await registerDeviceToken(token);
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔄 FCM Token Refreshed: $newToken');
        await registerDeviceToken(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📬 Foreground message received:');
        debugPrint('Title: ${message.notification?.title}');
        debugPrint('Body: ${message.notification?.body}');
        debugPrint('Data: ${message.data}');

        // You can show a custom notification here or update UI
        _handleNotificationMessage(message);
      });

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🔔 Notification tapped (app in background):');
        debugPrint('Data: ${message.data}');
        _handleNotificationMessage(message);
      });

      // Handle background message (needs to be a top-level function)
      // This is handled in main.dart with _firebaseMessagingBackgroundHandler

      // Handle notification tap when app is terminated
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🔔 Notification tapped (app was terminated):');
        debugPrint('Data: ${initialMessage.data}');
        _handleNotificationMessage(initialMessage);
      }

      _initialized = true;
      debugPrint('✅ FCM Service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing FCM: $e');
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
      final deviceName = 'Business App';
      final deviceModel = 'Mobile Device';

      // Call Cloud Function to register token
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
      }, SetOptions(merge: true));

      debugPrint('✅ Device token registered: $deviceToken');
    } catch (e) {
      debugPrint('❌ Error registering device token: $e');
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

        debugPrint('✅ Device token unregistered: $token');
      }
    } catch (e) {
      debugPrint('❌ Error unregistering device token: $e');
    }
  }

  /// Handle notification messages (both foreground and background)
  void _handleNotificationMessage(RemoteMessage message) {
    try {
      final data = message.data;
      final type = data['type'] ?? '';

      debugPrint('📨 Processing notification of type: $type');

      switch (type) {
        case 'enrollment_request':
          _handleEnrollmentNotification(data);
          break;
        default:
          debugPrint('Unknown notification type: $type');
      }
    } catch (e) {
      debugPrint('❌ Error handling notification: $e');
    }
  }

  /// Handle enrollment request notification
  void _handleEnrollmentNotification(Map<String, dynamic> data) {
    final requestId = data['requestId'] as String?;
    final propertyId = data['propertyId'] as String?;
    final tenantName = data['tenantName'] as String?;
    final moveInDate = data['moveInDate'] as String?;
    final propertyName = data['propertyName'] as String?;

    debugPrint('🏠 Enrollment Request Notification:');
    debugPrint('  Request ID: $requestId');
    debugPrint('  Property ID: $propertyId');
    if (propertyName != null) {
      debugPrint('  Property Name: $propertyName');
    }
    debugPrint('  Tenant: $tenantName');
    debugPrint('  Move-in: $moveInDate');

    // Navigate to enrollment requests screen
    if (propertyId != null && propertyId.isNotEmpty) {
      _navigateToPropertyRequests(propertyId);
      return;
    }

    if (requestId != null) {
      _navigateToEnrollmentRequests(requestId, propertyId);
    } else {
      debugPrint('⚠️ Missing requestId in notification payload');
    }
  }
  
  /// Navigate to enrollment requests screen
  void _navigateToEnrollmentRequests(String requestId, String? propertyId) {
    // Add a delay to ensure the app is fully ready
    Future.delayed(const Duration(milliseconds: 500), () {
      final navState = navigatorKey?.currentState;
      if (navState == null) {
        debugPrint('⚠️ Navigator state not available yet');
        return;
      }

      try {
        navState.pushNamed(
          '/enrollment-requests',
          arguments: {
            'requestId': requestId,
            'propertyId': propertyId,
          },
        );
        debugPrint('✅ Navigated to enrollment requests');
      } catch (e) {
        debugPrint('❌ Navigation error: $e');
      }
    });
  }

  void _navigateToPropertyRequests(String propertyId) {
    Future.delayed(const Duration(milliseconds: 500), () {
      final navState = navigatorKey?.currentState;
      if (navState == null) {
        debugPrint('⚠️ Navigator state not available yet');
        return;
      }

      try {
        navState.push(
          MaterialPageRoute(
            builder: (_) => ViewPropertyScreen(
              propertyId: propertyId,
              initialTabIndex: ViewPropertyScreen.requestsTabIndex,
            ),
          ),
        );
        debugPrint('✅ Navigated to property requests tab');
      } catch (e) {
        debugPrint('❌ Navigation error: $e');
      }
    });
  }
}

/// Background message handler - must be a top-level function
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Background message received: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  // Don't call DeviceTokenService here in background
  // Just log the message
}
