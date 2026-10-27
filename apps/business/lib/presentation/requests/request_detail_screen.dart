// lib/presentation/requests/request_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:models/tenant/tenant_request_model.dart';

import '../../app/refresh_signals.dart';
import '../design/components/biz_banner.dart';
import '../design/components/biz_button.dart';
import '../design/components/biz_card.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_dialogs.dart';
import '../design/components/biz_header.dart';
import '../design/components/biz_info.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_states.dart';
import '../design/tokens.dart';
import '../views/home/home_format.dart';
import '../views/home/home_sheets.dart' show whatsappNumber;
import 'firestore_request_source.dart';
import 'request_detail_actions.dart';
import 'request_detail_viewmodel.dart';
import 'request_models.dart';
import 'request_source.dart';

BizTone _tone(String key) => switch (key) {
      'success' => BizTone.success,
      'warning' => BizTone.warning,
      'danger' => BizTone.danger,
      'info' => BizTone.info,
      _ => BizTone.neutral,
    };

/// One enrollment request, live: who asked, what they want, the bill that was
/// sent and what the tenant paid, with the next thing the owner can do.
/// Pops with `true` when the owner rejects the request.
class RequestDetailScreen extends StatefulWidget {
  RequestDetailScreen({
    super.key,
    required this.propertyId,
    required TenantRequest request,
    this.source,
    this.actions = const DeviceRequestActions(),
    this.clock,
  }) : initial = EnrollmentRequest.fromTenantRequest(request);

  /// Opens a request the requests list already has.
  RequestDetailScreen.fromRequest({
    super.key,
    required EnrollmentRequest request,
    this.source,
    this.actions = const DeviceRequestActions(),
    this.clock,
  })  : initial = request,
        propertyId = request.propertyId;

  final String propertyId;

  /// What was known when the screen opened; shown until the live request
  /// arrives.
  final EnrollmentRequest initial;
  final RequestSource? source;
  final RequestDetailActions actions;
  final DateTime Function()? clock;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  late final RequestDetailViewModel _vm;
  late final DateTime Function() _clock;

  @override
  void initState() {
    super.initState();
    _clock = widget.clock ?? DateTime.now;
    _vm = RequestDetailViewModel(
      requestId: widget.initial.id,
      source: widget.source ?? FirestoreRequestSource(),
      initial: widget.initial,
    )..start();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  void _failed() => showBizToast(
        context,
        _vm.actionError ?? "Couldn't update the request. Try again.",
        tone: BizTone.danger,
      );

  Future<void> _reject() async {
    final ok = await showBizConfirm(
      context,
      title: 'Reject this request?',
      message: "${_vm.request?.displayName ?? 'This tenant'}'s request will be turned down. "
          "You can't undo this.",
      confirmLabel: 'Reject',
      destructive: true,
    );
    if (!ok || !mounted) return;
    if (await _vm.reject()) {
      if (!mounted) return;
      RefreshSignals.raise(context, tenants: true);
      showBizToast(context, 'Request rejected.');
      Navigator.of(context).pop(true);
    } else if (mounted) {
      _failed();
    }
  }

  Future<void> _approve() async {
    final r = _vm.request;
    if (r == null) return;
    await widget.actions.openApproval(context, r);
  }

  Future<void> _confirmPayment() async {
    final r = _vm.request;
    if (r == null) return;
    final total = r.bill?.total;
    final txn = r.payment?.transactionId;
    final where = r.bill?.location ?? '';
    final ok = await showBizConfirm(
      context,
      title: 'Confirm payment?',
      message: 'Have you checked ${total == null ? 'the amount' : formatInr(total)}'
          '${txn == null ? '' : ' (transaction $txn)'} in your account? '
          'Confirming adds ${r.displayName}${where.isEmpty ? '' : ' to $where'}.',
      confirmLabel: 'Yes, confirm',
    );
    if (!ok || !mounted) return;
    if (await _vm.confirmPayment()) {
      if (mounted) {
        RefreshSignals.raise(context, payments: true, tenants: true, properties: true);
        showBizToast(context, 'Payment confirmed. The tenant is being added.', tone: BizTone.success);
      }
    } else if (mounted) {
      _failed();
    }
  }

  Future<void> _rejectPayment() async {
    final reason = await showBizTextPrompt(
      context,
      title: 'Why is the payment rejected?',
      message: 'The tenant sees this and can pay again.',
      hint: 'e.g. Amount received is short by ₹500',
      confirmLabel: 'Reject',
    );
    if (reason == null || !mounted) return;
    if (await _vm.rejectPayment(reason)) {
      if (mounted) {
        RefreshSignals.raise(context, payments: true);
        showBizToast(context, 'Payment rejected. The tenant can try again.');
      }
    } else if (mounted) {
      _failed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final r = _vm.request;
        return BizScaffold(
          title: r?.displayName ?? 'Request',
          eyebrow: r?.propertyName,
          showBack: true,
          bottomBar: r == null || _vm.missing ? null : _bottomBar(r),
          body: _body(r),
        );
      },
    );
  }

  Widget? _bottomBar(EnrollmentRequest r) {
    switch (r.stage) {
      case RequestStage.pending:
        return Row(
          children: [
            Expanded(
              child: BizButton(
                label: 'Reject',
                kind: BizButtonKind.danger,
                size: BizButtonSize.medium,
                onPressed: _vm.busy ? null : _reject,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: BizButton(
                label: 'Approve',
                size: BizButtonSize.medium,
                onPressed: _vm.busy ? null : _approve,
              ),
            ),
          ],
        );
      case RequestStage.paymentSubmitted:
        return Row(
          children: [
            Expanded(
              child: BizButton(
                label: 'Reject payment',
                kind: BizButtonKind.danger,
                size: BizButtonSize.medium,
                onPressed: _vm.busy ? null : _rejectPayment,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BizButton(
                label: 'Confirm payment',
                size: BizButtonSize.medium,
                loading: _vm.busy,
                onPressed: _vm.busy ? null : _confirmPayment,
              ),
            ),
          ],
        );
      case RequestStage.approvalFailed:
        return BizButton(
          label: 'Try again',
          loading: _vm.busy,
          onPressed: _vm.busy ? null : _retryApproval,
        );
      default:
        return null;
    }
  }

  Future<void> _retryApproval() async {
    if (await _vm.retryApproval()) {
      if (mounted) {
        RefreshSignals.raise(context, tenants: true, properties: true);
        showBizToast(context, 'Trying again…');
      }
    } else if (mounted) {
      _failed();
    }
  }

  Widget _body(EnrollmentRequest? r) {
    if (_vm.missing) {
      return const BizEmptyState(
        icon: Icons.inbox_outlined,
        title: 'This request no longer exists',
        message: 'The tenant may have withdrawn it.',
      );
    }
    if (r == null) {
      if (_vm.error != null) {
        return BizErrorState(message: _vm.error!, onRetry: _vm.retry);
      }
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: BizSkeletonList(count: 3, cardHeight: 120),
      );
    }

    final bottom = MediaQuery.viewPaddingOf(context).bottom + 28;
    final now = _clock();
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottom),
      children: [
        if (_vm.error != null) ...[
          BizBanner(
            message: '${_vm.error!} Showing the last details. Tap to try again.',
            tone: BizTone.warning,
            onTap: _vm.retry,
          ),
          const SizedBox(height: 12),
        ],
        _StageCard(request: r, now: now),
        const SizedBox(height: 14),
        _TenantCard(request: r, actions: widget.actions),
        const SizedBox(height: 14),
        _StayCard(request: r),
        if (r.bill != null) ...[
          const SizedBox(height: 14),
          _BillCard(bill: r.bill!, lastRejection: r.stage == RequestStage.billSent ? r.payment?.rejectionReason : null),
        ],
        if (r.payment?.transactionId != null || r.payment?.submittedAt != null) ...[
          const SizedBox(height: 14),
          _PaymentCard(payment: r.payment!, actions: widget.actions),
        ],
        const SizedBox(height: 14),
        _TimelineCard(request: r),
      ],
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.request, required this.now});

  final EnrollmentRequest request;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final stage = request.stage;
    final updated = request.updatedAt ?? request.createdAt;
    final why = request.approvalProblem;
    return BizCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BizStatusPill(stage.label, tone: _tone(stage.tone)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Updated ${agoLabel(updated, now)}',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BizText.caption,
                ),
              ),
            ],
          ),
          if (stage.nextStep.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(stage.nextStep, style: BizText.body.copyWith(height: 1.4)),
          ],
          if (stage == RequestStage.approvalFailed && why != null) ...[
            const SizedBox(height: 12),
            BizBanner(message: why, tone: BizTone.danger),
          ],
        ],
      ),
    );
  }
}

class _TenantCard extends StatelessWidget {
  const _TenantCard({required this.request, required this.actions});

  final EnrollmentRequest request;
  final RequestDetailActions actions;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final hasPhone = r.phone.isNotEmpty;
    return BizInfoCard(
      title: 'Tenant',
      children: [
        BizInfoRow(
          'Phone',
          hasPhone ? r.phone : 'Not provided',
          muted: !hasPhone,
          trailing: hasPhone
              ? BizRoundButton(
                  icon: Icons.copy_rounded,
                  iconSize: 16,
                  size: 34,
                  tooltip: 'Copy phone number',
                  onTap: () => actions.copy(context, r.phone, message: 'Phone number copied'),
                )
              : null,
        ),
        BizInfoRow('Email', r.email ?? 'Not provided', muted: r.email == null),
        if (hasPhone) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: BizButton(
                  label: 'Call',
                  icon: Icons.call_rounded,
                  kind: BizButtonKind.tonal,
                  size: BizButtonSize.compact,
                  onPressed: () => actions.call(context, r.phone),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BizButton(
                  label: 'WhatsApp',
                  icon: Icons.chat_bubble_outline_rounded,
                  kind: BizButtonKind.tonal,
                  size: BizButtonSize.compact,
                  onPressed: () {
                    final number = whatsappNumber(r.phone);
                    if (number == null) {
                      showBizToast(context, 'No valid phone number to message.');
                      return;
                    }
                    actions.openUrl(context, Uri.https('wa.me', '/$number'));
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StayCard extends StatelessWidget {
  const _StayCard({required this.request});

  final EnrollmentRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return BizInfoCard(
      title: 'Stay',
      children: [
        BizInfoRow('Room type', r.sharingLabel ?? 'No preference', muted: r.sharingLabel == null),
        if (r.hasAC != null) BizInfoRow('AC', r.hasAC! ? 'Yes' : 'No'),
        BizInfoRow(
          'Move-in',
          r.moveIn == null ? 'Not given' : formatDay(r.moveIn!),
          muted: r.moveIn == null,
        ),
        if (r.source != null) BizInfoRow('Came from', _sourceLabel(r.source!)),
        if (r.notes != null) ...[
          const SizedBox(height: 8),
          Text('Note from the tenant', style: BizText.rowSubtitle),
          const SizedBox(height: 4),
          Text(r.notes!, style: BizText.body.copyWith(height: 1.4)),
        ],
      ],
    );
  }

  static String _sourceLabel(String s) {
    switch (s) {
      case 'qr':
      case 'qr_scan':
        return 'QR code';
      case 'explore':
        return 'Explore';
      case 'link':
        return 'Shared link';
      default:
        return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
    }
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill, this.lastRejection});

  final RequestBill bill;
  final String? lastRejection;

  @override
  Widget build(BuildContext context) {
    final b = bill;
    final pay = [if (b.paymentLabel != null) b.paymentLabel!, if (b.ownerUpiId != null) b.ownerUpiId!]
        .join(' · ');
    return BizInfoCard(
      title: 'First bill',
      children: [
        if (lastRejection != null) ...[
          const SizedBox(height: 4),
          BizBanner(
            message: 'Last payment was rejected: $lastRejection',
            tone: BizTone.danger,
          ),
          const SizedBox(height: 6),
        ],
        if (b.location.isNotEmpty) BizInfoRow('Bed', b.location),
        if (b.monthlyRent != null) BizInfoRow('Monthly rent', formatInr(b.monthlyRent!)),
        if (b.proratedRent != null) BizInfoRow('First month', formatInr(b.proratedRent!)),
        if (b.deposit != null && b.deposit! > 0) BizInfoRow('Deposit', formatInr(b.deposit!)),
        if (b.maintenance != null && b.maintenance! > 0)
          BizInfoRow('Maintenance', '${formatInr(b.maintenance!)} at exit'),
        if (b.total != null)
          BizInfoRow('Total', formatInr(b.total!)),
        if (pay.isNotEmpty) BizInfoRow('Pay via', pay),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment, required this.actions});

  final RequestPayment payment;
  final RequestDetailActions actions;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    return BizInfoCard(
      title: 'Payment from the tenant',
      children: [
        if (p.transactionId != null)
          BizInfoRow(
            'Transaction',
            p.transactionId!,
            trailing: BizRoundButton(
              icon: Icons.copy_rounded,
              iconSize: 16,
              size: 34,
              tooltip: 'Copy transaction ID',
              onTap: () => actions.copy(context, p.transactionId!, message: 'Transaction ID copied'),
            ),
          ),
        if (p.submittedAt != null) BizInfoRow('Submitted', formatDay(p.submittedAt!)),
      ],
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.request});

  final EnrollmentRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return BizInfoCard(
      title: 'Timeline',
      children: [
        BizInfoRow('Requested', formatDay(r.createdAt)),
        if (r.bill?.sentAt != null) BizInfoRow('Billed', formatDay(r.bill!.sentAt!)),
        if (r.payment?.confirmedAt != null) BizInfoRow('Confirmed', formatDay(r.payment!.confirmedAt!)),
      ],
    );
  }
}
