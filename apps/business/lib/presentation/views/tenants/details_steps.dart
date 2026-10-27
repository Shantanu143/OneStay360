// lib/presentation/views/tenants/details_steps.dart
//
// Steps 2-5 of the Add Tenant wizard: tenant info, lease, first bill and
// personal details.
import 'dart:async';

import 'package:firebase_services/services/tenant_search_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../design/components/biz_banner.dart';
import '../../design/components/biz_card.dart';
import '../../design/components/biz_chips.dart';
import '../../design/components/biz_dialogs.dart';
import '../../design/components/biz_picker_field.dart';
import '../../design/components/biz_search_field.dart';
import '../../design/components/biz_section_label.dart';
import '../../design/components/biz_text_field.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../view_models/tenant_wizard/wizard_viewmodel.dart';
import '../home/home_format.dart';

/// A text input bound to the wizard state. It is re-keyed when the wizard
/// prefills values (so the new value shows) but not while typing.
Widget wizardField(
  AddTenantWizardViewModel vm,
  WizardField f,
  String label, {
  String? hint,
  TextInputType? keyboard,
  List<TextInputFormatter>? formatters,
  Widget? prefix,
  int maxLines = 1,
  TextCapitalization capitalization = TextCapitalization.none,
}) {
  return BizTextField(
    key: ValueKey('${f.name}-${vm.prefillVersion}'),
    fieldKey: ValueKey('wizard-${f.name}'),
    label: label,
    initialValue: vm.text(f),
    hint: hint,
    keyboardType: keyboard,
    inputFormatters: formatters,
    prefix: prefix,
    maxLines: maxLines,
    textCapitalization: capitalization,
    textInputAction: maxLines > 1
        ? TextInputAction.newline
        : TextInputAction.next,
    errorText: vm.showErrors ? vm.errors[f] : null,
    onChanged: (v) => vm.setText(f, v),
  );
}

final _digitsAndDot = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
final _digitsOnly = [FilteringTextInputFormatter.digitsOnly];

const _rupee = Padding(
  padding: EdgeInsets.only(left: 16, right: 4),
  child: Align(
    widthFactor: 1,
    child: Text(
      '₹',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
);

Widget _gap([double h = 14]) => SizedBox(height: h);

// ─── Step 2: tenant info ─────────────────────────────────────────────────

class TenantInfoStep extends StatefulWidget {
  const TenantInfoStep({
    super.key,
    required this.vm,
    required this.searchTenants,
    required this.openScanner,
  });

  final AddTenantWizardViewModel vm;
  final Future<List<TenantSearchResult>> Function(String query) searchTenants;
  final Future<Map<String, dynamic>?> Function() openScanner;

  @override
  State<TenantInfoStep> createState() => _TenantInfoStepState();
}

class _TenantInfoStepState extends State<TenantInfoStep> {
  static const _modes = ['Add manually', 'Search tenant', 'Scan QR'];

  List<TenantSearchResult> _results = const [];
  bool _searching = false;
  String? _searchError;
  int _searchToken = 0;

  AddTenantWizardViewModel get vm => widget.vm;

  Future<void> _onMode(int i) async {
    if (i == 0) {
      vm.setMode(TenantEntryMode.manual);
    } else if (i == 1) {
      vm.setMode(TenantEntryMode.search);
    } else {
      final data = await widget.openScanner();
      if (data != null) vm.applyScannedTenant(data);
    }
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    final token = ++_searchToken;
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final found = await widget.searchTenants(query);
      if (!mounted || token != _searchToken) return;
      setState(() {
        _results = found;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _results = const [];
        _searching = false;
        _searchError =
            "Couldn't search right now. Try again, or add the tenant manually.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final searching = vm.mode == TenantEntryMode.search;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BizSectionLabel('How do you want to add them?'),
        BizFilterChips(
          padding: EdgeInsets.zero,
          chips: [for (final m in _modes) BizChipData(m)],
          selectedIndex: searching ? 1 : 0,
          onSelected: _onMode,
        ),
        const SizedBox(height: 20),
        if (searching) _searchPanel() else _manualPanel(),
      ],
    );
  }

  Widget _searchPanel() {
    final chosen = vm.selectedTenant;
    if (chosen != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BizSectionLabel('Selected tenant'),
          BizCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(chosen.name, style: BizText.cardTitle),
                      Text(chosen.phone, style: BizText.rowSubtitle),
                    ],
                  ),
                ),
                Pressable(
                  onTap: vm.clearTenant,
                  child: Text(
                    'Change',
                    style: BizText.style(16, 600, color: BizColors.green),
                  ),
                ),
              ],
            ),
          ),
          if (vm.showErrors && vm.errors[WizardField.fullName] != null)
            _error(vm.errors[WizardField.fullName]!),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BizSearchField(hint: 'Search by name or phone', onChanged: _search),
        const SizedBox(height: 12),
        if (_searching)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_searchError != null)
          BizBanner(message: _searchError!, tone: BizTone.warning)
        else if (_results.isNotEmpty)
          BizCard(
            padding: EdgeInsets.zero,
            clip: true,
            child: Column(
              children: [
                for (var i = 0; i < _results.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 16),
                  Pressable(
                    scale: 0.99,
                    onTap: () => vm.selectTenant(_results[i]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _results[i].name,
                                  style: BizText.cardTitle,
                                ),
                                Text(
                                  _results[i].phone,
                                  style: BizText.rowSubtitle,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: BizColors.chevron,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (vm.showErrors && vm.errors[WizardField.fullName] != null)
          _error(vm.errors[WizardField.fullName]!),
      ],
    );
  }

  Widget _manualPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BizSectionLabel('Tenant details'),
        BizCard(
          child: Column(
            children: [
              wizardField(
                vm,
                WizardField.fullName,
                'Full name',
                hint: 'e.g. Amit Patel',
                capitalization: TextCapitalization.words,
              ),
              _gap(),
              wizardField(
                vm,
                WizardField.phone,
                'Phone',
                hint: '10-digit mobile number',
                keyboard: TextInputType.phone,
              ),
              _gap(),
              wizardField(
                vm,
                WizardField.altPhone,
                'Alternate phone (optional)',
                keyboard: TextInputType.phone,
              ),
              _gap(),
              wizardField(
                vm,
                WizardField.email,
                'Email (optional)',
                hint: 'name@example.com',
                keyboard: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const BizSectionLabel('Gender'),
        BizChoiceWrap<String>(
          options: const ['Male', 'Female', 'Other'],
          selected: vm.gender,
          onChanged: vm.setGender,
        ),
        const SizedBox(height: 20),
        const BizSectionLabel('Tenant type'),
        BizChoiceWrap<String>(
          options: const ['Student', 'Bachelor', 'Family', 'Professional'],
          selected: vm.tenantType,
          onChanged: vm.setTenantType,
        ),
        const SizedBox(height: 20),
        const BizSectionLabel('Food preference'),
        BizChoiceWrap<String>(
          options: const ['Veg', 'Non-Veg', 'Both'],
          selected: vm.foodPreference,
          onChanged: vm.setFoodPreference,
        ),
      ],
    );
  }

  Widget _error(String text) => Padding(
    padding: const EdgeInsets.only(top: 10, left: 4),
    child: Text(
      text,
      style: BizText.style(14, 600, color: BizColors.dangerInk),
    ),
  );
}

// ─── Step 3: lease ───────────────────────────────────────────────────────

class LeaseStep extends StatelessWidget {
  const LeaseStep({super.key, required this.vm});

  final AddTenantWizardViewModel vm;

  static final _date = DateFormat('d MMM yyyy');

  Future<void> _pickMoveIn(BuildContext context) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.moveIn ?? today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 365 * 2)),
      helpText: 'Move-in date',
    );
    if (picked != null) vm.setMoveIn(picked);
  }

  Future<void> _pickMoveOut(BuildContext context) async {
    final from = (vm.moveIn ?? DateTime.now()).add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.moveOut != null && vm.moveOut!.isAfter(from)
          ? vm.moveOut!
          : from,
      firstDate: from,
      lastDate: from.add(const Duration(days: 365 * 3)),
      helpText: 'Move-out date',
    );
    if (picked != null) vm.setMoveOut(picked);
  }

  Future<void> _pickBillingDay(BuildContext context) {
    return showBizSheet<void>(
      context,
      title: 'Billing day of the month',
      subtitle: 'Rent invoices are raised on this day.',
      builder: (sheet) => SingleChildScrollView(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var d = 1; d <= 28; d++)
              SizedBox(
                width: 52,
                height: 40,
                child: BizChip(
                  data: BizChipData('$d'),
                  selected: vm.billingDay == d,
                  onTap: () {
                    vm.setBillingDay(d);
                    Navigator.of(sheet).pop();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? err(WizardField f) => vm.showErrors ? vm.errors[f] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BizSectionLabel('Dates'),
        BizCard(
          child: Column(
            children: [
              BizPickerField(
                key: const ValueKey('wizard-moveIn'),
                label: 'Move-in date',
                placeholder: 'Select date',
                value: vm.moveIn == null ? null : _date.format(vm.moveIn!),
                error: err(WizardField.moveIn),
                onTap: () => _pickMoveIn(context),
              ),
              _gap(),
              BizPickerField(
                key: const ValueKey('wizard-moveOut'),
                label: 'Move-out date (optional)',
                placeholder: 'Open-ended',
                value: vm.moveOut == null ? null : _date.format(vm.moveOut!),
                error: err(WizardField.moveOut),
                onTap: () => _pickMoveOut(context),
              ),
              _gap(),
              BizPickerField(
                key: const ValueKey('wizard-billingDay'),
                label: 'Billing day',
                placeholder: vm.moveIn == null
                    ? 'Same as move-in day'
                    : 'Day ${vm.moveIn!.day} (move-in day)',
                value: vm.billingDay == null ? null : 'Day ${vm.billingDay}',
                icon: Icons.event_repeat_outlined,
                onTap: () => _pickBillingDay(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const BizSectionLabel('Money'),
        BizCard(
          child: Column(
            children: [
              wizardField(
                vm,
                WizardField.rent,
                'Monthly rent',
                hint: 'e.g. 6500',
                keyboard: TextInputType.number,
                formatters: _digitsAndDot,
                prefix: _rupee,
              ),
              _gap(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: wizardField(
                      vm,
                      WizardField.deposit,
                      'Security deposit',
                      keyboard: TextInputType.number,
                      formatters: _digitsAndDot,
                      prefix: _rupee,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: wizardField(
                      vm,
                      WizardField.maintenance,
                      'Maintenance',
                      keyboard: TextInputType.number,
                      formatters: _digitsAndDot,
                      prefix: _rupee,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const BizSectionLabel('Terms'),
        BizCard(
          child: Column(
            children: [
              wizardField(
                vm,
                WizardField.duration,
                'Lease length (months)',
                keyboard: TextInputType.number,
                formatters: _digitsOnly,
              ),
              _gap(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: wizardField(
                      vm,
                      WizardField.lockIn,
                      'Lock-in (months)',
                      keyboard: TextInputType.number,
                      formatters: _digitsOnly,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: wizardField(
                      vm,
                      WizardField.notice,
                      'Notice (days)',
                      keyboard: TextInputType.number,
                      formatters: _digitsOnly,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const BizSectionLabel('Payment cycle'),
        BizChoiceWrap<String>(
          options: const ['Monthly', 'Quarterly', 'Yearly', 'Weekly', 'Daily'],
          selected: vm.paymentCycle,
          onChanged: vm.setPaymentCycle,
        ),
      ],
    );
  }
}

// ─── Step 4: first bill ──────────────────────────────────────────────────

class BillStep extends StatelessWidget {
  const BillStep({super.key, required this.vm});

  final AddTenantWizardViewModel vm;

  @override
  Widget build(BuildContext context) {
    final bill = vm.bill;
    final note = bill.prorationNote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (vm.moveIn == null)
          const BizBanner(
            message:
                'Pick a move-in date on the Lease step to work out the first bill.',
            tone: BizTone.warning,
          )
        else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: BizColors.card,
              borderRadius: BorderRadius.circular(BizRadius.hero),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total due now', style: BizText.cardLabel),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: bill.total),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Text(
                    formatInr(v),
                    style: BizText.style(
                      38,
                      800,
                      color: Colors.white,
                      letterSpacing: -1.2,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  vm.depositNow
                      ? 'First month rent + security deposit'
                      : 'First month rent',
                  style: BizText.heroCaption,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const BizSectionLabel('Breakdown'),
          BizCard(
            child: Column(
              children: [
                for (final row in bill.rows.where((r) => !r.isTotal))
                  _BillRow(
                    label: row.label,
                    amount: row.amount,
                    note: row.note,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const BizSectionLabel('Adjust'),
          BizCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                wizardField(
                  vm,
                  WizardField.prorated,
                  'Prorated rent (optional)',
                  hint: bill.autoProratedRent.toStringAsFixed(0),
                  keyboard: TextInputType.number,
                  formatters: _digitsAndDot,
                  prefix: _rupee,
                ),
                if (note != null) ...[_gap(10), BizBanner(message: note)],
                const Divider(height: 28),
                _SwitchRow(
                  title: 'Food included in rent',
                  subtitle: vm.foodIncluded
                      ? 'No deduction'
                      : 'A monthly deduction applies',
                  value: vm.foodIncluded,
                  onChanged: vm.setFoodIncluded,
                ),
                if (!vm.foodIncluded) ...[
                  _gap(10),
                  wizardField(
                    vm,
                    WizardField.foodDeduction,
                    'Monthly food deduction',
                    keyboard: TextInputType.number,
                    formatters: _digitsAndDot,
                    prefix: _rupee,
                  ),
                ],
                const Divider(height: 28),
                _SwitchRow(
                  title: 'Collect security deposit now',
                  subtitle: vm.depositNow
                      ? 'Added to the first bill'
                      : 'Pay later',
                  value: vm.depositNow,
                  onChanged: vm.setDepositNow,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.label, required this.amount, this.note});

  final String label;
  final double amount;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: BizText.style(15, 500)),
                if (note != null)
                  Text(
                    note!,
                    style: BizText.style(
                      12,
                      400,
                      color: BizColors.inkSoft,
                      height: 1.35,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(formatInr(amount), style: BizText.style(15, 700)),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: BizText.rowTitle),
              Text(subtitle, style: BizText.rowSubtitle),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

// ─── Step 5: personal details ────────────────────────────────────────────

class PersonalStep extends StatelessWidget {
  const PersonalStep({super.key, required this.vm});

  final AddTenantWizardViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.mode == TenantEntryMode.search) {
      return BizBanner(
        message:
            "${vm.selectedTenant?.name ?? 'This tenant'} already has a profile, so we'll use the details "
            'they have on file. Nothing more to fill in.',
        tone: BizTone.success,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BizSectionLabel('Identity'),
        BizCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID type', style: BizText.fieldLabel),
              const SizedBox(height: 8),
              BizChoiceWrap<String>(
                options: const [
                  'Aadhaar',
                  'PAN',
                  'Passport',
                  'Driving License',
                ],
                selected: vm.idType,
                onChanged: vm.setIdType,
              ),
              _gap(),
              wizardField(
                vm,
                WizardField.idNumber,
                'ID number',
                hint: 'Enter ID number',
              ),
              _gap(),
              wizardField(
                vm,
                WizardField.idAddress,
                'Address on the ID',
                hint: 'Full address',
                maxLines: 2,
                capitalization: TextCapitalization.words,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const BizSectionLabel('About them'),
        BizCard(
          child: Column(
            children: [
              wizardField(
                vm,
                WizardField.dob,
                'Date of birth',
                hint: 'DD/MM/YYYY',
                keyboard: TextInputType.datetime,
              ),
              _gap(),
              wizardField(
                vm,
                WizardField.currentAddress,
                'Current address',
                hint: 'Full address',
                maxLines: 2,
                capitalization: TextCapitalization.words,
              ),
              _gap(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: wizardField(
                      vm,
                      WizardField.nationality,
                      'Nationality',
                      hint: 'e.g. Indian',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: wizardField(
                      vm,
                      WizardField.motherTongue,
                      'Mother tongue',
                      hint: 'e.g. Hindi',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const BizSectionLabel('Work or study (optional)'),
        BizCard(
          child: Column(
            children: [
              wizardField(
                vm,
                WizardField.officeName,
                'Office or institute',
                hint: 'e.g. ABC Corporation',
              ),
              _gap(),
              wizardField(
                vm,
                WizardField.officeId,
                'Employee / student ID',
                hint: 'e.g. EMP123456',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
