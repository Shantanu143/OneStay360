// lib/presentation/home/activity_feed.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models.dart';
import '../../data/sources.dart';
import '../../data/tenant_session.dart';

/// The tenant's moving parts outside the stay itself: requests to join a PG,
/// owners' invitations, and maintenance requests. Follows the signed-in user.
class ActivityFeed extends ChangeNotifier {
  ActivityFeed({required TenantSession session, required TenantBackend backend, DateTime Function()? clock})
      : _session = session,
        _backend = backend,
        _clock = clock ?? DateTime.now {
    _session.addListener(_follow);
    _follow();
  }

  final TenantSession _session;
  final TenantBackend _backend;
  final DateTime Function() _clock;

  String? _uid;
  List<EnrollmentRequest> _requests = const [];
  List<PendingInvitation> _invitations = const [];
  List<MaintenanceRequest> _maintenance = const [];
  bool _requestsLoaded = false;
  bool _disposed = false;
  final _subs = <StreamSubscription<Object?>>[];

  List<EnrollmentRequest> get requests => _requests;
  List<PendingInvitation> get invitations => _invitations;
  List<MaintenanceRequest> get maintenance => _maintenance;
  bool get requestsLoaded => _requestsLoaded;

  List<MaintenanceRequest> get activeMaintenance => _maintenance.where((m) => m.status.isActive).toList();

  /// The newest request still moving.
  EnrollmentRequest? get activeRequest => _requests.where((r) => r.stage.isOpen).firstOrNull;

  /// The newest request, if the owner turned it down in the last two weeks
  /// and nothing else is open.
  EnrollmentRequest? get recentRejection {
    if (activeRequest != null) return null;
    final newest = _requests.firstOrNull;
    if (newest == null || newest.stage != EnrollmentStage.rejected) return null;
    final at = newest.createdAt;
    if (at == null || _clock().difference(at) > const Duration(days: 14)) return null;
    return newest;
  }

  bool hasPendingRequestFor(String propertyId) =>
      _requests.any((r) => r.propertyId == propertyId && r.stage.isOpen);

  Future<void> refreshInvitations() async {
    if (_uid == null) return;
    try {
      _invitations = await _backend.listInvitations();
    } catch (e) {
      debugPrint('⚠️ [Activity] invitations: $e');
      _invitations = const [];
    }
    _notify();
  }

  void _follow() {
    final uid = _session.uid;
    if (uid == _uid) return;
    _uid = uid;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _requests = const [];
    _invitations = const [];
    _maintenance = const [];
    _requestsLoaded = false;
    if (uid != null) {
      void onError(Object e) => debugPrint('⚠️ [Activity] $e');
      _subs
        ..add(_backend.watchMyRequests(uid).listen((list) {
          _requests = list;
          _requestsLoaded = true;
          _notify();
        }, onError: onError))
        ..add(_backend.watchMyMaintenance(uid).listen((list) {
          _maintenance = list;
          _notify();
        }, onError: onError));
      refreshInvitations();
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _session.removeListener(_follow);
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
