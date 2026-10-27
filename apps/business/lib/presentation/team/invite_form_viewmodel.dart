// lib/presentation/team/invite_form_viewmodel.dart
import 'package:flutter/foundation.dart';

import '../common/phone_format.dart';
import 'team_models.dart';

/// The invite form's name for [normalizePhoneNumber].
String? normalizeInvitePhone(String input) => normalizePhoneNumber(input);

/// What is sent to invite someone.
class InviteRequest {
  const InviteRequest({
    required this.phone,
    required this.role,
    required this.propertyIds,
    this.email,
  });

  final String phone;
  final String? email;
  final String role;
  final List<String> propertyIds;
}

/// The invite sheet's fields and what is wrong with them. Errors only appear
/// after a first attempt to send, and go away as soon as they are fixed.
class InviteFormViewModel extends ChangeNotifier {
  InviteFormViewModel({required this.properties});

  static const roles = ['manager', 'staff'];

  final List<TeamProperty> properties;

  String _phone = '';
  String _email = '';
  String _role = 'manager';
  final Set<String> _selected = {};
  bool _attempted = false;

  String get phone => _phone;
  String get email => _email;
  String get role => _role;
  Set<String> get selected => Set.unmodifiable(_selected);
  bool get allSelected => properties.isNotEmpty && _selected.length == properties.length;

  String? get phoneError {
    if (!_attempted) return null;
    if (_phone.trim().isEmpty) return 'Enter their mobile number.';
    if (normalizeInvitePhone(_phone) == null) return 'Enter a 10-digit mobile number.';
    return null;
  }

  String? get emailError {
    if (!_attempted) return null;
    final e = _email.trim();
    if (e.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) return null;
    return 'Enter a valid email, or leave it blank.';
  }

  String? get propertiesError {
    if (!_attempted) return null;
    if (properties.isEmpty) return 'Add a property first, then invite your team.';
    if (_selected.isEmpty) return 'Pick at least one property.';
    return null;
  }

  void setPhone(String v) {
    _phone = v;
    notifyListeners();
  }

  void setEmail(String v) {
    _email = v;
    notifyListeners();
  }

  void setRole(String v) {
    if (!roles.contains(v) || v == _role) return;
    _role = v;
    notifyListeners();
  }

  void toggleProperty(String id) {
    if (!_selected.remove(id)) _selected.add(id);
    notifyListeners();
  }

  void toggleAll() {
    if (allSelected) {
      _selected.clear();
    } else {
      _selected
        ..clear()
        ..addAll(properties.map((p) => p.id));
    }
    notifyListeners();
  }

  /// Shows what is wrong; true when it can be sent.
  bool validate() {
    _attempted = true;
    notifyListeners();
    return phoneError == null && emailError == null && propertiesError == null;
  }

  InviteRequest build() {
    final email = _email.trim().toLowerCase();
    return InviteRequest(
      phone: normalizeInvitePhone(_phone)!,
      email: email.isEmpty ? null : email,
      role: _role,
      propertyIds: [for (final p in properties) if (_selected.contains(p.id)) p.id],
    );
  }
}
