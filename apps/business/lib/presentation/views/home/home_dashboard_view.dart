// lib/presentation/views/home/home_dashboard_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/tokens.dart';
import '../../design/motion.dart';
import '../widgets/floating_nav_bar.dart';
import 'collections_card.dart';
import 'home_header.dart';
import 'needs_attention_card.dart';
import 'portfolio_card.dart';

/// Everything the home screen shows, as plain values (no Firebase, no
/// providers) so the layout can be exercised on its own.
class HomeDashboardData {
  const HomeDashboardData({
    required this.loading,
    required this.businessName,
    required this.firstName,
    required this.initials,
    required this.unreadCount,
    required this.collectionsTitle,
    required this.daysLeft,
    required this.target,
    required this.collected,
    required this.pending,
    required this.overdueCount,
    required this.collectionProgress,
    required this.occupancy,
    required this.occupiedBeds,
    required this.totalBeds,
    required this.properties,
    required this.tenants,
    required this.vacantBeds,
    this.error,
  });

  final bool loading;
  final String? error;

  final String businessName;
  final String firstName;
  final String initials;
  final int unreadCount;

  final String collectionsTitle;
  final String daysLeft;
  final double target;
  final double collected;
  final double pending;
  final int overdueCount;
  final double collectionProgress;

  final double occupancy;
  final int occupiedBeds;
  final int totalBeds;
  final int properties;
  final int tenants;
  final int vacantBeds;
}

class HomeDashboardView extends StatelessWidget {
  const HomeDashboardView({
    super.key,
    required this.entrance,
    required this.data,
    required this.attentionItems,
    required this.onRefresh,
    required this.onRetry,
    required this.onBusinessTap,
    required this.onBellTap,
    required this.onAvatarTap,
    required this.onSendReminders,
    this.onAnalytics,
    this.footer,
  });

  /// 0..1 controller driving the staggered entrance of the sections.
  final Animation<double> entrance;
  final HomeDashboardData data;
  final List<AttentionItem> attentionItems;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onBusinessTap;
  final VoidCallback onBellTap;
  final VoidCallback onAvatarTap;
  final VoidCallback onSendReminders;

  /// Shown as the "Analytics" link next to Portfolio; hidden when null.
  final VoidCallback? onAnalytics;

  /// Optional extra section below Portfolio (recent activity).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: RefreshIndicator(
        color: BizColors.green,
        backgroundColor: Colors.white,
        edgeOffset: topInset + 8,
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            topInset + 16,
            16,
            FloatingNavBar.heightFor(context) + 28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Reveal(
                animation: entrance,
                start: 0,
                end: 0.4,
                dy: 12,
                child: HomeHeader(
                  businessName: data.businessName,
                  firstName: data.firstName,
                  initials: data.initials,
                  unreadCount: data.unreadCount,
                  onBusinessTap: onBusinessTap,
                  onBellTap: onBellTap,
                  onAvatarTap: onAvatarTap,
                ),
              ),
              if (data.error != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(onTap: onRetry),
              ],
              const SizedBox(height: 23),
              Reveal(
                animation: entrance,
                start: 0.08,
                end: 0.55,
                child: CollectionsCard(
                  loading: data.loading,
                  title: data.collectionsTitle,
                  daysLeft: data.daysLeft,
                  target: data.target,
                  collected: data.collected,
                  pending: data.pending,
                  overdueCount: data.overdueCount,
                  progress: data.collectionProgress,
                  onSendReminders: onSendReminders,
                ),
              ),
              const SizedBox(height: 22),
              Reveal(
                animation: entrance,
                start: 0.22,
                end: 0.68,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Needs attention'),
                    const SizedBox(height: 10),
                    NeedsAttentionCard(
                      items: attentionItems,
                      loading: data.loading,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Reveal(
                animation: entrance,
                start: 0.34,
                end: 0.8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(
                      'Portfolio',
                      trailing: _AnalyticsLink(onTap: onAnalytics),
                    ),
                    const SizedBox(height: 10),
                    PortfolioCard(
                      loading: data.loading,
                      occupancy: data.occupancy,
                      occupiedBeds: data.occupiedBeds,
                      totalBeds: data.totalBeds,
                      properties: data.properties,
                      tenants: data.tenants,
                      vacantBeds: data.vacantBeds,
                    ),
                  ],
                ),
              ),
              if (footer != null)
                Reveal(
                  animation: entrance,
                  start: 0.46,
                  end: 0.92,
                  child: footer!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text, style: BizText.sectionTitle),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _AnalyticsLink extends StatelessWidget {
  const _AnalyticsLink({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return const SizedBox.shrink();
    return Pressable(
      scale: 0.94,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 6, 6),
        child: Text('Analytics', style: BizText.link),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1E0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.refresh_rounded,
              size: 18,
              color: Color(0xFFB45309),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Couldn't refresh your dashboard. Tap to retry.",
                style: BizText.style(13, 600, color: const Color(0xFF92400E)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
