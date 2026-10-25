import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/providers/tenant_state_provider.dart';
import 'explore_screen.dart';

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
  // UPI ID fetched from business Razorpay settings
  String _businessUpiId = '';

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
          // Read UPI ID from the same settings document
          _businessUpiId = (data['upiId'] as String? ?? '').trim();
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
        // Pass the invoice ID so the backend can link this payment to the invoice
        if (widget.rentInvoiceId != null && widget.rentInvoiceId!.isNotEmpty)
          'rentInvoiceId': widget.rentInvoiceId,
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
            return _AnimatedRentEmptyState(
              onExplore: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const ExploreScreen()),
                  (route) => false,
                );
              },
              onGoBack: () {
                Navigator.pop(context);
              },
            );
          }

          final rent = (tenantState.tenantData['monthlyRent'] as num?)?.toDouble() ?? 0.0;
          final propertyName = tenantState.currentPG;
          // UPI ID is fetched from businesses/{id}/settings/razorpay in _checkOnlinePayments()
          final upiId = _businessUpiId;

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
                  // If opened from an invoice, show the amount as read-only
                  if (widget.rentInvoiceId != null && widget.rentInvoiceId!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Amount is fixed to your invoice. Pay exactly ₹${_amountController.text} for ${widget.prefilledMonth ?? _selectedMonth}.',
                              style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Amount and Month
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedMonth,
                          decoration: const InputDecoration(
                            labelText: 'Rent Month',
                            border: OutlineInputBorder(),
                          ),
                          items: _monthOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          // Lock month when opened from an invoice
                          onChanged: widget.rentInvoiceId != null ? null : (val) {
                            if (val != null) setState(() => _selectedMonth = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          // Lock amount when opened from an invoice
                          readOnly: widget.rentInvoiceId != null && widget.rentInvoiceId!.isNotEmpty,
                          decoration: InputDecoration(
                            labelText: 'Amount (₹)',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                            filled: widget.rentInvoiceId != null && widget.rentInvoiceId!.isNotEmpty,
                            fillColor: widget.rentInvoiceId != null ? Colors.grey.shade100 : null,
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
                  // If opened from an invoice, show the amount as read-only
                  if (widget.rentInvoiceId != null && widget.rentInvoiceId!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Amount is fixed to your invoice. Pay exactly ₹${_amountController.text} for ${widget.prefilledMonth ?? _selectedMonth}.',
                              style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedMonth,
                          decoration: const InputDecoration(
                            labelText: 'Rent Month',
                            border: OutlineInputBorder(),
                          ),
                          items: _monthOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: widget.rentInvoiceId != null ? null : (val) {
                            if (val != null) setState(() => _selectedMonth = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          readOnly: widget.rentInvoiceId != null && widget.rentInvoiceId!.isNotEmpty,
                          decoration: InputDecoration(
                            labelText: 'Amount (₹)',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                            filled: widget.rentInvoiceId != null && widget.rentInvoiceId!.isNotEmpty,
                            fillColor: widget.rentInvoiceId != null ? Colors.grey.shade100 : null,
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

class _AnimatedRentEmptyState extends StatefulWidget {
  final VoidCallback onExplore;
  final VoidCallback onGoBack;

  const _AnimatedRentEmptyState({
    required this.onExplore,
    required this.onGoBack,
  });

  @override
  State<_AnimatedRentEmptyState> createState() => _AnimatedRentEmptyStateState();
}

class _AnimatedRentEmptyStateState extends State<_AnimatedRentEmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    _floatAnimation = Tween<double>(begin: 0.0, end: -12.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Animated Illustration
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return SizedBox(
                  height: 180,
                  width: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer Pulsing Circle 2
                      Transform.scale(
                        scale: _pulseAnimation.value * 1.1,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withAlpha((0.05 * 255).round()),
                          ),
                        ),
                      ),
                      // Pulsing Circle 1
                      Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withAlpha((0.1 * 255).round()),
                          ),
                        ),
                      ),
                      // Floating Core Card/Icon
                      Transform.translate(
                        offset: Offset(0, _floatAnimation.value),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withAlpha((0.3 * 255).round()),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // Small Floating Accent Element (e.g. Coin)
                      Transform.translate(
                        offset: Offset(35, _floatAnimation.value - 25),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.amber,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.currency_rupee_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'No Pending Dues',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
                letterSpacing: -0.5,
                fontFamily: 'Geist',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'You are not currently checked into any PG stay, so there are no rent invoices or monthly dues to pay.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
                fontFamily: 'Manrope',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            // Primary Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onExplore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.explore_outlined, size: 20, color: Colors.white),
                label: const Text(
                  'Explore PG Stays',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Geist'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Secondary Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onGoBack,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                ),
                icon: Icon(Icons.arrow_back_rounded, size: 20, color: Colors.grey[600]),
                label: const Text(
                  'Go Back',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Geist'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
