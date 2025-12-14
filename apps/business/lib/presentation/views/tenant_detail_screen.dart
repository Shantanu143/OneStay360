// lib/presentation/views/business/tenant_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/business_scaffold.dart';

class TenantDetailScreen extends StatefulWidget {
  final Map<String, dynamic> tenant;
  final String propertyName;

  const TenantDetailScreen({
    super.key,
    required this.tenant,
    required this.propertyName,
  });

  @override
  State<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends State<TenantDetailScreen> {
  String formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Not recorded';

    DateTime? dateTime;

    // Handle Firestore Timestamp objects
    if (dateValue.runtimeType.toString().contains('Timestamp')) {
      try {
        dateTime = dateValue.toDate() as DateTime;
      } catch (e) {
        return dateValue.toString();
      }
    } else if (dateValue is String) {
      try {
        dateTime = DateTime.parse(dateValue);
      } catch (e) {
        return dateValue;
      }
    } else if (dateValue is DateTime) {
      dateTime = dateValue;
    } else {
      return dateValue.toString();
    }

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tenant = widget.tenant;
    final name = tenant['name'] ?? 'Unknown Tenant';
    final id = tenant['id'] ?? 'N/A';
    final phone = tenant['phone'] ?? 'Not provided';
    final room = tenant['room'] ?? 'Not specified';
    final bed = tenant['bed'] ?? 'Not specified';
    final rent = tenant['rent'] ?? 'N/A';
    final status = tenant['status'] ?? 'Unknown';
    final joinDate = tenant['joinDate'] ?? 'Not recorded';
    final lastPayment = tenant['lastPayment'] ?? 'No payment';

    return BusinessScaffold(
      currentTab: BusinessTab.properties,
      showBackButton: true,
      title: const Text(
        'Tenant Details',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tenant Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF2E7D32).withOpacity(0.9),
                    const Color(0xFF1B5E20).withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E7D32).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ID: $id',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Residing at: ${widget.propertyName}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Contact Information Section
            _buildSectionTitle('Contact Information'),
            const SizedBox(height: 12),
            _buildInfoCard(
              icon: Icons.phone,
              label: 'Phone',
              value: phone,
              onTap: () {
                if (phone != 'Not provided') {
                  Clipboard.setData(ClipboardData(text: phone));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Phone copied to clipboard')),
                  );
                }
              },
            ),
            const SizedBox(height: 12),

            // Room & Bed Information Section
            _buildSectionTitle('Room Assignment'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDetailCard(
                    icon: Icons.meeting_room,
                    title: 'Room',
                    value: room.toString(),
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailCard(
                    icon: Icons.bed,
                    title: 'Bed',
                    value: bed.toString(),
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Financial Information Section
            _buildSectionTitle('Financial Information'),
            const SizedBox(height: 12),
            _buildDetailCard(
              icon: Icons.currency_rupee,
              title: 'Monthly Rent',
              value: '₹${rent.toString()}',
              color: Colors.green,
            ),
            const SizedBox(height: 12),

            // Dates Section
            _buildSectionTitle('Important Dates'),
            const SizedBox(height: 12),
            _buildDetailCard(
              icon: Icons.calendar_today,
              title: 'Join Date',
              value: formatDate(joinDate),
              color: Colors.purple,
            ),
            const SizedBox(height: 12),
            _buildDetailCard(
              icon: Icons.payment,
              title: 'Last Payment',
              value: formatDate(lastPayment),
              color: Colors.red,
            ),
            const SizedBox(height: 24),

            // Payment History Section
            _buildSectionTitle('Payment History'),
            const SizedBox(height: 12),
            _buildPaymentTimeline(),
            const SizedBox(height: 24),

            // Action Buttons
            _buildSectionTitle('Actions'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Contact feature coming soon'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.message),
                    label: const Text('Send Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Call feature coming soon'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.call),
                    label: const Text('Call Tenant'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Edit tenant feature coming soon'),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Tenant Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showConfirmDialog(
                    context,
                    'Remove Tenant',
                    'Are you sure you want to remove this tenant? This action cannot be undone.',
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tenant removal feature coming soon'),
                        ),
                      );
                    },
                  );
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove Tenant'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTimeline() {
    // Sample payment history data
    final payments = [
      {
        'month': 'December 2024',
        'amount': 8000,
        'date': DateTime.now(),
        'status': 'Paid',
        'method': 'Bank Transfer',
      },
      {
        'month': 'November 2024',
        'amount': 8000,
        'date': DateTime.now().subtract(const Duration(days: 30)),
        'status': 'Paid',
        'method': 'UPI',
      },
      {
        'month': 'October 2024',
        'amount': 8000,
        'date': DateTime.now().subtract(const Duration(days: 60)),
        'status': 'Paid',
        'method': 'Cash',
      },
      {
        'month': 'September 2024',
        'amount': 8000,
        'date': DateTime.now().subtract(const Duration(days: 90)),
        'status': 'Pending',
        'method': 'Awaiting',
      },
    ];

    return Column(
      children: List.generate(payments.length, (index) {
        final payment = payments[index];
        final isPaid = payment['status'] == 'Paid';
        
        return Column(
          children: [
            // Timeline item
            Row(
              children: [
                // Timeline circle and line
                Column(
                  children: [
                    // Circle
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPaid ? Colors.green : Colors.orange,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isPaid ? Colors.green : Colors.orange)
                                .withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isPaid ? Icons.check : Icons.schedule,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                    // Line to next item
                    if (index < payments.length - 1)
                      Container(
                        width: 2,
                        height: 100,
                        color: Colors.grey.shade300,
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Payment details
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPaid ? Colors.green.shade200 : Colors.orange.shade200,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              payment['month'].toString(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPaid ? Colors.green : Colors.orange,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                payment['status'].toString(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '₹${payment['amount']}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'via ${payment['method'].toString()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              formatDate(payment['date']),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (index < payments.length - 1) const SizedBox(height: 0),
          ],
        );
      }),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.blue.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.copy,
                size: 18,
                color: Colors.grey.shade400,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text(
              'Confirm',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
