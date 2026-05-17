import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/providers/tenant_state_provider.dart';

class RentPaymentScreen extends StatefulWidget {
  final int? prefilledAmount;
  final String? prefilledMonth;
  final String? rentInvoiceId;

  const RentPaymentScreen({
    super.key,
    this.prefilledAmount,
    this.prefilledMonth,
    this.rentInvoiceId,
  });

  @override
  State<RentPaymentScreen> createState() => _RentPaymentScreenState();
}

class _RentPaymentScreenState extends State<RentPaymentScreen> {
  final _amountController = TextEditingController();
  final _transactionIdController = TextEditingController();

  String _selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());
  final List<String> _monthOptions = [];

  // 'onestay' | 'UPI' | 'Cash'
  String _paymentMode = 'onestay';
  bool _isSubmitting = false;
  bool _isGeneratingLink = false;
  bool _paymentsEnabled = false;
  bool _checkingPaymentStatus = true;

  @override
  void initState() {
    super.initState();
    // Generate month options
    final now = DateTime.now();
    for (int i = -2; i <= 1; i++) {
      final d = DateTime(now.year, now.month + i);
      _monthOptions.add(DateFormat('MMMM yyyy').format(d));
    }

    // Apply prefilled values
    if (widget.prefilledMonth != null && widget.prefilledMonth!.isNotEmpty) {
      _selectedMonth = widget.prefilledMonth!;
      if (!_monthOptions.contains(_selectedMonth)) {
        _monthOptions.add(_selectedMonth);
      }
    }

    if (widget.prefilledAmount != null && widget.prefilledAmount! > 0) {
      _amountController.text = widget.prefilledAmount.toString();
    }

    _checkOnlinePayments();
  }

  Future<void> _checkOnlinePayments() async {
    final tenantState = Provider.of<TenantStateProvider>(context, listen: false);
    if (tenantState.businessId.isEmpty) {
      setState(() => _checkingPaymentStatus = false);
      return;
    }

    try {
      final configSnap = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(tenantState.businessId)
          .collection('settings')
          .doc('razorpay')
          .get();

      if (configSnap.exists) {
        final data = configSnap.data()!;
        setState(() {
          _paymentsEnabled = data['paymentsEnabled'] == true;
          _checkingPaymentStatus = false;
        });
      } else {
        setState(() {
          _paymentsEnabled = false;
          _checkingPaymentStatus = false;
          _paymentMode = 'UPI'; // Fallback if no Razorpay setup
        });
      }
    } catch (e) {
      setState(() {
        _paymentsEnabled = false;
        _checkingPaymentStatus = false;
        _paymentMode = 'UPI';
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _transactionIdController.dispose();
    super.dispose();
  }

  Future<void> _payViaOneStay(TenantStateProvider tenantState) async {
    if (widget.rentInvoiceId == null || widget.rentInvoiceId!.isEmpty) {
      _showError('No rent invoice found. Please wait for your invoice to be generated.');
      return;
    }

    setState(() => _isGeneratingLink = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('createPaymentLink');
      final result = await callable.call({
        'businessId': tenantState.businessId,
        'tenantId': tenantState.tenantId,
        'rentInvoiceId': widget.rentInvoiceId,
      });

      final paymentLinkUrl = result.data['paymentLinkUrl'] as String?;
      if (paymentLinkUrl != null && paymentLinkUrl.isNotEmpty) {
        final uri = Uri.parse(paymentLinkUrl);
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          // After returning, show a status message
          if (mounted) {
            _showPaymentPendingDialog();
          }
        } catch (e) {
          _showError('Could not open payment link. Please try again.');
        }
      } else {
        _showError('Failed to generate payment link.');
      }
    } on FirebaseFunctionsException catch (e) {
      _showError(e.message ?? 'Failed to create payment link');
    } catch (e) {
      _showError('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isGeneratingLink = false);
    }
  }

  void _showPaymentPendingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.hourglass_top_rounded, color: Color(0xFF0891B2)),
            SizedBox(width: 8),
            Text('Payment Processing'),
          ],
        ),
        content: const Text(
          'If you completed the payment, it will be automatically verified within a few minutes.\n\nYou can check your payment status on the My PG screen.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // Go back to My PG
            },
            child: const Text('Go Back to My PG'),
          ),
        ],
      ),
    );
  }

  Future<void> _openUpiApp(String upiId, double amount, String propertyName) async {
    final upiUrl = Uri.parse(
      'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(propertyName)}&am=$amount&cu=INR&tn=${Uri.encodeComponent("Rent for $propertyName $_selectedMonth")}'
    );

    try {
      await launchUrl(upiUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Open any UPI app and pay to $upiId'),
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
  }

  Future<void> _submitPayment(TenantStateProvider tenantState) async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showError('Please enter the rent amount you paid.');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount.');
      return;
    }

    final transactionId = _transactionIdController.text.trim();
    if (_paymentMode == 'UPI' && transactionId.isEmpty) {
      _showError('Please enter the UPI transaction ID.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final httpsCallable = FirebaseFunctions.instance.httpsCallable('submitRentPayment');
      await httpsCallable.call({
        'businessId': tenantState.businessId,
        'amount': amount,
        'month': _selectedMonth,
        'paymentMode': _paymentMode,
        'transactionId': transactionId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment submitted! Awaiting owner confirmation.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseFunctionsException catch (e) {
      _showError(e.message ?? 'Failed to submit payment');
    } catch (e) {
      _showError('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Rent'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Consumer<TenantStateProvider>(
        builder: (context, tenantState, child) {
          if (tenantState.businessId.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('You are not assigned to a property yet.', textAlign: TextAlign.center),
              ),
            );
          }

          final rent = (tenantState.tenantData['monthlyRent'] as num?)?.toDouble() ?? 0.0;
          final propertyName = tenantState.currentPG;
          final upiId = tenantState.tenantData['propertyUpiId'] as String? ??
                        tenantState.tenantData['businessUpiId'] as String? ?? '';

          if (_amountController.text.isEmpty && rent > 0) {
            _amountController.text = rent.toInt().toString();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0891B2), Color(0xFF0e7490)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.apartment, color: Colors.white70),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              propertyName,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Monthly Rent', style: TextStyle(color: Colors.white70)),
                          Text(
                            '₹${rent.toInt()}',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Payment Method Selection
                const Text('Choose Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // Pay via OneStay (Recommended)
                if (!_checkingPaymentStatus && _paymentsEnabled)
                  _buildPaymentOption(
                    title: 'Pay via OneStay',
                    subtitle: 'Recommended • Auto-verified',
                    icon: Icons.verified_rounded,
                    color: const Color(0xFF10b981),
                    badgeText: '🟢 Recommended',
                    isSelected: _paymentMode == 'onestay',
                    onTap: () => setState(() => _paymentMode = 'onestay'),
                  ),

                if (!_checkingPaymentStatus && _paymentsEnabled)
                  const SizedBox(height: 10),

                // Pay via UPI
                _buildPaymentOption(
                  title: 'Pay via UPI',
                  subtitle: 'Manual • Owner verifies',
                  icon: Icons.account_balance_wallet,
                  color: const Color(0xFFf59e0b),
                  badgeText: '🟡 Manual',
                  isSelected: _paymentMode == 'UPI',
                  onTap: () => setState(() => _paymentMode = 'UPI'),
                ),

                const SizedBox(height: 10),

                // Cash
                _buildPaymentOption(
                  title: 'Cash',
                  subtitle: 'Manual • Owner verifies',
                  icon: Icons.money,
                  color: const Color(0xFFef4444),
                  badgeText: '🔴 Manual',
                  isSelected: _paymentMode == 'Cash',
                  onTap: () => setState(() => _paymentMode = 'Cash'),
                ),

                const SizedBox(height: 24),

                // ── OneStay Pay Flow ──
                if (_paymentMode == 'onestay') ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFecfdf5),
                      border: Border.all(color: const Color(0xFF10b981).withAlpha(80)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shield_rounded, color: Color(0xFF10b981), size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Secure payment powered by Razorpay',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF065f46)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pay securely using UPI, Cards, or Net Banking. Your payment will be auto-verified — no screenshots or transaction IDs needed.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF047857), height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingLink ? null : () => _payViaOneStay(tenantState),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10b981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      icon: _isGeneratingLink
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.lock_rounded, size: 20),
                      label: Text(
                        _isGeneratingLink ? 'Generating Payment Link...' : 'Pay ₹${_amountController.text.isEmpty ? rent.toInt() : _amountController.text} Securely',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],

                // ── UPI Flow ──
                if (_paymentMode == 'UPI') ...[
                  // Amount and Month
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedMonth,
                          decoration: const InputDecoration(
                            labelText: 'Rent Month',
                            border: OutlineInputBorder(),
                          ),
                          items: _monthOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedMonth = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: 'Amount Paid (₹)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.currency_rupee, size: 18),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (upiId.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Owner UPI ID', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(upiId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: upiId));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI ID copied!')));
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final amt = double.tryParse(_amountController.text) ?? rent;
                                _openUpiApp(upiId, amt, propertyName);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Pay via UPI App'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Text('Confirm Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'After sending the money, enter the UPI Transaction ID / UTR below so the owner can verify it.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _transactionIdController,
                    decoration: const InputDecoration(
                      labelText: 'Transaction ID / UTR',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.receipt_long),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : () => _submitPayment(tenantState),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0891B2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Submit Payment Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],

                // ── Cash Flow ──
                if (_paymentMode == 'Cash') ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedMonth,
                          decoration: const InputDecoration(
                            labelText: 'Rent Month',
                            border: OutlineInputBorder(),
                          ),
                          items: _monthOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedMonth = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: 'Amount Paid (₹)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.currency_rupee, size: 18),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade700),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'You are submitting a cash payment record. The owner will need to physically receive the cash and verify this submission.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : () => _submitPayment(tenantState),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0891B2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Submit Payment Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badgeText,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(20) : Colors.white,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withAlpha(30), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? color.withAlpha(30) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isSelected ? color : Colors.grey.shade600, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 24),
          ],
        ),
      ),
    );
  }
}
