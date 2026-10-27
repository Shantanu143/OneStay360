// lib/presentation/profile/profile_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/account_actions.dart';
import '../../app/routes.dart';
import '../../data/tenant_session.dart';
import '../common/device_actions.dart';
import '../common/format.dart';
import '../common/phone_format.dart';
import '../design/components/app_avatar.dart';
import '../design/components/app_card.dart';
import '../design/components/app_chips.dart';
import '../design/components/app_dialogs.dart';
import '../design/components/app_list_row.dart';
import '../design/components/app_scaffold.dart';
import '../design/components/app_section_label.dart';
import '../design/components/floating_nav_bar.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../home/activity_feed.dart';

/// The tenant: who they are, their ID, documents, saved PGs, help, sign out.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TenantSession>();
    final activity = context.watch<ActivityFeed>();
    final account = session.account;
    final name = session.displayName == 'there' ? 'Your profile' : session.displayName;
    final phone = account?.phone ?? '';

    Widget group(String label, List<Widget> rows) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSectionLabel(label),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const Divider(indent: 64),
                      rows[i],
                    ],
                  ],
                ),
              ),
            ],
          ),
        );

    return AppScrollPage(
      title: 'Profile',
      bottomInset: FloatingNavBar.heightFor(context) + 12,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              EntranceFade(
                child: AppCard(
                  onTap: () => openEditProfile(context),
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      AppAvatar(initials: initialsOf(name), size: 60),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.style(20, 700, letterSpacing: -0.3)),
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (phone.isNotEmpty) formatPhoneForDisplay(normalizePhoneNumber(phone) ?? phone),
                                if (account?.email.isNotEmpty == true) account!.email,
                              ].join(' · ').ifBlank('Add your details'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.rowSubtitle,
                            ),
                            const SizedBox(height: 8),
                            account?.profileComplete == true
                                ? const AppStatusPill('Profile complete', tone: AppTone.success)
                                : const AppStatusPill('Profile incomplete', tone: AppTone.warning),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.chevron),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (session.tenantId != null)
                EntranceFade(
                  delay: const Duration(milliseconds: 60),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: AppListRow(
                      icon: Icons.qr_code_2_rounded,
                      color: AppColors.card,
                      title: 'My tenant ID',
                      subtitle: '${session.tenantId} · show to your owner',
                      onTap: () => _showTenantQr(context, session.tenantId!, name),
                    ),
                  ),
                ),
              EntranceFade(
                delay: const Duration(milliseconds: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    group('ACCOUNT', [
                      AppListRow(
                        flat: true,
                        icon: Icons.badge_rounded,
                        color: AppColors.green,
                        title: 'Personal details & KYC',
                        subtitle: 'Name, phone, address, Aadhaar',
                        onTap: () => openEditProfile(context),
                      ),
                      AppListRow(
                        flat: true,
                        icon: Icons.folder_rounded,
                        color: AppColors.blue,
                        title: 'ID documents',
                        subtitle: 'Upload Aadhaar, PAN, agreement',
                        onTap: () => openDocuments(context),
                      ),
                      AppListRow(
                        flat: true,
                        icon: Icons.favorite_rounded,
                        color: AppColors.badge,
                        title: 'Saved PGs',
                        subtitle: '${account?.favorites.length ?? 0} saved',
                        onTap: () => openSaved(context),
                      ),
                    ]),
                    group('STAY', [
                      AppListRow(
                        flat: true,
                        icon: Icons.notifications_rounded,
                        color: AppColors.orange,
                        title: 'Notifications',
                        subtitle: session.unread == 0 ? 'All caught up' : '${session.unread} unread',
                        onTap: () => openNotifications(context),
                      ),
                      AppListRow(
                        flat: true,
                        icon: Icons.receipt_long_rounded,
                        color: const Color(0xFF8E5CF7),
                        title: 'Payments',
                        onTap: () => openPaymentHistory(context),
                      ),
                      AppListRow(
                        flat: true,
                        icon: Icons.handyman_rounded,
                        color: AppColors.orange,
                        title: 'Maintenance requests',
                        subtitle: activity.activeMaintenance.isEmpty ? null : '${activity.activeMaintenance.length} open',
                        onTap: () => openMaintenance(context),
                      ),
                    ]),
                    group('HELP', [
                      AppListRow(
                        flat: true,
                        icon: Icons.support_agent_rounded,
                        color: AppColors.green,
                        title: 'Help & support',
                        subtitle: supportEmail,
                        onTap: () => openExternal(
                          context,
                          Uri(scheme: 'mailto', path: supportEmail, queryParameters: {
                            'subject': 'OneStay360 tenant help${session.tenantId == null ? '' : ' (${session.tenantId})'}',
                          }),
                        ),
                      ),
                      AppListRow(
                        flat: true,
                        icon: Icons.description_rounded,
                        color: AppColors.inkSoft,
                        title: 'Terms of service',
                        onTap: () => openExternal(context, Uri.parse(termsUrl)),
                      ),
                      AppListRow(
                        flat: true,
                        icon: Icons.privacy_tip_rounded,
                        color: AppColors.inkSoft,
                        title: 'Privacy policy',
                        onTap: () => openExternal(context, Uri.parse(privacyUrl)),
                      ),
                    ]),
                    AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          AppListRow(
                            flat: true,
                            icon: Icons.logout_rounded,
                            color: AppColors.dangerInk,
                            title: 'Sign out',
                            onTap: () => _signOut(context),
                          ),
                          const Divider(indent: 64),
                          AppListRow(
                            flat: true,
                            icon: Icons.delete_forever_rounded,
                            color: AppColors.badge,
                            title: 'Delete account',
                            onTap: () => _delete(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(child: Text('OneStay360 · Tenant', style: AppText.caption)),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await showAppConfirm(
      context,
      title: 'Sign out?',
      message: 'You can sign back in any time.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (ok && context.mounted) await context.read<AccountActions>().signOut();
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showAppConfirm(
      context,
      title: 'Delete your account?',
      message: 'Your profile is removed and you are signed out. Payment records your owner needs are kept. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await context.read<AccountActions>().deleteAccount();
    } catch (_) {
      if (context.mounted) showAppToast(context, "Couldn't delete your account. Try again.", tone: AppTone.danger);
    }
  }
}

void _showTenantQr(BuildContext context, String tenantId, String name) {
  showAppSheet<void>(
    context,
    title: 'My tenant ID',
    subtitle: 'Owners can scan this to add you',
    scrollable: false,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.page, borderRadius: BorderRadius.circular(AppRadius.card)),
          child: QrImageView(
            data: 'onestay360:tenant:$tenantId',
            size: 220,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.card),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.card),
          ),
        ),
        const SizedBox(height: 14),
        Text(name, style: AppText.cardTitle),
        const SizedBox(height: 4),
        Pressable(
          onTap: () => copyText(ctx, tenantId, message: 'Tenant ID copied'),
          semanticLabel: 'Copy tenant ID',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tenantId, style: AppText.style(16, 600, color: AppColors.green, tabular: true)),
              const SizedBox(width: 6),
              const Icon(Icons.copy_rounded, size: 16, color: AppColors.green),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    ),
  );
}

extension on String {
  String ifBlank(String fallback) => trim().isEmpty ? fallback : this;
}
