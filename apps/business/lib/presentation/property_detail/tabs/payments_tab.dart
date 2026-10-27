// lib/presentation/property_detail/tabs/payments_tab.dart
import 'package:flutter/material.dart';
import 'package:models/business/property/property_model.dart';

import '../../design/components/biz_button.dart';
import '../../design/components/biz_card.dart';
import '../../design/components/biz_chips.dart';
import '../../design/components/biz_dialogs.dart';
import '../../design/components/biz_section_label.dart';
import '../../design/components/biz_states.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../views/home/home_format.dart';
import '../property_detail_viewmodel.dart';
import '../../design/components/biz_info.dart';
import 'detail_common.dart';

/// The property's OneStay360 subscription: status, pay / activate, history.
class PaymentsTab extends StatelessWidget {
  const PaymentsTab({
    super.key,
    required this.vm,
    required this.onActivate,
    required this.onPay,
  });

  final PropertyDetailViewModel vm;
  final VoidCallback onActivate;
  final void Function(String invoiceId) onPay;

  @override
  Widget build(BuildContext context) {
    final p = vm.property!;
    final billing = vm.billingStatus;
    final invoice = vm.unpaidInvoiceId;

    return detailSliver([
      _StatusCard(property: p, label: billing.label, tone: billing.tone),
      if (billing.canActivate) ...[
        gap(),
        BizButton(label: 'Activate property', onPressed: onActivate),
      ],
      if (billing.canPay) ...[
        gap(),
        BizButton(
          label: 'Pay now',
          onPressed: invoice == null ? null : () => onPay(invoice),
        ),
        if (invoice == null) ...[
          gap(8),
          Text(
            vm.billingLoading
                ? 'Checking your latest invoice…'
                : "We couldn't find an open invoice yet. Pull down to refresh.",
            textAlign: TextAlign.center,
            style: BizText.rowSubtitle,
          ),
        ],
      ],
      gap(20),
      const BizSectionLabel('Payment history'),
      ..._history(context),
    ]);
  }

  List<Widget> _history(BuildContext context) {
    if (vm.billingLoading && vm.payments.isEmpty) {
      return const [BizSkeletonList(count: 2, cardHeight: 100)];
    }
    if (vm.billingError != null) {
      return [
        BizCard(
          child: BizErrorState(
            message: vm.billingError!,
            onRetry: () => vm.ensureBilling(force: true),
          ),
        ),
      ];
    }
    if (vm.payments.isEmpty) {
      return const [
        BizCard(
          child: BizEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No payments yet',
            message: 'Payments you make for this property are listed here.',
          ),
        ),
      ];
    }
    return [
      for (final pay in vm.payments) ...[
        _PaymentRow(payment: pay, onTap: () => _showDetails(context, pay)),
        gap(10),
      ],
    ];
  }

  void _showDetails(BuildContext context, Map<String, dynamic> pay) {
    showBizSheet<void>(
      context,
      title: formatInr(_amountOf(pay)),
      subtitle: _purposeOf(pay),
      builder: (_) => _PaymentDetails(payment: pay),
    );
  }
}

num _amountOf(Map<String, dynamic> pay) {
  final v = pay['finalAmount'] ?? pay['amount'];
  return v is num ? v : num.tryParse('$v') ?? 0;
}

String _purposeOf(Map<String, dynamic> pay) {
  switch ((pay['purpose'] ?? '').toString()) {
    case 'activation':
      return 'Activation payment';
    case 'monthly':
      return 'Monthly subscription';
    case '':
      return 'Payment';
    default:
      return titleCase(pay['purpose'].toString());
  }
}

(String, BizTone) _statusOf(Map<String, dynamic> pay) {
  final s = (pay['status'] ?? '').toString();
  switch (s) {
    case 'paid':
    case 'captured':
    case 'success':
      return ('Paid', BizTone.success);
    case 'failed':
      return ('Failed', BizTone.danger);
    case 'pending':
    case 'created':
      return ('Pending', BizTone.warning);
    case '':
      return ('Unknown', BizTone.neutral);
    default:
      return (titleCase(s), BizTone.neutral);
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.property, required this.label, required this.tone});

  final Property property;
  final String label;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final (bg, ink) = switch (tone) {
      'success' => (BizColors.greenTint, BizColors.greenDeep),
      'warning' => (BizColors.warnTint, BizColors.warnInk),
      'danger' => (BizColors.dangerTint, BizColors.dangerInk),
      _ => (Colors.white, BizColors.ink),
    };
    final next = property.nextBillingDate;
    final beds = property.billedBedCount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BizRadius.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: BizText.style(22, 800, color: ink, letterSpacing: -0.4)),
          if (next != null) ...[
            const SizedBox(height: 6),
            Text('Next billing: ${formatDay(next)}', style: BizText.style(14, 500, color: ink)),
          ],
          if (beds > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${formatInr(property.pricePerBed)} per bed · $beds ${beds == 1 ? 'bed' : 'beds'} billed',
              style: BizText.style(14, 500, color: ink.withValues(alpha: 0.8)),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.onTap});

  final Map<String, dynamic> payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final created = asDate(payment['createdAt']);
    final (statusLabel, tone) = _statusOf(payment);
    return Pressable(
      scale: 0.985,
      onTap: onTap,
      semanticLabel: _purposeOf(payment),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(BizRadius.control + 4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_purposeOf(payment), style: BizText.rowTitle),
                  if (created != null) ...[
                    const SizedBox(height: 2),
                    Text(formatDay(created), style: BizText.rowSubtitle),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatInr(_amountOf(payment)), style: BizText.bodyStrong),
                const SizedBox(height: 6),
                BizStatusPill(statusLabel, tone: tone),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentDetails extends StatelessWidget {
  const _PaymentDetails({required this.payment});

  final Map<String, dynamic> payment;

  @override
  Widget build(BuildContext context) {
    final created = asDate(payment['createdAt']);
    final (statusLabel, tone) = _statusOf(payment);
    final promo = payment['promoCode']?.toString() ?? '';
    final discount = payment['discountAmount'];
    String ref(String key) => payment[key]?.toString() ?? '';
    final paymentId = ref('paymentId').isNotEmpty ? ref('paymentId') : ref('id');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            BizStatusPill(statusLabel, tone: tone),
            const Spacer(),
            if (created != null) Text(formatDay(created), style: BizText.rowSubtitle),
          ],
        ),
        const SizedBox(height: 10),
        BizInfoRow('Paid via', ref('gateway').isEmpty ? 'Razorpay' : ref('gateway')),
        if (promo.isNotEmpty) BizInfoRow('Promo', promo),
        if (promo.isNotEmpty && discount is num && discount > 0)
          BizInfoRow('Promo saved', 'You saved ${formatInr(discount)}'),
        if (paymentId.isNotEmpty) BizInfoRow('Payment ID', paymentId),
        if (ref('orderId').isNotEmpty) BizInfoRow('Order ID', ref('orderId')),
        if (ref('invoiceId').isNotEmpty) BizInfoRow('Invoice', ref('invoiceId')),
      ],
    );
  }
}
