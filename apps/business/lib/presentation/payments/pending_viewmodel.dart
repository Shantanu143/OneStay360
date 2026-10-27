// lib/presentation/payments/pending_viewmodel.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../requests/request_models.dart';
import '../requests/request_source.dart';
import 'pending_models.dart';
import 'pending_source.dart';

enum PendingTab { rent, deposits }

class PendingPaymentsViewModel extends ChangeNotifier {
  PendingPaymentsViewModel({
    required this.businessId,
    required PendingPaymentsSource source,
    required RequestSource requests,
    this.propertyId,
  })  : _source = source,
        _requests = requests;

  final String businessId;
  final String? propertyId;
  final PendingPaymentsSource _source;
  final RequestSource _requests;
  bool _disposed = false;
  bool _started = false;

  // ─── Data ────────────────────────────────────────────────────────────
  List<PendingRent> _rent = const [];
  List<EnrollmentRequest> _deposits = const [];
  bool _rentLoading = true;
  bool _depositsLoading = true;
  String? _rentError;
  String? _depositsError;
  StreamSubscription<List<EnrollmentRequest>>? _sub;

  /// Newest first.
  List<PendingRent> get rent => [..._rent]..sort((a, b) {
        final x = a.submittedAt, y = b.submittedAt;
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        return y.compareTo(x);
      });

  List<EnrollmentRequest> get deposits {
    final list = [..._deposits];
    list.sort((a, b) {
      final x = a.payment?.submittedAt ?? a.createdAt;
      final y = b.payment?.submittedAt ?? b.createdAt;
      return y.compareTo(x);
    });
    return list;
  }

  bool get loading => _rentLoading || _depositsLoading;
  bool get rentLoading => _rentLoading;
  bool get depositsLoading => _depositsLoading;
  String? get rentError => _rentError;
  String? get depositsError => _depositsError;
  int get total => _rent.length + _deposits.length;

  int count(PendingTab tab) => tab == PendingTab.rent ? _rent.length : _deposits.length;

  PendingTab _tab = PendingTab.rent;
  PendingTab get tab => _tab;

  void selectTab(PendingTab t) {
    _tab = t;
    _notify();
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _sub = _source.deposits(businessId, propertyId: propertyId).listen(
      (list) {
        _deposits = list;
        _depositsLoading = false;
        _depositsError = null;
        _notify();
      },
      onError: (Object e) {
        debugPrint('❌ [Pending] deposits: $e');
        _depositsLoading = false;
        _depositsError = "Couldn't load deposits.";
        _notify();
      },
    );
    await reloadRent();
  }

  Future<void> reloadRent() async {
    _rentLoading = true;
    _rentError = null;
    _notify();
    try {
      _rent = await _source.rentPayments(businessId, propertyId: propertyId);
    } catch (e) {
      debugPrint('❌ [Pending] rent: $e');
      _rentError = "Couldn't load rent payments.";
    } finally {
      _rentLoading = false;
      _notify();
    }
  }

  void retryDeposits() {
    _sub?.cancel();
    _started = false;
    _depositsLoading = true;
    _depositsError = null;
    _notify();
    start();
  }

  // ─── Actions ─────────────────────────────────────────────────────────
  final Set<String> _busy = {};
  String? _actionError;

  String? get actionError => _actionError;
  bool isBusy(String id) => _busy.contains(id);

  Future<bool> confirmRent(PendingRent r) => _verify(r, confirm: true);

  Future<bool> rejectRent(PendingRent r, String reason) => _verify(r, confirm: false, reason: reason);

  Future<bool> _verify(PendingRent r, {required bool confirm, String? reason}) {
    return _run(r.paymentId, () async {
      await _source.verifyRent(
        businessId: businessId,
        tenantId: r.tenantId,
        paymentId: r.paymentId,
        confirm: confirm,
        reason: reason,
      );
      _rent = [for (final x in _rent) if (x.paymentId != r.paymentId) x];
    });
  }

  Future<bool> confirmDeposit(EnrollmentRequest d) => _run(d.id, () => _requests.confirmPayment(d.id));

  Future<bool> rejectDeposit(EnrollmentRequest d, String reason) =>
      _run(d.id, () => _requests.rejectPayment(d.id, reason));

  Future<bool> _run(String id, Future<void> Function() action) async {
    if (!_busy.add(id)) return false;
    _actionError = null;
    _notify();
    try {
      await action();
      return true;
    } catch (e) {
      debugPrint('❌ [Pending] action: $e');
      _actionError = "Couldn't update that payment. Try again.";
      return false;
    } finally {
      _busy.remove(id);
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
