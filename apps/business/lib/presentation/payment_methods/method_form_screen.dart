// lib/presentation/payment_methods/method_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/payment_method_model.dart';
import '../../services/payment_method_service.dart';
import '../design/components/biz_banner.dart';
import '../design/components/biz_button.dart';
import '../design/components/biz_card.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_dialogs.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_section_label.dart';
import '../design/components/biz_text_field.dart';
import '../design/tokens.dart';
import '../view_models/payment_methods_viewmodel.dart';
import 'firestore_razorpay_gateway.dart';
import 'method_form_viewmodel.dart';

/// Add a payment method, or edit one. Pops with `true` once saved.
class PaymentMethodFormScreen extends StatefulWidget {
  const PaymentMethodFormScreen({
    super.key,
    required this.businessId,
    this.method,
    this.type,
    this.service,
    this.razorpay,
  });

  final String businessId;

  /// The method being edited; null to add one.
  final PaymentMethod? method;

  /// The type to start on when adding.
  final MethodType? type;
  final PaymentMethodService? service;
  final RazorpayGateway? razorpay;

  @override
  State<PaymentMethodFormScreen> createState() => _PaymentMethodFormScreenState();
}

class _PaymentMethodFormScreenState extends State<PaymentMethodFormScreen> {
  late MethodFormViewModel _vm;
  late final PaymentMethodsViewModel _methods;
  late final RazorpayGateway _razorpay;
  final _controllers = <MethodField, TextEditingController>{};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _razorpay = widget.razorpay ?? FirestoreRazorpayGateway();
    _methods = PaymentMethodsViewModel(service: widget.service);
    final existing = widget.method;
    _vm = _newVm(existing != null ? MethodType.of(existing.type) : widget.type ?? MethodType.upi);
  }

  MethodFormViewModel _newVm(MethodType type) => MethodFormViewModel(
        businessId: widget.businessId,
        type: type,
        existing: widget.method,
        razorpay: _razorpay,
      );

  TextEditingController _controller(MethodField f) =>
      _controllers.putIfAbsent(f, () => TextEditingController(text: _vm.valueOf(f)));

  void _switchType(MethodType type) {
    if (type == _vm.type) return;
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _vm.dispose();
    setState(() {
      _vm = _newVm(type);
      _error = null;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _vm.dispose();
    _methods.dispose();
    super.dispose();
  }

  Future<bool> _confirmRazorpay() => showBizConfirm(
        context,
        title: 'Before you switch on Razorpay',
        message: 'Razorpay charges processing fees under your plan and pays out to your bank on its '
            'own schedule, usually 2 working days. Your keys are stored for your business only.',
        confirmLabel: 'I understand',
      );

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_vm.validate()) return;
    if (_vm.type == MethodType.razorpay && _vm.hasNewRazorpayCredentials && !await _confirmRazorpay()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_vm.type == MethodType.razorpay && _vm.hasNewRazorpayCredentials) {
        await _vm.saveRazorpayCredentials();
      }
      var ok = true;
      final built = _vm.build();
      if (_vm.isEditing) {
        // Editing Razorpay only replaces its keys; the method itself is unchanged.
        if (_vm.type != MethodType.razorpay) ok = await _methods.updatePaymentMethod(built);
      } else {
        ok = await _methods.addPaymentMethod(widget.businessId, built);
      }
      if (!mounted) return;
      if (ok) {
        showBizToast(context, _vm.isEditing ? 'Payment method updated.' : 'Payment method added.',
            tone: BizTone.success);
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = _methods.error.contains('already configured')
            ? 'Razorpay is already set up for this business.'
            : "Couldn't save this payment method. Try again.");
      }
    } catch (e) {
      debugPrint('❌ [PaymentMethodForm] $e');
      if (mounted) setState(() => _error = "Couldn't save this payment method. Try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom + 24;
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => BizScaffold(
        title: _vm.isEditing ? 'Edit ${_vm.type.label}' : 'Add payment method',
        eyebrow: 'Payment methods',
        showBack: true,
        bottomBar: BizButton(label: 'Save', loading: _saving, onPressed: _saving ? null : _save),
        body: ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (_error != null) ...[
              BizBanner(message: _error!, tone: BizTone.danger),
              const SizedBox(height: 12),
            ],
            if (!_vm.isEditing) ...[
              const BizSectionLabel('Type'),
              BizChoiceWrap<MethodType>(
                options: MethodType.values,
                selected: _vm.type,
                labelOf: (t) => t.label,
                onChanged: _switchType,
              ),
              const SizedBox(height: 18),
            ],
            BizCard(child: _fields()),
          ],
        ),
      ),
    );
  }

  Widget _field(MethodField f, String key, String label,
      {String? hint,
      String? helper,
      TextInputType? keyboard,
      bool obscure = false,
      TextCapitalization caps = TextCapitalization.none,
      List<TextInputFormatter>? formatters,
      ValueChanged<String>? onChanged}) {
    return BizTextField(
      label: label,
      fieldKey: Key(key),
      controller: _controller(f),
      hint: hint,
      helper: helper,
      keyboardType: keyboard,
      obscureText: obscure,
      textCapitalization: caps,
      inputFormatters: formatters,
      errorText: _vm.errorOf(f),
      onChanged: (v) {
        _vm.setField(f, v);
        onChanged?.call(v);
      },
    );
  }

  Widget _fields() {
    switch (_vm.type) {
      case MethodType.upi:
        return Column(
          children: [
            _field(MethodField.upiId, 'upiId', 'UPI ID', hint: 'name@bank', keyboard: TextInputType.emailAddress),
            const SizedBox(height: 14),
            _field(
              MethodField.upiPhone,
              'upiPhone',
              'Phone linked to this UPI (optional)',
              keyboard: TextInputType.phone,
            ),
          ],
        );
      case MethodType.bank:
        final suggestions = _vm.bankSuggestions(_vm.valueOf(MethodField.bankName));
        return Column(
          children: [
            _field(
              MethodField.bankName,
              'bankName',
              'Bank name',
              hint: 'Search: HDFC, SBI…',
              caps: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
            if (suggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final b in suggestions.take(5))
                        BizChip(
                          data: BizChipData(b),
                          selected: false,
                          onCard: true,
                          onTap: () {
                            _controller(MethodField.bankName).text = b;
                            _vm.setField(MethodField.bankName, b);
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 14),
            _field(MethodField.holder, 'holder', 'Account holder name', caps: TextCapitalization.words),
            const SizedBox(height: 14),
            _field(
              MethodField.accountNumber,
              'accountNumber',
              'Account number',
              keyboard: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 14),
            _field(
              MethodField.confirmAccount,
              'confirmAccount',
              'Confirm account number',
              keyboard: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 14),
            _field(
              MethodField.ifsc,
              'ifsc',
              'IFSC code',
              hint: 'HDFC0001234',
              caps: TextCapitalization.characters,
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: BizChoiceWrap<String>(
                options: const ['Savings', 'Current'],
                selected: _vm.accountType,
                onCard: true,
                onChanged: _vm.setAccountType,
              ),
            ),
          ],
        );
      case MethodType.cash:
        return Text(
          'Tenants can pay you in cash. You record the payment yourself when you receive it.',
          style: BizText.body.copyWith(color: BizColors.inkSoft, height: 1.4),
        );
      case MethodType.razorpay:
        return Column(
          children: [
            BizBanner(
              message: _vm.isEditing
                  ? 'Leave the keys blank to keep the ones you saved.'
                  : 'Find your keys in the Razorpay dashboard under Settings → API Keys.',
              tone: BizTone.info,
            ),
            const SizedBox(height: 14),
            _field(MethodField.rzKeyId, 'rzKeyId', 'Key ID', hint: 'rzp_live_…'),
            const SizedBox(height: 14),
            _field(MethodField.rzSecret, 'rzSecret', 'Key secret', obscure: true),
            const SizedBox(height: 14),
            _field(
              MethodField.rzWebhook,
              'rzWebhook',
              'Webhook secret (optional)',
              obscure: true,
              helper: 'Lets Razorpay tell us when a tenant has paid.',
            ),
          ],
        );
    }
  }
}
