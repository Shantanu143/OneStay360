// lib/presentation/tenant_detail/tenant_detail_viewmodel.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'tenant_detail_models.dart';
import 'tenant_detail_source.dart';

class TenantDetailViewModel extends ChangeNotifier {
  TenantDetailViewModel({required TenantProfile profile, required TenantDetailSource source})
      : _profile = profile,
        _source = source;

  final TenantDetailSource _source;
  TenantProfile _profile;
  bool _disposed = false;

  TenantProfile get profile => _profile;

  // ─── Payments ────────────────────────────────────────────────────────
  List<TenantPayment> _payments = const [];
  bool _paymentsLoading = false;
  String? _paymentsError;
  StreamSubscription<List<TenantPayment>>? _sub;

  List<TenantPayment> get payments => _payments;
  bool get paymentsLoading => _paymentsLoading;
  String? get paymentsError => _paymentsError;

  void listenPayments() {
    if (_sub != null) return;
    if (_profile.businessId.isEmpty || _profile.id.isEmpty) return;
    _paymentsLoading = true;
    _paymentsError = null;
    _notify();
    _sub = _source.payments(_profile.businessId, _profile.id).listen(
      (list) {
        // Newest first; payments without a date go last.
        _payments = [...list]..sort((a, b) {
            final x = a.date, y = b.date;
            if (x == null && y == null) return 0;
            if (x == null) return 1;
            if (y == null) return -1;
            return y.compareTo(x);
          });
        _paymentsLoading = false;
        _paymentsError = null;
        _notify();
      },
      onError: (Object e) {
        debugPrint('❌ [TenantDetail] payments: $e');
        _paymentsLoading = false;
        _paymentsError = "Couldn't load payments.";
        _notify();
      },
    );
  }

  void retryPayments() {
    _sub?.cancel();
    _sub = null;
    listenPayments();
  }

  // ─── Edit & remove ───────────────────────────────────────────────────
  bool _saving = false;
  bool _removing = false;
  String? _actionError;

  bool get saving => _saving;
  bool get removing => _removing;
  String? get actionError => _actionError;

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// Saves new contact details. Returns a message to show when the input is
  /// invalid or the save failed, null on success.
  Future<String?> saveContact({
    required String name,
    required String phone,
    required String email,
  }) async {
    final n = name.trim(), p = phone.trim(), e = email.trim();
    if (n.isEmpty) return "Enter the tenant's name.";
    final digits = p.replaceAll(RegExp(r'\D'), '').length;
    if (digits < 10 || digits > 13) return 'Enter a valid phone number.';
    if (e.isNotEmpty && !_email.hasMatch(e)) return 'Enter a valid email address.';

    _saving = true;
    _notify();
    try {
      await _source.updateContact(_profile.businessId, _profile.id, name: n, phone: p, email: e);
      _profile = _profile.withContact(name: n, phone: p, email: e);
      return null;
    } catch (err) {
      debugPrint('❌ [TenantDetail] save: $err');
      return "Couldn't save the changes. Try again.";
    } finally {
      _saving = false;
      _notify();
    }
  }

  /// Removes the tenant from their bed. True when it went through.
  Future<bool> remove() async {
    final t = _profile;
    final propertyId = t.propertyId, room = t.room, bed = t.bed;
    if (t.id.isEmpty ||
        t.businessId.isEmpty ||
        propertyId == null ||
        room == null ||
        bed == null) {
      _actionError = 'Missing information to remove this tenant.';
      _notify();
      return false;
    }
    _removing = true;
    _actionError = null;
    _notify();
    try {
      await _source.vacate(
        businessId: t.businessId,
        tenantId: t.id,
        propertyId: propertyId,
        roomId: room,
        bedId: bed,
      );
      return true;
    } catch (err) {
      debugPrint('❌ [TenantDetail] remove: $err');
      _actionError = "Couldn't remove this tenant. Try again.";
      return false;
    } finally {
      _removing = false;
      _notify();
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
