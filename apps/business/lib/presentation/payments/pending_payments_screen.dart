// lib/presentation/payments/pending_payments_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/refresh_signals.dart';
import '../../data/providers/business_state_provider.dart';
import '../common/device_actions.dart';
import '../design/components/biz_button.dart';
import '../design/components/biz_card.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_dialogs.dart';
import '../design/components/biz_header.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_states.dart';
import '../design/tokens.dart';
import '../requests/firestore_request_source.dart';
import '../requests/request_source.dart';
import '../views/home/home_format.dart';
import 'firestore_pending_source.dart';
import 'pending_source.dart';
import 'pending_viewmodel.dart';

/// What the screen asks the phone to do. Faked in tests.
abstract class PendingPaymentsActions {
  Future<void> copy(BuildContext context, String text, {String? message});

  Future<void> openUrl(BuildContext context, Uri uri);
}

class DevicePendingActions implements PendingPaymentsActions {
  const DevicePendingActions();

  @override
  Future<void> copy(BuildContext context, String text, {String? message}) =>
      copyText(context, text, message: message);

  @override
  Future<void> openUrl(BuildContext context, Uri uri) => openExternal(context, uri);
}

/// Payments tenants say they made, for the owner to check against their
/// account: monthly rent and enrollment deposits.
class PendingPaymentsScreen extends StatefulWidget {
  const PendingPaymentsScreen({
    super.key,
    required this.businessId,
    this.propertyId,
    this.source,
    this.requestSource,
    this.actions = const DevicePendingActions(),
    this.clock,
  });

  final String businessId;

  /// Only this property's payments.
  final String? propertyId;
  final PendingPaymentsSource? source;
  final RequestSource? requestSource;
  final PendingPaymentsActions actions;
  final DateTime Function()? clock;

  @override
  State<PendingPaymentsScreen> createState() => _PendingPaymentsScreenState();
}

class _PendingPaymentsScreenState extends State<PendingPaymentsScreen> {
  late final PendingPaymentsViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = PendingPaymentsViewModel(
      businessId: widget.businessId,
      propertyId: widget.propertyId,
      source: widget.source ??
          FirestorePendingSource(
            propertyScope: () {
              try {
                return context.read<BusinessStateProvider>().propertyScope;
              } on ProviderNotFoundException {
                return null;
              }
            },
          ),
      requests: widget.requestSource ?? FirestoreRequestSource(),
    )..start();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _confirm({
    required String who,
    required double amount,
    required Future<bool> Function() run,
    String? what,

    /// A confirmed deposit turns the enrolment into a tenant in a bed.
    bool addsTenant = false,
  }) async {
    final ok = await showBizConfirm(
      context,
      title: 'Confirm payment?',
      message: 'Have you received ${formatInr(amount)} from $who${what == null ? '' : ' for $what'}? '
          'Only confirm after you have seen it in your account.',
      confirmLabel: 'Yes, confirm',
    );
    if (!ok || !mounted) return;
    if (await run()) {
      if (mounted) {
        RefreshSignals.raise(context, payments: true, tenants: addsTenant, properties: addsTenant);
        showBizToast(context, 'Payment confirmed.', tone: BizTone.success);
      }
    } else if (mounted) {
      showBizToast(context, _vm.actionError ?? "Couldn't update that payment.", tone: BizTone.danger);
    }
  }

  Future<void> _reject({required Future<bool> Function(String reason) run}) async {
    final reason = await showBizTextPrompt(
      context,
      title: 'Why is it rejected?',
      message: 'The tenant sees this and can pay again.',
      hint: 'e.g. Amount received is short by ₹500',
      confirmLabel: 'Reject',
    );
    if (reason == null || !mounted) return;
    if (await run(reason)) {
      if (mounted) {
        RefreshSignals.raise(context, payments: true);
        showBizToast(context, 'Payment rejected. The tenant can try again.');
      }
    } else if (mounted) {
      showBizToast(context, _vm.actionError ?? "Couldn't update that payment.", tone: BizTone.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final total = _vm.total;
        return BizScaffold(
          title: 'Pending payments',
          eyebrow: _vm.loading ? null : (total == 0 ? 'All confirmed' : '$total to confirm'),
          showBack: true,
          belowHeader: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: BizFilterChips(
              chips: [
                BizChipData('Rent', count: _vm.count(PendingTab.rent)),
                BizChipData('Deposits', count: _vm.count(PendingTab.deposits)),
              ],
              selectedIndex: _vm.tab.index,
              onSelected: (i) => _vm.selectTab(PendingTab.values[i]),
            ),
          ),
          body: _vm.tab == PendingTab.rent ? _rent() : _deposits(),
        );
      },
    );
  }

  Widget _empty() => const BizEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'Nothing to confirm',
        message: 'Payments tenants submit show up here for you to check.',
      );

  Widget _rent() {
    if (_vm.rentError != null && _vm.rent.isEmpty) {
      return BizErrorState(message: _vm.rentError!, onRetry: _vm.reloadRent);
    }
    if (_vm.rentLoading && _vm.rent.isEmpty) return _loading();
    final items = _vm.rent;
    if (items.isEmpty) return _empty();
    final now = (widget.clock ?? DateTime.now)();
    return _list([
      for (final r in items)
        _PaymentCard(
          who: r.tenantName,
          subtitle: [if (r.location.isNotEmpty) r.location, r.month].join(' · '),
          amount: r.amount,
          method: r.method,
          transactionId: r.transactionId,
          screenshotUrl: r.screenshotUrl,
          submittedAt: r.submittedAt,
          now: now,
          busy: _vm.isBusy(r.paymentId),
          actions: widget.actions,
          onConfirm: () => _confirm(
            who: r.tenantName,
            amount: r.amount,
            what: r.month,
            run: () => _vm.confirmRent(r),
          ),
          onReject: () => _reject(run: (reason) => _vm.rejectRent(r, reason)),
        ),
    ]);
  }

  Widget _deposits() {
    if (_vm.depositsError != null && _vm.deposits.isEmpty) {
      return BizErrorState(message: _vm.depositsError!, onRetry: _vm.retryDeposits);
    }
    if (_vm.depositsLoading && _vm.deposits.isEmpty) return _loading();
    final items = _vm.deposits;
    if (items.isEmpty) return _empty();
    final now = (widget.clock ?? DateTime.now)();
    return _list([
      for (final d in items)
        _PaymentCard(
          who: d.displayName,
          subtitle: [if (d.bill?.location.isNotEmpty ?? false) d.bill!.location, 'First bill'].join(' · '),
          amount: d.bill?.total ?? 0,
          method: d.bill?.paymentLabel ?? 'UPI',
          transactionId: d.payment?.transactionId,
          submittedAt: d.payment?.submittedAt,
          now: now,
          busy: _vm.isBusy(d.id),
          actions: widget.actions,
          onConfirm: () => _confirm(
            who: d.displayName,
            amount: d.bill?.total ?? 0,
            addsTenant: true,
            run: () => _vm.confirmDeposit(d),
          ),
          onReject: () => _reject(run: (reason) => _vm.rejectDeposit(d, reason)),
        ),
    ]);
  }

  Widget _loading() => const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: BizSkeletonList(count: 3, cardHeight: 150),
      );

  Widget _list(List<Widget> cards) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom + 24;
    return RefreshIndicator(
      color: BizColors.green,
      onRefresh: _vm.reloadRent,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.who,
    required this.subtitle,
    required this.amount,
    required this.method,
    required this.now,
    required this.busy,
    required this.actions,
    required this.onConfirm,
    required this.onReject,
    this.transactionId,
    this.screenshotUrl,
    this.submittedAt,
  });

  final String who;
  final String subtitle;
  final double amount;
  final String method;
  final String? transactionId;
  final String? screenshotUrl;
  final DateTime? submittedAt;
  final DateTime now;
  final bool busy;
  final PendingPaymentsActions actions;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return BizCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(who, style: BizText.rowTitle),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: BizText.rowSubtitle),
                    ],
                  ],
                ),
              ),
              BizStatusPill(method, tone: BizTone.info, dot: false),
            ],
          ),
          const SizedBox(height: 14),
          Text(formatInr(amount), style: BizText.bigNumber),
          if (transactionId != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text(transactionId!, style: BizText.bodyStrong)),
                BizRoundButton(
                  icon: Icons.copy_rounded,
                  iconSize: 15,
                  size: 32,
                  tooltip: 'Copy transaction ID',
                  onTap: () => actions.copy(context, transactionId!, message: 'Transaction ID copied'),
                ),
              ],
            ),
          ],
          if (screenshotUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GestureDetector(
                onTap: () {
                  final uri = Uri.tryParse(screenshotUrl!);
                  if (uri != null) actions.openUrl(context, uri);
                },
                child: Text('View payment screenshot', style: BizText.link),
              ),
            ),
          if (submittedAt != null) ...[
            const SizedBox(height: 6),
            Text('Submitted ${agoLabel(submittedAt!, now)}', style: BizText.caption),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: BizButton(
                  label: 'Reject',
                  kind: BizButtonKind.danger,
                  size: BizButtonSize.compact,
                  onPressed: busy ? null : onReject,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: BizButton(
                  label: 'Confirm',
                  size: BizButtonSize.compact,
                  loading: busy,
                  onPressed: busy ? null : onConfirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
