// lib/presentation/tenant_detail/tenant_detail_screen.dart
import 'package:flutter/material.dart';

import '../../app/refresh_signals.dart';
import '../design/components/biz_avatar.dart';
import '../design/components/biz_button.dart';
import '../design/components/biz_card.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_dialogs.dart';
import '../design/components/biz_header.dart';
import '../design/components/biz_info.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_section_label.dart';
import '../design/components/biz_states.dart';
import '../design/components/biz_text_field.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../views/home/home_format.dart';
import '../views/home/home_sheets.dart' show whatsappNumber;
import 'firestore_tenant_detail_source.dart';
import 'tenant_detail_actions.dart';
import 'tenant_detail_models.dart';
import 'tenant_detail_source.dart';
import 'tenant_detail_viewmodel.dart';

/// One tenant: who they are, where they live, what they pay, with call,
/// message, record payment, edit and remove. Pops with `true` when the tenant
/// was removed, so the caller can reload.
class TenantDetailScreen extends StatefulWidget {
  const TenantDetailScreen({
    super.key,
    required this.tenant,
    required this.propertyName,
    this.businessId = '',
    this.canRemove = false,
    this.source,
    this.actions = const DeviceTenantActions(),
  });

  /// The tenant record as the property screen has it.
  final Map<String, dynamic> tenant;
  final String propertyName;
  final String businessId;

  /// Only owners may remove tenants.
  final bool canRemove;

  final TenantDetailSource? source;
  final TenantDetailActions actions;

  @override
  State<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends State<TenantDetailScreen> {
  late final TenantDetailViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = TenantDetailViewModel(
      profile: TenantProfile.fromMap(
        widget.tenant,
        propertyName: widget.propertyName,
        businessId: widget.businessId,
      ),
      source: widget.source ?? FirestoreTenantDetailSource(),
    )..listenPayments();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _message() async {
    final number = whatsappNumber(_vm.profile.phone ?? '');
    if (number == null) {
      showBizToast(context, 'No valid phone number to message.');
      return;
    }
    await widget.actions.openUrl(context, Uri.https('wa.me', '/$number'));
  }

  Future<void> _remove() async {
    final t = _vm.profile;
    final ok = await showBizConfirm(
      context,
      title: 'Remove tenant?',
      message:
          '${t.displayName} will be removed from ${t.location.isEmpty ? 'their bed' : t.location}. '
          'This will free up the bed and update occupancy counts.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    if (await _vm.remove()) {
      if (!mounted) return;
      RefreshSignals.raise(context, tenants: true, properties: true, payments: true);
      showBizToast(context, 'Tenant removed.', tone: BizTone.success);
      Navigator.of(context).pop(true);
    } else if (mounted) {
      showBizToast(context, _vm.actionError ?? "Couldn't remove this tenant.", tone: BizTone.danger);
    }
  }

  Future<void> _record() => widget.actions.recordPayment(context, _vm.profile);

  void _edit() {
    showBizSheet<void>(
      context,
      title: 'Edit details',
      subtitle: 'Contact details only. Room and rent stay as they are.',
      builder: (_) => _EditSheet(vm: _vm),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final t = _vm.profile;
        final bottom = MediaQuery.viewPaddingOf(context).bottom + 28;
        return BizScaffold(
          title: t.displayName,
          eyebrow: t.propertyName.isEmpty ? null : t.propertyName,
          showBack: true,
          body: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottom),
            children: [
              _Hero(profile: t),
              const SizedBox(height: 14),
              _ActionRow(
                hasPhone: t.phone != null,
                onCall: () => widget.actions.call(context, t.phone!),
                onMessage: _message,
                onRecord: _record,
              ),
              const SizedBox(height: 14),
              BizInfoCard(
                title: 'Contact',
                children: [
                  BizInfoRow(
                    'Phone',
                    t.phone ?? 'Not provided',
                    muted: t.phone == null,
                    trailing: t.phone == null
                        ? null
                        : BizRoundButton(
                            icon: Icons.copy_rounded,
                            iconSize: 16,
                            size: 34,
                            tooltip: 'Copy phone number',
                            onTap: () => widget.actions.copy(
                              context,
                              t.phone!,
                              message: 'Phone number copied',
                            ),
                          ),
                  ),
                  BizInfoRow('Email', t.email ?? 'Not provided', muted: t.email == null),
                  BizInfoRow(
                    'Joined',
                    t.joinDate == null ? 'Not recorded' : formatDay(t.joinDate!),
                    muted: t.joinDate == null,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const BizSectionLabel('Payment history'),
              _History(vm: _vm),
              const SizedBox(height: 14),
              BizButton(
                label: 'Edit details',
                icon: Icons.edit_outlined,
                kind: BizButtonKind.outline,
                onPressed: _edit,
              ),
              if (widget.canRemove && t.isActive) ...[
                const SizedBox(height: 10),
                BizButton(
                  label: 'Remove tenant',
                  icon: Icons.person_remove_outlined,
                  kind: BizButtonKind.danger,
                  loading: _vm.removing,
                  onPressed: _vm.removing ? null : _remove,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.profile});

  final TenantProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = profile;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BizColors.card,
        borderRadius: BorderRadius.circular(BizRadius.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BizAvatar(
                initials: t.initials,
                size: 52,
                background: BizColors.cardTile,
                foreground: BizColors.mint,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.displayId, style: BizText.cardLabel),
                    if (t.location.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(t.location, style: BizText.tileValue),
                    ],
                  ],
                ),
              ),
              BizStatusPill(t.statusLabel, tone: t.isActive ? BizTone.success : BizTone.neutral),
            ],
          ),
          const SizedBox(height: 18),
          Text('Monthly rent', style: BizText.tileLabel),
          const SizedBox(height: 4),
          Text(
            t.rent == null ? 'Rent not set' : formatInr(t.rent!),
            style: t.rent == null
                ? BizText.style(18, 600, color: BizColors.onCardMuted)
                : BizText.heroAmount,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.hasPhone,
    required this.onCall,
    required this.onMessage,
    required this.onRecord,
  });

  final bool hasPhone;
  final VoidCallback onCall;
  final VoidCallback onMessage;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.call_rounded,
            label: 'Call',
            onTap: hasPhone ? onCall : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Message',
            onTap: hasPhone ? onMessage : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.payments_outlined,
            label: 'Record payment',
            onTap: onRecord,
            highlight: true,
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final ink = highlight ? Colors.white : BizColors.ink;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Pressable(
        scale: 0.96,
        onTap: onTap,
        semanticLabel: label,
        child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: highlight ? BizColors.green : Colors.white,
            borderRadius: BorderRadius.circular(BizRadius.control + 4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: highlight ? Colors.white : BizColors.green),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BizText.style(13, 600, color: ink, height: 1.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.vm});

  final TenantDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.paymentsLoading && vm.payments.isEmpty) {
      return const BizSkeletonList(count: 2, cardHeight: 100);
    }
    if (vm.paymentsError != null && vm.payments.isEmpty) {
      return BizCard(
        child: BizErrorState(message: vm.paymentsError!, onRetry: vm.retryPayments),
      );
    }
    if (vm.payments.isEmpty) {
      return const BizCard(
        child: BizEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No payments yet',
          message: 'Rent payments for this tenant are listed here.',
        ),
      );
    }
    return Column(
      children: [for (final p in vm.payments) _PaymentRow(payment: p)],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final TenantPayment payment;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final view = p.view;
    final tone = switch (view.tone) {
      PaymentTone.success => BizTone.success,
      PaymentTone.warning => BizTone.warning,
      PaymentTone.danger => BizTone.danger,
      PaymentTone.neutral => BizTone.neutral,
    };
    final how = [if (p.method != null) p.method!, if (p.date != null) formatDay(p.date!)].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BizCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(p.month, style: BizText.rowTitle)),
                Text(formatInr(p.amount), style: BizText.bodyStrong),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(how, style: BizText.rowSubtitle)),
                BizStatusPill(view.label, tone: tone),
              ],
            ),
            if (p.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Text(
                'Reason: ${p.rejectionReason}',
                style: BizText.style(13, 500, color: BizColors.dangerInk, height: 1.3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.vm});

  final TenantDetailViewModel vm;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.vm.profile;
    _name = TextEditingController(text: p.name);
    _phone = TextEditingController(text: p.phone ?? '');
    _email = TextEditingController(text: p.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = await widget.vm.saveContact(
      name: _name.text,
      phone: _phone.text,
      email: _email.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    RefreshSignals.raise(context, tenants: true);
    showBizToast(context, 'Details updated.', tone: BizTone.success);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.vm,
      builder: (context, _) {
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        return SingleChildScrollView(
          padding: EdgeInsets.only(bottom: keyboard > 0 ? 8 : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              BizTextField(
                label: 'Full name',
                fieldKey: const Key('edit-name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              BizTextField(
                label: 'Phone',
                fieldKey: const Key('edit-phone'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              BizTextField(
                label: 'Email (optional)',
                fieldKey: const Key('edit-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: BizText.style(13, 600, color: BizColors.dangerInk)),
              ],
              const SizedBox(height: 18),
              BizButton(
                label: 'Save changes',
                loading: widget.vm.saving,
                onPressed: widget.vm.saving ? null : _save,
              ),
            ],
          ),
        );
      },
    );
  }
}
