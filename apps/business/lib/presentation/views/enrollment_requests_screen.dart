import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
          _showRequestDetails(requestId, request);
        },
      ),
    );
  }

  void _showRequestDetails(String requestId, Map<String, dynamic> request) {
    final propertyName = (request['propertyName'] as String?) ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: ListView(
              controller: scrollController,
              children: [
                const Text(
                  'Request Details',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                _buildDetailRow('Tenant Name', request['tenantName'] ?? 'Unknown'),
                _buildDetailRow('Phone', request['tenantPhone'] ?? ''),
                if (propertyName.isNotEmpty)
                  _buildDetailRow('Property', propertyName),
                _buildDetailRow('Property ID', request['propertyId'] ?? ''),
                if (request['roomType'] != null)
                  _buildDetailRow('Room Type', request['roomType']),
                if (request['sharingType'] != null)
                  _buildDetailRow('Sharing', request['sharingType']),
                if (request['moveInDate'] != null)
                  _buildDetailRow(
                    'Move-in Date',
                    DateFormat('MMMM d, yyyy').format(
                      (request['moveInDate'] as Timestamp).toDate(),
                    ),
                  ),
                if (request['notes'] != null && (request['notes'] as String).isNotEmpty)
                  _buildDetailRow('Notes', request['notes']),
                _buildDetailRow('Status', request['status'] ?? 'pending'),
                const SizedBox(height: 32),
                if (request['status'] == 'pending') ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateRequestStatus(requestId, 'approved'),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateRequestStatus(requestId, 'rejected'),
                          icon: const Icon(Icons.cancel),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateRequestStatus(String requestId, String newStatus) async {
    try {
      await _firestore.collection('enrollmentRequests').doc(requestId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request ${newStatus == 'approved' ? 'approved' : 'rejected'}!'),
          backgroundColor: newStatus == 'approved' ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      debugPrint('Error updating request: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.hourglass_empty;
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}
