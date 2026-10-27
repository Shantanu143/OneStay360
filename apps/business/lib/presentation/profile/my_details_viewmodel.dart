// lib/presentation/profile/my_details_viewmodel.dart
import 'package:flutter/foundation.dart';

import '../common/phone_format.dart';
import 'my_details_source.dart';

/// "Edit my details": name (required), email and phone (optional).
class MyDetailsViewModel extends ChangeNotifier {
  MyDetailsViewModel({
    required MyDetailsSource source,
    required this.businessId,
    required this.uid,
    String name = '',
    String email = '',
    String phone = '',
    Future<void> Function()? reloadSession,
  })  : _source = source,
        _reload = reloadSession,
        _name = name,
        _email = email,
        _phone = phone,
        _initial = (_tidy(name), email.trim().toLowerCase(), phone.trim());

  final MyDetailsSource _source;
  final Future<void> Function()? _reload;
  final String businessId;
  final String uid;
  final (String, String, String) _initial;

  String _name;
  String _email;
  String _phone;
  bool _attempted = false;
  bool _busy = false;
  String? _error;
  bool _disposed = false;

  static String _tidy(String v) => v.trim().replaceAll(RegExp(r'\s+'), ' ');
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String get name => _name;
  bool get busy => _busy;
  String? get error => _error;

  bool get isDirty => (_tidy(_name), _email.trim().toLowerCase(), _phone.trim()) != _initial;

  String? get nameError {
    if (!_attempted) return null;
    final n = _tidy(_name);
    if (n.isEmpty) return 'Enter your name.';
    if (n.length < 2) return 'Use at least 2 characters.';
    return null;
  }

  String? get emailError {
    if (!_attempted) return null;
    final e = _email.trim();
    return e.isEmpty || _emailPattern.hasMatch(e) ? null : 'Enter a valid email, or leave it blank.';
  }

  String? get phoneError {
    if (!_attempted) return null;
    final p = _phone.trim();
    return p.isEmpty || normalizePhoneNumber(p) != null ? null : 'Enter a 10-digit mobile number, or leave it blank.';
  }

  void setName(String v) {
    _name = v;
    _error = null;
    _notify();
  }

  void setEmail(String v) {
    _email = v;
    _error = null;
    _notify();
  }

  void setPhone(String v) {
    _phone = v;
    _error = null;
    _notify();
  }

  /// True when saved.
  Future<bool> submit() async {
    if (_busy) return false;
    _attempted = true;
    if (nameError != null || emailError != null || phoneError != null) {
      _notify();
      return false;
    }
    _busy = true;
    _error = null;
    _notify();
    try {
      final email = _email.trim().toLowerCase();
      final phone = _phone.trim();
      await _source.save(
        businessId: businessId,
        uid: uid,
        name: _tidy(_name),
        email: email.isEmpty ? null : email,
        phone: phone.isEmpty ? null : normalizePhoneNumber(phone),
      );
    } catch (e) {
      debugPrint('❌ [MyDetails] $e');
      _error = "Couldn't save your details. Try again.";
      _busy = false;
      _notify();
      return false;
    }
    try {
      await _reload?.call();
    } catch (e) {
      // Saved; the greeting catches up the next time the session reloads.
      debugPrint('⚠️ [MyDetails] reload: $e');
    }
    _busy = false;
    _notify();
    return true;
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
