// lib/screens/add_payment_method_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../view_models/payment_methods_viewmodel.dart';
import '../../models/payment_method_model.dart';
import '../views/widgets/business_scaffold.dart';

// -------------------- Config --------------------
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
  'South Indian Bank',
  'State Bank of India',
  'Union Bank of India',
  'Yes Bank',
];

// -------------------- Screen --------------------
class AddPaymentMethodScreen extends StatefulWidget {
  final String businessId;
  const AddPaymentMethodScreen({super.key, required this.businessId});

  @override
  State<AddPaymentMethodScreen> createState() => _AddPaymentMethodScreenState();
}

class _AddPaymentMethodScreenState extends State<AddPaymentMethodScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Segmented: 0 = UPI, 1 = Bank, 2 = Cash
  int _selectedIndex = 0;

  // Controllers - UPI
  final _upiIdController = TextEditingController();
  final _upiPhoneController = TextEditingController();

  // Controllers - Bank
  final _bankNameController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _confirmAccountNumberController = TextEditingController();
  final _ifscCodeController = TextEditingController();

  String _accountType = 'Savings';
  List<String> _bankSuggestions = [];

  bool _isSubmitting = false;

  // Animation for the form switch
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _upiIdController.dispose();
    _upiPhoneController.dispose();
    _bankNameController.dispose();
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    _confirmAccountNumberController.dispose();
    _ifscCodeController.dispose();
    super.dispose();
  }

  // -------------------- Validators --------------------
  String? _validateUpi(String? value) {
    if (value == null || value.trim().isEmpty) return 'UPI ID is required';
    // simple UPI id pattern check: something@bank
    if (!RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$').hasMatch(value.trim())) {
      return 'Enter a valid UPI ID (example@bank)';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return null; // optional
    final cleaned = value.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != 10) return 'Enter 10 digit phone number';
    return null;
  }

  String? _validateAccountHolder(String? value) {
    if (value == null || value.trim().isEmpty) return 'Account holder required';
    if (value.trim().length < 3) return 'Enter full name';
    return null;
  }

  String? _validateAccountNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Account number required';
    final digitsOnly = value.trim();
    if (!RegExp(r'^[0-9]{8,18}$').hasMatch(digitsOnly)) {
      return 'Enter valid account number (8-18 digits)';
    }
    return null;
  }

  String? _validateConfirmAccountNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Confirm account number';
    if (value.trim() != _accountNumberController.text.trim()) {
      return 'Account numbers do not match';
    }
    return null;
  }

  String? _validateIfsc(String? value) {
    if (value == null || value.trim().isEmpty) return 'IFSC is required';
    final v = value.trim().toUpperCase();
    final regex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
    if (!regex.hasMatch(v)) return 'Enter valid IFSC (e.g., HDFC0001234)';
    return null;
  }

  // -------------------- Submit --------------------
  Future<void> _submit() async {
    final form = _formKey.currentState!;
    if (!form.validate()) {
      // show first error via standard validation UI
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      late PaymentMethod method;
      final now = DateTime.now().toUtc();

      if (_selectedIndex == 0) {
        // UPI
        method = PaymentMethod(
          id: now.millisecondsSinceEpoch.toString(),
          businessId: widget.businessId,
          type: 'upi',
          upiId: _upiIdController.text.trim(),
          phoneNumber: _upiPhoneController.text.trim().isEmpty
              ? null
              : _upiPhoneController.text.trim(),
          isActive: true,
          isPreferred: false,
          createdAt: now,
          updatedAt: now,
        );
      } else if (_selectedIndex == 1) {
        // Bank
        method = PaymentMethod(
          id: now.millisecondsSinceEpoch.toString(),
          businessId: widget.businessId,
          type: 'bank',
          bankName: _bankNameController.text.trim(),
          accountHolderName: _accountHolderController.text.trim(),
          accountNumber: _accountNumberController.text.trim(),
          ifscCode: _ifscCodeController.text.trim().toUpperCase(),
          accountType: _accountType,
          isActive: true,
          isPreferred: false,
          createdAt: now,
          updatedAt: now,
        );
      } else {
        // Cash
        method = PaymentMethod(
          id: now.millisecondsSinceEpoch.toString(),
          businessId: widget.businessId,
          type: 'cash',
          isActive: true,
          isPreferred: false,
          createdAt: now,
          updatedAt: now,
        );
      }

      final vm = context.read<PaymentMethodsViewModel>();
      final success = await vm.addPaymentMethod(widget.businessId, method);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment method added'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(vm.error.isEmpty ? 'Failed to add payment method' : vm.error),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // -------------------- Helpers --------------------
  InputDecoration _in(String label, {IconData? icon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      prefixIcon: icon != null ? Icon(icon) : null,
    );
  }

  void _onBankQueryChanged(String query) {
    if (query.isEmpty) {
      setState(() => _bankSuggestions = []);
      return;
    }
    final filtered = indianBanks
        .where((b) => b.toLowerCase().contains(query.toLowerCase()))
        .toList();
    setState(() => _bankSuggestions = filtered);
  }

  // -------------------- Build --------------------
  @override
  Widget build(BuildContext context) {
    return BusinessScaffold(
      currentTab: BusinessTab.properties,
      titleText: 'Add Payment Method',
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopHeader(context),
                      const SizedBox(height: 18),
                      _buildSegmentedControl(context),
                      const SizedBox(height: 18),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: _buildFormBody(context),
                      ),
                      const SizedBox(height: 120), // leave space for sticky bar
                    ],
                  ),
                ),
              ),
            ),
            _buildStickyBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add a payment method', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Customers will see active methods during checkout. Keep verified bank/UPI ready.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildSegmentedControl(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          _segmentedButton('UPI', 0),
          _segmentedButton('Bank', 1),
          _segmentedButton('Cash', 2),
        ],
      ),
    );
  }

  Widget _segmentedButton(String label, int index) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade600 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                )),
          ),
        ),
      ),
    );
  }

  Widget _buildFormBody(BuildContext context) {
    switch (_selectedIndex) {
      case 0:
        return _buildUPIForm(context);
      case 1:
        return _buildBankForm(context);
      case 2:
      default:
        return _buildCashForm(context);
    }
  }

  // -------------------- UPI --------------------
  Widget _buildUPIForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('UPI Details', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextFormField(
          controller: _upiIdController,
          decoration: _in('UPI ID', icon: Icons.account_balance_wallet, hint: 'example@bank'),
          validator: _validateUpi,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _upiPhoneController,
          decoration: _in('Phone (optional)', icon: Icons.phone_outlined, hint: '9876543210'),
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          validator: _validatePhone,
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          title: 'Pro tip',
          content: 'Use UPI ID from your business account to avoid reconciliation issues.',
          icon: Icons.info_outline,
          color: Colors.blue.shade50,
        ),
      ],
    );
  }

  // -------------------- Bank --------------------
  Widget _buildBankForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bank Account', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),

        // Bank Name - searchable inline field
        TextFormField(
          controller: _bankNameController,
          decoration: _in('Bank name', icon: Icons.account_balance, hint: 'Search bank (HDFC, SBI...)'),
          onChanged: (q) => _onBankQueryChanged(q),
          textInputAction: TextInputAction.next,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Bank is required';
            if (!indianBanks.map((e) => e.toLowerCase()).contains(v.trim().toLowerCase())) {
              return 'Select a valid bank from suggestions';
            }
            return null;
          },
        ),

        // suggestions inline
        if (_bankSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _bankSuggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final bank = _bankSuggestions[i];
                return ListTile(
                  dense: true,
                  title: Text(bank),
                  onTap: () {
                    _bankNameController.text = bank;
                    setState(() => _bankSuggestions = []);
                    FocusScope.of(context).nextFocus();
                  },
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 12),
        TextFormField(
          controller: _accountHolderController,
          decoration: _in('Account holder name', icon: Icons.person_outline),
          validator: _validateAccountHolder,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _accountNumberController,
          decoration: _in('Account number', icon: Icons.numbers),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: _validateAccountNumber,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirmAccountNumberController,
          decoration: _in('Confirm account number', icon: Icons.numbers),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: _validateConfirmAccountNumber,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _ifscCodeController,
          decoration: _in('IFSC code', icon: Icons.credit_card, hint: 'HDFC0001234'),
          inputFormatters: [UpperCaseTextFormatter(), FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')), LengthLimitingTextInputFormatter(11)],
          validator: _validateIfsc,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _accountType,
          decoration: _in('Account type', icon: Icons.category_outlined),
          items: ['Savings', 'Current'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _accountType = v);
          },
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          title: 'Verification',
          content: 'We recommend depositing a small amount for verification before marking this account preferred.',
          icon: Icons.verified_user_outlined,
          color: Colors.green.shade50,
        ),
      ],
    );
  }

  // -------------------- Cash --------------------
  Widget _buildCashForm(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Cash Collection', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      Text(
        'Choose cash if you want tenants to pay you directly in person. Keep proper manual records.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
      _buildInfoCard(
        title: 'Note',
        content: 'Cash is not recommended for large-scale operations due to reconciliation overhead.',
        icon: Icons.warning_amber_outlined,
        color: Colors.orange.shade50,
      ),
    ]);
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(content, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ],
      ),
    );
  }

  // -------------------- Sticky submit bar --------------------
  Widget _buildStickyBar(BuildContext context) {
    final label = _selectedIndex == 0 ? 'Add UPI' : _selectedIndex == 1 ? 'Add Bank' : 'Add Cash';
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(label),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Cancel',
              onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------- Small helpers --------------------
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}
