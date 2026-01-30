import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/providers/business_notifications_provider.dart';
import 'view_property_screen.dart';
import 'widgets/business_scaffold.dart';
import 'package:models/business/business_notification_model.dart';

class BusinessNotificationsScreen extends StatelessWidget {
  const BusinessNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notificationsProvider =
        context.watch<BusinessNotificationsProvider>();

    return BusinessScaffold(
      currentTab: BusinessTab.dashboard,
      showBackButton: true,
      titleText: 'Notifications',
      body: _NotificationsBody(provider: notificationsProvider),
    );
  }
}

class _NotificationsBody extends StatelessWidget {
  final BusinessNotificationsProvider provider;

  const _NotificationsBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (!provider.hasBusinessContext) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Notifications will be available once your business account is fully linked.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.lastError != null) {
      return _buildErrorState(context);
    }

    if (provider.notifications.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: provider.unreadCount == 0
              ? null
              : () => provider.markAllAsRead(),
            icon: const Icon(Icons.done_all),
            label: const Text('Mark all as read'),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: provider.notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final notification = provider.notifications[index];
              return _NotificationTile(notification: notification);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('No notifications yet'),
            SizedBox(height: 8),
            Text(
              'You will see enrollment requests, tenant updates, and more here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 48),
            const SizedBox(height: 12),
            const Text('Unable to load notifications'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => provider.refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final BusinessNotification notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d • h:mm a');
    final timestamp = dateFormat.format(notification.createdAt);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _handleTap(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: notification.isUnread
              ? const Color(0xFFE3F2FD)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLeadingIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: notification.isUnread
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.message,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  if (notification.propertyName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        notification.propertyName!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    timestamp,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (notification.isUnread)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(left: 8, top: 6),
                decoration: const BoxDecoration(
                  color: Colors.teal,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingIcon() {
    IconData icon;
    Color color;

    switch (notification.type) {
      case BusinessNotificationType.enrollmentRequest:
        icon = Icons.person_add_alt_1;
        color = Colors.indigo;
        break;
      case BusinessNotificationType.payment:
        icon = Icons.currency_rupee;
        color = Colors.green;
        break;
      case BusinessNotificationType.tenantEvent:
        icon = Icons.home_work_outlined;
        color = Colors.orange;
        break;
      case BusinessNotificationType.general:
      default:
        icon = Icons.notifications;
        color = Colors.blueGrey;
        break;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.15),
      child: Icon(icon, color: color),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    final provider = context.read<BusinessNotificationsProvider>();
    await provider.markAsRead(notification.id);

    switch (notification.type) {
      case BusinessNotificationType.enrollmentRequest:
        await _openRequestsTab(context);
        break;
      default:
        break;
    }
  }

  Future<void> _openRequestsTab(BuildContext context) async {
    if (_navigateToProperty(context, notification.propertyId)) {
      return;
    }

    final requestId = notification.requestId;
    if (requestId == null || requestId.isEmpty) {
      _showMissingDataMessage(context);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('enrollmentRequests')
          .doc(requestId)
          .get();

      final propertyId = doc.data()?['propertyId']?.toString();
      if (_navigateToProperty(context, propertyId)) {
        return;
      }
    } catch (e) {
      _showError(context, 'Unable to locate property for this request');
    }

    Navigator.of(context).pushNamed(
      '/enrollment-requests',
      arguments: {
        'requestId': requestId,
        'propertyId': notification.propertyId,
      },
    );
  }

  bool _navigateToProperty(BuildContext context, String? propertyId) {
    if (propertyId == null || propertyId.isEmpty) {
      return false;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewPropertyScreen(
          propertyId: propertyId,
          initialTabIndex: ViewPropertyScreen.requestsTabIndex,
        ),
      ),
    );
    return true;
  }

  void _showMissingDataMessage(BuildContext context) {
    _showError(context, 'Request reference missing – opening requests list.');
    Navigator.of(context).pushNamed('/enrollment-requests');
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
