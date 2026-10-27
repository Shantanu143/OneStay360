// lib/presentation/property_detail/tabs/analytics_tab.dart
import 'package:flutter/material.dart';

import '../../design/components/biz_card.dart';
import '../../design/components/biz_chips.dart';
import '../../design/components/biz_states.dart';
import '../../design/tokens.dart';
import '../../views/home/home_format.dart';
import '../property_detail_models.dart';
import '../property_detail_viewmodel.dart';
import '../../design/components/biz_info.dart';
import 'detail_common.dart';

/// Occupancy and how much of this month's rent has come in.
class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key, required this.vm, required this.now});

  final PropertyDetailViewModel vm;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final month = monthName(now);
    final c = vm.collection;
    final s = vm.stats;

    Widget collections;
    if (vm.analyticsLoading) {
      collections = const BizSkeletonList(count: 1, cardHeight: 180);
    } else if (vm.analyticsError != null) {
      collections = BizCard(
        child: BizErrorState(
          message: vm.analyticsError!,
          onRetry: () => vm.ensureAnalytics(force: true),
        ),
      );
    } else if (!c.hasInvoices) {
      collections = BizCard(
        child: BizEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No rent invoices for $month yet',
          message: 'Invoices are created automatically at the start of each month.',
        ),
      );
    } else {
      collections = _Collections(month: month, collection: c);
    }

    return detailSliver([
      collections,
      gap(),
      BizCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Occupancy', style: BizText.cardTitle)),
                Text(formatPercent(s.occupancy), style: BizText.statValue),
              ],
            ),
            const SizedBox(height: 12),
            BizProgressBar(fraction: s.occupancy),
            const SizedBox(height: 10),
            Text(
              s.totalBeds == 0
                  ? 'No beds set up yet'
                  : '${s.occupiedBeds} of ${s.totalBeds} beds filled · '
                        '${s.occupiedRooms} of ${s.totalRooms} rooms in use',
              style: BizText.rowSubtitle,
            ),
          ],
        ),
      ),
    ]);
  }
}

class _Collections extends StatelessWidget {
  const _Collections({required this.month, required this.collection});

  final String month;
  final MonthCollection collection;

  @override
  Widget build(BuildContext context) {
    final c = collection;
    return BizCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('$month collections', style: BizText.cardTitle)),
              Text(formatPercent(c.rate), style: BizText.statValue.copyWith(color: BizColors.green)),
            ],
          ),
          const SizedBox(height: 12),
          BizProgressBar(fraction: c.rate),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Figure(label: 'Expected', value: formatInr(c.expected))),
              Expanded(child: _Figure(label: 'Collected', value: formatInr(c.collected))),
              Expanded(
                child: _Figure(
                  label: 'Outstanding',
                  value: formatInr(c.outstanding),
                  color: c.outstanding > 0 ? BizColors.lastBed : BizColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              BizStatusPill('${c.paidCount} paid', tone: BizTone.success),
              if (c.unpaidCount > 0) BizStatusPill('${c.unpaidCount} unpaid', tone: BizTone.warning),
              if (c.overdueCount > 0) BizStatusPill('${c.overdueCount} overdue', tone: BizTone.danger),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: BizText.statCaption),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: BizText.statValue.copyWith(color: color ?? BizColors.ink)),
        ),
      ],
    );
  }
}
