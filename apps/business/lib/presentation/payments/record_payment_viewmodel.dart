// lib/presentation/payments/record_payment_viewmodel.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Where a recorded payment goes (faked in tests).
abstract class PaymentRecorder {
  Future<void> record({
    required String businessId,
    required String tenantId,
    required double amount,
    required String month,
    required String mode,
    String? transactionId,
    String? note,
  });
}

/// Records through the `recordPayment` callable.
class CallablePaymentRecorder implements PaymentRecorder {
  CallablePaymentRecorder({FirebaseFunctions? functions}) : _functions = functions;

  final FirebaseFunctions? _functions;

  @override
  Future<void> record({
    required String businessId,
    required String tenantId,
    required double amount,
    required String month,
    required String mode,
    String? transactionId,
    String? note,
  }) async {
    final callable = (_functions ?? FirebaseFunctions.instance).httpsCallable('recordPayment');
    await callable.call<Object?>({
      'businessId': businessId,
      'tenantId': tenantId,
      'amount': amount,
      'month': month,
      'paymentMode': mode,
      'transactionId': transactionId,
      'note': note,
    });
  }
}

/// State of the "record a payment" form: cash or other money the owner
/// received directly.
class RecordPaymentViewModel extends ChangeNotifier {
  RecordPaymentViewModel({
    required this.businessId,
    required this.tenantId,
    required PaymentRecorder recorder,
    double? suggestedAmount,
    DateTime Function()? now,
  })  : _recorder = recorder,
        _amount = suggestedAmount ?? 0,
        months = _lastSixMonths((now ?? DateTime.now)()) {
    _month = months.first;
  }

  static const modes = ['Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Other'];

  final String businessId;
  final String tenantId;
  final PaymentRecorder _recorder;
  final List<String> months;
  bool _disposed = false;

  static List<String> _lastSixMonths(DateTime now) {
    final fmt = DateFormat('MMMM yyyy');
    return [for (var i = 0; i < 6; i++) fmt.format(DateTime(now.year, now.month - i, 1))];
  }

  double _amount;
  late String _month;
  String _mode = 'Cash';
  String _transactionId = '';
  String _note = '';
  bool _submitting = false;
  String? _error;

  double get amount => _amount;
  String get month => _month;
  String get mode => _mode;
  bool get submitting => _submitting;
  String? get error => _error;

  void setAmount(double v) => _set(() => _amount = v);
  void setTransactionId(String v) => _set(() => _transactionId = v);
  void setNote(String v) => _set(() => _note = v);

  void selectMonth(String v) {
    if (months.contains(v)) _set(() => _month = v);
  }

  void selectMode(String v) {
    if (modes.contains(v)) _set(() => _mode = v);
  }

  /// True when the payment was recorded.
  Future<bool> submit() async {
    if (_submitting) return false;
    if (_amount <= 0) {
      _error = 'Enter the amount received.';
      _notify();
      return false;
    }
    _submitting = true;
    _error = null;
    _notify();
    try {
      final txn = _transactionId.trim();
      final note = _note.trim();
      await _recorder.record(
        businessId: businessId,
        tenantId: tenantId,
        amount: _amount,
        month: _month,
        mode: _mode,
        transactionId: txn.isEmpty ? null : txn,
        note: note.isEmpty ? null : note,
      );
      return true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ [RecordPayment] ${e.code}: ${e.message}');
      _error = e.code == 'permission-denied'
          ? "You don't have permission to record payments for this tenant."
          : "Couldn't record the payment. Try again.";
      return false;
    } catch (e) {
      debugPrint('❌ [RecordPayment] $e');
      _error = "Couldn't record the payment. Try again.";
      return false;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  void _set(VoidCallback change) {
    change();
    _error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
