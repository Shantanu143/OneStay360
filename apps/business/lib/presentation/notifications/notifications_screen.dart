// lib/presentation/notifications/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:models/business/business_notification_model.dart';
import 'package:provider/provider.dart';

import '../../data/providers/business_notifications_provider.dart';
import '../design/components/biz_card.dart';
import '../design/components/biz_header.dart';
import '../design/components/biz_list_row.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_section_label.dart';
import '../design/components/biz_states.dart';
import '../design/tokens.dart';
import '../views/home/home_format.dart';
import 'notification_opener.dart';

typedef NotificationOpener = Future<void> Function(BuildContext context, BusinessNotification n);

/// Everything the business has been told: new enrollment requests, payments
/// to confirm, billing changes. Unread first; tapping a row marks it read and
/// opens what it is about.
class BusinessNotificationsScreen extends StatelessWidget {
  const BusinessNotificationsScreen({super.key, this.onOpen, this.clock});

  /// Replaces the default navigation (tests).
  final NotificationOpener? onOpen;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessNotificationsProvider>();
    final unread = provider.unreadCount;
    final loaded = provider.hasBusinessContext && !provider.isLoading && provider.lastError == null;

    return BizScaffold(
      title: 'Notifications',
      eyebrow: loaded ? (unread == 0 ? 'All caught up' : '$unread unread') : null,
      actions: [
        if (unread > 0)
          BizRoundButton(
            icon: Icons.done_all_rounded,
            tooltip: 'Mark all as read',
            onTap: provider.markAllAsRead,
          ),
      ],
      body: _Body(
        provider: provider,
        now: (clock ?? DateTime.now)(),
        onOpen: onOpen ?? openNotification,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider, required this.now, required this.onOpen});

  final BusinessNotificationsProvider provider;
  final DateTime now;
  final NotificationOpener onOpen;

  @override
  Widget build(BuildContext context) {
    if (!provider.hasBusinessContext) {
      return const BizEmptyState(
        icon: Icons.link_off_rounded,
        title: 'Not linked yet',
        message: 'Notifications will be available once your business account is fully linked.',
      );
    }
    final all = provider.notifications;
    if (provider.lastError != null && all.isEmpty) {
      return BizErrorState(
        title: 'Unable to load notifications',
        message: 'Check your connection and try again.',
        onRetry: provider.refresh,
      );
    }
    if (provider.isLoading && all.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: BizSkeletonList(count: 4, cardHeight: 104),
      );
    }
    if (all.isEmpty) {
      return const BizEmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'No notifications yet',
        message: 'You will see enrollment requests, tenant updates, and more here.',
      );
    }

    final fresh = [for (final n in all) if (n.isUnread) n];
    final earlier = [for (final n in all) if (!n.isUnread) n];
    final bottom = MediaQuery.viewPaddingOf(context).bottom + 24;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
      children: [
        if (fresh.isNotEmpty) ...[
          const BizSectionLabel('New'),
          for (final n in fresh) _Row(n, now: now, onOpen: onOpen),
        ],
        if (earlier.isNotEmpty) ...[
          if (fresh.isNotEmpty) const SizedBox(height: 10),
          if (fresh.isNotEmpty) const BizSectionLabel('Earlier'),
          for (final n in earlier) _Row(n, now: now, onOpen: onOpen),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.notification, {required this.now, required this.onOpen});

  final BusinessNotification notification;
  final DateTime now;
  final NotificationOpener onOpen;

  (IconData, Color) get _look => switch (notification.type) {
    BusinessNotificationType.enrollmentRequest => (Icons.person_add_alt_1_rounded, BizColors.blue),
    BusinessNotificationType.payment => (Icons.currency_rupee_rounded, BizColors.green),
    BusinessNotificationType.billing => (Icons.receipt_long_rounded, BizColors.orange),
    BusinessNotificationType.tenantEvent => (Icons.home_work_outlined, BizColors.orange),
    BusinessNotificationType.general => (Icons.notifications_none_rounded, BizColors.inkSoft),
  };

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final (icon, color) = _look;
    final property = n.propertyName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BizCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        onTap: () async {
          final provider = context.read<BusinessNotificationsProvider>();
          if (n.isUnread) {
            try {
              await provider.markAsRead(n.id);
            } catch (_) {
              // Reading is a convenience; opening the target still works.
            }
          }
          if (context.mounted) await onOpen(context, n);
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BizIconTile(icon: icon, color: color, size: 40, iconSize: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: n.isUnread ? BizText.rowTitle : BizText.style(16, 500),
                  ),
                  if (n.message.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(n.message, style: BizText.style(14, 400, color: BizColors.inkSoft, height: 1.35)),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    [if (property != null && property.isNotEmpty) property, agoLabel(n.createdAt, now)]
                        .join(' · '),
                    style: BizText.caption,
                  ),
                ],
              ),
            ),
            if (n.isUnread)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(left: 8, top: 6),
                decoration: const BoxDecoration(color: BizColors.green, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
