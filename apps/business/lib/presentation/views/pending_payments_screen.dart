import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Screen for business owner to view and confirm pending payments
/// Shows BOTH enrollment requests (deposit) AND monthly rent submissions.
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pending Confirmations'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: 'Monthly Rent'),
              Tab(text: 'Enrollment Deposits'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRentPaymentsList(),
            _buildEnrollmentPaymentsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRentPaymentsList() {
    Query query = FirebaseFirestore.instance
        .collectionGroup('payments')
        .where('businessId', isEqualTo: businessId)
        .where('status', isEqualTo: 'pending_verification');

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState('No pending rent payments');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _RentPaymentCard(paymentId: doc.id, data: data);
          },
        );
      },
    );
  }

  Widget _buildEnrollmentPaymentsList() {
    Query query = FirebaseFirestore.instance
        .collection('enrollmentRequests')
        .where('businessId', isEqualTo: businessId)
        .where('status', isEqualTo: 'payment_submitted');
    
    if (propertyId != null) {
      query = query.where('propertyId', isEqualTo: propertyId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('paymentSubmittedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState('No pending enrollments');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _EnrollmentPaymentCard(requestId: doc.id, data: data);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('All payments are verified', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// RENT PAYMENT CARD
// ---------------------------------------------------------
class _RentPaymentCard extends StatefulWidget {
  final String paymentId;
  final Map<String, dynamic> data;

  const _RentPaymentCard({required this.paymentId, required this.data});

  @override
  State<_RentPaymentCard> createState() => _RentPaymentCardState();
}

class _RentPaymentCardState extends State<_RentPaymentCard> {
  bool _isProcessing = false;

  Future<void> _verifyPayment(String action, String? reason) async {
    setState(() => _isProcessing = true);
    try {
      final httpsCallable = FirebaseFunctions.instance.httpsCallable('verifyRentPayment');
      await httpsCallable.call({
        'businessId': widget.data['businessId'],
        'tenantId': widget.data['tenantId'],
        'paymentId': widget.paymentId,
        'action': action,
        if (reason != null) 'rejectionReason': reason,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'confirm' ? 'Rent payment confirmed!' : 'Payment rejected.'),
            backgroundColor: action == 'confirm' ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmPayment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Rent Payment'),
        content: Text('Verify ₹${widget.data['amount']} received from ${widget.data['tenantName']} for ${widget.data['month']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Yes, Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _verifyPayment('confirm', null);
    }
  }

  Future<void> _rejectPayment() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Reject Payment'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Reason', hintText: 'e.g., Payment not received'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (reason != null) {
      _verifyPayment('reject', reason);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenantName = widget.data['tenantName'] ?? 'Unknown';
    final roomNumber = widget.data['roomNumber']?.toString() ?? '-';
    final bedNumber = widget.data['bedNumber']?.toString() ?? '-';
    final amount = widget.data['amount'] ?? 0;
    final month = widget.data['month'] ?? 'Unknown Month';
    final method = widget.data['method'] ?? 'UPI';
    final txnId = widget.data['transactionId'] ?? 'N/A';
    final submittedAt = widget.data['createdAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(tenantName, 'Rent: $month', Colors.blue),
            const Divider(),
            Row(
              children: [
                Expanded(child: _buildInfoItem(Icons.bed, 'Room/Bed', 'R$roomNumber / B$bedNumber')),
                Expanded(child: _buildInfoItem(Icons.payment, 'Method', method)),
              ],
            ),
            const SizedBox(height: 12),
            _buildAmountBox(amount, Colors.blue),
            const SizedBox(height: 12),
            if (method == 'UPI') _buildTxnIdBox(txnId),
            if (submittedAt != null) ...[
              const SizedBox(height: 8),
              Text('Submitted: ${_formatDate(submittedAt.toDate())}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
            const SizedBox(height: 16),
            _buildActionButtons(_isProcessing, _confirmPayment, _rejectPayment),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// ENROLLMENT PAYMENT CARD (Legacy implementation, kept exactly same)
// ---------------------------------------------------------
class _EnrollmentPaymentCard extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> data;

  const _EnrollmentPaymentCard({required this.requestId, required this.data});

  @override
  State<_EnrollmentPaymentCard> createState() => _EnrollmentPaymentCardState();
}

class _EnrollmentPaymentCardState extends State<_EnrollmentPaymentCard> {
  bool _isProcessing = false;

  Future<void> _confirmPayment() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Confirm Deposit'),
      content: Text('Are you sure you received the deposit from ${widget.data['tenantName']}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Yes, Confirm', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));

    if (confirmed != true) return;
    setState(() => _isProcessing = true);

    try {
      await FirebaseFirestore.instance.collection('enrollmentRequests').doc(widget.requestId).update({
        'status': 'confirmed',
        'confirmedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deposit confirmed!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectPayment() async {
    final reason = await showDialog<String>(context: context, builder: (context) {
      final controller = TextEditingController();
      return AlertDialog(
        title: const Text('Reject Deposit'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Reason')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    });

    if (reason == null) return;
    setState(() => _isProcessing = true);

    try {
      await FirebaseFirestore.instance.collection('enrollmentRequests').doc(widget.requestId).update({
        'status': 'bill_sent',
        'paymentRejectionReason': reason,
        'paymentRejectedAt': FieldValue.serverTimestamp(),
        'transactionId': FieldValue.delete(),
        'paymentSubmittedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment rejected.'), backgroundColor: Colors.orange));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenantName = widget.data['tenantName'] ?? 'Unknown';
    final roomNumber = widget.data['roomNumber']?.toString() ?? '-';
    final bedNumber = widget.data['bedNumber']?.toString() ?? '-';
    final totalAmount = (widget.data['totalBillAmount'] as num?)?.toDouble() ?? 
        ((widget.data['depositAmount'] as num?)?.toDouble() ?? 0) + ((widget.data['advanceAmount'] as num?)?.toDouble() ?? 0);
    final txnId = widget.data['transactionId'] ?? 'N/A';
    final submittedAt = widget.data['paymentSubmittedAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.orange.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(tenantName, 'Pending Enrollment Deposit', Colors.orange),
            const Divider(),
            _buildInfoItem(Icons.bed, 'Room/Bed', 'R$roomNumber / B$bedNumber'),
            const SizedBox(height: 12),
            _buildAmountBox(totalAmount, Colors.green),
            const SizedBox(height: 12),
            _buildTxnIdBox(txnId),
            if (submittedAt != null) ...[
              const SizedBox(height: 8),
              Text('Submitted: ${_formatDate(submittedAt.toDate())}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
            const SizedBox(height: 16),
            _buildActionButtons(_isProcessing, _confirmPayment, _rejectPayment),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// SHARED UI HELPERS
// ---------------------------------------------------------
Widget _buildHeader(String tenantName, String badgeText, MaterialColor color) {
  return Row(
    children: [
      CircleAvatar(backgroundColor: color.shade100, child: Text(tenantName.isNotEmpty ? tenantName[0].toUpperCase() : 'T', style: TextStyle(color: color.shade700, fontWeight: FontWeight.bold))),
      const SizedBox(width: 12),
      Expanded(child: Text(tenantName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.shade300)),
        child: Text(badgeText, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ),
    ],
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
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    ],
  );
}

Widget _buildAmountBox(num amount, MaterialColor color) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(8)),
    child: Row(
      children: [
        Icon(Icons.currency_rupee, color: color.shade700, size: 28),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Amount', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text('₹${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.shade700)),
          ],
        ),
      ],
    ),
  );
}

Widget _buildTxnIdBox(String txnId) {
  return Builder(
    builder: (context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Transaction ID / UTR', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(txnId, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: txnId));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction ID copied!')));
            },
            icon: const Icon(Icons.copy, size: 20),
          ),
        ],
      ),
    ),
  );
}

Widget _buildActionButtons(bool isProcessing, VoidCallback onConfirm, VoidCallback onReject) {
  return Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: isProcessing ? null : onReject,
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 12)),
          child: isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Reject'),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: ElevatedButton.icon(
          onPressed: isProcessing ? null : onConfirm,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12)),
          icon: isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle, color: Colors.white),
          label: Text(isProcessing ? 'Processing' : 'Confirm Payment', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    ],
  );
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
}
