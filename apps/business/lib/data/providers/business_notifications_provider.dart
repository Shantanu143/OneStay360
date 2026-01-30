import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_services/services/business_notification_service.dart';
import 'package:models/business/business_notification_model.dart';

/// App-level state for business notifications (list + unread counts).
class BusinessNotificationsProvider with ChangeNotifier {
  final BusinessNotificationService _service;
  StreamSubscription<List<BusinessNotification>>? _subscription;

  List<BusinessNotification> _notifications = const [];
  bool _isLoading = false;
  String? _businessId;
  Object? _lastError;

  List<BusinessNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  Object? get lastError => _lastError;
  int get unreadCount =>
      _notifications.where((notification) => notification.isUnread).length;
  bool get hasBusinessContext => _businessId != null && _businessId!.isNotEmpty;

  BusinessNotificationsProvider({BusinessNotificationService? service})
      : _service = service ?? BusinessNotificationService();

  /// Called by [ChangeNotifierProxyProvider] whenever the active business changes.
  void updateBusiness(String? businessId) {
    if (businessId == _businessId) {
      return;
    }

    _businessId = businessId;
    _notifications = const [];
    _lastError = null;
    _subscription?.cancel();

    if (businessId == null || businessId.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _subscribeToNotifications(businessId);
  }

  void refresh() {
    final businessId = _businessId;
    if (businessId == null || businessId.isEmpty) return;
    _subscribeToNotifications(businessId, resetState: false);
  }

  void _subscribeToNotifications(String businessId, {bool resetState = true}) {
    _subscription?.cancel();
    if (resetState) {
      _notifications = const [];
    }
    _isLoading = true;
    notifyListeners();

    _subscription = _service.streamNotifications(businessId).listen(
      (event) {
        _notifications = event;
        _isLoading = false;
        _lastError = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _lastError = error;
        notifyListeners();
      },
    );
  }

  Future<void> markAsRead(String notificationId) async {
    final businessId = _businessId;
    if (businessId == null || notificationId.isEmpty) return;
    await _service.markAsRead(
      businessId: businessId,
      notificationId: notificationId,
    );
  }

  Future<void> markAllAsRead() async {
    final businessId = _businessId;
    if (businessId == null) return;
    await _service.markAllAsRead(businessId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
