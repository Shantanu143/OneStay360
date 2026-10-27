// lib/presentation/onboarding/invite_landing_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/phone_login_screen.dart';
import '../common/phone_format.dart';
import '../design/components/biz_banner.dart';
import '../design/components/biz_button.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_info.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_states.dart';
import '../design/tokens.dart';
import 'invite_gateway.dart';
import 'invite_landing_viewmodel.dart';
import 'invite_models.dart';
import 'invite_welcome_screen.dart';

/// Where an invitation link opens. Works signed out: accepting first
/// verifies the invited phone number, then joins the business.
class InviteLandingScreen extends StatefulWidget {
  const InviteLandingScreen({
    super.key,
    required this.inviteId,
    this.gateway,
    this.verifiedPhone,
    this.openPhone,
    this.onAccepted,
    this.clock,
  });

  final String inviteId;

  /// Test hooks. Defaults use Firebase and the real phone and welcome screens.
  final InviteGateway? gateway;
  final String? Function()? verifiedPhone;
  final Future<bool> Function(BuildContext context, Invitation invite)? openPhone;
  final void Function(BuildContext context, Invitation invite, AcceptedInvite accepted)? onAccepted;
  final DateTime Function()? clock;

  @override
  State<InviteLandingScreen> createState() => _InviteLandingScreenState();
}

class _InviteLandingScreenState extends State<InviteLandingScreen> {
  late final InviteLandingViewModel _vm = InviteLandingViewModel(
    inviteId: widget.inviteId,
    gateway: widget.gateway ?? FirebaseInviteGateway(),
    verifiedPhone: widget.verifiedPhone ?? (() => FirebaseAuth.instance.currentUser?.phoneNumber),
    clock: widget.clock,
  );

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<bool> _verifyPhone(Invitation invite) async {
    final custom = widget.openPhone;
    if (custom != null) return custom(context, invite);
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PhoneLoginScreen(initialPhone: invite.phone, returnToCaller: true, lockPhone: true),
      ),
    );
    return ok == true;
  }

  Future<void> _accept() async {
    final invite = _vm.invitation!;
    final accepted = await _vm.accept(verifyPhone: _verifyPhone);
    if (accepted == null || !mounted) return;
    final custom = widget.onAccepted;
    if (custom != null) return custom(context, invite, accepted);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => InviteWelcomeScreen(invitation: invite, accepted: accepted)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => BizScaffold(
        title: 'Invitation',
        eyebrow: 'OneStay360',
        bottomBar: _vm.state == LandingState.ready
            ? BizButton(
                label: _vm.needsPhoneCheck ? 'Verify number and accept' : 'Accept invitation',
                loading: _vm.accepting,
                onPressed: _vm.accepting ? null : _accept,
              )
            : null,
        body: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    switch (_vm.state) {
      case LandingState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: BizSkeletonList(count: 2, cardHeight: 160),
        );
      case LandingState.failed:
        return BizErrorState(message: _vm.problem!, onRetry: _vm.load);
      case LandingState.unavailable:
        return BizEmptyState(
          icon: Icons.link_off_rounded,
          title: 'This invitation can\'t be used',
          message: _vm.problem!,
        );
      case LandingState.ready:
        return _ready(context, _vm.invitation!);
    }
  }

  Widget _ready(BuildContext context, Invitation invite) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom + 24;
    final expiry = invite.expiryLabel(_now);
    final who = invite.inviterName ?? 'The owner';
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 21, 20, 22),
          decoration: BoxDecoration(
            color: BizColors.card,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: BizColors.card.withValues(alpha: 0.20), blurRadius: 28, offset: const Offset(0, 14)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text("You're invited to join", style: BizText.cardLabel)),
                  if (expiry != null)
                    Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(color: BizColors.cardPill, borderRadius: BorderRadius.circular(12)),
                      child: Center(widthFactor: 1, child: Text(expiry, style: BizText.cardPill)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(invite.businessLabel, style: BizText.heroAmount),
              const SizedBox(height: 6),
              Text('$who invited you as ${invite.roleLabel.toLowerCase()}.', style: BizText.heroCaption),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_vm.error != null) ...[
          BizBanner(message: _vm.error!, tone: BizTone.danger),
          const SizedBox(height: 14),
        ],
        BizInfoCard(
          title: 'What you can open',
          children: [
            if (invite.propertyNames.isNotEmpty)
              for (final name in invite.propertyNames) BizInfoRow('Property', name)
            else
              BizInfoRow('Properties', '${invite.propertyCount} ${invite.propertyCount == 1 ? 'property' : 'properties'}'),
          ],
        ),
        const SizedBox(height: 14),
        _vm.needsPhoneCheck
            ? BizBanner(
                message: 'This invitation is for ${maskPhone(invite.phone)}. '
                    "We'll text that number a code to confirm it's you.",
                tone: BizTone.info,
                icon: Icons.sms_outlined,
              )
            : const BizBanner(
                message: "You're signed in with the invited number.",
                tone: BizTone.success,
                icon: Icons.verified_outlined,
              ),
      ],
    );
  }
}
