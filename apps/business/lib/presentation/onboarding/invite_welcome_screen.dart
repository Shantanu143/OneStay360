// lib/presentation/onboarding/invite_welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/providers/business_state_provider.dart';
import '../design/components/biz_button.dart';
import '../design/components/biz_card.dart';
import '../design/components/biz_info.dart';
import '../design/components/biz_list_row.dart';
import '../design/components/biz_scaffold.dart';
import '../design/tokens.dart';
import 'invite_models.dart';

/// Shown once an invitation is accepted: what they joined and what to do next.
class InviteWelcomeScreen extends StatefulWidget {
  const InviteWelcomeScreen({
    super.key,
    required this.invitation,
    required this.accepted,
    this.onContinue,
  });

  final Invitation invitation;
  final AcceptedInvite accepted;

  /// Test hook. By default this reloads the session and uncovers the auth
  /// gate, which swaps in the app once the business has loaded.
  final Future<void> Function(BuildContext context)? onContinue;

  @override
  State<InviteWelcomeScreen> createState() => _InviteWelcomeScreenState();
}

class _InviteWelcomeScreenState extends State<InviteWelcomeScreen> {
  bool _busy = false;

  Future<void> _continue() async {
    if (_busy) return;
    setState(() => _busy = true);
    final custom = widget.onContinue;
    if (custom != null) {
      await custom(context);
    } else {
      try {
        await context.read<BusinessStateProvider>().loadUserData();
      } catch (_) {
        // The gate shows its own retry if the business could not be loaded.
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invitation;
    final bottom = MediaQuery.viewPaddingOf(context).bottom + 24;
    return PopScope(
      canPop: false,
      child: BizScaffold(
        title: 'Welcome aboard',
        eyebrow: 'You joined ${invite.businessLabel}',
        showBack: false,
        bottomBar: BizButton(label: 'Open the app', loading: _busy, onPressed: _busy ? null : _continue),
        body: ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
          children: [
            BizCard(
              child: Row(
                children: [
                  const BizIconTile(icon: Icons.verified_rounded, color: BizColors.green, size: 52, iconSize: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("You're in", style: BizText.cardTitle),
                        const SizedBox(height: 2),
                        Text('Joined as ${invite.roleLabel.toLowerCase()}.', style: BizText.rowSubtitle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            BizInfoCard(
              title: 'Your properties',
              children: [
                if (invite.propertyNames.isNotEmpty)
                  for (final name in invite.propertyNames) BizInfoRow('Property', name)
                else if (widget.accepted.propertyIds.isNotEmpty)
                  BizInfoRow('Properties', '${widget.accepted.propertyIds.length}')
                else
                  const BizInfoRow('Properties', 'None yet', muted: true),
              ],
            ),
            const SizedBox(height: 14),
            const BizInfoCard(
              title: 'What you can do',
              children: [
                BizInfoRow('Tenants', 'Add and update them'),
                BizInfoRow('Beds', 'Mark them filled or free'),
                BizInfoRow('Payments', 'See and record rent'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
