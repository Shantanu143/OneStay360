// lib/presentation/property/join_viewmodel.dart
import 'package:flutter/foundation.dart';
import 'package:models/business/property/property_model.dart';

import '../../data/sources.dart';
import '../common/phone_format.dart';
import '../explore/property_facts.dart';

/// The "Request to join" form on a PG's page.
class JoinViewModel extends ChangeNotifier {
  JoinViewModel({
    required EnrollmentSource source,
    required this.property,
    required String name,
    required String phone,
    DateTime Function()? clock,
  })  : _source = source,
        _name = name,
        _phone = phone,
        _clock = clock ?? DateTime.now;

  final EnrollmentSource _source;
  final Property property;
  final DateTime Function() _clock;

  String _name;
  String _phone;
  DateTime? _moveIn;
  String? _sharing;
  String _notes = '';
  bool _attempted = false;
  bool _busy = false;
  bool _sent = false;
  String? _error;

  String get name => _name;
  String get phone => _phone;
  DateTime? get moveIn => _moveIn;
  String? get sharing => _sharing;
  String get notes => _notes;
  bool get busy => _busy;
  bool get sent => _sent;
  String? get error => _error;

  DateTime get firstMoveIn {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get lastMoveIn => DateTime(firstMoveIn.year + 1, firstMoveIn.month, firstMoveIn.day);

  /// Distinct sharing types the PG prices, cheapest first.
  List<String> get sharingOptions => {for (final o in priceOptions(property)) o.shortLabel}.toList();

  String? get nameError => _attempted && _name.trim().isEmpty ? 'Enter your name.' : null;

  String? get phoneError {
    if (!_attempted) return null;
    if (_phone.trim().isEmpty) return 'Enter your mobile number.';
    if (normalizePhoneNumber(_phone) == null) return 'Enter a 10-digit mobile number.';
    return null;
  }

  String? get moveInError => _attempted && _moveIn == null ? 'Pick a move-in date.' : null;

  void setName(String v) => _set(() => _name = v);
  void setPhone(String v) => _set(() => _phone = v);
  void setMoveIn(DateTime v) => _set(() => _moveIn = DateTime(v.year, v.month, v.day));
  void setSharing(String? v) => _set(() => _sharing = v == _sharing ? null : v);
  void setNotes(String v) => _set(() => _notes = v);

  void _set(VoidCallback change) {
    change();
    _error = null;
    notifyListeners();
  }

  Future<bool> submit() async {
    if (_busy) return false;
    _attempted = true;
    if (nameError != null || phoneError != null || moveInError != null) {
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _source.submitEnrollment(EnrollmentDraft(
        propertyId: property.id ?? '',
        businessId: property.businessId,
        propertyName: property.name,
        name: _name.trim(),
        phone: normalizePhoneNumber(_phone)!,
        moveIn: _moveIn!,
        sharing: _sharing,
        notes: _notes.trim().isEmpty ? null : _notes.trim(),
      ));
      _sent = true;
      return true;
    } on TenantFailure catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      debugPrint('❌ [Join] $e');
      _error = "Couldn't send your request. Try again.";
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
