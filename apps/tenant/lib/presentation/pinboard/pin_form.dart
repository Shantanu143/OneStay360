// lib/presentation/pinboard/pin_form.dart
import 'package:flutter/foundation.dart';

import '../../data/models.dart';
import '../../data/sources.dart';

/// Pinning a 48-hour note for everyone at the property.
class PinForm extends ChangeNotifier {
  PinForm({required PinboardSource source, required this.account, required this.propertyId}) : _source = source;

  final PinboardSource _source;
  final TenantAccount account;
  final String propertyId;

  static const maxLength = 200;

  PinCategory _category = PinCategory.social;
  String _content = '';
  bool _busy = false;
  String? _error;

  PinCategory get category => _category;
  String get content => _content;
  bool get busy => _busy;
  String? get error => _error;
  int get remaining => maxLength - _content.trim().length;

  void setCategory(PinCategory c) {
    _category = c;
    notifyListeners();
  }

  void setContent(String v) {
    _content = v;
    _error = null;
    notifyListeners();
  }

  Future<bool> submit() async {
    if (_busy) return false;
    final text = _content.trim();
    if (text.isEmpty) {
      _error = 'Write something first.';
    } else if (text.length > maxLength) {
      _error = 'Keep it under $maxLength characters.';
    }
    if (_error != null) {
      notifyListeners();
      return false;
    }
    _busy = true;
    notifyListeners();
    try {
      await _source.addPin(PinDraft(
        propertyId: propertyId,
        authorId: account.uid,
        authorName: account.name.isEmpty ? 'Resident' : account.name,
        authorPhone: account.phone,
        category: _category,
        content: text,
      ));
      return true;
    } catch (e) {
      debugPrint('❌ [Pin] $e');
      _error = "Couldn't pin your note. Try again.";
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
