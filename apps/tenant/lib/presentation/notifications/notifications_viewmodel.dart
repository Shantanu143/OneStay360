// lib/presentation/notifications/notifications_viewmodel.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models.dart';
import '../../data/sources.dart';

class NotificationsViewModel extends ChangeNotifier {
  NotificationsViewModel({required NotificationSource source, required this.tenantId}) : _source = source {
    final id = tenantId;
    if (id == null) {
      _loaded = true;
      return;
    }
    _sub = _source.watchNotifications(id).listen(
      (list) {
        _items = list;
        _loaded = true;
        _error = null;
        _notify();
      },
      onError: (Object e) {
        debugPrint('❌ [Notifications] $e');
        _loaded = true;
        _error = "Couldn't load notifications.";
        _notify();
      },
    );
  }

  final NotificationSource _source;
  final String? tenantId;
  StreamSubscription<List<TenantNotification>>? _sub;

  List<TenantNotification> _items = const [];
  bool _loaded = false;
  String? _error;
  bool _disposed = false;

  List<TenantNotification> get items => _items;
  bool get loading => !_loaded;
  String? get error => _error;
  int get unreadCount => _items.where((n) => !n.read).length;

  Future<void> markRead(TenantNotification n) async {
    if (n.read || tenantId == null) return;
    await _quietly(() => _source.markRead(tenantId!, [n.id]));
  }

  Future<void> markAllRead() async {
    final ids = _items.where((n) => !n.read).map((n) => n.id).toList();
    if (ids.isEmpty || tenantId == null) return;
    await _quietly(() => _source.markRead(tenantId!, ids));
  }

  Future<void> _quietly(Future<void> Function() write) async {
    try {
      await write();
    } catch (e) {
      debugPrint('⚠️ [Notifications] mark read: $e');
    }
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
