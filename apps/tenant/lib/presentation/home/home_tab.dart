// lib/presentation/home/home_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/tenant_shell.dart';
import '../../data/models.dart';
import '../../data/tenant_session.dart';
import '../common/format.dart';
import '../common/widgets.dart';
import '../design/components/app_avatar.dart';
import '../design/components/app_banner.dart';
import '../design/components/app_card.dart';
import '../design/components/app_chips.dart';
import '../design/components/app_header.dart';
import '../design/components/app_list_row.dart';
import '../design/components/app_scaffold.dart';
import '../design/components/floating_nav_bar.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../pinboard/pinboard_section.dart';
import '../stay/stay_feed.dart';
import 'activity_feed.dart';
import 'home_cards.dart';

/// The first tab: what needs the tenant's attention, their stay at a glance,
/// shortcuts, the house pinboard and recent activity.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TenantSession>();
    final stay = context.watch<StayFeed>();
    final activity = context.watch<ActivityFeed>();
    final now = (clock ?? DateTime.now)();
    final account = session.account;

    var i = 0;
    Widget reveal(Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: EntranceFade(delay: Duration(milliseconds: 60 * i++), child: child),
        );

    final request = activity.activeRequest;
    final rejection = activity.recentRejection;
    final children = <Widget>[
      if (account != null && !account.profileComplete)
        reveal(AppBanner(
          message: 'Complete your profile so owners can approve you faster.',
          tone: AppTone.warning,
          icon: Icons.person_outline_rounded,
          onTap: () => openEditProfile(context),
        )),
      for (final inv in activity.invitations) reveal(InvitationCard(invitation: inv)),
      if (request != null) reveal(JourneyCard(request: request)),
      if (rejection != null)
        reveal(AppBanner(
          message: "${rejection.propertyName} couldn't take your request${rejection.rejectionReason == null ? '' : ': ${rejection.rejectionReason}'}. Explore other PGs.",
          tone: AppTone.danger,
          icon: Icons.info_outline_rounded,
          onTap: () => context.read<ShellController>().goTo(ShellTab.explore),
        )),
      if (stay.stay != null)
        reveal(StayHeroCard(feed: stay, now: now))
      else if (request == null)
        reveal(ExploreHeroCard(onExplore: () => context.read<ShellController>().goTo(ShellTab.explore))),
      if (stay.stay != null) ...[
        reveal(_QuickActions(feed: stay)),
        reveal(PinboardSection(propertyId: stay.stay!.propertyId)),
      ],
      ..._recentActivity(context, stay, activity, now).map(reveal),
    ];

    return AppScrollPage(
      eyebrow: greetingFor(now),
      title: firstNameOf(session.displayName).isEmpty ? 'Hello' : firstNameOf(session.displayName),
      bottomInset: FloatingNavBar.heightFor(context) + 12,
      onRefresh: activity.refreshInvitations,
      actions: [
        AppRoundButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          badgeCount: session.unread,
          onTap: () => openNotifications(context),
        ),
        AppAvatarButton(
          initials: initialsOf(session.displayName == 'there' ? '' : session.displayName),
          onTap: () => context.read<ShellController>().goTo(ShellTab.profile),
        ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(delegate: SliverChildListDelegate(children)),
        ),
      ],
    );
  }

  List<Widget> _recentActivity(BuildContext context, StayFeed stay, ActivityFeed activity, DateTime now) {
    final items = <({DateTime at, Widget row})>[];
    for (final p in stay.payments.take(3)) {
      final (icon, color, status) = switch (p.state) {
        PaymentState.paid => (Icons.check_circle_rounded, AppColors.green, 'Paid'),
        PaymentState.pending => (Icons.hourglass_top_rounded, AppColors.orange, 'Being confirmed'),
        PaymentState.rejected => (Icons.error_outline_rounded, AppColors.badge, 'Sent back'),
      };
      items.add((
        at: p.date ?? DateTime(0),
        row: AppListRow(
          flat: true,
          icon: icon,
          color: color,
          title: '${formatInr(p.amount)} · ${p.month.isEmpty ? p.methodLabel : p.month}',
          subtitle: '$status${p.date == null ? '' : ' · ${agoLabel(p.date!, now)}'}',
          onTap: () => openPaymentHistory(context),
        ),
      ));
    }
    for (final m in activity.maintenance.take(2)) {
      items.add((
        at: m.updatedAt ?? m.createdAt ?? DateTime(0),
        row: AppListRow(
          flat: true,
          icon: m.category.icon,
          color: m.status == MaintenanceStatus.resolved ? AppColors.green : AppColors.blue,
          title: m.title,
          subtitle: '${m.status.label}${m.createdAt == null ? '' : ' · ${agoLabel(m.createdAt!, now)}'}',
          onTap: () => openMaintenance(context),
        ),
      ));
    }
    if (items.isEmpty) return const [];
    items.sort((a, b) => b.at.compareTo(a.at));
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('Recent activity'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < items.length && i < 4; i++) ...[
                  if (i > 0) const Divider(indent: 64),
                  items[i].row,
                ],
              ],
            ),
          ),
        ],
      ),
    ];
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.feed});

  final StayFeed feed;

  @override
  Widget build(BuildContext context) {
    final stay = feed.stay!;
    final actions = [
      (Icons.bed_rounded, AppColors.green, 'My room', () => context.read<ShellController>().goTo(ShellTab.stay)),
      (Icons.handyman_rounded, AppColors.orange, 'Get help', () => openMaintenance(context, startNew: true)),
      (
        Icons.call_rounded,
        AppColors.blue,
        'Owner',
        () => showContactOwnerSheet(
              context,
              propertyName: stay.propertyName,
              phone: feed.property?.phone ?? '',
              address: feed.property?.location,
            ),
      ),
      (Icons.receipt_long_rounded, const Color(0xFF8E5CF7), 'Payments', () => openPaymentHistory(context)),
    ];
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: AppCard(
              onTap: actions[i].$4,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              child: Column(
                children: [
                  AppIconTile(icon: actions[i].$1, color: actions[i].$2, size: 40, iconSize: 21),
                  const SizedBox(height: 8),
                  Text(actions[i].$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.style(12.5, 600)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
