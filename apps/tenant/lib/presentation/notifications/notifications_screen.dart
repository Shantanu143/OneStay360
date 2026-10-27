// lib/presentation/notifications/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/tenant_shell.dart';
import '../../data/models.dart';
import '../../data/sources.dart';
import '../../data/tenant_session.dart';
import '../common/format.dart';
import '../design/components/app_card.dart';
import '../design/components/app_header.dart';
import '../design/components/app_list_row.dart';
import '../design/components/app_scaffold.dart';
import '../design/components/app_states.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import 'notification_target.dart';
import 'notifications_viewmodel.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsViewModel _vm = NotificationsViewModel(
    source: context.read<TenantBackend>(),
    tenantId: context.read<TenantSession>().tenantId,
  );

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  void _open(TenantNotification n) {
    _vm.markRead(n);
    ShellController? shell;
    try {
      shell = context.read<ShellController>();
    } catch (_) {}
    openTarget(context, notificationTarget(n), shell: shell);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final items = _vm.items;
        final now = DateTime.now();
        return AppScaffold(
          title: 'Notifications',
          actions: [
            if (_vm.unreadCount > 0)
              AppRoundButton(icon: Icons.done_all_rounded, tooltip: 'Mark all read', onTap: _vm.markAllRead),
          ],
          body: SmoothSwitch(
            child: _vm.loading
                ? const Padding(
                    key: ValueKey('loading'),
                    padding: EdgeInsets.all(16),
                    child: AppSkeletonList(count: 4, cardHeight: 72),
                  )
                : _vm.error != null
                    ? AppErrorState(key: const ValueKey('error'), message: _vm.error!)
                    : items.isEmpty
                        ? const AppEmptyState(
                            key: ValueKey('empty'),
                            icon: Icons.notifications_none_rounded,
                            title: "You're all caught up",
                            message: 'Bills, invitations and updates from your owner appear here.',
                          )
                        : ListView.separated(
                            key: const ValueKey('list'),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            physics: const BouncingScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final n = items[i];
                              final (icon, color) = switch (n.type) {
                                'tenant_invitation' => (Icons.mark_email_unread_rounded, AppColors.blue),
                                'bill_received' || 'bill_sent' => (Icons.receipt_long_rounded, AppColors.green),
                                _ => (Icons.notifications_rounded, AppColors.orange),
                              };
                              return EntranceFade(
                                delay: Duration(milliseconds: i < 8 ? 35 * i : 0),
                                child: AppCard(
                                  onTap: () => _open(n),
                                  padding: const EdgeInsets.all(14),
                                  color: n.read ? Colors.white : const Color(0xFFF4FBF8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      AppIconTile(icon: icon, color: color),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(n.title, style: AppText.rowTitle.copyWith(fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
                                            if (n.body.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(n.body, style: AppText.rowSubtitle.copyWith(height: 1.35)),
                                            ],
                                            if (n.createdAt != null) ...[
                                              const SizedBox(height: 6),
                                              Text(agoLabel(n.createdAt!, now), style: AppText.caption),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (!n.read)
                                        Container(
                                          width: 9,
                                          height: 9,
                                          margin: const EdgeInsets.only(left: 8, top: 6),
                                          decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        );
      },
    );
  }
}
