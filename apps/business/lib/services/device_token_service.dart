// lib/services/device_token_service.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../app/deep_links.dart';

/// The slice of Firebase Messaging this app needs, so it can be faked.
abstract class PushGateway {
  Future<void> requestPermission();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;

  /// `data` of messages that arrive while the app is open.
  Stream<Map<String, dynamic>> get onForegroundMessage;

  /// `data` of a notification the user tapped while the app was in background.
  Stream<Map<String, dynamic>> get onOpenedFromBackground;

  /// `data` of the notification that launched the app from a terminated state.
  Future<Map<String, dynamic>?> initialMessageData();
}

class FirebasePushGateway implements PushGateway {
  FirebasePushGateway([FirebaseMessaging? messaging])
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<void> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('🔔 FCM permission: ${settings.authorizationStatus}');
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map((m) => m.data);

  @override
  Stream<Map<String, dynamic>> get onOpenedFromBackground =>
      FirebaseMessaging.onMessageOpenedApp.map((m) => m.data);

  @override
  Future<Map<String, dynamic>?> initialMessageData() async =>
      (await _messaging.getInitialMessage())?.data;
}

/// Keeps this device's FCM token registered to whoever is signed in, and turns
/// notification taps into [AppLink]s.
///
/// * Registers when a user signs in (not just at app start), on token rotation,
///   and moves the device to the new user on an account switch.
/// * [deactivateCurrentToken] must run *before* sign-out (Firestore rules need
///   the user still authenticated) so a signed-out phone stops getting pushes.
/// * Foreground messages never navigate; the in-app notification list already
///   shows them and yanking the user to another screen mid-task is hostile.
class DeviceTokenService {
  DeviceTokenService({
    required this.gateway,
    required this.authChanges,
    required this.firestore,
    required this.onLink,
  });

  final PushGateway gateway;
  final Stream<User?> authChanges;
  final FirebaseFirestore firestore;
  final void Function(AppLink link) onLink;

  final List<StreamSubscription<dynamic>> _subs = [];
  Future<void> _queue = Future.value();
  bool _started = false;
  String? _uid;
  String? _token;

  void start() {
    if (_started) return;
    _started = true;

    _subs
      ..add(authChanges.listen((user) {
        // Serialise: sign-out and sign-in events must not interleave.
        _queue = _queue.then((_) => _onAuth(user)).catchError((Object e) {
          debugPrint('❌ [DeviceTokenService] $e');
        });
      }))
      ..add(gateway.onTokenRefresh.listen(_onTokenRefresh))
      ..add(gateway.onOpenedFromBackground.listen(_open))
      ..add(gateway.onForegroundMessage.listen((data) {
        debugPrint('📬 Foreground push: ${data['type']}');
      }));

    gateway.initialMessageData().then((data) {
      if (data != null) _open(data);
    }).catchError((Object e) {
      debugPrint('❌ [DeviceTokenService] initial message: $e');
    });
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _started = false;
  }

  Future<void> _onAuth(User? user) async {
    if (user == null) {
      await deactivateCurrentToken();
      return;
    }
    if (user.uid == _uid) return;

    await deactivateCurrentToken(); // previous user, if any
    _uid = user.uid;
    try {
      await gateway.requestPermission();
      final token = await gateway.getToken();
      if (token == null) {
        _uid = null;
        return;
      }
      _token = token;
      await _register(user.uid, token);
    } catch (e) {
      debugPrint('❌ [DeviceTokenService] registering failed: $e');
      _uid = null;
      _token = null;
    }
  }

  void _onTokenRefresh(String token) {
    final uid = _uid;
    if (uid == null) return;
    _token = token;
    _register(uid, token).catchError((Object e) {
      debugPrint('❌ [DeviceTokenService] refresh failed: $e');
    });
  }

  DocumentReference<Map<String, dynamic>> _doc(String uid, String token) =>
      firestore.collection('users').doc(uid).collection('deviceTokens').doc(token);

  Future<void> _register(String uid, String token) {
    return _doc(uid, token).set({
      'token': token,
      'active': true,
      'registeredAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
      'deviceName': 'Business App',
      'deviceModel': defaultTargetPlatform.name,
    }, SetOptions(merge: true));
  }

  /// Marks this device's token inactive for the current user. Call it *before*
  /// signing out. Safe to call repeatedly or when nothing is registered.
  Future<void> deactivateCurrentToken() async {
    final uid = _uid;
    final token = _token;
    _uid = null;
    _token = null;
    if (uid == null || token == null) return;
    try {
      await _doc(uid, token).set({
        'active': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Expected when already signed out (rules deny the write).
      debugPrint('⚠️ [DeviceTokenService] could not deactivate token: $e');
    }
  }

  void _open(Map<String, dynamic> data) {
    final link = AppLink.fromPushData(data);
    if (link != null) onLink(link);
  }
}
