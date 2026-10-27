// lib/presentation/onboarding/create_business_viewmodel.dart
import 'package:flutter/foundation.dart';

import '../../services/create_business_service.dart';

/// Creates the business and makes the signed-in user its owner.
abstract class BusinessCreator {
  /// The new business's id.
  Future<String> create(String name);
}

class FirebaseBusinessCreator implements BusinessCreator {
  FirebaseBusinessCreator({CreateBusinessService? service}) : _service = service ?? CreateBusinessService();

  final CreateBusinessService _service;

  @override
  Future<String> create(String name) => _service.createBusiness(businessName: name);
}

/// The one question a new owner is asked: what is the business called?
class CreateBusinessViewModel extends ChangeNotifier {
  CreateBusinessViewModel({required BusinessCreator creator, required Future<void> Function() reloadSession})
      : _creator = creator,
        _reload = reloadSession;

  final BusinessCreator _creator;
  final Future<void> Function() _reload;

  String _name = '';
  bool _attempted = false;
  bool _busy = false;
  String? _error;
  String? _createdId;
  bool _disposed = false;

  bool get busy => _busy;
  String? get error => _error;
  String? get createdId => _createdId;

  String get _clean => _name.trim().replaceAll(RegExp(r'\s+'), ' ');

  String? get nameError {
    if (!_attempted) return null;
    if (_clean.isEmpty) return 'Enter your business name.';
    if (_clean.length < 2) return 'Use at least 2 characters.';
    if (_clean.length > 60) return 'Keep it under 60 characters.';
    return null;
  }

  void setName(String v) {
    _name = v;
    _error = null;
    _notify();
  }

  /// True when the business was created.
  Future<bool> submit() async {
    if (_busy) return false;
    _attempted = true;
    if (nameError != null) {
      _notify();
      return false;
    }
    _busy = true;
    _error = null;
    _notify();
    try {
      _createdId = await _creator.create(_clean);
    } catch (e) {
      debugPrint('❌ [CreateBusiness] $e');
      _error = e.toString().replaceFirst('Exception: ', '');
      _busy = false;
      _notify();
      return false;
    }
    try {
      await _reload();
    } catch (e) {
      // It exists now; the session loads it the next time it tries.
      debugPrint('⚠️ [CreateBusiness] reload: $e');
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
