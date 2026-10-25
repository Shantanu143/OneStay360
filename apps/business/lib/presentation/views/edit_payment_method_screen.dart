import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../view_models/payment_methods_viewmodel.dart';
import '../../models/payment_method_model.dart';
import '../views/widgets/business_scaffold.dart';

// List of major Indian banks
const List<String> indianBanks = [
  'Axis Bank',
  'Bank of Baroda',
  'Bank of India',
  'Bank of Maharashtra',
  'Central Bank of India',
  'City Union Bank',
  'Federal Bank',
  'HDFC Bank',
  'ICICI Bank',
  'IDBI Bank',
  'Indian Bank',
  'Indian Overseas Bank',
  'IndusInd Bank',
  'Kotak Mahindra Bank',
  'Punjab National Bank',
  'Schedules Commercial Banks',
  'South Indian Bank',
  'State Bank of India',
  'Union Bank of India',
  'Yes Bank',
];

class EditPaymentMethodScreen extends StatefulWidget {
  final PaymentMethod method;
  final String businessId;

  const EditPaymentMethodScreen({
    super.key,
    required this.method,
    required this.businessId,
  });

  @override
  State<EditPaymentMethodScreen> createState() => _EditPaymentMethodScreenState();
}

class _EditPaymentMethodScreenState extends State<EditPaymentMethodScreen> {
  final _formKey = GlobalKey<FormState>();

  // UPI fields
  late TextEditingController _upiIdController;
  late TextEditingController _upiPhoneController;

  // Bank fields
  late TextEditingController _bankNameController;
  late TextEditingController _accountHolderController;
  late TextEditingController _accountNumberController;
  late TextEditingController _ifscCodeController;
  late String _accountType;

  // Razorpay fields
  late TextEditingController _razorpayKeyIdController;
  late TextEditingController _razorpayKeySecretController;
  late TextEditingController _razorpayWebhookSecretController;

  String _existingKeyIdLast4 = '';
  String _existingKeySecretLast4 = '';
  String _existingWebhookLast4 = '';

  // Loading state
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadRazorpayPrivate();
  }

  void _initializeControllers() {
    _upiIdController = TextEditingController(text: widget.method.upiId ?? '');
    _upiPhoneController = TextEditingController(text: widget.method.phoneNumber ?? '');
    _bankNameController = TextEditingController(text: widget.method.bankName ?? '');
    _accountHolderController = TextEditingController(text: widget.method.accountHolderName ?? '');
    _accountNumberController = TextEditingController(text: widget.method.accountNumber ?? '');
    _ifscCodeController = TextEditingController(text: widget.method.ifscCode ?? '');
    _accountType = widget.method.accountType ?? 'Savings';
    _razorpayKeyIdController = TextEditingController();
    _razorpayKeySecretController = TextEditingController();
    _razorpayWebhookSecretController = TextEditingController();
  }

  Future<void> _loadRazorpayPrivate() async {
    if (widget.method.type != 'razorpay') return;
    try {
      final snap = await FirebaseFirestore.instance
          .doc('businesses/${widget.businessId}/settings/razorpay')
          .get();
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      setState(() {
        final hint = (data['keyIdHint'] ?? data['merchantId'] ?? '').toString();
        _existingKeyIdLast4 = hint.isNotEmpty ? hint : 'configured';
        _existingKeySecretLast4 = (data['hasSecret'] == true || data['verified'] == true) ? '••••' : '';
        _existingWebhookLast4 = data['hasWebhookSecret'] == true ? '••••' : '';
      });
    } catch (e) {
      // Ignore loading errors to avoid blocking edit flow.
    }
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _upiPhoneController.dispose();
    _bankNameController.dispose();
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    _razorpayKeyIdController.dispose();
    _razorpayKeySecretController.dispose();
    _razorpayWebhookSecretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BusinessScaffold(
      currentTab: BusinessTab.properties,
      titleText: 'Edit Payment Method',
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Method type display (non-editable)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getMethodTypeIcon(widget.method.type),
                        color: _getMethodTypeColor(widget.method.type),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Method Type',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Text(
                              _getMethodTypeName(widget.method.type),
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Dynamic form fields based on type
                if (widget.method.type == 'upi') _buildUPIForm(context),
                if (widget.method.type == 'bank') _buildBankForm(context),
                if (widget.method.type == 'cash') _buildCashForm(context),
                if (widget.method.type == 'razorpay') _buildRazorpayForm(context),

                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : () => _submitForm(context),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Update Payment Method'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUPIForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UPI Details',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _upiIdController,
          decoration: InputDecoration(
            labelText: 'UPI ID',
            hintText: 'example@bank',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.mail_outline),
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'UPI ID is required';
            }
            if (!value!.contains('@')) {
              return 'Enter a valid UPI ID';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _upiPhoneController,
          decoration: InputDecoration(
            labelText: 'Phone Number (Optional)',
            hintText: '9876543210',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.phone_outlined),
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value?.isNotEmpty ?? false) {
              if (value!.length < 10) {
                return 'Enter a valid phone number';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildBankForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bank Account Details',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        // Bank Name Dropdown with Search
        DropdownButtonFormField<String>(
          initialValue: _bankNameController.text.isEmpty ? null : _bankNameController.text,
          decoration: InputDecoration(
            labelText: 'Bank Name',
            hintText: 'Select or search bank',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.account_balance),
          ),
          items: indianBanks
              .map((bank) => DropdownMenuItem(
                    value: bank,
                    child: Text(bank),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _bankNameController.text = value);
            }
          },
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Bank name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        // Bank Name Search Field (Type to search)
        TextField(
          decoration: InputDecoration(
            labelText: 'Search Bank',
            hintText: 'Type bank name (e.g., "HDFC", "SBI")',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (query) {
            // Show filtered list
            if (query.isNotEmpty) {
              final filtered = indianBanks
                  .where((bank) =>
                      bank.toLowerCase().contains(query.toLowerCase()))
                  .toList();
              if (filtered.isNotEmpty) {
                _showBankSuggestions(context, filtered);
              }
            }
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _accountHolderController,
          decoration: InputDecoration(
            labelText: 'Account Holder Name',
            hintText: 'Your Name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.person_outline),
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Account holder name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _accountNumberController,
          decoration: InputDecoration(
            labelText: 'Account Number',
            hintText: '1234567890',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.numbers),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Account number is required';
            }
            if (value!.length < 8) {
              return 'Account number must be at least 8 digits';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _ifscCodeController,
          decoration: InputDecoration(
            labelText: 'IFSC Code',
            hintText: 'HDFC0001234',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.credit_card),
          ),
          inputFormatters: [_UpperCaseTextFormatter()],
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'IFSC code is required';
            }
            if (value!.length != 11) {
              return 'IFSC code must be 11 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _accountType,
          decoration: InputDecoration(
            labelText: 'Account Type',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.category_outlined),
          ),
          items: ['Savings', 'Current']
              .map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _accountType = value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildCashForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cash Payment Setup',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            border: Border.all(color: Colors.green.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cash Collection Method',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'You have selected to collect payments in cash. Tenants will be prompted to pay in cash during the payment process.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Make sure to maintain proper records of cash transactions.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRazorpayForm(BuildContext context) {
    final keyIdHelper = _existingKeyIdLast4.isNotEmpty ? 'Current: ****$_existingKeyIdLast4' : null;
    final keySecretHelper = _existingKeySecretLast4.isNotEmpty ? 'Current: ****$_existingKeySecretLast4' : null;
    final webhookHelper = _existingWebhookLast4.isNotEmpty ? 'Current: ****$_existingWebhookLast4' : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Razorpay Integration',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            border: Border.all(color: Colors.orange.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Razorpay charges processing fees and settles to your bank on its settlement cycle (typically T+2 business days, varies by account).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _razorpayKeyIdController,
          decoration: InputDecoration(
            labelText: 'Razorpay Key ID',
            hintText: 'rzp_test_...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.key),
            helperText: keyIdHelper,
          ),
          validator: (value) {
            if ((value?.isEmpty ?? true) && _existingKeyIdLast4.isEmpty) {
              return 'Key ID is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _razorpayKeySecretController,
          decoration: InputDecoration(
            labelText: 'Razorpay Key Secret',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.lock_outline),
            helperText: keySecretHelper,
          ),
          obscureText: true,
          validator: (value) {
            if ((value?.isEmpty ?? true) && _existingKeySecretLast4.isEmpty) {
              return 'Key Secret is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _razorpayWebhookSecretController,
          decoration: InputDecoration(
            labelText: 'Webhook Secret',
            hintText: 'Optional but recommended',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.link),
            helperText: webhookHelper,
          ),
        ),
      ],
    );
  }

  Future<void> _submitForm(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      late PaymentMethod updatedMethod;

      if (widget.method.type == 'upi') {
        updatedMethod = widget.method.copyWith(
          upiId: _upiIdController.text.trim(),
          phoneNumber: _upiPhoneController.text.trim().isEmpty
              ? null
              : _upiPhoneController.text.trim(),
          updatedAt: DateTime.now(),
        );
      } else if (widget.method.type == 'bank') {
        updatedMethod = widget.method.copyWith(
          bankName: _bankNameController.text.trim(),
          accountHolderName: _accountHolderController.text.trim(),
          accountNumber: _accountNumberController.text.trim(),
          ifscCode: _ifscCodeController.text.trim(),
          accountType: _accountType,
          updatedAt: DateTime.now(),
        );
      } else if (widget.method.type == 'razorpay') {
        final updates = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (_razorpayKeyIdController.text.trim().isNotEmpty) {
          updates['keyId'] = _razorpayKeyIdController.text.trim();
        }
        if (_razorpayKeySecretController.text.trim().isNotEmpty) {
          updates['keySecret'] = _razorpayKeySecretController.text.trim();
        }
        if (_razorpayWebhookSecretController.text.trim().isNotEmpty) {
          updates['webhookSecret'] = _razorpayWebhookSecretController.text.trim();
        }

        await FirebaseFirestore.instance
            .doc('businesses/${widget.businessId}/settings/razorpay_private')
            .set(updates, SetOptions(merge: true));

        await FirebaseFirestore.instance
            .doc('businesses/${widget.businessId}/settings/razorpay')
            .set({
          'paymentsEnabled': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        updatedMethod = widget.method.copyWith(
          updatedAt: DateTime.now(),
        );
      } else {
        // Cash - minimal update
        updatedMethod = widget.method.copyWith(
          updatedAt: DateTime.now(),
        );
      }

      final viewModel = context.read<PaymentMethodsViewModel>();
      final success = await viewModel.updatePaymentMethod(updatedMethod);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment method updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(viewModel.error.isEmpty
                  ? 'Failed to update payment method'
                  : viewModel.error),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  IconData _getMethodTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'upi':
        return Icons.account_balance_wallet;
      case 'bank':
        return Icons.account_balance;
      case 'cash':
        return Icons.local_atm;
      case 'razorpay':
        return Icons.language;
      default:
        return Icons.payment;
    }
  }

  Color _getMethodTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'upi':
        return Colors.blue;
      case 'bank':
        return Colors.orange;
      case 'cash':
        return Colors.green;
      case 'razorpay':
        return Colors.purple;
      default:
        return Colors.grey;
    }
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

  String _last4(String value) {
    if (value.isEmpty) return '';
    if (value.length <= 4) return value;
    return value.substring(value.length - 4);
  }

  void _showBankSuggestions(BuildContext context, List<String> suggestions) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(0, 300, 0, 0),
      items: suggestions
          .map((bank) => PopupMenuItem(
                value: bank,
                child: Text(bank),
              ))
          .toList(),
      elevation: 8,
    ).then((value) {
      if (value != null) {
        setState(() => _bankNameController.text = value);
      }
    });
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
