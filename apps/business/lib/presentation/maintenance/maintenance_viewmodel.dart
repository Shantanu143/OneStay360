// lib/presentation/maintenance/maintenance_viewmodel.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'maintenance_models.dart';
import 'maintenance_source.dart';

enum MaintenanceFilter { active, done }

/// Tenants' maintenance requests for the business: what to fix, and moving
/// each one along. Managers and staff see only their properties.
class MaintenanceViewModel extends ChangeNotifier {
  MaintenanceViewModel({
    required MaintenanceSource source,
    required this.businessId,
    required this.uid,
    required Set<String>? Function() scope,
  })  : _source = source,
        _scope = scope {
    _sub = _source.watch(businessId).listen(
      (list) {
        _all = list;
        _loaded = true;
        _loadError = null;
        _notify();
      },
      onError: (Object e) {
        debugPrint('❌ [Maintenance] $e');
        _loaded = true;
        _loadError = "Couldn't load maintenance requests.";
        _notify();
      },
    );
  }

  final MaintenanceSource _source;
  final String businessId;
  final String uid;
  final Set<String>? Function() _scope;
  late final StreamSubscription<List<MaintenanceItem>> _sub;

  List<MaintenanceItem> _all = const [];
  bool _loaded = false;
  String? _loadError;
  String? _error;
  MaintenanceFilter _filter = MaintenanceFilter.active;
  final Set<String> _busy = {};
  bool _disposed = false;

  bool get loading => !_loaded;
  String? get loadError => _loadError;
  String? get error => _error;
  MaintenanceFilter get filter => _filter;
  bool isBusy(String id) => _busy.contains(id);

  List<MaintenanceItem> get _inScope {
    final scope = _scope();
    return scope == null ? _all : _all.where((m) => scope.contains(m.propertyId)).toList();
  }

  int get activeCount => _inScope.where((m) => m.status.isActive).length;
  int get openCount => _inScope.where((m) => m.status == MaintenanceState.open).length;
  int get doneCount => _inScope.length - activeCount;

  /// Active: urgent first, then open before in progress, oldest first.
  /// Done: most recently updated first.
  List<MaintenanceItem> get visible {
    final far = DateTime(9999);
    if (_filter == MaintenanceFilter.done) {
      return _inScope.where((m) => !m.status.isActive).toList()
        ..sort((a, b) => (b.updatedAt ?? b.createdAt ?? far).compareTo(a.updatedAt ?? a.createdAt ?? far));
    }
    int rank(MaintenanceItem m) => (m.urgent ? 0 : 2) + (m.status == MaintenanceState.open ? 0 : 1);
    return _inScope.where((m) => m.status.isActive).toList()
      ..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : (a.createdAt ?? far).compareTo(b.createdAt ?? far);
      });
  }

  void setFilter(MaintenanceFilter f) {
    _filter = f;
    _notify();
  }

  Future<bool> start(MaintenanceItem m) => _update(m, MaintenanceState.inProgress);

  Future<bool> resolve(MaintenanceItem m, {String? note}) => _update(m, MaintenanceState.resolved, note: note);

  Future<bool> addNote(MaintenanceItem m, String note) => _update(m, m.status, note: note);

  Future<bool> _update(MaintenanceItem m, MaintenanceState status, {String? note}) async {
    if (_busy.contains(m.id)) return false;
    _busy.add(m.id);
    _error = null;
    _notify();
    try {
      final trimmed = note?.trim();
      await _source.update(m.id, status: status, note: trimmed == null || trimmed.isEmpty ? null : trimmed, by: uid);
      return true;
    } catch (e) {
      debugPrint('❌ [Maintenance] update: $e');
      _error = "Couldn't update the request. Try again.";
      return false;
    } finally {
      _busy.remove(m.id);
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub.cancel();
    super.dispose();
  }
}
