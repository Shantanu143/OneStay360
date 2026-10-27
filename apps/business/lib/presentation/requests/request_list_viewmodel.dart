// lib/presentation/requests/request_list_viewmodel.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'request_models.dart';
import 'request_source.dart';

enum RequestFilter {
  needsYou('Needs you'),
  waiting('Waiting'),
  done('Done'),
  all('All');

  const RequestFilter(this.label);

  final String label;

  bool matches(RequestStage stage) {
    switch (this) {
      case needsYou:
        return stage.needsOwner;
      case waiting:
        return stage == RequestStage.billSent || stage == RequestStage.approved;
      case done:
        return stage == RequestStage.confirmed || stage == RequestStage.rejected;
      case all:
        return true;
    }
  }
}

class RequestListViewModel extends ChangeNotifier {
  RequestListViewModel({
    required RequestListSource source,
    required this.businessId,
    this.propertyId,
    Set<String>? Function()? propertyScope,
  }) : _source = source,
       _propertyScope = propertyScope;

  /// The ids of the properties this person can open; null means all (owner).
  final Set<String>? Function()? _propertyScope;

  final RequestListSource _source;
  final String businessId;

  /// Only this property's requests, when set.
  final String? propertyId;
  bool _disposed = false;

  List<EnrollmentRequest> _all = const [];
  bool _loading = true;
  String? _error;
  RequestFilter _filter = RequestFilter.all;
  bool _filterChosen = false;
  StreamSubscription<List<EnrollmentRequest>>? _sub;

  bool get loading => _loading;
  String? get error => _error;
  RequestFilter get filter => _filter;

  List<EnrollmentRequest> get _scoped {
    final scope = _propertyScope?.call();
    return [
      for (final r in _all)
        if ((propertyId == null || r.propertyId == propertyId) && (scope == null || scope.contains(r.propertyId))) r,
    ];
  }

  int count(RequestFilter f) => _scoped.where((r) => f.matches(r.stage)).length;

  /// The requests under the current filter, newest first.
  List<EnrollmentRequest> get visible {
    final list = [for (final r in _scoped) if (_filter.matches(r.stage)) r]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  void start() {
    if (_sub != null) return;
    _sub = _source.watchAll(businessId).listen(
      (list) {
        _all = list;
        _loading = false;
        _error = null;
        if (!_filterChosen) {
          // The first look: what needs the owner, or everything if nothing does.
          _filter = count(RequestFilter.needsYou) > 0 ? RequestFilter.needsYou : RequestFilter.all;
          _filterChosen = true;
        }
        _notify();
      },
      onError: (Object e) {
        debugPrint('❌ [Requests] list: $e');
        _loading = false;
        _error = "Couldn't load requests.";
        _notify();
      },
    );
  }

  void retry() {
    _sub?.cancel();
    _sub = null;
    _error = null;
    _loading = true;
    _notify();
    start();
  }

  void setFilter(RequestFilter f) {
    _filter = f;
    _filterChosen = true;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
