// lib/data/tenant_session.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'sources.dart';

enum SessionPhase { idle, loading, ready }

/// The signed-in tenant: their account, their current stay (if any) and the
/// unread notification count, kept live from Firestore.
///
/// The auth gate calls [start] for a signed-in user and [reset] on sign out.
class TenantSession extends ChangeNotifier {
  TenantSession({required SessionSource source}) : _source = source;

  final SessionSource _source;

  String? _uid;
  TenantAccount? _account;
  bool _accountLoaded = false;
  String? _stayFor;
  Stay? _stay;
  bool _stayLoaded = false;
  int _unread = 0;
  Object? _error;
  bool _disposed = false;

  StreamSubscription<TenantAccount?>? _accountSub;
  StreamSubscription<Stay?>? _staySub;
  StreamSubscription<int>? _unreadSub;

  String? get uid => _uid;
  TenantAccount? get account => _account;
  Stay? get stay => _stay;
  int get unread => _unread;
  Object? get error => _error;

  String? get tenantId => _account?.tenantId;
  bool get hasStay => _stay != null;

  String get displayName {
    final name = _account?.name.trim() ?? '';
    return name.isEmpty ? 'there' : name;
  }

  bool isFavorite(String propertyId) => _account?.favorites.contains(propertyId) ?? false;

  SessionPhase get phase {
    if (_uid == null) return SessionPhase.idle;
    if (!_accountLoaded) return SessionPhase.loading;
    if (tenantId != null && !_stayLoaded) return SessionPhase.loading;
    return SessionPhase.ready;
  }

  void start(String uid) {
    if (_uid == uid) return;
    _clear();
    _uid = uid;
    _accountSub = _source.watchAccount(uid).listen(
      (account) {
        _account = account;
        _accountLoaded = true;
        _error = null;
        _followTenant(account?.tenantId);
        _notify();
      },
      onError: (Object e) {
        debugPrint('❌ [Session] account: $e');
        _error = e;
        _accountLoaded = true;
        _notify();
      },
    );
    _notify();
  }

  void _followTenant(String? tenantId) {
    if (tenantId == _stayFor) return;
    _staySub?.cancel();
    _unreadSub?.cancel();
    _stayFor = tenantId;
    _stay = null;
    _stayLoaded = false;
    _unread = 0;
    if (tenantId == null) return;

    _staySub = _source.watchActiveStay(tenantId).listen(
      (stay) {
        _stay = stay;
        _stayLoaded = true;
        _notify();
      },
      onError: (Object e) {
        debugPrint('❌ [Session] stay: $e');
        _stayLoaded = true;
        _notify();
      },
    );
    _unreadSub = _source.watchUnreadCount(tenantId).listen(
      (count) {
        _unread = count;
        _notify();
      },
      onError: (Object e) => debugPrint('⚠️ [Session] unread: $e'),
    );
  }

  void reset() {
    _clear();
    _notify();
  }

  void _clear() {
    _accountSub?.cancel();
    _staySub?.cancel();
    _unreadSub?.cancel();
    _accountSub = _staySub = _unreadSub = null;
    _uid = null;
    _account = null;
    _accountLoaded = false;
    _stayFor = null;
    _stay = null;
    _stayLoaded = false;
    _unread = 0;
    _error = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _clear();
    super.dispose();
  }
}
