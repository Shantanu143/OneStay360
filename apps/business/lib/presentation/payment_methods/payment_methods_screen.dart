// lib/presentation/payment_methods/payment_methods_screen.dart
import 'package:flutter/material.dart';

import '../../models/payment_method_model.dart';
import '../../services/payment_method_service.dart';
import '../design/components/biz_button.dart';
import '../design/components/biz_card.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_dialogs.dart';
import '../design/components/biz_list_row.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_section_label.dart';
import '../design/components/biz_states.dart';
import '../design/tokens.dart';
import '../view_models/payment_methods_viewmodel.dart';
import 'firestore_razorpay_gateway.dart';
import 'method_form_screen.dart';
import 'method_form_viewmodel.dart';

typedef MethodFormOpener = Future<bool> Function(
  BuildContext context, {
  PaymentMethod? method,
  MethodType? type,
});

/// The ways tenants can pay this business, and the Razorpay setup.
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({
    super.key,
    required this.businessId,
    this.service,
    this.razorpay,
    this.openForm,
  });

  final String businessId;
  final PaymentMethodService? service;
  final RazorpayGateway? razorpay;

  /// Replaces opening the add/edit form (tests). True when something changed.
  final MethodFormOpener? openForm;

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  late final PaymentMethodsViewModel _vm;
  late final RazorpayGateway _razorpay;
  RazorpayStatus _status = const RazorpayStatus.notSet();
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _vm = PaymentMethodsViewModel(service: widget.service);
    _razorpay = widget.razorpay ?? FirestoreRazorpayGateway();
    _load();
  }

  Future<void> _load() async {
    await _vm.loadPaymentMethods(widget.businessId);
    await _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _razorpay.status(widget.businessId);
      if (mounted) setState(() => _status = status);
    } catch (_) {
      // The card simply keeps saying "Not set".
    }
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _openForm({PaymentMethod? method, MethodType? type}) async {
    final custom = widget.openForm;
    final changed = custom != null
        ? await custom(context, method: method, type: type)
        : await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => PaymentMethodFormScreen(
                  businessId: widget.businessId,
                  method: method,
                  type: type,
                  service: widget.service,
                  razorpay: _razorpay,
                ),
              ),
            ) ??
            false;
    if (changed && mounted) await _load();
  }

  Future<void> _verify() async {
    if (_verifying) return;
    setState(() => _verifying = true);
    try {
      await _razorpay.verify(widget.businessId);
      await _loadStatus();
      if (mounted) showBizToast(context, 'Razorpay setup verified.', tone: BizTone.success);
    } catch (_) {
      if (mounted) {
        showBizToast(
          context,
          "Couldn't verify Razorpay. Check your keys and try again.",
          tone: BizTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _delete(PaymentMethod m) async {
    final ok = await showBizConfirm(
      context,
      title: 'Delete this method?',
      message: "${_title(m)} will be removed. This can't be undone.",
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final done = await _vm.deletePaymentMethod(widget.businessId, m.id);
    if (!mounted) return;
    showBizToast(
      context,
      done ? 'Payment method deleted.' : "Couldn't delete it. Try again.",
      tone: done ? BizTone.success : BizTone.danger,
    );
  }

  static String _title(PaymentMethod m) {
    switch (m.type) {
      case 'upi':
        return m.upiId ?? 'UPI';
      case 'bank':
        final n = m.accountNumber ?? '';
        final last4 = n.length >= 4 ? n.substring(n.length - 4) : n;
        return '${m.bankName ?? 'Bank'} · •••• $last4';
      case 'razorpay':
        return 'Razorpay';
      default:
        return 'Cash';
    }
  }

  static String _subtitle(PaymentMethod m) {
    switch (m.type) {
      case 'upi':
        return m.phoneNumber == null ? 'UPI' : 'UPI · ${m.phoneNumber}';
      case 'bank':
        return [m.accountHolderName, m.ifscCode].whereType<String>().join(' · ');
      case 'razorpay':
        return 'Online payments';
      default:
        return 'Collected in person';
    }
  }

  static (IconData, Color) _look(String type) => switch (type) {
        'upi' => (Icons.qr_code_2_rounded, BizColors.green),
        'bank' => (Icons.account_balance_outlined, BizColors.blue),
        'razorpay' => (Icons.language_rounded, BizColors.blue),
        _ => (Icons.payments_outlined, BizColors.orange),
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final manual = [for (final m in _vm.paymentMethods) if (m.type != 'razorpay') m];
        final razorpayMethod = _vm.paymentMethods.where((m) => m.type == 'razorpay').firstOrNull;
        final bottom = MediaQuery.viewPaddingOf(context).bottom + 24;

        Widget body;
        if (_vm.isLoading && _vm.paymentMethods.isEmpty) {
          body = const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: BizSkeletonList(count: 3, cardHeight: 90),
          );
        } else if (_vm.error.isNotEmpty && _vm.paymentMethods.isEmpty) {
          body = BizErrorState(message: "Couldn't load your payment methods.", onRetry: _load);
        } else {
          body = RefreshIndicator(
            color: BizColors.green,
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
              children: [
                const BizSectionLabel('Online payments'),
                _RazorpayCard(
                  configured: razorpayMethod != null || _status.configured,
                  status: _status,
                  verifying: _verifying,
                  onSetUp: () => _openForm(type: MethodType.razorpay),
                  onEdit: () => _openForm(method: razorpayMethod, type: MethodType.razorpay),
                  onVerify: _verify,
                ),
                const SizedBox(height: 18),
                const BizSectionLabel('UPI, bank and cash'),
                if (manual.isEmpty)
                  const BizCard(
                    child: BizEmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No payment methods yet',
                      message: 'Add a UPI ID or bank account so tenants know where to pay.',
                    ),
                  )
                else
                  for (final m in manual) ...[
                    _MethodRow(
                      method: m,
                      title: _title(m),
                      subtitle: _subtitle(m),
                      look: _look(m.type),
                      onToggle: (on) => _vm.togglePaymentMethodStatus(m, on),
                      onPreferred: () => _vm.setPreferredPaymentMethod(widget.businessId, m.id),
                      onEdit: () => _openForm(method: m),
                      onDelete: () => _delete(m),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          );
        }

        return BizScaffold(
          title: 'Payment methods',
          eyebrow: 'Settings',
          showBack: true,
          bottomBar: BizButton(
            label: 'Add payment method',
            icon: Icons.add_rounded,
            onPressed: () => _openForm(),
          ),
          body: body,
        );
      },
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.method,
    required this.title,
    required this.subtitle,
    required this.look,
    required this.onToggle,
    required this.onPreferred,
    required this.onEdit,
    required this.onDelete,
  });

  final PaymentMethod method;
  final String title;
  final String subtitle;
  final (IconData, Color) look;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPreferred;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = look;
    return BizCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
      child: Row(
        children: [
          BizIconTile(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: BizText.rowTitle),
                if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: BizText.rowSubtitle),
                if (method.isPreferred) ...[
                  const SizedBox(height: 6),
                  const BizStatusPill('Preferred', tone: BizTone.success, dot: false),
                ],
              ],
            ),
          ),
          Switch(
            value: method.isActive,
            onChanged: onToggle,
            activeThumbColor: Colors.white,
            activeTrackColor: BizColors.green,
          ),
          PopupMenuButton<String>(
            tooltip: 'More for ${title.split(' · ').first}',
            icon: const Icon(Icons.more_horiz_rounded, color: BizColors.inkSoft),
            onSelected: (v) {
              switch (v) {
                case 'preferred':
                  onPreferred();
                case 'edit':
                  onEdit();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (_) => [
              if (!method.isPreferred) const PopupMenuItem(value: 'preferred', child: Text('Make preferred')),
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _RazorpayCard extends StatelessWidget {
  const _RazorpayCard({
    required this.configured,
    required this.status,
    required this.verifying,
    required this.onSetUp,
    required this.onEdit,
    required this.onVerify,
  });

  final bool configured;
  final RazorpayStatus status;
  final bool verifying;
  final VoidCallback onSetUp;
  final VoidCallback onEdit;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final tone = !configured || !status.configured
        ? BizTone.neutral
        : status.verified
            ? BizTone.success
            : status.kycStatus == 'suspended'
                ? BizTone.danger
                : BizTone.warning;
    return BizCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BizIconTile(icon: Icons.language_rounded, color: BizColors.blue),
              const SizedBox(width: 12),
              Expanded(child: Text('Razorpay', style: BizText.rowTitle)),
              BizStatusPill(configured ? status.label : 'Not set', tone: tone),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Let tenants pay rent online by UPI or card. Razorpay charges its own fees and '
            'settles to your bank on its schedule, usually 2 working days.',
            style: BizText.rowSubtitle.copyWith(height: 1.4),
          ),
          const SizedBox(height: 14),
          if (!configured)
            BizButton(label: 'Set up Razorpay', size: BizButtonSize.compact, onPressed: onSetUp)
          else
            Row(
              children: [
                Expanded(
                  child: BizButton(
                    label: 'Edit setup',
                    kind: BizButtonKind.tonal,
                    size: BizButtonSize.compact,
                    onPressed: onEdit,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BizButton(
                    label: 'Verify setup',
                    size: BizButtonSize.compact,
                    loading: verifying,
                    onPressed: verifying ? null : onVerify,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
