// lib/presentation/payments/request_viewmodel.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models.dart';
import '../../data/sources.dart';
import '../common/device_actions.dart';

/// One request to join a PG, followed live: waiting for the owner, paying
/// the first bill, being checked, confirmed or turned down.
class RequestViewModel extends ChangeNotifier {
  RequestViewModel({required EnrollmentSource source, required this.requestId, required this.uid})
      : _source = source {
    _sub = _source.watchRequest(requestId).listen(
      (r) {
        _request = r;
        _loaded = true;
        _notify();
      },
      onError: (Object e) {
        debugPrint('❌ [Request] $e');
        _loaded = true;
        _notify();
      },
    );
  }

  final EnrollmentSource _source;
  final String requestId;
  final String uid;
  late final StreamSubscription<EnrollmentRequest?> _sub;

  EnrollmentRequest? _request;
  bool _loaded = false;
  String _reference = '';
  bool _attempted = false;
  bool _busy = false;
  String? _error;
  bool _disposed = false;

  EnrollmentRequest? get request => _request;
  bool get loading => !_loaded;
  bool get missing => _loaded && _request == null;
  bool get busy => _busy;
  String? get error => _error;
  String get reference => _reference;

  bool get canWithdraw => _request?.stage == EnrollmentStage.pending;

  bool get referenceRequired {
    final mode = _request?.paymentMode;
    return mode != BillPaymentMode.cash && mode != BillPaymentMode.immediate;
  }

  String get referenceLabel =>
      _request?.paymentMode == BillPaymentMode.bank ? 'Transfer reference (UTR)' : 'UPI reference (UTR)';

  String? get referenceError {
    if (!_attempted || !referenceRequired) return null;
    final ref = _reference.trim();
    if (ref.isEmpty) {
      return _request?.paymentMode == BillPaymentMode.bank
          ? 'Enter the reference (UTR) from your bank.'
          : 'Enter the UPI reference (UTR) from your payment app.';
    }
    if (ref.length < 6) return 'That reference looks too short.';
    return null;
  }

  Uri? get upiIntent {
    final r = _request;
    if (r == null || r.ownerUpiId == null || r.total <= 0) return null;
    return upiPayUri(upiId: r.ownerUpiId!, payee: r.propertyName, amount: r.total, note: 'First bill ${r.propertyName}');
  }

  void setReference(String v) {
    _reference = v;
    _notify();
  }

  /// Tells the owner the bill was paid. True when it was sent.
  Future<bool> confirmPaid() async {
    if (_busy || _request?.stage != EnrollmentStage.billSent) return false;
    _attempted = true;
    _error = null;
    if (referenceError != null) {
      _notify();
      return false;
    }
    return _run(() => _source.submitBillPayment(
          requestId,
          uid: uid,
          reference: referenceRequired ? _reference.trim() : 'CASH',
        ));
  }

  Future<bool> withdraw() async {
    if (_busy || !canWithdraw) return false;
    return _run(() => _source.withdraw(requestId));
  }

  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    _notify();
    try {
      await action();
      return true;
    } on TenantFailure catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      debugPrint('❌ [Request] $e');
      _error = "Couldn't send it. Check your connection and try again.";
      return false;
    } finally {
      _busy = false;
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
