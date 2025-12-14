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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: viewModel.paymentMethods.length,
            itemBuilder: (context, index) {
              final method = viewModel.paymentMethods[index];
              return _buildPaymentMethodCard(context, viewModel, method, widget.businessId);
            },
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
