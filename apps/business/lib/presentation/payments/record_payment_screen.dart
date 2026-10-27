// lib/presentation/payments/record_payment_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/refresh_signals.dart';
import '../design/components/biz_banner.dart';
import '../design/components/biz_button.dart';
import '../design/components/biz_card.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_dialogs.dart';
import '../design/components/biz_picker_field.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_section_label.dart';
import '../design/components/biz_text_field.dart';
import '../views/home/home_format.dart';
import 'record_payment_viewmodel.dart';

/// Records money the owner received directly (cash, a cheque, a transfer
/// the tenant never submitted). Pops with `true` once it is recorded.
class RecordPaymentScreen extends StatefulWidget {
  const RecordPaymentScreen({
    super.key,
    required this.tenant,
    required this.businessId,
    this.recorder,
    this.now,
  });

  /// Reads `tenantId`/`id`, `name`, `room`, `bed` and `rent`/`monthlyRent`.
  final Map<String, dynamic> tenant;
  final String businessId;
  final PaymentRecorder? recorder;
  final DateTime Function()? now;

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  late final RecordPaymentViewModel _vm;
  late final TextEditingController _amount;

  double? get _rent {
    final v = widget.tenant['rent'] ?? widget.tenant['monthlyRent'];
    return v is num && v > 0 ? v.toDouble() : null;
  }

  @override
  void initState() {
    super.initState();
    final rent = _rent;
    _vm = RecordPaymentViewModel(
      businessId: widget.businessId,
      tenantId: (widget.tenant['tenantId'] ?? widget.tenant['id'] ?? '').toString(),
      suggestedAmount: rent,
      recorder: widget.recorder ?? CallablePaymentRecorder(),
      now: widget.now,
    );
    _amount = TextEditingController(
      text: rent == null ? '' : rent.toStringAsFixed(rent.truncateToDouble() == rent ? 0 : 2),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _pickMonth() async {
    final month = await showBizSheet<String>(
      context,
      title: 'Which month is it for?',
      builder: (sheet) => ListView(
        shrinkWrap: true,
        children: [
          for (final m in _vm.months)
            BizSheetOption(
              label: m,
              selected: m == _vm.month,
              onTap: () => Navigator.of(sheet).pop(m),
            ),
        ],
      ),
    );
    if (month != null) _vm.selectMonth(month);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (await _vm.submit()) {
      if (!mounted) return;
      RefreshSignals.raise(context, payments: true);
      showBizToast(context, 'Payment recorded.', tone: BizTone.success);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.tenant['name'] ?? 'Tenant').toString();
    final room = (widget.tenant['room'] ?? '').toString();
    final bed = (widget.tenant['bed'] ?? '').toString();
    final where = [
      if (room.isNotEmpty) 'Room $room',
      if (bed.isNotEmpty) 'Bed $bed',
      if (_rent != null) 'rent ${formatInr(_rent!)}',
    ].join(' · ');
    final bottom = MediaQuery.viewPaddingOf(context).bottom + 24;

    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => BizScaffold(
        title: name,
        eyebrow: 'Record payment',
        showBack: true,
        bottomBar: BizButton(
          label: _vm.amount > 0 ? 'Record ${formatInr(_vm.amount)}' : 'Record payment',
          loading: _vm.submitting,
          onPressed: _vm.submitting ? null : _submit,
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (where.isNotEmpty) ...[
              BizBanner(message: where, tone: BizTone.info, icon: Icons.bed_outlined),
              const SizedBox(height: 14),
            ],
            if (_vm.error != null) ...[
              BizBanner(message: _vm.error!, tone: BizTone.danger),
              const SizedBox(height: 14),
            ],
            BizCard(
              child: Column(
                children: [
                  BizTextField(
                    label: 'Amount received (₹)',
                    fieldKey: const Key('amount'),
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    onChanged: (v) => _vm.setAmount(double.tryParse(v.trim()) ?? 0),
                  ),
                  const SizedBox(height: 14),
                  BizPickerField(
                    label: 'For month',
                    placeholder: 'Pick a month',
                    value: _vm.month,
                    icon: Icons.expand_more_rounded,
                    onTap: _pickMonth,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const BizSectionLabel('Paid by'),
            BizChoiceWrap<String>(
              options: RecordPaymentViewModel.modes,
              selected: _vm.mode,
              onChanged: _vm.selectMode,
            ),
            const SizedBox(height: 16),
            BizCard(
              child: Column(
                children: [
                  BizTextField(
                    label: 'Transaction ID (optional)',
                    fieldKey: const Key('txn'),
                    hint: 'UPI reference, cheque number...',
                    onChanged: _vm.setTransactionId,
                  ),
                  const SizedBox(height: 14),
                  BizTextField(
                    label: 'Note (optional)',
                    fieldKey: const Key('note'),
                    hint: 'e.g. part payment, includes late fee',
                    maxLines: 2,
                    onChanged: _vm.setNote,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
