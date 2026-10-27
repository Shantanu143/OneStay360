// lib/presentation/auth/login_viewmodel.dart
import 'package:flutter/foundation.dart';

import 'auth_actions.dart';

/// Something to tell the person above the form.
class LoginMessage {
  const LoginMessage(this.text, {this.isError = true});

  final String text;
  final bool isError;
}

/// Email and password sign in / sign up, Google, and a forgotten password.
///
/// After a successful sign in this stays busy on purpose: the auth gate
/// notices the new user and replaces the screen.
class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required AuthActions auth}) : _auth = auth;

  final AuthActions _auth;

  bool _isSignUp = false;
  String _email = '';
  String _password = '';
  String _confirm = '';
  bool _attempted = false;
  String? _emailHint;
  bool _busy = false;
  LoginMessage? _message;
  bool _disposed = false;

  bool get isSignUp => _isSignUp;
  bool get busy => _busy;
  LoginMessage? get message => _message;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String get _cleanEmail => _email.trim().toLowerCase();

  String? get emailError {
    if (_emailHint != null) return _emailHint;
    if (!_attempted) return null;
    return _emailProblem();
  }

  String? _emailProblem() {
    if (_cleanEmail.isEmpty) return 'Enter your email.';
    if (!_emailPattern.hasMatch(_cleanEmail)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? get passwordError {
    if (!_attempted) return null;
    if (_password.isEmpty) return 'Enter your password.';
    if (_isSignUp && _password.length < 6) return 'Use at least 6 characters.';
    return null;
  }

  String? get confirmError {
    if (!_attempted || !_isSignUp) return null;
    if (_confirm.isEmpty) return 'Confirm your password.';
    if (_confirm != _password) return "The passwords don't match.";
    return null;
  }

  void setEmail(String v) {
    _email = v;
    _emailHint = null;
    _notify();
  }

  void setPassword(String v) {
    _password = v;
    _notify();
  }

  void setConfirm(String v) {
    _confirm = v;
    _notify();
  }

  void toggleMode() {
    _isSignUp = !_isSignUp;
    _attempted = false;
    _emailHint = null;
    _confirm = '';
    _message = null;
    _notify();
  }

  Future<void> submit() async {
    if (_busy) return;
    _attempted = true;
    _message = null;
    if (emailError != null || passwordError != null || confirmError != null) {
      _notify();
      return;
    }
    await _run(
      () => _isSignUp
          ? _auth.signUpWithEmail(_cleanEmail, _password)
          : _auth.signInWithEmail(_cleanEmail, _password),
    );
  }

  Future<void> google() async {
    if (_busy) return;
    _message = null;
    await _run(() async {
      final signedIn = await _auth.signInWithGoogle();
      if (!signedIn) throw const _Backed();
    });
  }

  Future<void> forgotPassword() async {
    if (_busy) return;
    final problem = _emailProblem();
    if (problem != null) {
      _emailHint = _cleanEmail.isEmpty
          ? 'Enter your email above, then tap "Forgot password?".'
          : problem;
      _notify();
      return;
    }
    _message = null;
    _busy = true;
    _notify();
    try {
      await _auth.sendPasswordReset(_cleanEmail);
      _message = LoginMessage(
        'If an account exists for $_cleanEmail, a link to reset the password is on its way.',
        isError: false,
      );
    } on AuthFailure catch (e) {
      _message = LoginMessage(e.message);
    } catch (e) {
      debugPrint('❌ [Login] reset: $e');
      _message = const LoginMessage("Couldn't send the link. Try again.");
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Runs a sign in. On success it stays busy; on failure it explains.
  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    _notify();
    try {
      await action();
    } on _Backed {
      _busy = false;
    } on AuthFailure catch (e) {
      _message = LoginMessage(e.message);
      _busy = false;
    } catch (e) {
      debugPrint('❌ [Login] $e');
      _message = const LoginMessage("Couldn't sign you in. Try again.");
      _busy = false;
    } finally {
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The person closed the Google sheet.
class _Backed implements Exception {
  const _Backed();
}
