// lib/presentation/payments/request_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/tenant_shell.dart';
import '../../data/models.dart';
import '../../data/sources.dart';
import '../../data/tenant_session.dart';
import '../common/device_actions.dart';
import '../common/format.dart';
import '../common/widgets.dart';
import '../design/components/app_banner.dart';
import '../design/components/app_button.dart';
import '../design/components/app_card.dart';
import '../design/components/app_chips.dart';
import '../design/components/app_dialogs.dart';
import '../design/components/app_scaffold.dart';
import '../design/components/app_section_label.dart';
import '../design/components/app_states.dart';
import '../design/components/app_text_field.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../home/home_cards.dart' show journeySteps;
import 'payment_widgets.dart';
import 'request_viewmodel.dart';

/// One request to join a PG, live: its progress, the first bill and how to
/// pay it, or why it was turned down.
class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  late final RequestViewModel _vm = RequestViewModel(
    source: context.read<TenantBackend>(),
    requestId: widget.requestId,
    uid: context.read<TenantSession>().uid ?? '',
  );

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _confirmPaid() async {
    HapticFeedback.mediumImpact();
    if (await _vm.confirmPaid() && mounted) {
      showAppToast(context, 'Sent. Your owner will confirm it.', tone: AppTone.success);
    }
  }

  Future<void> _withdraw() async {
    final ok = await showAppConfirm(
      context,
      title: 'Withdraw request?',
      message: 'The owner will no longer see it. You can send a new one later.',
      confirmLabel: 'Withdraw',
      destructive: true,
    );
    if (!ok || !mounted) return;
    if (await _vm.withdraw() && mounted) {
      showAppToast(context, 'Request withdrawn');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final r = _vm.request;
        final paying = r?.stage == EnrollmentStage.billSent;
        return AppScaffold(
          title: r?.propertyName ?? 'Your request',
          eyebrow: 'Request to join',
          bottomBar: paying
              ? AppButton(
                  label: "I've paid ${formatInr(r!.total)}",
                  icon: Icons.check_rounded,
                  loading: _vm.busy,
                  onPressed: _confirmPaid,
                )
              : null,
          body: SmoothSwitch(
            child: _vm.loading
                ? const Padding(
                    key: ValueKey('loading'),
                    padding: EdgeInsets.all(16),
                    child: AppSkeletonList(count: 3, cardHeight: 110),
                  )
                : _vm.missing
                    ? const AppEmptyState(
                        key: ValueKey('missing'),
                        icon: Icons.inbox_outlined,
                        title: 'Request not found',
                        message: 'It may have been withdrawn.',
                      )
                    : _Body(key: ValueKey(r!.stage), vm: _vm, onWithdraw: _withdraw),
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({super.key, required this.vm, required this.onWithdraw});

  final RequestViewModel vm;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final r = vm.request!;
    if (r.stage == EnrollmentStage.confirmed) {
      return PaymentDone(
        title: 'Welcome home!',
        message: 'Your payment is confirmed and your bed is yours. Everything about your stay is in My stay.',
        icon: Icons.celebration_rounded,
        onDone: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
          try {
            context.read<ShellController>().goTo(ShellTab.stay);
          } catch (_) {}
        },
      );
    }

    final (message, tone) = switch (r.stage) {
      EnrollmentStage.pending => ('The owner is reviewing your request. We will tell you when they reply.', AppTone.warning),
      EnrollmentStage.approved => ('Approved! The owner is getting your room ready.', AppTone.success),
      EnrollmentStage.billSent => ('Your room is held for you. Pay the first bill below to confirm it.', AppTone.info),
      EnrollmentStage.paymentSubmitted => ('Thanks! The owner is checking your payment. This usually takes a few hours.', AppTone.warning),
      EnrollmentStage.rejected => (
          'The owner could not accept this request${r.rejectionReason == null ? '.' : ': ${r.rejectionReason}'}',
          AppTone.danger,
        ),
      EnrollmentStage.failed => ('Your payment is in. The owner is finishing your move-in.', AppTone.warning),
      _ => ('Your request is in progress.', AppTone.neutral),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        EntranceFade(
          child: AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Progress', style: AppText.cardTitle)),
                    AppStatusPill(r.stage.label, tone: tone),
                  ],
                ),
                const SizedBox(height: 16),
                if (r.stage != EnrollmentStage.rejected) ...[
                  StepTrack(steps: journeySteps, current: r.stage.step, failed: r.stage == EnrollmentStage.failed),
                  const SizedBox(height: 16),
                ],
                Text(message, style: AppText.body.copyWith(color: AppColors.inkSoft, height: 1.4)),
                if (r.moveIn != null || r.placement != null) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (r.moveIn != null) AppStatusPill('Move-in ${formatDay(r.moveIn!)}', dot: false),
                      if (r.placement != null) AppStatusPill(r.placement!, dot: false),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (r.lines.isNotEmpty || r.total > 0) ...[
          const SizedBox(height: 20),
          const AppSectionLabel('FIRST BILL'),
          EntranceFade(
            delay: const Duration(milliseconds: 80),
            child: AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  for (final line in r.lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(child: Text(line.label, style: AppText.body.copyWith(color: AppColors.inkSoft))),
                          Text(formatInr(line.amount), style: AppText.bodyStrong),
                        ],
                      ),
                    ),
                  if (r.lines.isNotEmpty) const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(child: Text('Total', style: AppText.cardTitle)),
                      Text(formatInr(r.total), style: AppText.style(20, 800, letterSpacing: -0.3)),
                    ],
                  ),
                  if (r.monthlyRent != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Then ${formatInr(r.monthlyRent!)} a month', style: AppText.caption),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (r.stage == EnrollmentStage.billSent) ...[
          if (r.paymentRejectionReason != null) ...[
            const SizedBox(height: 14),
            AppBanner(
              message: 'Your owner sent back the last payment: ${r.paymentRejectionReason}. Check and try again.',
              tone: AppTone.danger,
            ),
          ],
          const SizedBox(height: 20),
          const AppSectionLabel('HOW TO PAY'),
          _HowToPay(vm: vm),
          if (vm.error != null) ...[
            const SizedBox(height: 14),
            AppBanner(message: vm.error!, tone: AppTone.danger),
          ],
        ],
        if (r.stage == EnrollmentStage.paymentSubmitted && r.transactionId != null && r.transactionId != 'CASH') ...[
          const SizedBox(height: 14),
          Text('Reference sent: ${r.transactionId}', textAlign: TextAlign.center, style: AppText.caption),
        ],
        if (vm.canWithdraw) ...[
          const SizedBox(height: 24),
          AppButton(
            label: 'Withdraw request',
            kind: AppButtonKind.danger,
            size: AppButtonSize.medium,
            loading: vm.busy,
            onPressed: onWithdraw,
          ),
        ],
      ],
    );
  }
}

class _HowToPay extends StatelessWidget {
  const _HowToPay({required this.vm});

  final RequestViewModel vm;

  @override
  Widget build(BuildContext context) {
    final r = vm.request!;
    final reference = AppCard(
      padding: const EdgeInsets.all(16),
      child: AppTextField(
        label: vm.referenceLabel,
        fieldKey: const Key('bill-reference'),
        hint: '12-digit number',
        helper: 'The owner uses it to find your payment.',
        onChanged: vm.setReference,
        errorText: vm.referenceError,
      ),
    );
    return switch (r.paymentMode) {
      BillPaymentMode.bank => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
              child: Column(
                children: [
                  if (r.bank?.accountHolderName != null) CopyRow('Name', r.bank!.accountHolderName!),
                  if (r.bank?.bankName != null) CopyRow('Bank', r.bank!.bankName!),
                  if (r.bank?.accountNumber != null) CopyRow('Account no.', r.bank!.accountNumber!),
                  if (r.bank?.ifscCode != null) CopyRow('IFSC', r.bank!.ifscCode!),
                ],
              ),
            ),
            const SizedBox(height: 14),
            reference,
          ],
        ),
      BillPaymentMode.cash => const InfoNote(
          icon: Icons.payments_rounded,
          text: 'Pay this in cash to your owner, then tap the button below so they can confirm it.',
        ),
      _ => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (r.ownerUpiId != null)
              UpiCard(
                upiId: r.ownerUpiId!,
                onOpenApp: vm.upiIntent == null ? null : () => openExternal(context, vm.upiIntent!),
              )
            else
              const InfoNote(
                icon: Icons.info_outline_rounded,
                text: 'Pay your owner the way they asked, then add the reference here.',
              ),
            const SizedBox(height: 14),
            reference,
          ],
        ),
    };
  }
}
