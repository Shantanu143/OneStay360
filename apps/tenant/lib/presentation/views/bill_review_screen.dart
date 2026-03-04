import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen for tenant to review bill and submit payment confirmation
/// 
/// Flow:
/// 1. Owner sends bill → status becomes 'bill_sent'
/// 2. Tenant sees this screen with payment details
/// 3. Tenant pays via UPI (using deep link)
/// 4. Tenant enters transaction ID and clicks "I've Paid"
/// 5. Owner receives notification to verify
/// 6. Owner confirms → Tenant record created
class BillReviewScreen extends StatefulWidget {
  final String enrollmentRequestId;
  
  const BillReviewScreen({
    super.key,
    required this.enrollmentRequestId,
  });

  @override
  State<BillReviewScreen> createState() => _BillReviewScreenState();
}

class _BillReviewScreenState extends State<BillReviewScreen> {
  final _transactionIdController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _transactionIdController.dispose();
    super.dispose();
  }

  Future<void> _openUpiApp(String upiId, double amount, String propertyName) async {
    // Build UPI intent URL
    final upiUrl = Uri.parse(
      'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(propertyName)}&am=$amount&cu=INR&tn=${Uri.encodeComponent("Deposit for $propertyName")}'
    );
    
    try {
      if (await canLaunchUrl(upiUrl)) {
        await launchUrl(upiUrl, mode: LaunchMode.externalApplication);
      } else {
        // Show manual payment instructions
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Open any UPI app and pay to $upiId'),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Copy UPI',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: upiId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('UPI ID copied!')),
                  );
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open UPI app: $e')),
        );
      }
    }
  }

  Future<void> _submitPayment(Map<String, dynamic> data) async {
    final transactionId = _transactionIdController.text.trim();
    
    if (transactionId.isEmpty) {
      setState(() => _error = 'Please enter the transaction ID / UTR number');
      return;
    }
    
    if (transactionId.length < 6) {
      setState(() => _error = 'Transaction ID seems too short. Please check and re-enter.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _firestore.collection('enrollmentRequests').doc(widget.enrollmentRequestId).update({
        'status': 'payment_submitted',
        'transactionId': transactionId,
        'paymentSubmittedAt': FieldValue.serverTimestamp(),
        'paymentSubmittedBy': FirebaseAuth.instance.currentUser?.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment submitted! Owner will verify and confirm shortly.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to submit: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review & Pay'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection('enrollmentRequests')
            .doc(widget.enrollmentRequestId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Request not found'),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] as String?;
          
          // Check if already submitted or confirmed
          if (status == 'payment_submitted') {
            return _buildWaitingForConfirmation(data);
          }
          
          if (status == 'confirmed' || status == 'approved') {
            return _buildPaymentConfirmed(data);
          }
          
          if (status != 'bill_sent') {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('Status: ${status ?? "Unknown"}'),
                  const Text('No pending bill for this request.'),
                ],
              ),
            );
          }

          return _buildBillReview(data);
        },
      ),
    );
  }

  Widget _buildBillReview(Map<String, dynamic> data) {
    final propertyName = data['propertyName'] as String? ?? 'PG';
    final roomNumber = data['roomNumber']?.toString() ?? '-';
    final bedNumber = data['bedNumber']?.toString() ?? '-';
    final depositAmount = (data['depositAmount'] as num?)?.toDouble() ?? 0;
    final advanceAmount = (data['advanceAmount'] as num?)?.toDouble() ?? 0;
    final monthlyRent = (data['monthlyRent'] as num?)?.toDouble() ?? 0;
    final totalAmount = (data['totalBillAmount'] as num?)?.toDouble() ?? (depositAmount + advanceAmount);
    final ownerUpiId = data['ownerUpiId'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property & Room Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🎉 Room Reserved For You!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.apartment, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        propertyName,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.bed, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Room $roomNumber, Bed $bedNumber',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Monthly Rent: ₹${monthlyRent.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Bill Breakdown
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildBillRow('Security Deposit', depositAmount),
                const Divider(),
                _buildBillRow('Advance Rent', advanceAmount),
                const Divider(thickness: 2),
                _buildBillRow('Total Amount', totalAmount, isTotal: true),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // UPI Payment Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'Pay via UPI',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pay directly to the owner\'s UPI - No platform fees!',
                  style: TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 16),
                
                // UPI ID display
                if (ownerUpiId.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'UPI ID',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                ownerUpiId,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: ownerUpiId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('UPI ID copied!')),
                            );
                          },
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy UPI ID',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Pay Now Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openUpiApp(ownerUpiId, totalAmount, propertyName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new, color: Colors.white),
                      label: Text(
                        'Pay ₹${totalAmount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} via UPI',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Transaction ID Input
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Confirm Your Payment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'After paying, enter the UPI transaction ID (UTR number) from your payment app to confirm.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _transactionIdController,
                  decoration: InputDecoration(
                    labelText: 'Transaction ID / UTR Number',
                    hintText: 'e.g., 123456789012',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.receipt_long),
                    errorText: _error,
                  ),
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : () => _submitPayment(data),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "I've Paid - Confirm Payment",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, double amount, {bool isTotal = false}) {
    final formattedAmount = '₹${amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    )}';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.grey.shade700,
            ),
          ),
          Text(
            formattedAmount,
            style: TextStyle(
              fontSize: isTotal ? 20 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? Colors.green.shade700 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingForConfirmation(Map<String, dynamic> data) {
    final transactionId = data['transactionId'] as String? ?? '';
    final propertyName = data['propertyName'] as String? ?? 'PG';
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.hourglass_top,
                size: 64,
                color: Colors.orange.shade600,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Verification Pending',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your payment for $propertyName has been submitted.\n\nThe owner is verifying your transaction.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long, color: Colors.grey),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transaction ID',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        transactionId,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'You will be notified once confirmed.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentConfirmed(Map<String, dynamic> data) {
    final propertyName = data['propertyName'] as String? ?? 'PG';
    final roomNumber = data['roomNumber']?.toString() ?? '-';
    final bedNumber = data['bedNumber']?.toString() ?? '-';
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 64,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '🎉 Welcome!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your payment has been confirmed.\nWelcome to $propertyName!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bed, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Room $roomNumber, Bed $bedNumber',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text(
                'Go to My PG',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
