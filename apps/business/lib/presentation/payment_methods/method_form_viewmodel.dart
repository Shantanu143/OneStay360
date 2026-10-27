// lib/presentation/payment_methods/method_form_viewmodel.dart
import 'package:flutter/foundation.dart';

import '../../models/payment_method_model.dart';
import 'bank_names.dart';

enum MethodType {
  upi('UPI'),
  bank('Bank'),
  cash('Cash'),
  razorpay('Razorpay');

  const MethodType(this.label);

  final String label;

  String get key => name;

  static MethodType of(String type) =>
      MethodType.values.firstWhere((t) => t.key == type, orElse: () => MethodType.cash);
}

enum MethodField {
  upiId,
  upiPhone,
  bankName,
  holder,
  accountNumber,
  confirmAccount,
  ifsc,
  rzKeyId,
  rzSecret,
  rzWebhook,
}

/// Where Razorpay credentials and status live (faked in tests).
abstract class RazorpayGateway {
  Future<void> saveCredentials(
    String businessId, {
    required String keyId,
    required String keySecret,
    required String webhookSecret,
  });

  Future<RazorpayStatus> status(String businessId);

  /// Asks the backend to check the stored credentials.
  Future<void> verify(String businessId);
}

class RazorpayStatus {
  const RazorpayStatus({
    required this.configured,
    this.enabled = false,
    this.verified = false,
    this.kycStatus = '',
  });

  const RazorpayStatus.notSet() : this(configured: false);

  final bool configured;
  final bool enabled;
  final bool verified;
  final String kycStatus;

  String get label {
    if (!configured) return 'Not set';
    if (verified) return 'Verified';
    if (!enabled) return 'Disabled';
    // `activated` / `configured` only say payments were switched on with keys,
    // not that Razorpay accepted them, so only its own review states are shown.
    switch (kycStatus) {
      case 'under_review':
        return 'Under review';
      case 'needs_clarification':
        return 'Needs clarification';
      case 'suspended':
        return 'Suspended';
    }
    return 'Not verified';
  }
}

/// State of the add/edit payment method form for one [type].
class MethodFormViewModel extends ChangeNotifier {
  MethodFormViewModel({
    required this.businessId,
    required this.type,
    required RazorpayGateway razorpay,
    this.existing,
    DateTime Function()? now,
  })  : _razorpay = razorpay,
        _now = now ?? DateTime.now {
    final m = existing;
    if (m != null) {
      _values.addAll({
        MethodField.upiId: m.upiId ?? '',
        MethodField.upiPhone: m.phoneNumber ?? '',
        MethodField.bankName: m.bankName ?? '',
        MethodField.holder: m.accountHolderName ?? '',
        MethodField.accountNumber: m.accountNumber ?? '',
        MethodField.confirmAccount: m.accountNumber ?? '',
        MethodField.ifsc: m.ifscCode ?? '',
      });
      _accountType = m.accountType ?? 'Savings';
    }
  }

  final String businessId;
  final MethodType type;
  final PaymentMethod? existing;
  final RazorpayGateway _razorpay;
  final DateTime Function() _now;
  bool _disposed = false;

  final Map<MethodField, String> _values = {};
  final Map<MethodField, String> _errors = {};
  String _accountType = 'Savings';

  bool get isEditing => existing != null;
  String get accountType => _accountType;

  String valueOf(MethodField f) => _values[f] ?? '';
  String? errorOf(MethodField f) => _errors[f];

  void setField(MethodField f, String v) {
    _values[f] = v;
    _errors.remove(f);
    _notify();
  }

  void setAccountType(String v) {
    _accountType = v;
    _notify();
  }

  List<String> bankSuggestions(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return [
      for (final b in indianBanks)
        if (b.toLowerCase().contains(q) && b.toLowerCase() != q) b,
    ];
  }

  // ─── Validation ──────────────────────────────────────────────────────
  static final _upi = RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$');
  static final _account = RegExp(r'^\d{8,18}$');
  static final _ifsc = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');

  String _t(MethodField f) => valueOf(f).trim();

  /// True when the entered values are good; otherwise sets the errors.
  bool validate() {
    _errors.clear();
    void fail(MethodField f, String message) => _errors[f] = message;

    switch (type) {
      case MethodType.upi:
        if (_t(MethodField.upiId).isEmpty) {
          fail(MethodField.upiId, 'Enter your UPI ID.');
        } else if (!_upi.hasMatch(_t(MethodField.upiId))) {
          fail(MethodField.upiId, 'Enter a valid UPI ID, like name@bank.');
        }
        final phone = _t(MethodField.upiPhone).replaceAll(RegExp(r'\D'), '');
        if (_t(MethodField.upiPhone).isNotEmpty && phone.length != 10) {
          fail(MethodField.upiPhone, 'Enter a 10-digit phone number.');
        }
      case MethodType.bank:
        if (_t(MethodField.bankName).length < 2) fail(MethodField.bankName, 'Enter the bank name.');
        if (_t(MethodField.holder).length < 3) fail(MethodField.holder, 'Enter the account holder name.');
        if (_t(MethodField.accountNumber).isEmpty) {
          fail(MethodField.accountNumber, 'Enter the account number.');
        } else if (!_account.hasMatch(_t(MethodField.accountNumber))) {
          fail(MethodField.accountNumber, 'Enter 8 to 18 digits.');
        } else if (_t(MethodField.confirmAccount) != _t(MethodField.accountNumber)) {
          fail(MethodField.confirmAccount, 'The account numbers do not match.');
        }
        final ifsc = _t(MethodField.ifsc).toUpperCase();
        if (ifsc.isEmpty) {
          fail(MethodField.ifsc, 'Enter the IFSC code.');
        } else if (!_ifsc.hasMatch(ifsc)) {
          fail(MethodField.ifsc, 'Enter a valid IFSC, like HDFC0001234.');
        }
      case MethodType.cash:
        break;
      case MethodType.razorpay:
        final key = _t(MethodField.rzKeyId);
        final secret = _t(MethodField.rzSecret);
        // Editing: leaving both blank keeps what is saved.
        final keepSaved = isEditing && key.isEmpty && secret.isEmpty;
        if (!keepSaved) {
          if (key.isEmpty) {
            fail(MethodField.rzKeyId, 'Enter your Razorpay Key ID.');
          } else if (!key.startsWith('rzp_')) {
            fail(MethodField.rzKeyId, 'A Razorpay Key ID starts with rzp_.');
          }
          if (secret.isEmpty) fail(MethodField.rzSecret, 'Enter your Razorpay Key Secret.');
        }
    }
    _notify();
    return _errors.isEmpty;
  }

  // ─── Output ──────────────────────────────────────────────────────────
  bool get hasNewRazorpayCredentials =>
      _t(MethodField.rzKeyId).isNotEmpty && _t(MethodField.rzSecret).isNotEmpty;

  Future<void> saveRazorpayCredentials() => _razorpay.saveCredentials(
        businessId,
        keyId: _t(MethodField.rzKeyId),
        keySecret: _t(MethodField.rzSecret),
        webhookSecret: _t(MethodField.rzWebhook),
      );

  /// The payment method to store. An edit keeps the original's identity,
  /// state and creation time.
  PaymentMethod build() {
    final now = _now().toUtc();
    final old = existing;
    final phone = _t(MethodField.upiPhone);
    return PaymentMethod(
      id: old?.id ?? now.millisecondsSinceEpoch.toString(),
      businessId: businessId,
      type: type.key,
      upiId: type == MethodType.upi ? _t(MethodField.upiId) : null,
      phoneNumber: type == MethodType.upi && phone.isNotEmpty ? phone : null,
      bankName: type == MethodType.bank ? _t(MethodField.bankName) : null,
      accountHolderName: type == MethodType.bank ? _t(MethodField.holder) : null,
      accountNumber: type == MethodType.bank ? _t(MethodField.accountNumber) : null,
      ifscCode: type == MethodType.bank ? _t(MethodField.ifsc).toUpperCase() : null,
      accountType: type == MethodType.bank ? _accountType : null,
      isActive: old?.isActive ?? true,
      isPreferred: old?.isPreferred ?? false,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
    );
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
