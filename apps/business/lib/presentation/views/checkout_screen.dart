import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:models/business/property/property_model.dart';

import '../design/components/biz_banner.dart';
import '../design/components/biz_button.dart';
import '../design/components/biz_card.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_dialogs.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_section_label.dart';
import '../design/components/biz_states.dart';
import '../design/components/biz_text_field.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import 'home/home_format.dart';

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
    final repo = context.read<PropertyRepository>();
    if (_property == null || _quote == null) {
      await _fetchQuote();
      if (_quote == null) return;
    }
    setState(() {
      _processingPayment = true;
    });
    try {
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
      _openRazorpayCheckout(order);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processingPayment = false;
      });
      showBizToast(context, "Couldn't start the payment. Try again.", tone: BizTone.danger);
    }
  }

  void _openRazorpayCheckout(Map<String, dynamic> order) {
    final keyId = order['razorpayKeyId']?.toString();
    final orderId = order['orderId']?.toString();
    final amountPaise = (order['amount'] as num?)?.toInt();

    if (keyId == null || orderId == null || amountPaise == null) {
      showBizToast(context, 'Missing payment details, please retry', tone: BizTone.danger);
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
      showBizToast(context, "Couldn't open the payment page. Try again.", tone: BizTone.danger);
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final orderId = response.orderId;
    final paymentId = response.paymentId;
    final signature = response.signature;

    if (orderId == null || paymentId == null || signature == null) {
      if (mounted) {
        showBizToast(context, 'Payment success missing fields', tone: BizTone.danger);
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
        showBizToast(context, 'Payment confirmed. Your property is live.', tone: BizTone.success);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        showBizToast(context, "We couldn't confirm the payment yet. If money was taken, it is confirmed automatically within minutes.", tone: BizTone.danger);
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
    showBizToast(context, message, tone: BizTone.danger);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    showBizToast(context, 'External wallet not allowed: ${response.walletName}', tone: BizTone.danger);
  }

  @override
  Widget build(BuildContext context) {
    final monthly = widget.purpose == 'monthly';
    return PopScope(
      canPop: !_processingPayment,
      child: BizScaffold(
        title: monthly ? 'Pay plan invoice' : 'Go live',
        eyebrow: _property?.name,
        bottomBar: _loading || _error != null || _property == null
            ? null
            : BizButton(
                label: _quote == null
                    ? (monthly ? 'Pay invoice' : 'Pay & go live')
                    : '${monthly ? 'Pay' : 'Pay & go live'} · ${formatInr((_quote!['finalAmount'] as num?) ?? 0)}',
                icon: Icons.lock_rounded,
                loading: _processingPayment,
                onPressed: _quoteLoading ? null : _createOrderAndPay,
              ),
        body: _loading
            ? const Padding(padding: EdgeInsets.all(16), child: BizSkeletonList(count: 3, cardHeight: 120))
            : _error != null
                ? BizErrorState(message: "Couldn't load the price for this property.", onRetry: _loadPropertyAndQuote)
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final property = _property;
    if (property == null) return const SizedBox.shrink();
    final totalBeds = property.totalBeds;
    final planRaw = _quote?['plan'];
    final plan = planRaw is Map ? Map<String, dynamic>.from(planRaw) : <String, dynamic>{};
    final planName = (plan['name'] as String?)?.trim().isNotEmpty == true ? plan['name'] as String : 'Standard plan';
    final pricePerBed = (plan['pricePerBedInr'] as num?)?.toInt() ?? property.pricePerBed;
    final discount = (_quote?['discountAmount'] as num?) ?? 0;
    final monthly = widget.purpose == 'monthly';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Reveal(
          animation: const AlwaysStoppedAnimation(1),
          start: 0,
          end: 1,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: BizColors.card, borderRadius: BorderRadius.circular(BizRadius.hero)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(monthly ? 'Plan invoice' : 'Activate ${property.name}', style: BizText.cardLabel),
                const SizedBox(height: 6),
                Text(
                  _quote == null ? '—' : formatInr((_quote!['finalAmount'] as num?) ?? 0),
                  style: BizText.heroAmount.copyWith(fontSize: 34),
                ),
                const SizedBox(height: 6),
                Text('$planName · ${formatInr(pricePerBed)} per bed · $totalBeds ${totalBeds == 1 ? 'bed' : 'beds'}',
                    style: BizText.heroCaption),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const BizSectionLabel('SUMMARY'),
        BizCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _row('Beds × price', '$totalBeds × ${formatInr(pricePerBed)}'),
              _row('Base amount', formatInr((_quote?['baseAmount'] as num?) ?? 0)),
              if (discount > 0) _row('Promo discount', '− ${formatInr(discount)}', color: BizColors.greenDeep),
              const Divider(height: 22),
              _row('You pay', formatInr((_quote?['finalAmount'] as num?) ?? 0), strong: true),
              if (!monthly) ...[
                const SizedBox(height: 6),
                _row('Next bill around', formatDay(DateTime.now().add(const Duration(days: 30)))),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        const BizSectionLabel('PROMO CODE'),
        BizCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: BizTextField(
                  label: 'Code (optional)',
                  fieldKey: const Key('checkout-promo'),
                  controller: _promoController,
                  hint: 'LAUNCH50',
                  textCapitalization: TextCapitalization.characters,
                  errorText: _promoError,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: BizButton(
                  label: 'Apply',
                  expand: false,
                  kind: BizButtonKind.tonal,
                  size: BizButtonSize.medium,
                  loading: _quoteLoading,
                  onPressed: _processingPayment ? null : _fetchQuote,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        BizBanner(
          message: monthly
              ? 'Paying keeps this property live for tenants for the next month.'
              : 'Once paid, the property goes live: tenants can find it, request to join and pay you rent.',
          tone: BizTone.info,
          icon: Icons.verified_user_outlined,
        ),
        const SizedBox(height: 12),
        Center(child: Text('Secure payment by Razorpay · UPI, cards, net banking', style: BizText.caption)),
      ],
    );
  }

  Widget _row(String label, String value, {bool strong = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: strong ? BizText.cardTitle : BizText.body.copyWith(color: BizColors.inkSoft))),
          Text(value, style: (strong ? BizText.style(20, 800) : BizText.bodyStrong).copyWith(color: color)),
        ],
      ),
    );
  }
}
