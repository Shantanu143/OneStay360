// lib/presentation/views/widgets/business_scaffold.dart
//
// LEGACY: keeps the old call sites compiling while screens move to
// `BizScaffold` / `BizScrollPage` (presentation/design/components). It now
// draws the new header and page background; only the screen bodies still look
// old. It no longer draws the bottom nav (the BusinessShell owns that) and no
// longer gates on the business or listens for requests (the AuthGate and the
// BusinessStateProvider do). Delete once nothing uses it.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/actions.dart';
import '../../../data/providers/business_notifications_provider.dart';
import '../../../data/providers/business_state_provider.dart';
import '../../design/components/biz_header.dart';
import '../../design/components/biz_scaffold.dart';

/// Kept so call sites compile; the value no longer affects anything.
enum BusinessTab { dashboard, properties, tenants, team, reports, profile }

class BusinessScaffold extends StatelessWidget {
  final Widget body;
  final BusinessTab currentTab;
  final Widget? title;
  final String? titleText;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBarBottom;
  final FloatingActionButton? floatingActionButton;
  final Color primaryColor;
  final bool showBackButton;
  final String? businessId;

  const BusinessScaffold({
    super.key,
    required this.body,
    required this.currentTab,
    this.title,
    this.titleText,
    this.actions,
    this.appBarBottom,
    this.floatingActionButton,
    this.primaryColor = const Color(0xFF0D9488),
    this.showBackButton = false,
    this.businessId,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BusinessStateProvider>();
    final unread = context.watch<BusinessNotificationsProvider>().unreadCount;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final given = title;
    final heading =
        titleText ??
        (given is Text ? (given.data ?? given.textSpan?.toPlainText()) : null);

    return BizScaffold(
      title: heading ?? state.businessName,
      showBack: showBackButton || canPop,
      actions:
          actions ??
          [
            BizRoundButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifications',
              badgeCount: unread,
              onTap: () => openNotifications(context),
            ),
          ],
      belowHeader: appBarBottom,
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}
