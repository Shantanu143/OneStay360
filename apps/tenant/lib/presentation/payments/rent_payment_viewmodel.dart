// lib/presentation/payments/rent_payment_viewmodel.dart
import 'package:flutter/foundation.dart';

import '../../data/models.dart';
import '../../data/sources.dart';
import '../common/device_actions.dart';
import '../common/format.dart';

enum RentMethod {
  online('Pay online', 'Card, UPI or net banking. Confirmed automatically.'),
  upi('UPI to owner', 'Pay from any UPI app, then share the reference.'),
  cash('Cash', 'Hand it to your owner. They confirm it here.');

  const RentMethod(this.label, this.subtitle);

  final String label;
  final String subtitle;
}

enum RentStage { choosing, awaitingOnline, submitted }

/// Paying rent: for an invoice, or reporting a payment when none was issued.
///
/// Online payments go through the owner's Razorpay link and are confirmed by
/// the webhook. UPI and cash are reported with submitRentPayment and stay
/// "pending" until the owner confirms them.
class RentPaymentViewModel extends ChangeNotifier {
  RentPaymentViewModel({
    required RentSource source,
    required Stay stay,
    required String tenantId,
    RentInvoice? invoice,
    DateTime Function()? clock,
  })  : _source = source,
        _stay = stay,
        _tenantId = tenantId,
        _invoice = invoice,
        _clock = clock ?? DateTime.now {
    final now = _clock();
    _monthOptions = [for (var i = -2; i <= 1; i++) monthLabel(DateTime(now.year, now.month + i))];
    _month = invoice?.month.isNotEmpty == true ? invoice!.month : monthLabel(now);
    if (!_monthOptions.contains(_month)) _monthOptions.add(_month);
    _amountText = (invoice?.amount ?? stay.monthlyRent).round().toString();
  }

  final RentSource _source;
  final Stay _stay;
  final String _tenantId;
  final RentInvoice? _invoice;
  final DateTime Function() _clock;

  bool _loading = true;
  PaymentSettings _settings = const PaymentSettings();
  RentMethod _method = RentMethod.upi;
  late final List<String> _monthOptions;
  late String _month;
  late String _amountText;
  String _reference = '';
  bool _attempted = false;
  bool _busy = false;
  String? _error;
  RentStage _stage = RentStage.choosing;
  bool _disposed = false;

  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;
  RentStage get stage => _stage;
  RentInvoice? get invoice => _invoice;
  Stay get stay => _stay;
  RentMethod get method => _method;
  String? get ownerUpiId => _settings.upiId;
  bool get amountLocked => _invoice != null;
  String get month => _month;
  List<String> get monthOptions => List.unmodifiable(_monthOptions);
  String get amountText => _amountText;
  String get reference => _reference;

  List<RentMethod> get methods => [
        if (_settings.onlineEnabled && _invoice != null) RentMethod.online,
        RentMethod.upi,
        RentMethod.cash,
      ];

  double get amount {
    if (_invoice != null) return _invoice.amount;
    return double.tryParse(_amountText.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  }

  String? get amountError {
    if (!_attempted || amountLocked) return null;
    if (amount <= 0) return 'Enter the amount you paid.';
    if (amount > 1000000) return 'That amount looks too large.';
    return null;
  }

  String? get referenceError {
    if (!_attempted || _method != RentMethod.upi) return null;
    final ref = _reference.trim();
    if (ref.isEmpty) return 'Enter the UPI reference (UTR) from your payment app.';
    if (ref.length < 6) return 'That reference looks too short.';
    return null;
  }

  String get actionLabel => switch (_method) {
        RentMethod.online => 'Pay ${formatInr(amount)} online',
        RentMethod.upi => "I've paid ${formatInr(amount)}",
        RentMethod.cash => 'I paid ${formatInr(amount)} in cash',
      };

  /// Opens any UPI app with the owner's id and the amount filled in.
  Uri? get upiIntent {
    final upi = ownerUpiId;
    if (upi == null || amount <= 0) return null;
    return upiPayUri(
      upiId: upi,
      payee: _stay.propertyName.isEmpty ? 'PG rent' : _stay.propertyName,
      amount: amount,
      note: 'Rent $_month',
    );
  }

  Future<void> load() async {
    _settings = await _source.loadSettings(_stay.businessId);
    _method = methods.first;
    _loading = false;
    _notify();
  }

  void select(RentMethod m) {
    if (!methods.contains(m) || m == _method) return;
    _method = m;
    _error = null;
    _notify();
  }

  void setAmount(String v) {
    if (amountLocked) return;
    _amountText = v;
    _notify();
  }

  void setMonth(String v) {
    if (amountLocked || !_monthOptions.contains(v)) return;
    _month = v;
    _notify();
  }

  void setReference(String v) {
    _reference = v;
    _notify();
  }

  /// The Razorpay link to open, or null when it couldn't be made.
  Future<String?> startOnlinePayment() async {
    final invoice = _invoice;
    if (_busy || invoice == null) return null;
    _busy = true;
    _error = null;
    _notify();
    try {
      final url = await _source.createPaymentLink(
        businessId: _stay.businessId,
        tenantId: _tenantId,
        invoiceId: invoice.id,
      );
      _stage = RentStage.awaitingOnline;
      return url;
    } on TenantFailure catch (e) {
      _error = e.message;
      return null;
    } catch (e) {
      debugPrint('❌ [Rent] link: $e');
      _error = "Couldn't start the payment. Try again.";
      return null;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Reports a UPI or cash payment. True when it was sent.
  Future<bool> submitManual() async {
    if (_busy || _method == RentMethod.online) return false;
    _attempted = true;
    _error = null;
    if (amountError != null || referenceError != null) {
      _notify();
      return false;
    }
    _busy = true;
    _notify();
    try {
      await _source.submitRentPayment(RentSubmission(
        businessId: _stay.businessId,
        amount: amount,
        month: _month,
        mode: _method == RentMethod.upi ? 'UPI' : 'Cash',
        reference: _method == RentMethod.upi ? _reference.trim() : null,
        invoiceId: _invoice?.id,
      ));
      _stage = RentStage.submitted;
      return true;
    } on TenantFailure catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      debugPrint('❌ [Rent] submit: $e');
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
    super.dispose();
  }
}
