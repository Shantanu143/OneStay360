import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:models/business/property/property_model.dart';

import 'widgets/business_scaffold.dart';

class CheckoutScreen extends StatefulWidget {
  final String propertyId;
  final String purpose; // 'activation' | 'monthly'
  final String? invoiceId;

  const CheckoutScreen({
    super.key,
    required this.propertyId,
    required this.purpose,
    this.invoiceId,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _promoController = TextEditingController();
  late Razorpay _razorpay;

  Property? _property;
  String? _invoiceId;
  Map<String, dynamic>? _quote;
  bool _loading = true;
  bool _quoteLoading = false;
  bool _processingPayment = false;
  String? _error;
  String? _promoError;
  Map<String, dynamic>? _pendingOrder;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadPropertyAndQuote();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _loadPropertyAndQuote() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<PropertyRepository>();
      final property = await repo.getPropertyById(widget.propertyId);
      _property = property;
      _invoiceId = widget.invoiceId;
      await _fetchQuote();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _fetchQuote() async {
    if (_property == null) return;
    setState(() {
      _quoteLoading = true;
      _promoError = null;
    });
    try {
      final repo = context.read<PropertyRepository>();
      final result = await repo.createCheckoutQuote(
        businessId: _property!.businessId,
        propertyId: _property!.id!,
        purpose: widget.purpose,
        promoCode: _promoController.text.trim().isEmpty
            ? null
            : _promoController.text.trim(),
        invoiceId: _invoiceId,
      );
      _quote = result;
    } catch (e) {
      if (e is FirebaseFunctionsException) {
        _promoError = e.message ?? 'Promo not valid';
      } else {
        _promoError = 'Promo not valid';
      }
    } finally {
      if (mounted) {
        setState(() {
          _quoteLoading = false;
        });
      }
    }
  }

  Future<void> _createOrderAndPay() async {
    if (_property == null || _quote == null) {
      await _fetchQuote();
      if (_quote == null) return;
    }
    setState(() {
      _processingPayment = true;
    });
    try {
      final repo = context.read<PropertyRepository>();
      final order = await repo.createActivationOrder(
        businessId: _property!.businessId,
        propertyId: _property!.id!,
        purpose: widget.purpose,
        promoCode: _promoController.text.trim().isEmpty
            ? null
            : _promoController.text.trim(),
        clientFinalAmount: (_quote!['finalAmount'] as num?)?.toInt(),
        invoiceId: _invoiceId,
      );
      _pendingOrder = order;
      _openRazorpayCheckout(order);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processingPayment = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start payment: $e')));
    }
  }

  void _openRazorpayCheckout(Map<String, dynamic> order) {
    final keyId = order['razorpayKeyId']?.toString();
    final orderId = order['orderId']?.toString();
    final amountPaise = (order['amount'] as num?)?.toInt();

    if (keyId == null || orderId == null || amountPaise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing payment details, please retry')),
      );
      setState(() {
        _processingPayment = false;
      });
      return;
    }

    final options = {
      'key': keyId,
      'order_id': orderId,
      'amount': amountPaise,
      'currency': 'INR',
      'method': {
        'upi': true,
        'card': true,
        'netbanking': true,
        'wallet': false,
      },
      'retry': {'enabled': false},
      'prefill': {},
      'notes': {},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() {
        _processingPayment = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open payment: $e')));
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final orderId = response.orderId;
    final paymentId = response.paymentId;
    final signature = response.signature;

    if (orderId == null || paymentId == null || signature == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment success missing fields')),
        );
      }
      setState(() {
        _processingPayment = false;
      });
      return;
    }

    try {
      final repo = context.read<PropertyRepository>();
      await repo.confirmActivationPayment(
        orderId: orderId,
        paymentId: paymentId,
        razorpaySignature: signature,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Activation confirmed')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Confirmation failed: $e')));
      }
      setState(() {
        _processingPayment = false;
      });
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() {
      _processingPayment = false;
    });
    final message = response.message ?? 'Payment failed';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External wallet not allowed: ${response.walletName}'),
      ),
    );
  }

  String _formatCurrency(num? amount) {
    if (amount == null) return '—';
    return '₹${amount.toInt()}';
  }

  String _nextBillingDateText() {
    final now = DateTime.now();
    final next = now.add(const Duration(days: 30));
    return '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_processingPayment,
      child: BusinessScaffold(
        currentTab: BusinessTab.properties,
        showBackButton: true,
        titleText: 'Checkout',
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_property == null) return const SizedBox.shrink();
    final totalBeds = (_property!.totalBeds as num?)?.toInt() ?? 0;
    final planRaw = _quote?['plan'];
    final plan = planRaw is Map
        ? Map<String, dynamic>.from(planRaw)
        : <String, dynamic>{};
    final planName = (plan['name'] as String?)?.trim().isNotEmpty == true
        ? plan['name'] as String
        : 'Plan';
    final pricePerBed =
        (plan['pricePerBedInr'] as num?)?.toInt() ??
        (_property!.pricePerBed as num?)?.toInt() ??
        0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(planName, pricePerBed, totalBeds),
          const SizedBox(height: 12),
          _buildPromoCard(),
          const SizedBox(height: 12),
          _buildSummaryCard(),
          const SizedBox(height: 12),
          _buildAmountCard(),
          const SizedBox(height: 16),
          _buildPayButton(),
        ],
      ),
    );
  }

  Widget _buildHeader(String planName, int pricePerBed, int totalBeds) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _property!.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            _property!.businessName ?? 'Business',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F7F2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFF0D9488),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        planName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '₹$pricePerBed per bed · $totalBeds beds',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final purposeLabel = widget.purpose == 'monthly'
        ? 'Monthly Billing'
        : 'Property Activation';
    final planRaw = _quote?['plan'];
    final plan = planRaw is Map
        ? Map<String, dynamic>.from(planRaw)
        : <String, dynamic>{};
    final planName = (plan['name'] as String?)?.trim().isNotEmpty == true
        ? plan['name'] as String
        : 'Plan';
    final pricePerBed =
        (plan['pricePerBedInr'] as num?)?.toInt() ??
        (_property!.pricePerBed as num?)?.toInt() ??
        0;
    final totalBeds = (_property!.totalBeds as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                purposeLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  planName,
                  style: const TextStyle(
                    color: Color(0xFF15803D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹$pricePerBed × $totalBeds beds / month',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildAmountRow(
            'Base amount',
            _formatCurrency(_quote?['baseAmount']),
          ),
          const SizedBox(height: 8),
          _buildAmountRow(
            'Discount',
            _formatCurrency(_quote?['discountAmount']),
          ),
          const Divider(height: 24),
          _buildAmountRow(
            'Payable',
            _formatCurrency(_quote?['finalAmount']),
            isBold: true,
          ),
          if (widget.purpose == 'activation') ...[
            const SizedBox(height: 12),
            _buildAmountRow('Next billing date', _nextBillingDateText()),
          ],
        ],
      ),
    );
  }

  Widget _buildPromoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Promo code',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoController,
                  decoration: InputDecoration(
                    hintText: 'Add a promo (optional)',
                    errorText: _promoError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _fetchQuote(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _quoteLoading ? null : _fetchQuote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _quoteLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_quoteLoading || _processingPayment)
            ? null
            : _createOrderAndPay,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D9488),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _processingPayment
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                widget.purpose == 'monthly' ? 'Pay Invoice' : 'Pay & Activate',
              ),
      ),
    );
  }

  Widget _buildAmountRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
