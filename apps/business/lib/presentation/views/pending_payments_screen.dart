import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Screen for business owner to view and confirm pending payments
/// 
/// Shows enrollment requests with status 'payment_submitted'
/// where tenant has paid and submitted transaction ID
class PendingPaymentsScreen extends StatelessWidget {
  final String businessId;
  final String? propertyId; // Optional filter by property

  const PendingPaymentsScreen({
    super.key,
    required this.businessId,
    this.propertyId,
  });

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('enrollmentRequests')
        .where('businessId', isEqualTo: businessId)
        .where('status', isEqualTo: 'payment_submitted');
    
    if (propertyId != null) {
      query = query.where('propertyId', isEqualTo: propertyId);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Payments'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.orderBy('paymentSubmittedAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'No pending payments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All payments have been confirmed',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final payments = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final doc = payments[index];
              final data = doc.data() as Map<String, dynamic>;
              
              return _PaymentCard(
                requestId: doc.id,
                data: data,
              );
            },
          );
        },
      ),
    );
  }
}

class _PaymentCard extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> data;

  const _PaymentCard({
    required this.requestId,
    required this.data,
  });

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  bool _isConfirming = false;
  bool _isRejecting = false;

  Future<void> _confirmPayment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tenant: ${widget.data['tenantName']}'),
            const SizedBox(height: 8),
            Text('Transaction ID: ${widget.data['transactionId'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Amount: ₹${(widget.data['totalBillAmount'] ?? 0).toString()}'),
            const SizedBox(height: 16),
            const Text(
              'Have you verified this payment in your bank account?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Yes, Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isConfirming = true);

    try {
      await FirebaseFirestore.instance
          .collection('enrollmentRequests')
          .doc(widget.requestId)
          .update({
        'status': 'confirmed',
        'confirmedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment confirmed! Tenant record will be created.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isConfirming = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectPayment() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Reject Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason for rejection:'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'e.g., Payment not received, Wrong amount',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (reason == null) return;

    setState(() => _isRejecting = true);

    try {
      await FirebaseFirestore.instance
          .collection('enrollmentRequests')
          .doc(widget.requestId)
          .update({
        'status': 'bill_sent', // Revert to bill_sent so tenant can retry
        'paymentRejectionReason': reason,
        'paymentRejectedAt': FieldValue.serverTimestamp(),
        'transactionId': FieldValue.delete(),
        'paymentSubmittedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment rejected. Tenant will be notified to retry.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _isRejecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenantName = widget.data['tenantName'] ?? 'Unknown';
    final tenantPhone = widget.data['tenantPhone'] ?? '';
    final propertyName = widget.data['propertyName'] ?? 'Property';
    final roomNumber = widget.data['roomNumber']?.toString() ?? '-';
    final bedNumber = widget.data['bedNumber']?.toString() ?? '-';
    final transactionId = widget.data['transactionId'] ?? 'Not provided';
    final totalAmount = (widget.data['totalBillAmount'] as num?)?.toDouble() ?? 
        ((widget.data['depositAmount'] as num?)?.toDouble() ?? 0) + 
        ((widget.data['advanceAmount'] as num?)?.toDouble() ?? 0);
    final paymentSubmittedAt = widget.data['paymentSubmittedAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with tenant info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: Text(
                    tenantName.isNotEmpty ? tenantName[0].toUpperCase() : 'T',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenantName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        tenantPhone,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: const Text(
                    'Pending Verification',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Property & Room info
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(Icons.apartment, 'Property', propertyName),
                ),
                Expanded(
                  child: _buildInfoItem(Icons.bed, 'Room/Bed', 'R$roomNumber / B$bedNumber'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Payment details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.currency_rupee, color: Colors.green.shade700, size: 28),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Amount Paid',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '₹${totalAmount.toInt().toString().replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (m) => '${m[1]},',
                        )}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Transaction ID
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transaction ID / UTR',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          transactionId,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: transactionId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaction ID copied!')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Copy',
                  ),
                ],
              ),
            ),
            
            if (paymentSubmittedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Submitted: ${_formatDate(paymentSubmittedAt.toDate())}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isRejecting || _isConfirming ? null : _rejectPayment,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isRejecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isConfirming || _isRejecting ? null : _confirmPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: _isConfirming
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle, color: Colors.white),
                    label: Text(
                      _isConfirming ? 'Confirming...' : 'Confirm Payment',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}
