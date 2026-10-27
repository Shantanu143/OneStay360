// lib/services/device_token_service.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Registers this device for push notifications (`users/{uid}/deviceTokens`)
/// and hands notification taps and foreground messages to the app.
class DeviceTokenService {
  DeviceTokenService._();

  static final DeviceTokenService _instance = DeviceTokenService._();

  factory DeviceTokenService() => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  /// The data payload of a notification the person tapped.
  void Function(Map<String, dynamic> data)? onOpened;

  /// A notification that arrived while the app was open.
  void Function(String title, String body, Map<String, dynamic> data)? onForeground;

  /// Taps that arrived before the app was ready to route them.
  Map<String, dynamic>? _pendingTap;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      _messaging.onTokenRefresh.listen(registerDeviceToken);
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) onForeground?.call(n.title ?? 'OneStay360', n.body ?? '', m.data);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _opened(m.data));
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _opened(initial.data);
    } catch (e) {
      debugPrint('❌ [Push] init: $e');
    }
  }

  void _opened(Map<String, dynamic> data) {
    final handler = onOpened;
    if (handler == null) {
      _pendingTap = data;
    } else {
      handler(data);
    }
  }

  /// Delivers a tap that came in before [onOpened] was set.
  void flushPending() {
    final data = _pendingTap;
    _pendingTap = null;
    if (data != null) onOpened?.call(data);
  }

  /// Saves this device's token for the signed-in user.
  Future<void> registerCurrentToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await registerDeviceToken(token);
    } catch (e) {
      debugPrint('⚠️ [Push] token: $e');
    }
  }

  Future<void> registerDeviceToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.doc('users/${user.uid}/deviceTokens/$token').set({
        'token': token,
        'active': true,
        'registeredAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'deviceName': 'Tenant App',
        'platform': defaultTargetPlatform.name,
        'appType': 'tenant',
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ [Push] register: $e');
    }
  }

  /// Stops pushes to this device for the user signing out.
  Future<void> unregisterDeviceToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance.doc('users/${user.uid}/deviceTokens/$token').set({
        'active': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ [Push] unregister: $e');
    }
  }
}
