// lib/presentation/auth/auth_actions.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// A sign-in problem with a message fit to show as it is.
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Plain words for what Firebase Auth reports.
AuthFailure explainAuthError(FirebaseAuthException e) {
  final message = switch (e.code) {
    'invalid-email' => "That email address doesn't look right.",
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' ||
    'invalid-login-credentials' => 'Wrong email or password.',
    'email-already-in-use' =>
      'An account with this email already exists. Sign in instead.',
    'weak-password' => 'Choose a stronger password, at least 6 characters.',
    'too-many-requests' => 'Too many attempts. Try again in a few minutes.',
    'network-request-failed' =>
      'No internet connection. Check it and try again.',
    'user-disabled' => 'This account has been disabled.',
    'account-exists-with-different-credential' =>
      'This email is already registered another way. Sign in with the method you used first.',
    'operation-not-allowed' => 'This way of signing in is not turned on yet.',
    'invalid-phone-number' => "That phone number doesn't look right.",
    'invalid-verification-code' =>
      'That code is not right. Check it and try again.',
    'session-expired' ||
    'code-expired' => 'That code has expired. Ask for a new one.',
    'quota-exceeded' => 'Too many codes were requested. Try again later.',
    _ => "Couldn't sign you in. Try again.",
  };
  return AuthFailure(message, code: e.code);
}

/// What the sign-in screens ask of Firebase. Faked in tests.
abstract class AuthActions {
  Future<void> signInWithEmail(String email, String password);

  Future<void> signUpWithEmail(String email, String password);

  /// False when the person backed out of the Google sheet.
  Future<bool> signInWithGoogle();

  Future<void> sendPasswordReset(String email);
}

class FirebaseAuthActions implements AuthActions {
  FirebaseAuthActions({FirebaseAuth? auth, GoogleSignIn Function()? google})
    : _auth = auth ?? FirebaseAuth.instance,
      _google = google ?? GoogleSignIn.new;

  final FirebaseAuth _auth;
  final GoogleSignIn Function() _google;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on FirebaseAuthException catch (e) {
      throw explainAuthError(e);
    }
  }

  @override
  Future<void> signInWithEmail(String email, String password) => _guard(
    () => _auth.signInWithEmailAndPassword(email: email, password: password),
  );

  @override
  Future<void> signUpWithEmail(String email, String password) => _guard(
    () =>
        _auth.createUserWithEmailAndPassword(email: email, password: password),
  );

  @override
  Future<bool> signInWithGoogle() => _guard(() async {
    final account = await _google().signIn();
    if (account == null) return false;
    final tokens = await account.authentication;
    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(
        accessToken: tokens.accessToken,
        idToken: tokens.idToken,
      ),
    );
    return true;
  });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email));
}
