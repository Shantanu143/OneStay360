// lib/presentation/payments/rent_payment_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/sources.dart';
import '../../data/tenant_session.dart';
import '../common/device_actions.dart';
import '../common/format.dart';
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
import '../stay/stay_feed.dart';
import 'payment_widgets.dart';
import 'rent_payment_viewmodel.dart';

/// Pay rent: online through the owner's link, by UPI, or report cash.
class RentPaymentScreen extends StatefulWidget {
  const RentPaymentScreen({super.key, this.invoice});

  /// Null to report a payment no invoice was issued for.
  final RentInvoice? invoice;

  @override
  State<RentPaymentScreen> createState() => _RentPaymentScreenState();
}

class _RentPaymentScreenState extends State<RentPaymentScreen> with WidgetsBindingObserver {
  RentPaymentViewModel? _vm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final stay = context.read<StayFeed>().stay;
    final tenantId = context.read<TenantSession>().tenantId;
    if (stay != null && tenantId != null) {
      _vm = RentPaymentViewModel(
        source: context.read<TenantBackend>(),
        stay: stay,
        tenantId: tenantId,
        invoice: widget.invoice,
      )..load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vm?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the payment page: the webhook marks the invoice paid, and the
    // feed sees it. Close if that already happened.
    if (state == AppLifecycleState.resumed && _vm?.stage == RentStage.awaitingOnline) setState(() {});
  }

  Future<void> _act() async {
    final vm = _vm!;
    HapticFeedback.mediumImpact();
    if (vm.method == RentMethod.online) {
      final url = await vm.startOnlinePayment();
      if (url != null && mounted) await openExternal(context, Uri.parse(url));
      return;
    }
    if (await vm.submitManual() && mounted) {
      HapticFeedback.heavyImpact();
      showAppToast(context, 'Sent to your owner to confirm', tone: AppTone.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    if (vm == null) {
      return const AppScaffold(
        title: 'Pay rent',
        body: AppEmptyState(
          icon: Icons.bed_outlined,
          title: 'No stay yet',
          message: 'You can pay rent once you have joined a PG.',
        ),
      );
    }
    final feed = context.watch<StayFeed>();
    final paidMeanwhile = widget.invoice != null &&
        feed.invoices.any((i) => i.id == widget.invoice!.id && i.status == InvoiceStatus.paid);

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final done = vm.stage == RentStage.submitted || paidMeanwhile;
        return AppScaffold(
          title: widget.invoice == null ? 'Report a payment' : 'Pay rent',
          eyebrow: vm.stay.propertyName,
          bottomBar: done || vm.loading
              ? null
              : AppButton(
                  label: vm.actionLabel,
                  icon: vm.method == RentMethod.online ? Icons.lock_rounded : Icons.check_rounded,
                  loading: vm.busy,
                  onPressed: _act,
                ),
          body: SmoothSwitch(
            child: vm.loading
                ? const Padding(
                    key: ValueKey('loading'),
                    padding: EdgeInsets.all(16),
                    child: AppSkeletonList(count: 3, cardHeight: 90),
                  )
                : done
                    ? PaymentDone(
                        key: const ValueKey('done'),
                        title: paidMeanwhile ? 'Rent paid' : 'Sent to your owner',
                        message: paidMeanwhile
                            ? 'Your payment is confirmed. Thank you!'
                            : 'They will confirm it shortly. You can follow it in Payments.',
                        onDone: () => Navigator.of(context).pop(),
                      )
                    : _Form(key: const ValueKey('form'), vm: vm),
          ),
        );
      },
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({super.key, required this.vm});

  final RentPaymentViewModel vm;

  @override
  Widget build(BuildContext context) {
    final invoice = vm.invoice;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        AmountCard(
          label: invoice == null ? 'Amount paid' : 'Rent for ${vm.month}',
          amount: vm.amount,
          caption: invoice?.dueDate == null ? vm.stay.roomLabel : dueLabel(invoice!.dueDate!, DateTime.now()),
          warn: invoice?.isOverdueAt(DateTime.now()) ?? false,
        ),
        if (!vm.amountLocked) ...[
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Amount (₹)',
                  fieldKey: const Key('rent-amount'),
                  initialValue: vm.amountText,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
                  onChanged: vm.setAmount,
                  errorText: vm.amountError,
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('For the month of', style: AppText.fieldLabel),
                ),
                AppChoiceWrap<String>(
                  options: vm.monthOptions,
                  selected: vm.month,
                  onChanged: vm.setMonth,
                  onCard: true,
                ),
              ],
            ),
          ),
        ],
        if (vm.error != null) ...[
          const SizedBox(height: 14),
          AppBanner(message: vm.error!, tone: AppTone.danger),
        ],
        const SizedBox(height: 20),
        const AppSectionLabel('HOW YOU PAY'),
        for (final m in vm.methods) ...[
          MethodTile(
            title: m.label,
            subtitle: m.subtitle,
            icon: switch (m) {
              RentMethod.online => Icons.credit_card_rounded,
              RentMethod.upi => Icons.qr_code_2_rounded,
              RentMethod.cash => Icons.payments_rounded,
            },
            badge: m == RentMethod.online ? 'Fastest' : null,
            selected: vm.method == m,
            onTap: () => vm.select(m),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        SmoothSwitch(
          child: switch (vm.method) {
            RentMethod.online => InfoNote(
                key: const ValueKey('online'),
                icon: Icons.verified_user_rounded,
                text: 'You will pay on a secure Razorpay page. Your rent is marked paid automatically when it goes through.',
              ),
            RentMethod.cash => InfoNote(
                key: const ValueKey('cash'),
                icon: Icons.info_outline_rounded,
                text: 'Hand the cash to your owner. It shows as "being confirmed" until they mark it received.',
              ),
            RentMethod.upi => Column(
                key: const ValueKey('upi'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (vm.ownerUpiId != null)
                    UpiCard(
                      upiId: vm.ownerUpiId!,
                      onOpenApp: vm.upiIntent == null ? null : () => openExternal(context, vm.upiIntent!),
                    )
                  else
                    const InfoNote(
                      icon: Icons.info_outline_rounded,
                      text: 'Your owner has not added a UPI ID here. Pay to the ID they gave you, then add the reference.',
                    ),
                  const SizedBox(height: 14),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: AppTextField(
                      label: 'UPI reference (UTR)',
                      fieldKey: const Key('rent-reference'),
                      hint: '12-digit number from your UPI app',
                      helper: 'Find it in the payment details of your UPI app.',
                      textInputAction: TextInputAction.done,
                      onChanged: vm.setReference,
                      errorText: vm.referenceError,
                    ),
                  ),
                ],
              ),
          },
        ),
      ],
    );
  }
}
