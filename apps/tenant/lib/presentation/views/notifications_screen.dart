import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import './tenant_invitation_approval_screen.dart';
import './bill_review_screen.dart';
import './widgets/tenant_scaffold.dart';

class NotificationsScreen extends StatefulWidget {
  final String? tenantId;

  const NotificationsScreen({
    super.key,
    this.tenantId,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String? _actualTenantId;

  @override
  void initState() {
    super.initState();
    _getTenantId();
  }

  Future<void> _getTenantId() async {
    if (widget.tenantId != null && widget.tenantId!.isNotEmpty) {
      setState(() {
        _actualTenantId = widget.tenantId;
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        setState(() {
          _actualTenantId = userData['tenantId']?.toString() ?? user.uid;
        });
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    if (_actualTenantId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(_actualTenantId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) async {
    final type = notification['type']?.toString();
    final notificationId = notification['id']?.toString();

    if (notificationId != null) {
      await _markAsRead(notificationId);
    }

    if (type == 'tenant_invitation') {
      final invitationId = notification['invitationId']?.toString();
      if (invitationId != null && mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TenantInvitationApprovalScreen(
              invitationId: invitationId,
            ),
          ),
        );

        // Refresh notifications if invitation was processed
        if (result != null && mounted) {
          setState(() {});
        }
      }
    } else if (type == 'bill_received') {
      // Navigate to bill review screen
      final enrollmentRequestId = notification['enrollmentRequestId']?.toString();
      if (enrollmentRequestId != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BillReviewScreen(
              enrollmentRequestId: enrollmentRequestId,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_actualTenantId == null) {
      return TenantScaffold(
        currentTab: TenantTab.profile,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return TenantScaffold(
      currentTab: TenantTab.profile,
      titleText: 'Notifications',
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tenants')
            .doc(_actualTenantId)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              final isRead = data['read'] as bool? ?? false;
              final type = data['type']?.toString() ?? '';
              final title = data['title']?.toString() ?? 'Notification';
              final message = data['message']?.toString() ?? '';
              final createdAt = data['createdAt'] as Timestamp?;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: isRead ? Colors.white : (type == 'bill_received' ? Colors.green.shade50 : Colors.blue.shade50),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isRead
                        ? Colors.grey.shade300
                        : (type == 'bill_received' ? Colors.green.shade100 : Colors.blue.shade100),
                    child: Icon(
                      type == 'tenant_invitation'
                          ? Icons.home
                          : type == 'bill_received'
                              ? Icons.receipt_long
                              : Icons.notifications,
                      color: isRead ? Colors.grey : (type == 'bill_received' ? Colors.green : Colors.blue),
                    ),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(message),
                      if (createdAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(createdAt.toDate()),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: (type == 'tenant_invitation' || type == 'bill_received') && !isRead
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: type == 'bill_received' ? Colors.green : Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            type == 'bill_received' ? 'Pay Now' : 'Action Required',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                  onTap: () => _handleNotificationTap({
                    ...data,
                    'id': doc.id,
                  }),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}



