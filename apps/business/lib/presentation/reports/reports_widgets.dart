// lib/presentation/reports/reports_widgets.dart
import 'package:flutter/material.dart';

import '../design/components/biz_avatar.dart';
import '../design/components/biz_card.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_info.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../views/home/home_format.dart';
import 'reports_models.dart';

/// Dark hero: what was collected out of what was billed, with what is still
/// to come in and what is late.
class ReportsHero extends StatelessWidget {
  const ReportsHero({super.key, required this.rangeLabel, required this.summary});

  final String rangeLabel;
  final ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final hasInvoices = s.invoiceCount > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 21, 20, 20),
      decoration: BoxDecoration(
        color: BizColors.card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: BizColors.card.withValues(alpha: 0.20),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Rent collected', style: BizText.cardLabel),
              const SizedBox(width: 12),
              Flexible(
                // widthFactor keeps the pill as wide as its label (a Container
                // with `alignment` would stretch across the card).
                child: Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: BizColors.cardPill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(rangeLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: BizText.cardPill),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(formatInr(s.collected), style: BizText.heroAmount),
          const SizedBox(height: 3),
          Text(
            hasInvoices ? 'of ${formatInr(s.billed)} billed' : 'No rent invoices in this period yet.',
            style: BizText.heroCaption,
          ),
          if (hasInvoices) ...[
            const SizedBox(height: 14),
            BizProgressBar(fraction: s.rate, onDark: true),
            const SizedBox(height: 7),
            Text('${formatPercent(s.rate)} collected', style: BizText.tileLabel),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Tile(label: 'Still to come in', value: formatInr(s.pending)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Tile(
                  label: s.overdueCount == 0
                      ? 'Overdue'
                      : 'Overdue · ${s.overdueCount} ${s.overdueCount == 1 ? 'invoice' : 'invoices'}',
                  value: formatInr(s.overdueAmount),
                  valueColor: s.overdueCount > 0 ? BizColors.amber : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: BizColors.cardTile,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: BizText.tileLabel),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: BizText.tileValue.copyWith(color: valueColor)),
          ),
        ],
      ),
    );
  }
}

/// One pair of bars per month: what was billed (the grey track) with what was
/// collected filled in from the bottom. Tap a month to read its numbers.
class MonthlyCollections extends StatefulWidget {
  const MonthlyCollections({super.key, required this.months});

  final List<MonthPoint> months;

  @override
  State<MonthlyCollections> createState() => _MonthlyCollectionsState();
}

class _MonthlyCollectionsState extends State<MonthlyCollections> {
  static const _chartHeight = 128.0;
  int? _selected;

  int get _index => (_selected ?? widget.months.length - 1).clamp(0, widget.months.length - 1);

  @override
  Widget build(BuildContext context) {
    final months = widget.months;
    final maxBilled = months.fold<double>(0, (m, p) => p.billed > m ? p.billed : m);
    final current = months[_index];
    final animate = !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

    return BizCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Collections by month', style: BizText.cardTitle)),
              const _Swatch(color: BizColors.green, label: 'Collected'),
              const SizedBox(width: 12),
              const _Swatch(color: BizColors.track, label: 'Billed'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _chartHeight + 26,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < months.length; i++)
                  Expanded(
                    child: _MonthBar(
                      point: months[i],
                      maxBilled: maxBilled,
                      chartHeight: _chartHeight,
                      selected: i == _index,
                      animate: animate,
                      onTap: () => setState(() => _selected = i),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(current.longLabel, style: BizText.bodyStrong),
          const SizedBox(height: 2),
          Text(
            current.billed > 0
                ? '${formatInr(current.collected)} collected of ${formatInr(current.billed)} · ${formatPercent(current.rate)}'
                : 'No rent was billed this month.',
            style: BizText.rowSubtitle,
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(label, style: BizText.caption),
      ],
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.point,
    required this.maxBilled,
    required this.chartHeight,
    required this.selected,
    required this.animate,
    required this.onTap,
  });

  final MonthPoint point;
  final double maxBilled;
  final double chartHeight;
  final bool selected;
  final bool animate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final billedH = maxBilled > 0 && point.billed > 0
        ? (chartHeight * point.billed / maxBilled).clamp(4.0, chartHeight)
        : 0.0;
    final collectedH = billedH * point.rate;

    return Semantics(
      button: true,
      selected: selected,
      label: '${point.longLabel}: ${formatInr(point.collected)} collected of ${formatInr(point.billed)} billed',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
          decoration: BoxDecoration(
            color: selected ? BizColors.page : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: billedH),
                    duration: animate ? const Duration(milliseconds: 420) : Duration.zero,
                    curve: Curves.easeOutCubic,
                    builder: (context, h, _) => Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        // A month nobody was billed is a zero, not a gap.
                        if (billedH == 0)
                          Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: BizColors.track,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: BizColors.track,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ),
                        if (billedH > 0)
                          Container(
                            height: h * (collectedH / billedH),
                            decoration: BoxDecoration(
                              color: BizColors.green,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(collectedH >= billedH ? 6 : 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                point.label,
                style: BizText.style(12, selected ? 700 : 500, color: selected ? BizColors.ink : BizColors.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A property's beds and rent for the period.
class PropertyReportCard extends StatelessWidget {
  const PropertyReportCard({super.key, required this.report, this.onTap});

  final PropertyReport report;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final card = BizCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: BizText.rowTitle),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded, size: 22, color: BizColors.chevron),
            ],
          ),
          if (r.totalBeds > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${r.occupiedBeds} of ${r.totalBeds} beds filled · ${formatPercent(r.occupancy)}',
              style: BizText.rowSubtitle,
            ),
            const SizedBox(height: 8),
            BizProgressBar(fraction: r.occupancy),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  r.billed > 0
                      ? '${formatInr(r.collected)} of ${formatInr(r.billed)} collected'
                      : 'No rent billed',
                  style: BizText.bodyStrong,
                ),
              ),
              if (r.overdueCount > 0)
                BizStatusPill('${r.overdueCount} overdue', tone: BizTone.warning),
            ],
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Pressable(scale: 0.985, onTap: onTap, semanticLabel: r.name, child: card);
  }
}

/// How the collected rent arrived: a name, an amount and its share.
class PayModesCard extends StatelessWidget {
  const PayModesCard({super.key, required this.modes});

  final List<PayMode> modes;

  @override
  Widget build(BuildContext context) {
    return BizCard(
      child: Column(
        children: [
          for (var i = 0; i < modes.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: Text(modes[i].label, style: BizText.rowTitle)),
                Text(formatInr(modes[i].amount), style: BizText.bodyStrong),
                const SizedBox(width: 10),
                SizedBox(
                  width: 52,
                  child: Text(
                    formatPercent(modes[i].share),
                    textAlign: TextAlign.right,
                    style: BizText.rowSubtitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            BizProgressBar(fraction: modes[i].share),
          ],
        ],
      ),
    );
  }
}

/// Tenants owing the most.
class OverdueCard extends StatelessWidget {
  const OverdueCard({super.key, required this.tenants});

  final List<OverdueTenant> tenants;

  @override
  Widget build(BuildContext context) {
    return BizCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < tenants.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: BizColors.hairline),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  BizAvatar(
                    initials: initialsOf(tenants[i].name),
                    size: 40,
                    background: BizColors.dangerTint,
                    foreground: BizColors.dangerInk,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tenants[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BizText.rowTitle,
                        ),
                        const SizedBox(height: 2),
                        Text(_owedLine(tenants[i]), style: BizText.rowSubtitle),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatInr(tenants[i].amount),
                    style: BizText.bodyStrong.copyWith(color: BizColors.dangerInk),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _owedLine(OverdueTenant t) {
    final invoices = '${t.invoices} ${t.invoices == 1 ? 'invoice' : 'invoices'}';
    if (t.daysLate <= 0) return invoices;
    return '$invoices · ${t.daysLate} ${t.daysLate == 1 ? 'day' : 'days'} late';
  }
}
