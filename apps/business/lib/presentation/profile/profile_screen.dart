// lib/presentation/profile/profile_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/providers/business_state_provider.dart';
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
import '../design/components/biz_text_field.dart';
import '../design/tokens.dart';
import '../views/home/home_format.dart';
import 'profile_actions.dart';

/// Account and business settings: who you are, the business details, the
/// things only an owner manages, and signing out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.actions, this.account});

  /// Replaces the real actions (tests).
  final ProfileActions? actions;

  /// Replaces the signed-in Firebase user (tests).
  final ProfileAccount? account;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileActions _actions;
  // Bumped after an email/phone refresh so the account card re-reads the user.
  int _reloaded = 0;

  @override
  void initState() {
    super.initState();
    _actions =
        widget.actions ??
        DeviceProfileActions(
          onContactChanged: () {
            if (mounted) setState(() => _reloaded++);
          },
        );
  }

  ProfileAccount? _account() {
    if (widget.account != null) return widget.account;
    final user = FirebaseAuth.instance.currentUser;
    return user == null ? null : ProfileAccount.fromUser(user);
  }

  static String _roleLabel(String role) =>
      role.isEmpty ? 'Member' : role[0].toUpperCase() + role.substring(1);

  Future<void> _rename(String businessId, String current) async {
    final name = await showBizSheet<String>(
      context,
      title: 'Rename business',
      builder: (sheet) => _RenameSheet(initial: current),
    );
    if (name == null || !mounted) return;
    try {
      await _actions.renameBusiness(context, businessId, name);
      if (mounted)
        showBizToast(context, 'Business renamed.', tone: BizTone.success);
    } catch (_) {
      if (mounted)
        showBizToast(
          context,
          "Couldn't rename the business. Try again.",
          tone: BizTone.danger,
        );
    }
  }

  Future<void> _changePassword(String email) async {
    try {
      await _actions.sendPasswordReset(email);
      if (mounted)
        showBizToast(
          context,
          'Reset link sent to $email.',
          tone: BizTone.success,
        );
    } catch (_) {
      if (mounted) {
        showBizToast(
          context,
          "Couldn't send the reset link. Try again.",
          tone: BizTone.danger,
        );
      }
    }
  }

  Future<void> _signOut() async {
    final ok = await showBizConfirm(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to use the app.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (ok && mounted) await _actions.signOut(context);
  }

  Future<void> _delete() async {
    final ok = await showBizConfirm(
      context,
      title: 'Delete your account?',
      message:
          "Your sign-in and profile are permanently deleted. This can't be undone.",
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok && mounted) await _actions.deleteAccount(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BusinessStateProvider>();
    final account = _account();
    final role = state.role;
    final isOwner = role == 'owner';
    final businessId = state.businessId ?? '';
    final name = state.businessName;
    final bottom = MediaQuery.viewPaddingOf(context).bottom + 28;

    return BizScaffold(
      title: 'Profile',
      eyebrow: state.fullName.isEmpty ? null : state.fullName,
      showBack: true,
      body: ListView(
        key: ValueKey(_reloaded),
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottom),
        children: [
          _Hero(name: name, role: _roleLabel(role)),
          if (!state.profileCompleted) ...[
            const SizedBox(height: 12),
            const BizBanner(
              tone: BizTone.warning,
              message:
                  'Complete your profile: add and verify both an email and a phone number.',
            ),
          ],
          if (account != null) ...[
            const SizedBox(height: 18),
            const BizSectionLabel('Your account'),
            _AccountCard(
              account: account,
              actions: _actions,
              onEdit: () => _actions.openMyDetails(context, account),
            ),
          ],
          if (isOwner && businessId.isNotEmpty) ...[
            const SizedBox(height: 18),
            const BizSectionLabel('Business'),
            BizCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _NameRow(
                    name: name,
                    onRename: () => _rename(businessId, name),
                  ),
                  const _Divider(),
                  BizListRow(
                    flat: true,
                    icon: Icons.verified_user_outlined,
                    color: BizColors.green,
                    title: 'KYC & documents',
                    subtitle: 'GSTIN, PAN and certificates',
                    onTap: () => _actions.openKyc(context, businessId),
                  ),
                  const _Divider(),
                  BizListRow(
                    flat: true,
                    icon: Icons.account_balance_wallet_outlined,
                    color: BizColors.blue,
                    title: 'Payment methods',
                    subtitle: 'UPI, bank, cash and Razorpay',
                    onTap: () =>
                        _actions.openPaymentMethods(context, businessId),
                  ),
                  const _Divider(),
                  BizListRow(
                    flat: true,
                    icon: Icons.groups_outlined,
                    color: BizColors.orange,
                    title: 'Team & access',
                    subtitle: 'Invite managers and staff',
                    onTap: () => _actions.openTeam(context),
                  ),
                  const _Divider(),
                  BizListRow(
                    flat: true,
                    icon: Icons.receipt_long_outlined,
                    color: BizColors.blue,
                    title: 'Billing & subscription',
                    subtitle: 'What each property costs on OneStay360',
                    onTap: () => _actions.openBilling(context, businessId),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          const BizSectionLabel('Security'),
          BizCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                if (account != null &&
                    account.hasPassword &&
                    account.hasEmail) ...[
                  BizListRow(
                    flat: true,
                    icon: Icons.password_rounded,
                    color: BizColors.blue,
                    title: 'Change password',
                    subtitle: 'We email you a reset link',
                    onTap: () => _changePassword(account.email!),
                  ),
                  const _Divider(),
                ],
                BizListRow(
                  flat: true,
                  icon: Icons.privacy_tip_outlined,
                  color: BizColors.inkSoft,
                  title: 'Privacy policy',
                  subtitle: 'How your data is used',
                  onTap: () => _actions.openPrivacyPolicy(context),
                ),
                const _Divider(),
                BizListRow(
                  flat: true,
                  icon: Icons.logout_rounded,
                  color: BizColors.badge,
                  title: 'Sign out',
                  subtitle: 'Sign out of this account',
                  onTap: _signOut,
                ),
                const _Divider(),
                BizListRow(
                  flat: true,
                  icon: Icons.delete_forever_outlined,
                  color: BizColors.dangerInk,
                  title: 'Delete account',
                  subtitle: 'Permanently remove your account',
                  onTap: _delete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16),
    child: Divider(height: 1, thickness: 1, color: BizColors.hairline),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BizColors.card,
        borderRadius: BorderRadius.circular(BizRadius.hero),
      ),
      child: Row(
        children: [
          BizAvatar(
            initials: name.isEmpty ? '?' : initialsOf(name),
            size: 56,
            background: BizColors.cardTile,
            foreground: BizColors.mint,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Your business' : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BizText.style(
                    20,
                    700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(role, style: BizText.cardLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.name, required this.onRename});

  final String name;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const BizIconTile(
            icon: Icons.apartment_rounded,
            color: BizColors.green,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Business name', style: BizText.rowSubtitle),
                const SizedBox(height: 2),
                Text(name.isEmpty ? 'Not set' : name, style: BizText.rowTitle),
              ],
            ),
          ),
          BizRoundButton(
            icon: Icons.edit_outlined,
            iconSize: 17,
            size: 36,
            tooltip: 'Rename business',
            onTap: onRename,
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.actions,
    required this.onEdit,
  });

  final ProfileAccount account;
  final ProfileActions actions;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return BizCard(
      padding: const EdgeInsets.only(top: 4, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ContactRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: account.email,
            addLabel: 'Add email',
            refreshTooltip: 'Refresh email',
            onAdd: () => actions.addEmail(context),
            onRefresh: () => actions.refreshEmail(context),
          ),
          const _Divider(),
          _ContactRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: account.phone,
            addLabel: 'Add phone',
            refreshTooltip: 'Refresh phone',
            onAdd: () => actions.addPhone(context),
            onRefresh: () => actions.refreshPhone(context),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BizButton(
              label: 'Edit my details',
              icon: Icons.edit_outlined,
              kind: BizButtonKind.tonal,
              size: BizButtonSize.compact,
              onPressed: onEdit,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.addLabel,
    required this.refreshTooltip,
    required this.onAdd,
    required this.onRefresh,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String addLabel;
  final String refreshTooltip;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final has = value != null && value!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          BizIconTile(icon: icon, color: BizColors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: BizText.rowSubtitle),
                const SizedBox(height: 2),
                Text(
                  has ? value! : 'Not added',
                  style: has
                      ? BizText.rowTitle
                      : BizText.style(16, 400, color: BizColors.inkSoft),
                ),
              ],
            ),
          ),
          if (has)
            BizRoundButton(
              icon: Icons.sync_rounded,
              iconSize: 17,
              size: 36,
              tooltip: refreshTooltip,
              onTap: onRefresh,
            )
          else
            GestureDetector(
              onTap: onAdd,
              child: Text(addLabel, style: BizText.link),
            ),
        ],
      ),
    );
  }
}

class _RenameSheet extends StatefulWidget {
  const _RenameSheet({required this.initial});

  final String initial;

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Enter a name for your business.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BizTextField(
            label: 'Business name',
            fieldKey: const Key('business-name'),
            controller: _controller,
            textCapitalization: TextCapitalization.words,
            errorText: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 16),
          BizButton(label: 'Save', onPressed: _save),
        ],
      ),
    );
  }
}
