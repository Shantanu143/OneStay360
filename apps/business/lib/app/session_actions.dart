// lib/app/session_actions.dart
import 'package:flutter/material.dart';

/// Signing out, in the one correct order. The AuthGate reacts to the auth
/// change and shows the login screen; this only has to get pushed routes out
/// of the way.
class SessionActions {
  SessionActions({required this.deactivatePushToken, required this.signOut});

  /// Marks this device's push token inactive (needs the user still signed in).
  final Future<void> Function() deactivatePushToken;

  /// Signs out of Firebase (and Google).
  final Future<void> Function() signOut;

  Future<void> signOutAndReturnToRoot(BuildContext context) async {
    try {
      await deactivatePushToken();
    } catch (e) {
      // A failure here must never trap the user in the app.
      debugPrint('⚠️ could not deactivate push token: $e');
    }
    await signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// After the account is deleted server-side: the user is already gone, so
  /// just sign out locally and return to the root.
  Future<void> finishAccountDeletion(BuildContext context) async {
    await signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}
