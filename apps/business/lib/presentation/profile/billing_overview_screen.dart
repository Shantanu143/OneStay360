// lib/presentation/profile/billing_overview_screen.dart
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:flutter/material.dart';
import 'package:models/business/property/property_model.dart';
import 'package:provider/provider.dart';

import '../design/components/biz_card.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_states.dart';
import '../design/tokens.dart';
import '../views/home/home_format.dart';
import '../views/view_property_screen.dart';
import 'billing_overview_viewmodel.dart';

typedef PropertyBillingOpener =
    void Function(BuildContext context, Property property);

BizTone _tone(String key) => switch (key) {
  'success' => BizTone.success,
  'warning' => BizTone.warning,
  'danger' => BizTone.danger,
  _ => BizTone.neutral,
};

/// What each property costs on OneStay360 and which ones need paying.
/// Tapping one opens its Payments tab, where it can be paid.
class BillingOverviewScreen extends StatefulWidget {
  const BillingOverviewScreen({
    super.key,
    required this.businessId,
    this.repository,
    this.onOpen,
  });

  final String businessId;
  final PropertyRepository? repository;
  final PropertyBillingOpener? onOpen;

  @override
  State<BillingOverviewScreen> createState() => _BillingOverviewScreenState();
}

class _BillingOverviewScreenState extends State<BillingOverviewScreen> {
  late final BillingOverviewViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = BillingOverviewViewModel(
      repository: widget.repository ?? context.read<PropertyRepository>(),
      businessId: widget.businessId,
    )..load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  void _open(Property p) {
    final custom = widget.onOpen;
    if (custom != null) return custom(context, p);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ViewPropertyScreen(
              propertyId: p.id ?? '',
              initialTabIndex: ViewPropertyScreen.billingTabIndex,
            ),
          ),
        )
        // The status may have changed while paying.
        .then((_) => _vm.load());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => BizScaffold(
        title: 'Billing',
        eyebrow: 'OneStay360 subscription',
        showBack: true,
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_vm.loading && _vm.rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: BizSkeletonList(count: 3, cardHeight: 100),
      );
    }
    if (_vm.error != null && _vm.rows.isEmpty) {
      return BizErrorState(message: _vm.error!, onRetry: _vm.load);
    }
    if (_vm.rows.isEmpty) {
      return const BizEmptyState(
        icon: Icons.apartment_rounded,
        title: 'No properties yet',
        message: 'Add a property and its subscription shows up here.',
      );
    }
    final bottom = MediaQuery.viewPaddingOf(context).bottom + 24;
    final attention = _vm.needAttention;
    return RefreshIndicator(
      color: BizColors.green,
      onRefresh: _vm.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BizColors.card,
              borderRadius: BorderRadius.circular(BizRadius.hero),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Every month', style: BizText.cardLabel),
                const SizedBox(height: 6),
                Text(formatInr(_vm.monthlyTotal), style: BizText.heroAmount),
                const SizedBox(height: 4),
                Text(
                  attention == 0
                      ? 'Everything is paid up'
                      : '$attention ${attention == 1 ? 'property needs' : 'properties need'} your attention',
                  style: BizText.heroCaption.copyWith(
                    color: attention == 0
                        ? BizColors.onCardMuted
                        : BizColors.amber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final row in _vm.rows) ...[
            _Row(row: row, onTap: () => _open(row.property)),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.onTap});

  final BillingRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = row.property;
    final next = p.nextBillingDate;
    return BizCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BizText.rowTitle,
                ),
                const SizedBox(height: 2),
                Text(
                  row.isBilling
                      ? '${formatInr(row.monthly)} / month'
                            '${next == null ? '' : ' · next ${formatDay(next)}'}'
                      : 'Not activated yet',
                  style: BizText.rowSubtitle,
                ),
                const SizedBox(height: 8),
                BizStatusPill(row.status.label, tone: _tone(row.status.tone)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: BizColors.chevron),
        ],
      ),
    );
  }
}
