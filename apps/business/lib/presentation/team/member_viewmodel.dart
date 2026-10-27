// lib/presentation/team/member_viewmodel.dart
import 'package:flutter/foundation.dart';

import 'invite_form_viewmodel.dart';
import 'team_models.dart';
import 'team_source.dart';

/// One teammate's role and the properties they can open.
class MemberViewModel extends ChangeNotifier {
  MemberViewModel({
    required this.businessId,
    required this.member,
    required this.properties,
    required TeamSource source,
  })  : _source = source,
        _role = member.role;

  final String businessId;
  final TeamMember member;
  final List<TeamProperty> properties;
  final TeamSource _source;

  String _role;
  String _savedRole = '';
  Set<String> _selected = {};
  Set<String> _saved = {};
  bool _loading = false;
  bool _loaded = false;
  bool _saving = false;
  bool _disposed = false;
  String? _loadError;
  String? _error;

  String get role => _role;
  Set<String> get selected => Set.unmodifiable(_selected);
  bool get loading => _loading;
  bool get saving => _saving;
  String? get loadError => _loadError;
  String? get error => _error;

  /// Not the owner, not someone whose access is off, and only once their
  /// current access is known (saving blind could take away what they have).
  bool get canEdit => !member.isOwner && member.isActive && _loaded;

  bool get isDirty => _role != _savedRole || !setEquals(_selected, _saved);

  Future<void> load() async {
    _loading = true;
    _loadError = null;
    _notify();
    try {
      final all = await _source.loadAccess(businessId, properties);
      _selected = {...?all[member.uid]};
      _saved = {..._selected};
      _savedRole = _role;
      _loaded = true;
    } catch (e) {
      debugPrint('❌ [Member] access: $e');
      _loadError = "Couldn't load their access.";
    } finally {
      _loading = false;
      _notify();
    }
  }

  void setRole(String v) {
    if (!canEdit || !InviteFormViewModel.roles.contains(v) || v == _role) return;
    _role = v;
    _notify();
  }

  void toggleProperty(String id) {
    if (!canEdit) return;
    if (!_selected.remove(id)) _selected.add(id);
    _notify();
  }

  /// True when saved (or there was nothing to save).
  Future<bool> save() async {
    if (!canEdit) return false;
    if (!isDirty) return true;
    _saving = true;
    _error = null;
    _notify();
    try {
      await _source.updateAccess(
        businessId: businessId,
        memberUid: member.uid,
        role: _role,
        propertyIds: [for (final p in properties) if (_selected.contains(p.id)) p.id],
      );
      _saved = {..._selected};
      _savedRole = _role;
      return true;
    } on TeamException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      debugPrint('❌ [Member] save: $e');
      _error = "Couldn't save their access. Try again.";
      return false;
    } finally {
      _saving = false;
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
