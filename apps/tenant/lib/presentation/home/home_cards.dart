// lib/presentation/home/home_cards.dart
import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/models.dart';
import '../common/format.dart';
import '../common/widgets.dart';
import '../design/components/app_button.dart';
import '../design/components/app_card.dart';
import '../design/components/app_chips.dart';
import '../design/components/app_list_row.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../stay/stay_feed.dart';

const journeySteps = ['Requested', 'Approved', 'Paid', 'Moved in'];

/// Where a request to join a PG has got to, and what to do next.
class JourneyCard extends StatelessWidget {
  const JourneyCard({super.key, required this.request});

  final EnrollmentRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final (message, tone) = switch (r.stage) {
      EnrollmentStage.pending => ('The owner is reviewing your request.', AppTone.warning),
      EnrollmentStage.approved => ('Approved! The owner is getting your room ready.', AppTone.success),
      EnrollmentStage.billSent => ('Your first bill is ready. Pay it to confirm your bed.', AppTone.info),
      EnrollmentStage.paymentSubmitted => ('Payment sent. The owner is checking it.', AppTone.warning),
      EnrollmentStage.failed => ('The owner is finishing your move-in.', AppTone.warning),
      _ => ('Your request is in progress.', AppTone.neutral),
    };
    final paying = r.stage == EnrollmentStage.billSent;

    return AppCard(
      onTap: () => openRequest(context, r.id),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppIconTile(icon: Icons.home_work_rounded, color: AppColors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your request', style: AppText.caption),
                    Text(r.propertyName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.cardTitle),
                  ],
                ),
              ),
              AppStatusPill(r.stage.label, tone: tone),
            ],
          ),
          const SizedBox(height: 18),
          StepTrack(steps: journeySteps, current: r.stage.step, failed: r.stage == EnrollmentStage.failed),
          const SizedBox(height: 16),
          Text(message, style: AppText.body.copyWith(color: AppColors.inkSoft, height: 1.35)),
          if (paying) ...[
            const SizedBox(height: 14),
            AppButton(
              label: 'Review & pay ${formatInr(r.total)}',
              icon: Icons.lock_rounded,
              onPressed: () => openRequest(context, r.id),
            ),
          ],
        ],
      ),
    );
  }
}

/// An owner invited the tenant to their PG.
class InvitationCard extends StatelessWidget {
  const InvitationCard({super.key, required this.invitation});

  final PendingInvitation invitation;

  @override
  Widget build(BuildContext context) {
    final inv = invitation;
    return AppCard(
      onTap: () => openInvitation(context, inv.id),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const AppIconTile(icon: Icons.mark_email_unread_rounded, color: AppColors.blue, size: 44, iconSize: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You are invited to ${inv.propertyName}', style: AppText.rowTitle),
                const SizedBox(height: 2),
                Text(
                  '${inv.placement} · ${formatInr(inv.monthlyRent)}/month',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.rowSubtitle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('Review', style: AppText.link),
        ],
      ),
    );
  }
}

/// Dark hero card: the stay, what is owed and a pay button.
class StayHeroCard extends StatelessWidget {
  const StayHeroCard({super.key, required this.feed, required this.now});

  final StayFeed feed;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final stay = feed.stay!;
    final due = feed.dueInvoice;
    final pending = due == null ? null : feed.pendingPaymentFor(due.id);
    final overdue = due != null && due.isOverdueAt(now);
    final next = feed.nextBillingDate;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        boxShadow: [BoxShadow(color: AppColors.card.withValues(alpha: 0.2), blurRadius: 28, offset: const Offset(0, 14))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Your stay', style: AppText.cardLabel)),
              _DarkPill(stay.roomLabel),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            stay.propertyName.isEmpty ? 'Your PG' : stay.propertyName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.style(24, 700, color: Colors.white, letterSpacing: -0.5, height: 1.15),
          ),
          if ((feed.property?.location ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.place_rounded, size: 15, color: AppColors.onCardMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(feed.property!.location,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.heroCaption),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.cardTile, borderRadius: BorderRadius.circular(18)),
            child: SmoothSwitch(
              child: feed.loadingMoney
                  ? const Row(
                      key: ValueKey('loading'),
                      children: [Skeleton(width: 120, height: 26), Spacer(), Skeleton(width: 70, height: 20)],
                    )
                  : due == null
                      ? Row(
                          key: const ValueKey('paid'),
                          children: [
                            const Icon(Icons.verified_rounded, color: AppColors.mint, size: 26),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('All paid up', style: AppText.tileValue),
                                  Text(
                                    next == null
                                        ? 'Monthly rent ${formatInr(stay.monthlyRent)}'
                                        : 'Next rent ${formatInr(stay.monthlyRent)} on ${formatShortDay(next)}',
                                    style: AppText.tileLabel,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Row(
                          key: ValueKey('due-${due.id}'),
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(due.month.isEmpty ? 'Rent due' : 'Rent for ${due.month}', style: AppText.tileLabel),
                                  const SizedBox(height: 2),
                                  AnimatedNumber(value: feed.totalDue, style: AppText.heroAmount),
                                ],
                              ),
                            ),
                            if (due.dueDate != null)
                              _DarkPill(
                                pending != null ? 'Being confirmed' : dueLabel(due.dueDate!, now),
                                color: overdue && pending == null ? AppColors.badge : null,
                              ),
                          ],
                        ),
            ),
          ),
          if (!feed.loadingMoney && due != null) ...[
            const SizedBox(height: 14),
            AppButton(
              label: pending != null ? 'Payment sent · view' : 'Pay rent',
              kind: AppButtonKind.mint,
              icon: pending != null ? Icons.hourglass_top_rounded : Icons.arrow_forward_rounded,
              onPressed: () => pending != null ? openPaymentHistory(context) : openRentPayment(context, invoice: due),
            ),
          ],
        ],
      ),
    );
  }
}

class _DarkPill extends StatelessWidget {
  const _DarkPill(this.label, {this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color ?? AppColors.cardPill, borderRadius: BorderRadius.circular(13)),
      child: Text(label, style: AppText.cardPill.copyWith(color: color == null ? AppColors.onCardMuted : Colors.white)),
    );
  }
}

/// For someone without a stay: start looking.
class ExploreHeroCard extends StatelessWidget {
  const ExploreHeroCard({super.key, required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        boxShadow: [BoxShadow(color: AppColors.card.withValues(alpha: 0.2), blurRadius: 28, offset: const Offset(0, 14))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.travel_explore_rounded, color: AppColors.onMint, size: 28),
          ),
          const SizedBox(height: 18),
          Text('Find your next home',
              style: AppText.style(26, 700, color: Colors.white, letterSpacing: -0.6, height: 1.1)),
          const SizedBox(height: 6),
          Text('Browse PGs and hostels near you, compare prices and ask to join in a tap.',
              style: AppText.heroCaption.copyWith(height: 1.4)),
          const SizedBox(height: 18),
          AppButton(label: 'Explore PGs', kind: AppButtonKind.mint, icon: Icons.search_rounded, onPressed: onExplore),
        ],
      ),
    );
  }
}
