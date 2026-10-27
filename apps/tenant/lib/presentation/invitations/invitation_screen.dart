// lib/presentation/invitations/invitation_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/tenant_shell.dart';
import '../../data/sources.dart';
import '../common/format.dart';
import '../common/widgets.dart';
import '../design/components/app_banner.dart';
import '../design/components/app_button.dart';
import '../design/components/app_card.dart';
import '../design/components/app_chips.dart';
import '../design/components/app_dialogs.dart';
import '../design/components/app_scaffold.dart';
import '../design/components/app_states.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../home/activity_feed.dart';
import '../payments/payment_widgets.dart';
import 'invitation_viewmodel.dart';

/// An owner's invitation to their PG: the room, the money, accept or decline.
class InvitationScreen extends StatefulWidget {
  const InvitationScreen({super.key, required this.invitationId});

  final String invitationId;

  @override
  State<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen> {
  late final InvitationViewModel _vm = InvitationViewModel(
    source: context.read<TenantBackend>(),
    invitationId: widget.invitationId,
  )..load();

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  void _refreshHome() {
    try {
      context.read<ActivityFeed>().refreshInvitations();
    } catch (_) {}
  }

  Future<void> _accept() async {
    final inv = _vm.invitation!;
    final ok = await showAppConfirm(
      context,
      title: 'Join ${inv.propertyName}?',
      message: 'You will be added to ${inv.placement} and rent of ${formatInr(inv.monthlyRent)} a month starts from your move-in date.',
      confirmLabel: 'Accept',
    );
    if (ok && await _vm.accept()) _refreshHome();
  }

  Future<void> _decline() async {
    final reason = await showAppTextPrompt(
      context,
      title: 'Decline invitation?',
      message: 'Let the owner know why (optional).',
      hint: 'Found another place',
      confirmLabel: 'Decline',
      required: false,
    );
    if (reason != null && await _vm.decline(reason)) _refreshHome();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final inv = _vm.invitation;
        return AppScaffold(
          title: inv?.propertyName ?? 'Invitation',
          eyebrow: 'You are invited',
          bottomBar: _vm.canRespond
              ? Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Decline',
                        kind: AppButtonKind.tonal,
                        onPressed: _vm.busy ? null : _decline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: AppButton(label: 'Accept', loading: _vm.busy, onPressed: _accept)),
                  ],
                )
              : null,
          body: SmoothSwitch(
            child: _vm.loading
                ? const Padding(
                    key: ValueKey('loading'),
                    padding: EdgeInsets.all(16),
                    child: AppSkeletonList(count: 2, cardHeight: 140),
                  )
                : _vm.outcome != InvitationOutcome.none
                    ? PaymentDone(
                        key: const ValueKey('done'),
                        title: _vm.outcome == InvitationOutcome.accepted ? 'Welcome home!' : 'Invitation declined',
                        message: _vm.outcome == InvitationOutcome.accepted
                            ? 'You have joined ${inv?.propertyName ?? 'the PG'}. Your room and rent are in My stay.'
                            : 'We let the owner know.',
                        icon: _vm.outcome == InvitationOutcome.accepted ? Icons.celebration_rounded : Icons.check_rounded,
                        onDone: () {
                          Navigator.of(context).popUntil((r) => r.isFirst);
                          if (_vm.outcome == InvitationOutcome.accepted) {
                            try {
                              context.read<ShellController>().goTo(ShellTab.stay);
                            } catch (_) {}
                          }
                        },
                      )
                    : inv == null
                        ? AppErrorState(
                            key: const ValueKey('error'),
                            title: 'Invitation unavailable',
                            message: _vm.error ?? 'This invitation could not be found.',
                            onRetry: _vm.load,
                          )
                        : ListView(
                            key: const ValueKey('invite'),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            children: [
                              if (_vm.error != null) ...[
                                AppBanner(message: _vm.error!, tone: AppTone.danger),
                                const SizedBox(height: 14),
                              ],
                              if (!inv.isPending) ...[
                                AppBanner(
                                  message: 'You already ${inv.status == 'rejected' ? 'declined' : 'accepted'} this invitation.',
                                  tone: AppTone.info,
                                ),
                                const SizedBox(height: 14),
                              ],
                              EntranceFade(
                                child: AmountCard(
                                  label: 'Monthly rent',
                                  amount: inv.monthlyRent,
                                  caption: inv.placement,
                                ),
                              ),
                              const SizedBox(height: 14),
                              EntranceFade(
                                delay: const Duration(milliseconds: 80),
                                child: AppCard(
                                  padding: const EdgeInsets.all(16),
                                  child: FactGrid(facts: [
                                    FactTile(label: 'Room', value: inv.roomNumber.isEmpty ? '—' : inv.roomNumber, icon: Icons.meeting_room_rounded),
                                    FactTile(label: 'Bed', value: inv.bedNumber.isEmpty ? '—' : inv.bedNumber, icon: Icons.bed_rounded),
                                    FactTile(
                                      label: 'Move-in',
                                      value: inv.moveIn == null ? 'To agree' : formatDay(inv.moveIn!),
                                      icon: Icons.event_rounded,
                                    ),
                                    FactTile(
                                      label: 'Rent is due',
                                      value: inv.billingDay == null ? 'Monthly' : 'On the ${ordinalDay(inv.billingDay!)}',
                                      icon: Icons.event_repeat_rounded,
                                    ),
                                    if (inv.deposit > 0)
                                      FactTile(label: 'Deposit', value: formatInr(inv.deposit), icon: Icons.savings_rounded),
                                    if (inv.maintenance > 0)
                                      FactTile(label: 'Maintenance', value: formatInr(inv.maintenance), icon: Icons.build_rounded),
                                    if (inv.noticePeriodDays != null)
                                      FactTile(label: 'Notice period', value: '${inv.noticePeriodDays} days', icon: Icons.schedule_rounded),
                                    if (inv.lockInMonths != null && inv.lockInMonths! > 0)
                                      FactTile(label: 'Lock-in', value: '${inv.lockInMonths} months', icon: Icons.lock_clock_rounded),
                                  ]),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Accepting adds you as a tenant of this room. Your owner collects the deposit and rent the way you agree with them.',
                                textAlign: TextAlign.center,
                                style: AppText.caption.copyWith(height: 1.45),
                              ),
                            ],
                          ),
          ),
        );
      },
    );
  }
}
