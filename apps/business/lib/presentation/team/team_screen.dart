// lib/presentation/team/team_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/actions.dart';
import '../../data/providers/business_state_provider.dart';
import '../../utils/permissions.dart';
import '../design/components/biz_avatar.dart';
import '../design/components/biz_banner.dart';
import '../design/components/biz_button.dart';
import '../design/components/biz_card.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_dialogs.dart';
import '../design/components/biz_header.dart';
import '../design/components/biz_list_row.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_section_label.dart';
import '../design/components/biz_states.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../views/home/home_format.dart';
import '../views/widgets/floating_nav_bar.dart';
import 'firestore_team_source.dart';
import 'invite_sheet.dart';
import 'member_detail_screen.dart';
import 'team_actions.dart';
import 'team_models.dart';
import 'team_source.dart';
import 'team_viewmodel.dart';

/// The owner's team: who works with them, what they can open, invitations
/// still waiting, and how to invite someone new.
class TeamScreen extends StatefulWidget {
  const TeamScreen({
    super.key,
    this.source,
    this.actions,
    this.clock,
    this.businessId,
    this.canManage,
    this.showBack,
  });

  /// Test hooks. Defaults read Firestore and the signed-in session.
  final TeamSource? source;
  final TeamActions? actions;
  final DateTime Function()? clock;
  final String? businessId;
  final bool? canManage;
  final bool? showBack;

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  late final TeamViewModel _vm = TeamViewModel(
    source: widget.source ?? FirestoreTeamSource(),
    clock: widget.clock,
  );
  late final TeamActions _actions = widget.actions ?? const DeviceTeamActions();
  late final String? _businessId;
  late final bool _canManage;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    BusinessStateProvider? session;
    try {
      session = context.read<BusinessStateProvider>();
    } on ProviderNotFoundException {
      session = null;
    }
    final id = widget.businessId ?? session?.businessId;
    _businessId = id == null || id.isEmpty ? null : id;
    _canManage = widget.canManage ?? (session != null && BusinessPermissions.fromRole(session.role).canInviteMembers);
    if (_canManage && _businessId != null) _vm.load(_businessId);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    if (_vm.properties.isEmpty && _vm.hasLoaded) {
      showBizToast(context, 'Add a property first, then invite your team.');
      return;
    }
    await showBizSheet<void>(
      context,
      title: 'Invite a teammate',
      subtitle: 'They get a link by text message, and by email if you add one.',
      builder: (_) => InviteSheet(team: _vm, actions: _actions),
    );
    if (mounted) await _vm.refresh();
  }

  Future<void> _openMember(TeamMember m) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MemberDetailScreen(
          businessId: _businessId!,
          member: m,
          properties: _vm.properties,
          source: widget.source ?? FirestoreTeamSource(),
          actions: _actions,
          onSetActive: (active) => _vm.setActive(m, active),
        ),
      ),
    );
    if (changed == true && mounted) await _vm.refresh();
  }

  Future<void> _showInvite(TeamInvite invite) {
    return showBizSheet<void>(
      context,
      title: invite.sentTo,
      subtitle: '${invite.roleLabel} · ${invite.expiryLabel(_now)}',
      builder: (_) => InviteLinkPanel(
        heading: 'Invitation link',
        detail: 'If they have not seen the text, send them the link yourself.',
        phone: invite.phone,
        link: inviteLinkFor(invite.id),
        actions: _actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<BusinessStateProvider?>();
    final inShell = widget.showBack == false;
    final initials = initialsOf(
      (session?.fullName ?? '').isNotEmpty
          ? session!.fullName
          : (session?.businessName ?? ''),
    );

    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => BizScaffold(
        title: 'Team',
        eyebrow: _canManage && _vm.hasLoaded ? _vm.summaryLine : null,
        showBack: widget.showBack,
        actions: [
          if (_canManage && inShell)
            BizRoundButton(
              icon: Icons.person_add_alt_1_rounded,
              tooltip: 'Invite someone',
              onTap: _invite,
            ),
          if (inShell)
            BizAvatarButton(
              initials: initials,
              onTap: () => openProfile(context),
            ),
        ],
        bottomBar: _canManage && !inShell
            ? BizButton(label: 'Invite someone', icon: Icons.person_add_alt_1_rounded, onPressed: _invite)
            : null,
        body: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (!_canManage) {
      return const BizEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Only the owner manages the team',
        message: 'Ask the owner if you need someone invited or their access changed.',
      );
    }
    if (_businessId == null) {
      return const BizErrorState(message: 'Your business has not loaded yet. Go back and try again.');
    }
    if (_vm.error != null && !_vm.hasLoaded) {
      return BizErrorState(message: _vm.error!, onRetry: () => _vm.load(_businessId));
    }
    if (!_vm.hasLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: BizSkeletonList(count: 3, cardHeight: 100),
      );
    }

    final inShell = widget.showBack == false;
    final bottom = MediaQuery.viewPaddingOf(context).bottom +
        (inShell ? FloatingNavBar.heightFor(context) + 24 : 24);
    final onlyOwner = _vm.members.every((m) => m.isOwner);
    return RefreshIndicator(
      onRefresh: _vm.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
        children: [
          if (_vm.error != null) ...[
            const BizBanner(message: "Couldn't refresh your team. Showing what we had.", tone: BizTone.warning),
            const SizedBox(height: 12),
          ],
          if (_vm.actionError != null) ...[
            BizBanner(message: _vm.actionError!, tone: BizTone.danger),
            const SizedBox(height: 12),
          ],
          const BizSectionLabel('Members'),
          BizCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < _vm.members.length; i++) ...[
                  if (i > 0) const Divider(height: 1, thickness: 1, color: BizColors.hairline),
                  _MemberRow(
                    member: _vm.members[i],
                    subtitle: '${_vm.members[i].roleLabel} · ${_vm.accessSummary(_vm.members[i])}',
                    onTap: () => _openMember(_vm.members[i]),
                  ),
                ],
              ],
            ),
          ),
          if (onlyOwner) ...[
            const SizedBox(height: 14),
            const BizBanner(
              message: 'Invite a manager or staff to share the day-to-day work.',
              tone: BizTone.info,
              icon: Icons.group_add_outlined,
            ),
          ],
          if (_vm.invites.isNotEmpty) ...[
            const SizedBox(height: 22),
            const BizSectionLabel('Pending invitations'),
            for (final invite in _vm.invites) ...[
              BizListRow(
                icon: Icons.mail_outline_rounded,
                color: BizColors.orange,
                title: invite.sentTo,
                subtitle: '${invite.roleLabel} · ${invite.expiryLabel(_now)}',
                trailing: const Icon(Icons.share_outlined, size: 20, color: BizColors.chevron),
                onTap: () => _showInvite(invite),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.subtitle, required this.onTap});

  final TeamMember member;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final off = !member.isActive;
    return Pressable(
      scale: 0.99,
      onTap: onTap,
      semanticLabel: member.displayName,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            BizAvatar(
              initials: member.initials,
              size: 44,
              background: off ? BizColors.track : (member.isOwner ? BizColors.card : BizColors.greenTint),
              foreground: off ? BizColors.inkSoft : (member.isOwner ? Colors.white : BizColors.greenDeep),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BizText.rowTitle.copyWith(color: off ? BizColors.inkSoft : BizColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: BizText.rowSubtitle),
                ],
              ),
            ),
            if (off) ...[
              const SizedBox(width: 8),
              const BizStatusPill('Access off', tone: BizTone.warning),
            ],
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, size: 22, color: BizColors.chevron),
          ],
        ),
      ),
    );
  }
}
