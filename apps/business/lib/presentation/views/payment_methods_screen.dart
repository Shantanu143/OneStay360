import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/payment_methods_viewmodel.dart';
import '../../models/payment_method_model.dart';
import '../views/widgets/business_scaffold.dart';
import 'add_payment_method_screen.dart';
import 'edit_payment_method_screen.dart';

class PaymentMethodsScreen extends StatefulWidget {
  final String businessId;

  const PaymentMethodsScreen({super.key, required this.businessId});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  bool _isVerifying = false;

  Future<void> _verifyRazorpaySetup() async {
    if (_isVerifying) return;
    setState(() => _isVerifying = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('verifyRazorpaySetup');
      await callable.call({'businessId': widget.businessId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Razorpay setup verified'), backgroundColor: Colors.green),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Verification failed'), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentMethodsViewModel>().loadPaymentMethods(widget.businessId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BusinessScaffold(
      currentTab: BusinessTab.properties,
      titleText: 'Payment Methods',
      body: Consumer<PaymentMethodsViewModel>(
        builder: (context, viewModel, _) {
          if (viewModel.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (viewModel.error.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error loading payment methods',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    viewModel.error,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      viewModel.loadPaymentMethods(widget.businessId);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (viewModel.paymentMethods.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.payment_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No payment methods added',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a payment method to start collecting payments',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }

          final razorpayMethod = viewModel.paymentMethods
              .firstWhere((m) => m.type.toLowerCase() == 'razorpay', orElse: () => PaymentMethod(
                    id: '',
                    businessId: widget.businessId,
                    type: 'razorpay',
                    isActive: false,
                    isPreferred: false,
                    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                  ));
          final hasRazorpay = razorpayMethod.id.isNotEmpty;
          final otherMethods = viewModel.paymentMethods
              .where((m) => m.type.toLowerCase() != 'razorpay')
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildRazorpaySetupCard(context, viewModel, razorpayMethod, hasRazorpay),
              const SizedBox(height: 16),
              ...otherMethods.map((method) => _buildPaymentMethodCard(context, viewModel, method, widget.businessId)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddPaymentMethodScreen(
                businessId: widget.businessId,
              ),
            ),
          ).then((_) {
            context.read<PaymentMethodsViewModel>().loadPaymentMethods(widget.businessId);
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPaymentMethodCard(
    BuildContext context,
    PaymentMethodsViewModel viewModel,
    PaymentMethod method,
    String businessId,
  ) {
    final isPreferred = method.isPreferred;
    final isActive = method.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with type, preferred badge, and status toggle
                Row(
                  children: [
                    // Payment method type icon
                    _buildMethodTypeIcon(method.type),
                    const SizedBox(width: 12),
                    // Method type and details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _getMethodTypeName(method.type),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (isPreferred)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      border: Border.all(color: Colors.green),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Preferred',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getMethodDisplayText(method),
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Status toggle
                    Switch(
                      value: isActive,
                      onChanged: (value) async {
                        await viewModel.togglePaymentMethodStatus(method, value);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value
                                    ? 'Payment method enabled'
                                    : 'Payment method disabled',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Divider before action buttons
          Divider(height: 1, color: Colors.grey[300]),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Make preferred button (if not already preferred)
                if (!isPreferred)
                  TextButton.icon(
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Make Preferred'),
                    onPressed: () async {
                      await viewModel.setPreferredPaymentMethod(businessId, method.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment method marked as preferred'),
                          ),
                        );
                      }
                    },
                  )
                else
                  TextButton.icon(
                    icon: const Icon(Icons.star),
                    label: const Text('Preferred'),
                    onPressed: null, // Disabled for preferred method
                  ),
                const Spacer(),
                // Edit button
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditPaymentMethodScreen(
                          method: method,
                          businessId: businessId,
                        ),
                      ),
                    ).then((_) {
                      context.read<PaymentMethodsViewModel>().loadPaymentMethods(businessId);
                    });
                  },
                ),
                // Delete button
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  onPressed: () => _showDeleteConfirmation(context, viewModel, method, businessId),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRazorpaySetupCard(
    BuildContext context,
    PaymentMethodsViewModel viewModel,
    PaymentMethod razorpayMethod,
    bool hasRazorpay,
  ) {
    final razorpayStatus = FirebaseFirestore.instance
        .doc('businesses/${widget.businessId}/settings/razorpay')
        .get();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha(24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.language, color: Colors.purple, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Razorpay Setup',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        if (hasRazorpay)
                          _chip('Configured', Colors.green.shade50, Colors.green.shade800),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Online payments with Razorpay fees and settlement cycle.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _buildRazorpayStatusChip(razorpayStatus),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Razorpay applies its own commission and settles to your bank on its schedule (typically T+2 business days).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => hasRazorpay
                          ? EditPaymentMethodScreen(method: razorpayMethod, businessId: widget.businessId)
                          : AddPaymentMethodScreen(businessId: widget.businessId, initialMethodType: 'razorpay'),
                    ),
                  ).then((_) {
                    context.read<PaymentMethodsViewModel>().loadPaymentMethods(widget.businessId);
                  });
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(hasRazorpay ? 'Edit Setup' : 'Set Up Razorpay'),
              ),
              if (hasRazorpay) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _isVerifying ? null : _verifyRazorpaySetup,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isVerifying
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Verify Setup'),
                ),
              ],
              const Spacer(),
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Razorpay Fees & Settlement'),
                      content: const Text(
                        'Razorpay charges processing fees based on your plan and settles to your bank on its settlement cycle. Most accounts see T+2 business days, but it can vary by account and risk settings.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Got it'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Learn More'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRazorpayStatusChip(Future<DocumentSnapshot<Map<String, dynamic>>> statusFuture) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: statusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _chip('Checking', Colors.grey.shade200, Colors.grey.shade700);
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _chip('Not set', Colors.grey.shade200, Colors.grey.shade700);
        }

        final data = snapshot.data!.data() ?? {};
        final paymentsEnabled = data['paymentsEnabled'] == true;
        final verified = data['verified'] == true;
        final kycStatus = (data['kycStatus'] ?? '').toString();

        if (verified) {
          return _chip('Verified', Colors.green.shade50, Colors.green.shade800);
        }

        if (!paymentsEnabled) {
          return _chip('Disabled', Colors.orange.shade50, Colors.orange.shade800);
        }

        if (kycStatus.isNotEmpty) {
          final label = kycStatus.replaceAll('_', ' ').toUpperCase();
          return _chip(label, Colors.green.shade50, Colors.green.shade800);
        }

        return _chip('Enabled', Colors.green.shade50, Colors.green.shade800);
      },
    );
  }

  Widget _chip(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: foreground.withAlpha(80)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _buildMethodTypeIcon(String type) {
    IconData icon;
    Color color;

    switch (type.toLowerCase()) {
      case 'upi':
        icon = Icons.account_balance_wallet;
        color = Colors.blue;
        break;
      case 'bank':
        icon = Icons.account_balance;
        color = Colors.orange;
        break;
      case 'cash':
        icon = Icons.local_atm;
        color = Colors.green;
        break;
      case 'razorpay':
        icon = Icons.language;
        color = Colors.purple;
        break;
      default:
        icon = Icons.payment;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  String _getMethodTypeName(String type) {
    switch (type.toLowerCase()) {
      case 'upi':
        return 'UPI';
      case 'bank':
        return 'Bank Transfer';
      case 'cash':
        return 'Cash';
      case 'razorpay':
        return 'Razorpay';
      default:
        return 'Payment Method';
    }
  }

  String _getMethodDisplayText(PaymentMethod method) {
    switch (method.type.toLowerCase()) {
      case 'upi':
        return method.upiId ?? 'No UPI ID';
      case 'bank':
        return method.accountNumber ?? 'No account';
      case 'cash':
        return 'Cash payment collection';
      case 'razorpay':
        return 'Online payments via Razorpay';
      default:
        return 'Unknown method';
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    PaymentMethodsViewModel viewModel,
    PaymentMethod method,
    String businessId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment Method?'),
        content: Text(
          'Are you sure you want to delete ${_getMethodTypeName(method.type)}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await viewModel.deletePaymentMethod(businessId, method.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Payment method deleted' : 'Failed to delete payment method',
                    ),
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
