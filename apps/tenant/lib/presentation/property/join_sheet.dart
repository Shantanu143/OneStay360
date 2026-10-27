// lib/presentation/property/join_sheet.dart
import 'package:flutter/material.dart';
import 'package:models/business/property/property_model.dart';
import 'package:provider/provider.dart';

import '../../app/tenant_shell.dart';
import '../../data/sources.dart';
import '../../data/tenant_session.dart';
import '../common/format.dart';
import '../design/components/app_banner.dart';
import '../design/components/app_button.dart';
import '../design/components/app_chips.dart';
import '../design/components/app_dialogs.dart';
import '../design/components/app_picker_field.dart';
import '../design/components/app_text_field.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import 'join_viewmodel.dart';

/// "Request to join": who, when, which sharing. Ends on a confirmation that
/// points to Home, where the request is tracked.
Future<void> showJoinSheet(BuildContext context, Property property) async {
  final account = context.read<TenantSession>().account;
  final vm = JoinViewModel(
    source: context.read<TenantBackend>(),
    property: property,
    name: account?.name ?? '',
    phone: account?.phone ?? '',
  );
  ShellController? shell;
  try {
    shell = context.read<ShellController>();
  } catch (_) {}

  final goHome = await showAppSheet<bool>(
    context,
    title: vm.sent ? 'Request sent' : 'Request to join',
    subtitle: property.name,
    builder: (ctx) => ListenableBuilder(
      listenable: vm,
      builder: (ctx, _) => SmoothSwitch(child: vm.sent ? _Sent(key: const ValueKey('sent'), vm: vm) : _Form(vm: vm)),
    ),
  );
  vm.dispose();
  if (goHome == true && context.mounted) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    shell?.goTo(ShellTab.home);
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.vm});

  final JoinViewModel vm;

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.moveIn ?? vm.firstMoveIn,
      firstDate: vm.firstMoveIn,
      lastDate: vm.lastMoveIn,
      helpText: 'Move-in date',
    );
    if (picked != null) vm.setMoveIn(picked);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (vm.error != null) ...[
            AppBanner(message: vm.error!, tone: AppTone.danger),
            const SizedBox(height: 14),
          ],
          AppPickerField(
            label: 'Move-in date',
            placeholder: 'Choose a date',
            value: vm.moveIn == null ? null : formatDay(vm.moveIn!),
            error: vm.moveInError,
            onTap: () => _pickDate(context),
          ),
          if (vm.sharingOptions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Sharing (optional)', style: AppText.fieldLabel),
            ),
            AppChoiceWrap<String>(options: vm.sharingOptions, selected: vm.sharing, onChanged: vm.setSharing),
          ],
          const SizedBox(height: 16),
          AppTextField(
            label: 'Your name',
            fieldKey: const Key('join-name'),
            initialValue: vm.name,
            textCapitalization: TextCapitalization.words,
            onChanged: vm.setName,
            errorText: vm.nameError,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Mobile number',
            fieldKey: const Key('join-phone'),
            initialValue: vm.phone,
            keyboardType: TextInputType.phone,
            onChanged: vm.setPhone,
            errorText: vm.phoneError,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Message to the owner (optional)',
            fieldKey: const Key('join-notes'),
            hint: 'Anything they should know',
            maxLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            onChanged: vm.setNotes,
          ),
          const SizedBox(height: 18),
          AppButton(label: 'Send request', icon: Icons.send_rounded, loading: vm.busy, onPressed: vm.submit),
          const SizedBox(height: 8),
          Text(
            'The owner reviews it and sends your first bill. Nothing is charged until you pay that bill.',
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Sent extends StatelessWidget {
  const _Sent({super.key, required this.vm});

  final JoinViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.4, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, s, child) => Transform.scale(scale: s, child: child),
          child: Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(color: AppColors.greenTint, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 46, color: AppColors.green),
          ),
        ),
        const SizedBox(height: 18),
        Text('The owner has your request', textAlign: TextAlign.center, style: AppText.style(20, 700)),
        const SizedBox(height: 6),
        Text(
          "We'll let you know when they reply. You can follow it on Home.",
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 22),
        AppButton(label: 'Track on Home', onPressed: () => Navigator.of(context).pop(true)),
        const SizedBox(height: 8),
        AppButton(
          label: 'Keep browsing',
          kind: AppButtonKind.ghost,
          size: AppButtonSize.medium,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
