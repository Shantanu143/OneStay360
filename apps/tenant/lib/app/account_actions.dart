// lib/app/account_actions.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_services/services/auth_service.dart';

import '../services/device_token_service.dart';

/// Signing out and deleting the account. Faked in widget tests.
abstract class AccountActions {
  /// The auth gate notices and shows the login screen.
  Future<void> signOut();

  /// Anonymises the account on the server (deleteUserAccount), then signs out.
  Future<void> deleteAccount();
}

class FirebaseAccountActions implements AccountActions {
  const FirebaseAccountActions();

  @override
  Future<void> signOut() async {
    await DeviceTokenService().unregisterDeviceToken();
    await AuthService().signOut();
  }

  @override
  Future<void> deleteAccount() async {
    await FirebaseFunctions.instance.httpsCallable('deleteUserAccount').call<Object?>();
    await AuthService().signOut();
  }
}
