// lib/presentation/requests/approval_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/payment_method_model.dart';
import '../../app/refresh_signals.dart';
import '../design/components/biz_banner.dart';
import '../design/components/biz_button.dart';
import '../design/components/biz_card.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_dialogs.dart';
import '../design/components/biz_picker_field.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_section_label.dart';
import '../design/components/biz_states.dart';
import '../design/components/biz_text_field.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../views/home/home_format.dart';
import 'approval_source.dart';
import 'approval_viewmodel.dart';
import 'bed_picker.dart';
import 'firestore_approval_source.dart';
import 'request_models.dart';

/// Approve a request: pick the bed, set the first bill, and either send the
/// bill for the tenant to pay or approve straight away and collect payment
/// yourself. Pops with `true` when the request was approved or billed.
class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({super.key, required this.request, this.source, this.today});

  final EnrollmentRequest request;
  final ApprovalSource? source;
  final DateTime Function()? today;

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> {
  late final ApprovalViewModel _vm;
  final _rent = TextEditingController();
  final _deposit = TextEditingController();
  final _maintenance = TextEditingController();
  final _foodDeduction = TextEditingController();
  final _prorated = TextEditingController();
  final _upi = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm = ApprovalViewModel(
      request: widget.request,
      source: widget.source ?? FirestoreApprovalSource(),
      today: widget.today,
    );
    _load();
  }

  Future<void> _load() async {
    await _vm.load();
    if (!mounted || _vm.property == null) return;
    _deposit.text = _plain(_vm.deposit);
    _maintenance.text = _plain(_vm.maintenance);
    _upi.text = _vm.upiId;
  }

  @override
  void dispose() {
    for (final c in [_rent, _deposit, _maintenance, _foodDeduction, _prorated, _upi]) {
      c.dispose();
    }
    _vm.dispose();
    super.dispose();
  }

  static String _plain(double v) => v == 0 ? '' : v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
  static double _num(String s) => double.tryParse(s.trim()) ?? 0;

  void _pickBed(String room, String bed) {
    _vm.selectBed(room, bed);
    if (!_vm.rentEdited) _rent.text = _plain(_vm.rent);
    // A fresh bed means a fresh prorated suggestion.
    if (_vm.proratedOverride == null) _prorated.clear();
  }

  Future<void> _pickMoveIn() async {
    final today = _vm.today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _vm.moveIn,
      firstDate: DateTime(today.year, today.month, today.day).subtract(const Duration(days: 60)),
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked != null) _vm.setMoveIn(picked);
  }

  Future<void> _pickBillingDay() async {
    final day = await showBizSheet<int>(
      context,
      title: 'Rent due day',
      subtitle: 'Rent is due on this day every month.',
      builder: (sheet) => ListView(
        shrinkWrap: true,
        children: [
          for (var d = 1; d <= 28; d++)
            BizSheetOption(
              label: _ordinal(d),
              selected: d == _vm.billingDate,
              onTap: () => Navigator.of(sheet).pop(d),
            ),
        ],
      ),
    );
    if (day != null) _vm.setBillingDate(day);
  }

  static String _ordinal(int d) {
    if (d >= 11 && d <= 13) return '${d}th of every month';
    final suffix = switch (d % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' };
    return '$d$suffix of every month';
  }

  Future<void> _submit({required bool bill}) async {
    FocusScope.of(context).unfocus();
    final ok = bill ? await _vm.sendBill() : await _vm.approve();
    if (!ok || !mounted) return;
    RefreshSignals.raise(context, tenants: true, properties: true);
    showBizToast(
      context,
      bill ? 'Bill sent. The tenant will be notified.' : 'Approved. The tenant is being added.',
      tone: BizTone.success,
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final ready = !_vm.loading && _vm.property != null;
        return BizScaffold(
          title: 'Approve request',
          eyebrow: widget.request.displayName,
          showBack: true,
          bottomBar: ready ? _bottomBar() : null,
          body: _vm.loading
              ? const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: BizSkeletonList(count: 3, cardHeight: 140),
                )
              : !ready
                  ? BizErrorState(message: _vm.error ?? "Couldn't load the rooms.", onRetry: _load)
                  : _form(),
        );
      },
    );
  }

  Widget _bottomBar() {
    final total = _vm.bill.total;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BizButton(
          label: 'Send bill · ${formatInr(total)}',
          loading: _vm.submitting,
          onPressed: _vm.submitting ? null : () => _submit(bill: true),
        ),
        const SizedBox(height: 8),
        BizButton(
          label: "Approve, I'll collect payment myself",
          kind: BizButtonKind.outline,
          size: BizButtonSize.medium,
          onPressed: _vm.submitting ? null : () => _submit(bill: false),
        ),
      ],
    );
  }

  Widget _form() {
    final bottom = MediaQuery.viewPaddingOf(context).bottom + 24;
    final bill = _vm.bill;
    final firstMonthHint = _plain(bill.autoProratedRent);

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (_vm.error != null) ...[
          BizBanner(message: _vm.error!, tone: BizTone.danger),
          const SizedBox(height: 12),
        ],
        _Requested(request: widget.request),
        const SizedBox(height: 16),
        const BizSectionLabel('Choose a bed'),
        BedPicker(
          floors: _vm.floors,
          selectedRoom: _vm.selectedRoom?.number,
          selectedBed: _vm.selectedBed,
          onSelect: _pickBed,
          highlight: _vm.matchesRequest,
        ),
        const SizedBox(height: 12),
        const BizSectionLabel('Rent and deposit'),
        BizCard(
          child: Column(
            children: [
              BizTextField(
                label: 'Monthly rent (₹)',
                fieldKey: const Key('rent'),
                controller: _rent,
                hint: 'Filled in from the bed you choose',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) => _vm.setRent(_num(v)),
              ),
              const SizedBox(height: 12),
              BizTextField(
                label: 'Security deposit (₹)',
                fieldKey: const Key('deposit'),
                controller: _deposit,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) => _vm.setDeposit(_num(v)),
              ),
              const SizedBox(height: 12),
              BizTextField(
                label: 'Maintenance, one-time (₹)',
                fieldKey: const Key('maintenance'),
                controller: _maintenance,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                helper: _vm.maintenanceFromDeposit
                    ? 'Taken from the deposit refund when they leave.'
                    : 'Taken from the refund when they leave.',
                onChanged: (v) => _vm.setMaintenance(_num(v)),
              ),
              const SizedBox(height: 8),
              _Toggle(
                title: 'Collect deposit now',
                subtitle: 'Turn off to let them pay it later.',
                value: _vm.depositNow,
                onChanged: _vm.setDepositNow,
              ),
              _Toggle(
                title: 'Food included',
                subtitle: 'Turn off to take a food amount off the rent.',
                value: _vm.foodIncluded,
                onChanged: _vm.setFoodIncluded,
              ),
              if (!_vm.foodIncluded)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: BizTextField(
                    label: 'Food deduction per month (₹)',
                    fieldKey: const Key('food-deduction'),
                    controller: _foodDeduction,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) => _vm.setFoodDeduction(_num(v)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const BizSectionLabel('Dates'),
        BizCard(
          child: Column(
            children: [
              BizPickerField(
                label: 'Move-in date',
                placeholder: 'Pick a date',
                value: formatDay(_vm.moveIn),
                onTap: _pickMoveIn,
              ),
              const SizedBox(height: 12),
              BizPickerField(
                label: 'Rent due',
                placeholder: 'Pick a day',
                value: _ordinal(_vm.billingDate),
                icon: Icons.event_repeat_rounded,
                onTap: _pickBillingDay,
              ),
              const SizedBox(height: 12),
              BizTextField(
                label: 'First month rent (₹)',
                fieldKey: const Key('prorated'),
                controller: _prorated,
                hint: firstMonthHint.isEmpty ? 'Worked out from the move-in date' : firstMonthHint,
                helper: bill.prorationNote,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) => _vm.setProratedOverride(v.trim().isEmpty ? null : _num(v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const BizSectionLabel('First bill'),
        _BillCard(vm: _vm),
        const SizedBox(height: 16),
        const BizSectionLabel('How the tenant pays'),
        _PaymentCard(vm: _vm, upi: _upi),
      ],
    );
  }
}

class _Requested extends StatelessWidget {
  const _Requested({required this.request});

  final EnrollmentRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final wants = [
      if (r.sharingLabel != null) r.sharingLabel!,
      if (r.hasAC == true) 'AC',
      if (r.moveIn != null) 'from ${formatDay(r.moveIn!)}',
    ].join(' · ');
    return BizBanner(
      tone: BizTone.info,
      icon: Icons.person_outline_rounded,
      message: wants.isEmpty
          ? '${r.displayName} did not say what room they want.'
          : '${r.displayName} asked for $wants.',
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.99,
      onTap: () => onChanged(!value),
      semanticLabel: title,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: BizText.rowTitle),
                  const SizedBox(height: 2),
                  Text(subtitle, style: BizText.rowSubtitle),
                ],
              ),
            ),
            IgnorePointer(
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: BizColors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.vm});

  final ApprovalViewModel vm;

  @override
  Widget build(BuildContext context) {
    final rows = vm.bill.rows;
    return BizCard(
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.label,
                          style: row.isTotal ? BizText.rowTitle : BizText.style(15, 400, color: BizColors.inkSoft),
                        ),
                      ),
                      Text(
                        formatInr(row.amount),
                        style: row.isTotal ? BizText.style(20, 800, letterSpacing: -0.3) : BizText.bodyStrong,
                      ),
                    ],
                  ),
                  if (row.note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(row.note!, style: BizText.caption),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.vm, required this.upi});

  final ApprovalViewModel vm;
  final TextEditingController upi;

  static String _describe(PaymentMethod m) {
    switch (m.type) {
      case 'upi':
        return 'UPI · ${m.upiId ?? ''}';
      case 'bank':
        final n = m.accountNumber ?? '';
        final last4 = n.length >= 4 ? n.substring(n.length - 4) : n;
        return '${m.bankName ?? 'Bank transfer'} · •••• $last4';
      default:
        return 'Cash';
    }
  }

  @override
  Widget build(BuildContext context) {
    final methods = vm.methods;
    if (methods.isEmpty) {
      return BizCard(
        child: BizTextField(
          label: 'Your UPI ID',
          fieldKey: const Key('upi'),
          controller: upi,
          hint: 'name@bank',
          helper: 'The tenant pays this ID. It is saved for next time. '
              'Add more ways to pay in Settings.',
          keyboardType: TextInputType.emailAddress,
          onChanged: vm.setUpiId,
        ),
      );
    }
    return Column(
      children: [
        for (final m in methods)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Pressable(
              scale: 0.985,
              onTap: () => vm.selectMethod(m.id),
              semanticLabel: _describe(m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(BizRadius.control + 4),
                  border: Border.all(
                    color: vm.selectedMethodId == m.id ? BizColors.green : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(_describe(m), style: BizText.rowTitle)),
                    if (m.isPreferred) const BizStatusPill('Preferred', tone: BizTone.success, dot: false),
                    if (vm.selectedMethodId == m.id)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.check_circle_rounded, color: BizColors.green, size: 22),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
