// lib/presentation/team/member_detail_screen.dart
import 'package:flutter/material.dart';

import '../design/components/biz_avatar.dart';
import '../design/components/biz_banner.dart';
import '../design/components/biz_button.dart';
import '../design/components/biz_card.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_dialogs.dart';
import '../design/components/biz_info.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_section_label.dart';
import '../design/components/biz_states.dart';
import '../design/tokens.dart';
import 'invite_sheet.dart';
import 'invite_form_viewmodel.dart';
import 'member_viewmodel.dart';
import 'team_actions.dart';
import 'team_models.dart';
import 'team_source.dart';

/// One teammate: contact, role, and which properties they can open. Pops with
/// `true` when something changed, so the list reloads.
class MemberDetailScreen extends StatefulWidget {
  const MemberDetailScreen({
    super.key,
    required this.businessId,
    required this.member,
    required this.properties,
    required this.source,
    required this.actions,
    required this.onSetActive,
  });

  final String businessId;
  final TeamMember member;
  final List<TeamProperty> properties;
  final TeamSource source;
  final TeamActions actions;

  /// Turns their access off or on; true when it worked.
  final Future<bool> Function(bool active) onSetActive;

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  late final MemberViewModel _vm = MemberViewModel(
    businessId: widget.businessId,
    member: widget.member,
    properties: widget.properties,
    source: widget.source,
  )..load();
  bool _changed = false;
  bool _switching = false;

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (await _vm.save()) {
      _changed = true;
      if (!mounted) return;
      showBizToast(context, 'Access updated.', tone: BizTone.success);
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _setActive(bool active) async {
    final name = widget.member.displayName;
    final ok = await showBizConfirm(
      context,
      title: active ? 'Turn access back on?' : 'Turn off access?',
      message: active
          ? '$name will be able to open the app and their properties again.'
          : "$name won't be able to open the app or see any property until you turn it back on. "
              "Their tenants and records stay as they are.",
      confirmLabel: active ? 'Turn on' : 'Turn off',
      destructive: !active,
    );
    if (!ok || !mounted) return;
    setState(() => _switching = true);
    final done = await widget.onSetActive(active);
    if (!mounted) return;
    setState(() => _switching = false);
    if (done) {
      showBizToast(context, active ? 'Access is on.' : 'Access is off.', tone: BizTone.success);
      Navigator.of(context).pop(true);
    } else {
      showBizToast(context, "Couldn't change their access. Try again.", tone: BizTone.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => BizScaffold(
          title: m.displayName,
          eyebrow: 'Team member',
          showBack: true,
          onBack: () => Navigator.of(context).pop(_changed),
          bottomBar: _vm.canEdit
              ? BizButton(
                  label: 'Save access',
                  loading: _vm.saving,
                  onPressed: _vm.isDirty && !_vm.saving ? _save : null,
                )
              : null,
          body: _body(context),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final m = widget.member;
    final bottom = MediaQuery.viewPaddingOf(context).bottom + 24;
    if (_vm.loading && !m.isOwner) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: BizSkeletonList(count: 2, cardHeight: 140),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
      children: [
        _Hero(member: m),
        const SizedBox(height: 14),
        BizInfoCard(
          title: 'Contact',
          children: [
            BizInfoRow(
              'Phone',
              m.phone ?? 'Not provided',
              muted: m.phone == null,
              trailing: m.phone == null
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Call',
                          icon: const Icon(Icons.call_outlined, size: 20, color: BizColors.green),
                          onPressed: () => widget.actions.call(context, m.phone!),
                        ),
                        IconButton(
                          tooltip: 'Copy phone number',
                          icon: const Icon(Icons.copy_rounded, size: 18, color: BizColors.inkSoft),
                          onPressed: () => widget.actions.copy(context, m.phone!, message: 'Number copied'),
                        ),
                      ],
                    ),
            ),
            BizInfoRow('Email', m.email ?? 'Not provided', muted: m.email == null),
          ],
        ),
        const SizedBox(height: 18),
        if (m.isOwner)
          const BizBanner(
            message: 'The owner can always open every property. This cannot be changed.',
            tone: BizTone.info,
            icon: Icons.verified_user_outlined,
          )
        else if (!m.isActive)
          BizBanner(
            message: "Their access is off, so they can't open the app. Turn it on to change their properties.",
            tone: BizTone.warning,
            icon: Icons.pause_circle_outline_rounded,
          )
        else if (_vm.loadError != null) ...[
          BizBanner(message: _vm.loadError!, tone: BizTone.danger),
          const SizedBox(height: 12),
          BizButton(label: 'Try again', kind: BizButtonKind.outline, onPressed: _vm.load),
        ] else ...[
          if (_vm.error != null) ...[
            BizBanner(message: _vm.error!, tone: BizTone.danger),
            const SizedBox(height: 14),
          ],
          const BizSectionLabel('Role'),
          BizChoiceWrap<String>(
            options: InviteFormViewModel.roles,
            selected: _vm.role,
            labelOf: (r) => r == 'manager' ? 'Manager' : 'Staff',
            onChanged: _vm.setRole,
          ),
          const SizedBox(height: 8),
          Text(roleHint, style: BizText.rowSubtitle.copyWith(height: 1.4)),
          const SizedBox(height: 20),
          const BizSectionLabel('Properties they can open'),
          BizCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: PropertyChecklist(
              properties: widget.properties,
              selected: _vm.selected,
              onToggle: _vm.toggleProperty,
            ),
          ),
          if (_vm.selected.isEmpty && widget.properties.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text("With none ticked they can sign in but won't see any property.", style: BizText.caption),
          ],
        ],
        if (!m.isOwner) ...[
          const SizedBox(height: 26),
          if (m.isActive)
            BizButton(
              label: 'Turn off access',
              icon: Icons.block_rounded,
              kind: BizButtonKind.danger,
              loading: _switching,
              onPressed: _switching ? null : () => _setActive(false),
            )
          else
            BizButton(
              label: 'Turn access back on',
              icon: Icons.play_circle_outline_rounded,
              loading: _switching,
              onPressed: _switching ? null : () => _setActive(true),
            ),
        ],
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.member});

  final TeamMember member;

  @override
  Widget build(BuildContext context) {
    return BizCard(
      child: Row(
        children: [
          BizAvatar(
            initials: member.initials,
            size: 56,
            background: member.isOwner ? BizColors.card : BizColors.greenTint,
            foreground: member.isOwner ? Colors.white : BizColors.greenDeep,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: BizText.cardTitle),
                const SizedBox(height: 6),
                Row(
                  children: [
                    BizStatusPill(member.roleLabel, tone: BizTone.neutral, dot: false),
                    if (!member.isActive) ...[
                      const SizedBox(width: 6),
                      const BizStatusPill('Access off', tone: BizTone.warning),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
