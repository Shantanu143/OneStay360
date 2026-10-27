// lib/presentation/requests/request_detail_viewmodel.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'request_models.dart';
import 'request_source.dart';

class RequestDetailViewModel extends ChangeNotifier {
  RequestDetailViewModel({
    required this.requestId,
    required RequestSource source,
    EnrollmentRequest? initial,
  })  : _source = source,
        _request = initial,
        _loading = initial == null;

  final String requestId;
  final RequestSource _source;
  bool _disposed = false;

  EnrollmentRequest? _request;
  bool _loading;
  bool _missing = false;
  String? _error;
  StreamSubscription<EnrollmentRequest?>? _sub;

  EnrollmentRequest? get request => _request;
  bool get loading => _loading;

  /// The request was deleted.
  bool get missing => _missing;
  String? get error => _error;

  void start() {
    if (_sub != null) return;
    _sub = _source.watch(requestId).listen(
      (r) {
        _request = r ?? _request;
        _missing = r == null;
        _loading = false;
        _error = null;
        _notify();
      },
      onError: (Object e) {
        debugPrint('❌ [Request] watch: $e');
        _loading = false;
        _error = "Couldn't load this request.";
        _notify();
      },
    );
  }

  void retry() {
    _sub?.cancel();
    _sub = null;
    _error = null;
    _loading = _request == null;
    _notify();
    start();
  }

  // ─── Actions ─────────────────────────────────────────────────────────
  bool _busy = false;
  String? _actionError;

  bool get busy => _busy;
  String? get actionError => _actionError;

  Future<bool> reject() => _act(RequestStage.pending, () => _source.reject(requestId));

  Future<bool> confirmPayment() =>
      _act(RequestStage.paymentSubmitted, () => _source.confirmPayment(requestId));

  /// Confirms again after adding the tenant failed (the backend retries when
  /// the status changes back to confirmed).
  Future<bool> retryApproval() =>
      _act(RequestStage.approvalFailed, () => _source.confirmPayment(requestId));

  Future<bool> rejectPayment(String reason) =>
      _act(RequestStage.paymentSubmitted, () => _source.rejectPayment(requestId, reason));

  /// Runs [run] only while the request is still in [stage], so a stale screen
  /// can't undo what was decided elsewhere.
  Future<bool> _act(RequestStage stage, Future<void> Function() run) async {
    if (_request?.stage != stage) {
      _actionError = 'This request has changed. Review it again.';
      _notify();
      return false;
    }
    _busy = true;
    _actionError = null;
    _notify();
    try {
      await run();
      return true;
    } catch (e) {
      debugPrint('❌ [Request] action: $e');
      _actionError = "Couldn't update the request. Try again.";
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
    _sub?.cancel();
    super.dispose();
  }
}
