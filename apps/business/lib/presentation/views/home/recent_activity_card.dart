// lib/presentation/views/home/recent_activity_card.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// Live feed of the latest audit-log entries. Audit logs are readable by the
/// business owner only, so for anyone else (or if the read fails) this simply
/// renders nothing.
class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({super.key, required this.businessId});

  final String? businessId;

  @override
  Widget build(BuildContext context) {
    final id = businessId;
    if (id == null || id.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(id)
          .collection('audit_logs')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();
        final docs = snapshot.data?.docs ?? const [];

        final Widget body;
        if (snapshot.connectionState == ConnectionState.waiting &&
            docs.isEmpty) {
          body = const SizedBox.shrink();
        } else {
          body = Column(
            key: const ValueKey('activity'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('Recent activity', style: BizText.sectionTitle),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: docs.isEmpty
                    ? const _EmptyActivity()
                    : Column(
                        children: [
                          for (var i = 0; i < docs.length; i++) ...[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                thickness: 1,
                                indent: 64,
                                endIndent: 16,
                                color: BizColors.hairline,
                              ),
                            _ActivityRow(data: docs[i].data()),
                          ],
                        ],
                      ),
              ),
            ],
          );
        }

        return AnimatedSize(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            child: body,
          ),
        );
      },
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          const Icon(
            Icons.history_toggle_off_rounded,
            size: 32,
            color: BizColors.chevron,
          ),
          const SizedBox(height: 8),
          Text('No recent activity yet', style: BizText.rowSubtitle),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final action = data['action'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final tint = _activityColor(action);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_activityIcon(action), size: 20, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activityLabel(action),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BizText.style(15, 600, letterSpacing: -0.15),
                ),
                if (createdAt != null)
                  Text(
                    _timeAgo(createdAt.toDate()),
                    style: BizText.rowSubtitle,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _activityLabel(String action) {
    switch (action) {
      case 'tenant_created':
        return 'New tenant added';
      case 'tenant_deleted':
        return 'Tenant removed';
      case 'bed_occupied':
        return 'Bed assigned to tenant';
      case 'bed_vacated':
        return 'Bed vacated';
      case 'property_access_granted':
        return 'Property access granted to member';
      case 'property_access_revoked':
        return 'Property access revoked from member';
      case 'member_role_changed':
        return 'Member role updated';
      default:
        // Humanise snake_case fallback
        return action
            .replaceAll('_', ' ')
            .replaceFirstMapped(
              RegExp(r'^.'),
              (m) => m.group(0)!.toUpperCase(),
            );
    }
  }

  static IconData _activityIcon(String action) {
    switch (action) {
      case 'tenant_created':
        return Icons.person_add_alt_1_outlined;
      case 'tenant_deleted':
        return Icons.person_remove_outlined;
      case 'bed_occupied':
        return Icons.bed_outlined;
      case 'bed_vacated':
        return Icons.hotel_outlined;
      case 'property_access_granted':
      case 'property_access_revoked':
        return Icons.key_outlined;
      case 'member_role_changed':
        return Icons.manage_accounts_outlined;
      default:
        return Icons.history_outlined;
    }
  }

  static Color _activityColor(String action) {
    switch (action) {
      case 'tenant_created':
      case 'bed_occupied':
      case 'property_access_granted':
        return BizColors.blue;
      case 'tenant_deleted':
      case 'bed_vacated':
      case 'property_access_revoked':
        return BizColors.badge;
      case 'member_role_changed':
        return BizColors.orange;
      default:
        return BizColors.inkSoft;
    }
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
