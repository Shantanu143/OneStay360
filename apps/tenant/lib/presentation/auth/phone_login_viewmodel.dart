// lib/presentation/auth/phone_login_viewmodel.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../common/phone_format.dart';
import 'auth_actions.dart';

/// What phone sign in asks of Firebase. Faked in tests.
abstract class PhoneAuthActions {
  /// Texts a code to [phone]. Returns the id to verify it with, or null when
  /// the phone read the code itself and the person is already signed in.
  /// [onAutoSignedIn] is called if that happens after the code was sent.
  Future<String?> sendCode(
    String phone, {
    required void Function() onAutoSignedIn,
  });

  Future<void> verifyCode(String verificationId, String code);
}

class FirebasePhoneAuthActions implements PhoneAuthActions {
  FirebasePhoneAuthActions({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  int? _resendToken;

  @override
  Future<String?> sendCode(
    String phone, {
    required void Function() onAutoSignedIn,
  }) {
    final result = Completer<String?>();
    _auth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          await _auth.signInWithCredential(credential);
          if (result.isCompleted) {
            onAutoSignedIn();
          } else {
            result.complete(null);
          }
        } on FirebaseAuthException catch (e) {
          if (!result.isCompleted) result.completeError(explainAuthError(e));
        }
      },
      verificationFailed: (e) {
        if (!result.isCompleted) result.completeError(explainAuthError(e));
      },
      codeSent: (id, token) {
        _resendToken = token;
        if (!result.isCompleted) result.complete(id);
      },
      codeAutoRetrievalTimeout: (id) {
        if (!result.isCompleted) result.complete(id);
      },
    );
    return result.future;
  }

  @override
  Future<void> verifyCode(String verificationId, String code) async {
    try {
      await _auth.signInWithCredential(
        PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code,
        ),
      );
    } on FirebaseAuthException catch (e) {
      throw explainAuthError(e);
    }
  }
}

enum PhoneStep { number, code }

/// Sign in with a phone number: type it, get a code, type the code.
class PhoneLoginViewModel extends ChangeNotifier {
  PhoneLoginViewModel({
    required PhoneAuthActions actions,
    String? initialPhone,
    DateTime Function()? clock,
    this.resendAfter = const Duration(seconds: 30),
  }) : _actions = actions,
       _clock = clock ?? DateTime.now,
       _phone = initialPhone ?? '';

  final PhoneAuthActions _actions;
  final DateTime Function() _clock;
  final Duration resendAfter;

  PhoneStep _step = PhoneStep.number;
  String _phone;
  String _code = '';
  String? _verificationId;
  String? _sentTo;
  bool _busy = false;
  bool _signedIn = false;
  bool _phoneAttempted = false;
  String? _error;
  String? _codeError;
  DateTime? _resendAt;
  bool _disposed = false;

  PhoneStep get step => _step;
  String get phone => _phone;
  String get code => _code;
  bool get busy => _busy;

  /// The phone is signed in, whichever way it got there.
  bool get signedIn => _signedIn;

  /// A problem with sending, shown above the form.
  String? get error => _error;
  String? get codeError => _codeError;

  String? get phoneError {
    if (!_phoneAttempted) return null;
    if (_phone.trim().isEmpty) return 'Enter your mobile number.';
    if (normalizePhoneNumber(_phone) == null) {
      return 'Enter a 10-digit mobile number.';
    }
    return null;
  }

  String get maskedPhone =>
      maskPhone(_sentTo ?? normalizePhoneNumber(_phone) ?? _phone);

  int get secondsUntilResend {
    final at = _resendAt;
    if (at == null) return 0;
    final left = at.difference(_clock()).inMilliseconds;
    return left <= 0 ? 0 : (left / 1000).ceil();
  }

  bool get canResend =>
      _step == PhoneStep.code && !_busy && secondsUntilResend == 0;

  void setPhone(String v) {
    _phone = v;
    _error = null;
    _notify();
  }

  void setCode(String v) {
    _code = v.replaceAll(RegExp(r'\D'), '');
    if (_code.length > 6) _code = _code.substring(0, 6);
    _codeError = null;
    _notify();
  }

  void changeNumber() {
    _step = PhoneStep.number;
    _code = '';
    _codeError = null;
    _error = null;
    _notify();
  }

  Future<void> sendCode() async {
    if (_busy) return;
    _phoneAttempted = true;
    if (phoneError != null) {
      _notify();
      return;
    }
    final number = normalizePhoneNumber(_phone)!;
    _busy = true;
    _error = null;
    _notify();
    try {
      final id = await _actions.sendCode(
        number,
        onAutoSignedIn: () {
          _signedIn = true;
          _notify();
        },
      );
      if (id == null) {
        _signedIn = true;
      } else {
        _verificationId = id;
        _sentTo = number;
        _step = PhoneStep.code;
        _code = '';
        _resendAt = _clock().add(resendAfter);
      }
    } on AuthFailure catch (e) {
      _error = e.message;
    } catch (e) {
      debugPrint('❌ [PhoneLogin] send: $e');
      _error = "Couldn't send the code. Try again.";
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> resend() async {
    if (!canResend) return;
    _code = '';
    _codeError = null;
    await sendCode();
  }

  Future<void> verify() async {
    if (_busy) return;
    if (_code.length != 6) {
      _codeError = 'Enter the 6-digit code.';
      _notify();
      return;
    }
    final id = _verificationId;
    if (id == null) {
      _codeError = 'Ask for a new code first.';
      _notify();
      return;
    }
    _busy = true;
    _codeError = null;
    _notify();
    try {
      await _actions.verifyCode(id, _code);
      _signedIn = true;
    } on AuthFailure catch (e) {
      _codeError = e.message;
    } catch (e) {
      debugPrint('❌ [PhoneLogin] verify: $e');
      _codeError = "Couldn't check the code. Try again.";
    } finally {
      _busy = false;
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
