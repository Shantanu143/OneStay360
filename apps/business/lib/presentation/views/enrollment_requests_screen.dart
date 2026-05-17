import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:models/tenant/tenant_request_model.dart';
import 'request_detail_screen.dart';

/// Enrollment Requests Screen
/// Displays all enrollment requests for the business owner's properties
class EnrollmentRequestsScreen extends StatefulWidget {
  final String? initialPropertyId;
  final String? initialRequestId;

  const EnrollmentRequestsScreen({
    super.key,
    this.initialPropertyId,
    this.initialRequestId,
  });

  @override
  State<EnrollmentRequestsScreen> createState() => _EnrollmentRequestsScreenState();
}

class _EnrollmentRequestsScreenState extends State<EnrollmentRequestsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _businessId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBusinessId();
  }

  Future<void> _loadBusinessId() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _businessId = userDoc.data()?['businessId'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading business ID: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enrollment Requests'),
        backgroundColor: const Color(0xFF06B6D4),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _businessId == null
              ? const Center(child: Text('No business found'))
              : StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('enrollmentRequests')
                    .where('businessId', isEqualTo: _businessId)
                    .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final requests = snapshot.data?.docs ?? [];

                    if (requests.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No enrollment requests yet',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: requests.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final request = requests[index].data() as Map<String, dynamic>;
                        final requestId = requests[index].id;
                        return _buildRequestCard(requestId, request);
                      },
                    );
                  },
                ),
    );
  }

  Widget _buildRequestCard(String requestId, Map<String, dynamic> request) {
    final tenantName = request['tenantName'] as String? ?? 'Unknown';
    final tenantPhone = request['tenantPhone'] as String? ?? '';
    final propertyId = request['propertyId'] as String? ?? '';
    final propertyName = request['propertyName'] as String? ?? '';
    final status = request['status'] as String? ?? 'pending';
    final moveInDate = request['moveInDate'] as Timestamp?;
    final createdAt = request['createdAt'] as Timestamp?;
    final notes = request['notes'] as String? ?? '';

    final isHighlighted = widget.initialRequestId == requestId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isHighlighted ? const Color(0xFFE0F7FA) : null,
      elevation: isHighlighted ? 4 : 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(status).withOpacity(0.2),
          child: Icon(
            _getStatusIcon(status),
            color: _getStatusColor(status),
          ),
        ),
        title: Text(
          tenantName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '📞 $tenantPhone',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '🏠 Property: ${propertyName.isNotEmpty ? propertyName : propertyId}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            if (moveInDate != null) ...[
              const SizedBox(height: 4),
              Text(
                '📅 Move-in: ${DateFormat('MMM d, yyyy').format(moveInDate.toDate())}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                '⏰ ${_formatTimestamp(createdAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '💬 $notes',
                style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
        trailing: Chip(
          label: Text(
            status.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          backgroundColor: _getStatusColor(status).withOpacity(0.2),
          labelStyle: TextStyle(color: _getStatusColor(status)),
        ),
        onTap: () {
          final tenantRequest = TenantRequest.fromMap(request, requestId);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RequestDetailScreen(
                propertyId: request['propertyId'] ?? '',
                request: tenantRequest,
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'bill_sent':
        return Colors.purple;
      case 'payment_submitted':
        return Colors.blue;
      case 'confirmed':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.access_time;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'bill_sent':
        return Icons.receipt_long;
      case 'payment_submitted':
        return Icons.payment;
      case 'confirmed':
        return Icons.done_all;
      default:
        return Icons.info;
    }
  }
}