// lib/presentation/profile/edit_profile_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/tenant_session.dart';
import '../common/format.dart';
import '../design/components/app_banner.dart';
import '../design/components/app_button.dart';
import '../design/components/app_card.dart';
import '../design/components/app_chips.dart';
import '../design/components/app_dialogs.dart';
import '../design/components/app_info.dart';
import '../design/components/app_picker_field.dart';
import '../design/components/app_scaffold.dart';
import '../design/components/app_section_label.dart';
import '../design/components/app_states.dart';
import '../design/components/app_text_field.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import 'profile_viewmodel.dart';

/// Personal details, emergency contact, work, KYC and address.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.viewModel});

  /// Test hook.
  final ProfileViewModel? viewModel;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final ProfileViewModel _vm = widget.viewModel ??
      ProfileViewModel(
        firestore: FirebaseFirestore.instance,
        uid: context.read<TenantSession>().uid ?? '',
        email: context.read<TenantSession>().account?.email ?? '',
      );
  final Map<ProfileField, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _vm.load().then((_) {
      if (!mounted) return;
      setState(() {
        for (final f in ProfileField.values) {
          _controllers[f] = TextEditingController(text: _vm.value(f));
        }
      });
    });
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (await _vm.save() && mounted) {
      HapticFeedback.mediumImpact();
      showAppToast(context, 'Profile saved', tone: AppTone.success);
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _vm.dateOfBirth ?? DateTime(now.year - 22),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 14, now.month, now.day),
      helpText: 'Date of birth',
    );
    if (picked != null) _vm.setDateOfBirth(picked);
  }

  Future<void> _pickLanguage() async {
    final choice = await showAppSheet<String>(
      context,
      title: 'Mother tongue',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final l in ProfileViewModel.languages)
            AppSheetOption(label: l, selected: l == _vm.language, onTap: () => Navigator.of(ctx).pop(l)),
        ],
      ),
    );
    if (choice != null) _vm.setLanguage(choice);
  }

  Widget _field(ProfileField f, {TextInputType? type, String? hint, List<TextInputFormatter>? formatters, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppTextField(
        label: f.label,
        fieldKey: Key('profile-${f.name}'),
        controller: _controllers[f],
        hint: hint,
        keyboardType: type,
        inputFormatters: formatters,
        maxLines: maxLines,
        textCapitalization: type == null ? TextCapitalization.words : TextCapitalization.none,
        onChanged: (v) => _vm.set(f, v),
        errorText: _vm.errorFor(f),
      ),
    );
  }

  Widget _section(String label, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionLabel(label),
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final ready = !_vm.loading && _controllers.isNotEmpty;
        return AppScaffold(
          title: 'Your details',
          eyebrow: 'Profile',
          bottomBar: ready ? AppButton(label: 'Save', loading: _vm.saving, onPressed: _save) : null,
          body: SmoothSwitch(
            child: !ready
                ? const Padding(
                    key: ValueKey('loading'),
                    padding: EdgeInsets.all(16),
                    child: AppSkeletonList(count: 3, cardHeight: 160),
                  )
                : ListView(
                    key: const ValueKey('form'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _vm.isComplete ? 'Your profile is complete' : 'Profile ${(_vm.completion * 100).round()}% complete',
                                    style: AppText.cardTitle,
                                  ),
                                ),
                                if (_vm.isComplete) const Icon(Icons.verified_rounded, color: AppColors.green),
                              ],
                            ),
                            const SizedBox(height: 10),
                            AppProgressBar(fraction: _vm.completion),
                            if (!_vm.isComplete) ...[
                              const SizedBox(height: 8),
                              Text('Still needed: ${_vm.missing.join(', ')}', style: AppText.caption.copyWith(height: 1.4)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_vm.error != null) ...[
                        AppBanner(message: _vm.error!, tone: AppTone.danger),
                        const SizedBox(height: 14),
                      ],
                      _section('ABOUT YOU', [
                        _field(ProfileField.name, hint: 'As on your ID'),
                        _field(ProfileField.phone, type: TextInputType.phone, hint: '98111 00001'),
                        _field(ProfileField.altPhone, type: TextInputType.phone),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text('Gender', style: AppText.fieldLabel),
                        ),
                        AppChoiceWrap<String>(
                          options: ProfileViewModel.genders,
                          selected: _vm.gender,
                          onChanged: _vm.setGender,
                          onCard: true,
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: AppPickerField(
                            label: 'Date of birth',
                            placeholder: 'Choose',
                            value: _vm.dateOfBirth == null ? null : formatDay(_vm.dateOfBirth!),
                            onTap: _pickDob,
                          ),
                        ),
                      ]),
                      _section('EMERGENCY CONTACT', [
                        _field(ProfileField.emergencyName, hint: 'Parent, sibling or friend'),
                        _field(ProfileField.emergencyPhone, type: TextInputType.phone),
                      ]),
                      _section('WORK OR STUDY', [
                        _field(ProfileField.workName),
                        _field(ProfileField.workId, type: TextInputType.text),
                      ]),
                      _section('KYC', [
                        _field(
                          ProfileField.idNumber,
                          type: TextInputType.number,
                          hint: '12 digits',
                          formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(14)],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text('Nationality', style: AppText.fieldLabel),
                        ),
                        AppChoiceWrap<String>(
                          options: ProfileViewModel.nationalities,
                          selected: _vm.nationality,
                          onChanged: _vm.setNationality,
                          onCard: true,
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: AppPickerField(
                            label: 'Mother tongue',
                            placeholder: 'Choose',
                            value: _vm.language,
                            icon: Icons.translate_rounded,
                            onTap: _pickLanguage,
                          ),
                        ),
                      ]),
                      _section('PERMANENT ADDRESS', [
                        _field(ProfileField.address, hint: 'House, street, area', maxLines: 2),
                        _field(ProfileField.city),
                        _field(
                          ProfileField.pincode,
                          type: TextInputType.number,
                          formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                        ),
                      ]),
                      Text(
                        'Your owner sees these details for police verification and emergencies. We never show them on listings.',
                        textAlign: TextAlign.center,
                        style: AppText.caption.copyWith(height: 1.4),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
