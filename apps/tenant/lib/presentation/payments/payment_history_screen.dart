// lib/presentation/payments/payment_history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../data/models.dart';
import '../common/format.dart';
import '../design/components/app_card.dart';
import '../design/components/app_chips.dart';
import '../design/components/app_list_row.dart';
import '../design/components/app_scaffold.dart';
import '../design/components/app_section_label.dart';
import '../design/components/app_states.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../stay/my_stay_tab.dart' show paymentStatus;
import '../stay/stay_feed.dart';

/// Rent invoices still open, then every payment with its state.
class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<StayFeed>();
    final now = DateTime.now();
    final open = feed.openInvoices;
    final paidTotal = feed.payments.where((p) => p.state == PaymentState.paid).fold<double>(0, (s, p) => s + p.amount);

    return AppScaffold(
      title: 'Payments',
      eyebrow: feed.stay?.propertyName,
      body: feed.stay == null
          ? const AppEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No payments yet',
              message: 'Payments appear here once you live in a PG.',
            )
          : feed.loadingMoney
              ? const Padding(padding: EdgeInsets.all(16), child: AppSkeletonList(count: 4, cardHeight: 76))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    EntranceFade(
                      child: Row(
                        children: [
                          Expanded(child: _Stat(label: 'Paid so far', value: formatInr(paidTotal))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Stat(
                              label: 'Due now',
                              value: formatInr(feed.totalDue),
                              color: open.isEmpty ? AppColors.green : AppColors.badge,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (open.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const AppSectionLabel('TO PAY'),
                      for (final inv in open) ...[
                        AppListRow(
                          icon: Icons.receipt_rounded,
                          color: inv.isOverdueAt(now) ? AppColors.badge : AppColors.orange,
                          title: '${formatInr(inv.amount)} · ${inv.month}',
                          subtitle: feed.pendingPaymentFor(inv.id) != null
                              ? 'Payment sent, being confirmed'
                              : inv.dueDate == null
                                  ? 'Unpaid'
                                  : dueLabel(inv.dueDate!, now),
                          trailing: feed.pendingPaymentFor(inv.id) != null ? null : Text('Pay', style: AppText.link),
                          onTap: feed.pendingPaymentFor(inv.id) != null ? null : () => openRentPayment(context, invoice: inv),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                    const SizedBox(height: 20),
                    const AppSectionLabel('HISTORY'),
                    if (feed.payments.isEmpty)
                      AppCard(
                        child: Text('No payments recorded yet.', style: AppText.body.copyWith(color: AppColors.inkSoft)),
                      )
                    else
                      AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            for (var i = 0; i < feed.payments.length; i++) ...[
                              if (i > 0) const Divider(indent: 16),
                              _PaymentRow(payment: feed.payments[i]),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => openRentPayment(context),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Report a payment'),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.statCaption),
          const SizedBox(height: 4),
          Text(value, style: AppText.statValue.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final RentPayment payment;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final (status, tone) = paymentStatus(p);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.month.isEmpty ? (p.description ?? 'Payment') : p.month,
                  style: AppText.rowTitle,
                ),
              ),
              Text(formatInr(p.amount), style: AppText.style(16, 700)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  [p.methodLabel, if (p.date != null) formatDay(p.date!), if (p.transactionId != null && p.transactionId != 'CASH') 'Ref ${p.transactionId}']
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.rowSubtitle,
                ),
              ),
              const SizedBox(width: 8),
              AppStatusPill(status, tone: tone),
            ],
          ),
          if (p.state == PaymentState.rejected && p.rejectionReason != null) ...[
            const SizedBox(height: 6),
            Text('Owner: ${p.rejectionReason}', style: AppText.caption.copyWith(color: AppColors.dangerInk)),
          ],
        ],
      ),
    );
  }
}
