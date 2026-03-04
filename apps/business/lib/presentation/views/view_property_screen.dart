// lib/presentation/views/business/view_property_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import '../view_models/view_property_viewmodel.dart';
import 'package:firebase_services/services/property_room_service.dart';
import './request_detail_screen.dart';
import './tenant_detail_screen.dart';
import 'package:models/tenant/tenant_request_model.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'widgets/business_scaffold.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'checkout_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewPropertyScreen extends StatefulWidget {
  final String propertyId;
  final int? initialTabIndex;

  static const int requestsTabIndex = 5;

  const ViewPropertyScreen({
    super.key,
    required this.propertyId,
    this.initialTabIndex,
  });

  @override
  State<ViewPropertyScreen> createState() => _ViewPropertyScreenState();
}

class _ViewPropertyScreenState extends State<ViewPropertyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Razorpay _razorpay;
  ViewPropertyViewModel? _viewModelRef; // cached provider-safe reference for callbacks

  static const int kTabLayout = 0;
  static const int kTabOverview = 1;
  static const int kTabTenants = 2;
  static const int kTabFinancials = 3;
  static const int kTabPayments = 4;
  static const int kTabRequests = 5;
  static const int kTabQr = 6;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _tabController = TabController(length: 7, vsync: this);
    if (widget.initialTabIndex != null &&
        widget.initialTabIndex! >= 0 &&
        widget.initialTabIndex! < _tabController.length) {
      _tabController.index = widget.initialTabIndex!;
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final propertyRepository = context.read<PropertyRepository>();
    final roomService = PropertyRoomService();

    return ChangeNotifierProvider(
      create: (_) => ViewPropertyViewModel(
        propertyRepository: propertyRepository,
        roomService: roomService,
      )
        ..loadProperty(widget.propertyId)
        ..listenRequests(widget.propertyId),
      child: Consumer<ViewPropertyViewModel>(
        builder: (context, viewModel, _) {
          _viewModelRef = viewModel; // ensure callbacks have access without relying on ancestor context
          // Title uses property name when available - NOW USED WITHIN DEFAULT HEADER STRUCTURE
          final titleWidget = Text(
            viewModel.property?.name ?? 'Property Details',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );

          return BusinessScaffold(
            currentTab: BusinessTab.properties,
            showBackButton: true,
            title: titleWidget,
            appBarBottom: _buildAppBarTabs(context, viewModel),
            body: _buildBody(viewModel),
          );
        },
      ),
    );
  }

  // REMOVED: _buildAppBarActions method entirely since we're using default actions

  PreferredSizeWidget _buildAppBarTabs(
      BuildContext context, ViewPropertyViewModel viewModel) {
    final requestCount = viewModel.pendingRequestsCount;

    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: Container(
        color: Colors.white,
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF2E7D32),
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: const Color(0xFF2E7D32),
          indicatorWeight: 3,
          labelStyle:
          const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
          const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          tabs: [
            const Tab(text: 'Overview'),
            const Tab(text: 'Layout'),
            const Tab(text: 'Tenants'),
            const Tab(text: 'Financials'),
            const Tab(text: 'Payment History'),
            Tab(
              child: Row(
                children: [
                  const Text('Requests'),
                  if (requestCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$requestCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'QR'),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ViewPropertyViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.hasError) {
      return _buildErrorState(viewModel);
    }

    if (viewModel.property == null) {
      return _buildEmptyState();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(viewModel),
        _buildLayoutTab(viewModel),
        _buildTenantsTab(viewModel),
        _buildFinancialsTab(viewModel),
        _buildPaymentHistoryTab(viewModel),
        _buildRequestsTab(viewModel),
        _buildQrTab(viewModel),
      ],
    );
  }

  Widget _buildPaymentHistoryTab(ViewPropertyViewModel viewModel) {
    final property = viewModel.property;
    if (property == null) {
      return const Center(child: Text('No property loaded'));
    }

    final billingStatus = (property.billingStatus ?? 'unknown').toString();
    final nextBillingDate = property.nextBillingDate;
    final planName = (property.plan?['name'] as String?) ?? 'Plan';
    final pricePerBed = (property.plan?['pricePerBedInr'] as num?)?.toInt() ?? property.pricePerBed;
    final dateFmt = DateFormat('d MMM yyyy, h:mm a');

    if (viewModel.paymentsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.paymentsError != null) {
      return Center(child: Text(viewModel.paymentsError!));
    }

    final payments = viewModel.payments;

    // Group payments by Month/Year for display-only grouping
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final p in payments) {
      DateTime? created;
      final ts = p['createdAt'];
      if (ts is Timestamp) created = ts.toDate();
      if (ts is DateTime) created = ts;
      final key = created != null ? DateFormat('MMMM yyyy').format(created) : 'Unspecified';
      grouped.putIfAbsent(key, () => []).add(p);
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusHeader(context, viewModel, billingStatus, nextBillingDate, dateFmt),
          const SizedBox(height: 12),
          _buildPlanCard(planName, pricePerBed),
          const SizedBox(height: 16),
          if (billingStatus == 'suspended')
            _buildSuspendedBanner(viewModel),
          if (payments.isEmpty)
            _buildEmptyPaymentsState()
          else
            Expanded(
              child: ListView(
                children: grouped.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        ...entry.value.map((payment) {
                          final status = (payment['status'] ?? 'unknown').toString();
                          final amount = payment['finalAmount'] ?? payment['amount'];
                          final purposeRaw = payment['purpose']?.toString() ?? '';
                          final purposeLabel = purposeRaw == 'activation'
                              ? 'Activation payment'
                              : purposeRaw == 'monthly'
                                  ? 'Monthly subscription'
                                  : 'Payment';
                          final createdAt = payment['createdAt'];
                          DateTime? created;
                          if (createdAt is Timestamp) created = createdAt.toDate();
                          if (createdAt is DateTime) created = createdAt;
                          final statusChip = _statusChip(status, compact: true);
                          final purposeIcon = purposeRaw == 'activation' ? '⚡' : '🔁';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _showPaymentDetails(context, payment, dateFmt),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                  color: Colors.white,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x0F000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('₹$amount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                        Row(
                                          children: [
                                            Text('View details', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(purposeIcon, style: const TextStyle(fontSize: 16)),
                                        const SizedBox(width: 6),
                                        Text(purposeLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${created != null ? dateFmt.format(created) : 'Date unavailable'} · Razorpay',
                                      style: const TextStyle(color: Colors.black54),
                                    ),
                                    const SizedBox(height: 6),
                                    statusChip,
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context, ViewPropertyViewModel viewModel, String billingStatus, DateTime? nextBillingDate, DateFormat fmt) {
    final statusMeta = _billingStatusMeta(billingStatus);
    final unpaidInvoiceId = viewModel.unpaidInvoiceId;
    final showPayCta = billingStatus == 'due' || billingStatus == 'grace' || billingStatus == 'past_due';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusMeta['color'] as Color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(statusMeta['label'] as String, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (nextBillingDate != null)
            Text('Next billing: ${fmt.format(nextBillingDate)}', style: const TextStyle(color: Colors.white70)),
          if (showPayCta)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: statusMeta['color'] as Color,
                  minimumSize: const Size(120, 38),
                ),
                onPressed: unpaidInvoiceId == null
                    ? null
                    : () async {
                        final paid = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => CheckoutScreen(
                              propertyId: widget.propertyId,
                              purpose: 'monthly',
                              invoiceId: unpaidInvoiceId,
                            ),
                          ),
                        );
                        if (paid == true) {
                          await viewModel.refreshProperty(widget.propertyId);
                        }
                      },
                child: const Text('Pay now'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(String planName, int pricePerBed) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: const Text('Plan & Charges'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(planName, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('₹$pricePerBed / bed / month'),
          ],
        ),
        trailing: OutlinedButton(
          onPressed: null,
          child: const Text('Change plan'),
        ),
      ),
    );
  }

  Widget _buildSuspendedBanner(ViewPropertyViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 10),
          const Expanded(child: Text('⚠️ Billing overdue — service suspended. Pay now to reactivate.', style: TextStyle(color: Colors.red))),
          TextButton(
            onPressed: () => _onActivateProperty(viewModel),
            child: const Text('Pay now'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPaymentsState() {
    return Column(
      children: const [
        SizedBox(height: 12),
        Text('No payments yet.', style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 4),
        Text('Your first payment will appear here after activation.', textAlign: TextAlign.center),
      ],
    );
  }

  Widget _statusChip(String status, {bool compact = false}) {
    Color chipColor;
    String label;
    switch (status) {
      case 'success':
        chipColor = const Color(0xFFC8E6C9);
        label = 'Successful';
        break;
      case 'failed':
      case 'cancelled':
        chipColor = Colors.red.shade100;
        label = 'Failed';
        break;
      default:
        chipColor = Colors.orange.shade100;
        label = 'Pending';
    }
    return Chip(
      visualDensity: compact ? const VisualDensity(horizontal: -2, vertical: -2) : null,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Text(label, style: TextStyle(fontSize: compact ? 12 : 14)),
      backgroundColor: chipColor,
    );
  }

  Map<String, dynamic> _billingStatusMeta(String status) {
    switch (status) {
      case 'paid':
        return {'label': 'Billing Active', 'color': const Color(0xFF2E7D32)};
      case 'due':
      case 'grace':
        return {'label': 'Payment Due', 'color': const Color(0xFFFFC107)};
      case 'past_due':
        return {'label': 'Overdue', 'color': const Color(0xFFFF9800)};
      case 'suspended':
        return {'label': 'Service Suspended', 'color': const Color(0xFFD32F2F)};
      default:
        return {'label': 'Billing Status', 'color': Colors.grey.shade600};
    }
  }

  void _showPaymentDetails(BuildContext context, Map<String, dynamic> payment, DateFormat fmt) {
    final status = (payment['status'] ?? 'unknown').toString();
    final amount = payment['finalAmount'] ?? payment['amount'];
    final purposeRaw = payment['purpose']?.toString() ?? '';
    final purpose = purposeRaw == 'activation'
        ? 'Activation payment'
        : purposeRaw == 'monthly'
            ? 'Monthly subscription'
            : purposeRaw.isNotEmpty
                ? purposeRaw
                : 'Payment';
    final paymentId = payment['paymentId']?.toString() ?? payment['id']?.toString() ?? '';
    final orderId = payment['orderId']?.toString() ?? '';
    final gateway = payment['gateway']?.toString() ?? 'Razorpay';
    final promoCode = payment['promoCode']?.toString();
    final discountAmount = payment['discountAmount'];
    final createdAt = payment['createdAt'];
    DateTime? created;
    if (createdAt is Timestamp) created = createdAt.toDate();
    if (createdAt is DateTime) created = createdAt;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        bool expanded = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('₹$amount', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      _statusChip(status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(purpose, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(gateway, style: const TextStyle(color: Colors.black54)),
                  if (created != null)
                    Text(fmt.format(created), style: const TextStyle(color: Colors.black54)),
                  if (promoCode != null) ...[
                    const SizedBox(height: 12),
                    Text('🎁 Promo applied: $promoCode', style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (discountAmount != null) Text('You saved ₹$discountAmount'),
                  ],
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Technical details'),
                    trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                    onTap: () => setState(() => expanded = !expanded),
                  ),
                  if (expanded) ...[
                    const SizedBox(height: 4),
                    if (paymentId.isNotEmpty)
                      Text('Payment ID: $paymentId', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    if (orderId.isNotEmpty)
                      Text('Order ID: $orderId', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    if (payment['propertyId'] != null)
                      Text('Property: ${payment['propertyId']}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    if (payment['invoiceId'] != null)
                      Text('Invoice: ${payment['invoiceId']}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildErrorState(ViewPropertyViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            'Failed to load property',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            viewModel.error ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => viewModel.refreshProperty(widget.propertyId),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _onActivateProperty(ViewPropertyViewModel viewModel) async {
    if (!mounted) return;
    final activated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          propertyId: widget.propertyId,
          purpose: 'activation',
          invoiceId: null,
        ),
      ),
    );
    if (activated == true) {
      await viewModel.refreshProperty(widget.propertyId);
    }
  }

  Widget _buildActivationBanner(ViewPropertyViewModel viewModel) {
    final property = viewModel.property;
    if (property == null) return const SizedBox.shrink();

    // Banner shows only when property is not fully activated/paid
    final billingStatus = (property.billingStatus ?? '').toString();
    final status = (property.status ?? '').toString();
    final needsActivation = status != 'active' || billingStatus != 'paid';
    if (!needsActivation) return const SizedBox.shrink();

    final title = status == 'draft' || billingStatus == 'payment_due'
      ? 'Property is in draft'
      : 'Payment due';
    final subtitle = status == 'draft' || billingStatus == 'payment_due'
      ? 'Activate to unlock beds and tenant assignments.'
      : 'Complete activation to enable beds and assignments.';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_open, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: viewModel.isActivating ? null : () => _onActivateProperty(viewModel),
                icon: viewModel.isActivating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.flash_on),
                label: Text(viewModel.isActivating ? 'Activating...' : 'Activate now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    billingStatus == 'payment_due'
                      ? 'Current billing status: payment due'
                      : 'Current billing status: $billingStatus',
                  style: TextStyle(color: Colors.grey.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (viewModel.activationError != null) ...[
            const SizedBox(height: 8),
            Text(
              viewModel.activationError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthlyBillingBanner(ViewPropertyViewModel viewModel) {
    final property = viewModel.property;
    if (property == null) return const SizedBox.shrink();
    final status = property.billingStatus;
    final show = status == 'due' || status == 'grace' || status == 'past_due';
    if (!show) return const SizedBox.shrink();

    final invoiceId = viewModel.unpaidInvoiceId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment due',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete monthly payment to avoid suspension.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: (invoiceId == null)
                    ? null
                    : () async {
                        if (!mounted) return;
                        final paid = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => CheckoutScreen(
                              propertyId: widget.propertyId,
                              purpose: 'monthly',
                              invoiceId: invoiceId,
                            ),
                          ),
                        );
                        if (paid == true) {
                          await viewModel.refreshProperty(widget.propertyId);
                        }
                      },
                icon: viewModel.isActivating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.payment),
                label: const Text('Pay Monthly'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Status: $status',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
          if (invoiceId == null) ...[
            const SizedBox(height: 8),
            const Text(
              'Invoice missing. Please retry later.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBillingStatusBadge(String? billingStatus) {
    if (billingStatus == null || billingStatus.isEmpty) return const SizedBox.shrink();

    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (billingStatus) {
      case 'paid':
        bg = Colors.green.shade50;
        fg = const Color(0xFF2E7D32);
        icon = Icons.check_circle;
        label = 'Paid';
        break;
      case 'due':
        bg = Colors.amber.shade50;
        fg = Colors.orange.shade800;
        icon = Icons.warning_amber_rounded;
        label = 'Due';
        break;
      case 'grace':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        icon = Icons.hourglass_bottom;
        label = 'Grace';
        break;
      case 'past_due':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        icon = Icons.error_outline;
        label = 'Past Due';
        break;
      case 'suspended':
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        icon = Icons.block;
        label = 'Suspended';
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        icon = Icons.help_outline;
        label = billingStatus;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 8),
          Text(
            'Billing: $label',
            style: TextStyle(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _openRazorpayCheckout(Map<String, dynamic> order) {
    final keyId = order['razorpayKeyId']?.toString();
    final orderId = order['orderId']?.toString();
    final amountPaise = (order['amount'] as num?)?.toInt();

    if (keyId == null || orderId == null || amountPaise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing payment details, please retry')),
      );
      return;
    }

    final options = {
      'key': keyId,
      'order_id': orderId,
      'amount': amountPaise,
      'currency': 'INR',
      'method': {
        'upi': true,
        'card': false,
        'netbanking': false,
        'wallet': false,
      },
      'retry': {'enabled': false},
      'prefill': {},
      'notes': {},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open payment: $e')),
      );
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
      return;
    }

    final viewModel = _viewModelRef;
    if (viewModel == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment confirmed but screen was disposed. Please refresh.')),
        );
      }
      return;
    }
    // Legacy inline payment path is no longer used; checkout handled in CheckoutScreen.
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    final message = response.message ?? 'Payment failed';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Wallets are disabled in options; this is a safeguard.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet not allowed: ${response.walletName}')),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home_work_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'Property not found',
            style: TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutTab(ViewPropertyViewModel viewModel) {
    final floors = viewModel.getFloorsFromProperty();

    if (floors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_work_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No rooms found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'This property has no rooms configured yet',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOccupancyStats(viewModel),
          const SizedBox(height: 20),
          ...floors.asMap().entries.map((entry) {
            final floorIndex = entry.key;
            final floor = entry.value;
            return _buildFloorSection(floorIndex, floor);
          }),
        ],
      ),
    );
  }

  Widget _buildOccupancyStats(ViewPropertyViewModel viewModel) {
    final stats = viewModel.propertyStats;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
                'Total Rooms', stats['totalRooms'].toString(), Colors.blue),
          ),
          Expanded(
            child: _buildStatItem('Occupied Rooms',
                stats['occupiedRooms'].toString(), Colors.orange),
          ),
          Expanded(
            child: _buildStatItem(
                'Total Beds', stats['totalBeds'].toString(), Colors.green),
          ),
          Expanded(
            child: _buildStatItem(
                'Occupied Beds', stats['occupiedBeds'].toString(), Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFloorSection(int floorIndex, Map<String, dynamic> floor) {
    final rooms = floor['rooms'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Floor ${floorIndex + 1}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: rooms.length,
          itemBuilder: (context, roomIndex) {
            final room = rooms[roomIndex] as Map<String, dynamic>;
            return _buildRoomCard(room, floorIndex, roomIndex);
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRoomCard(
      Map<String, dynamic> room, int floorIndex, int roomIndex) {
    final beds = room['beds'] as List<dynamic>? ?? [];
    final occupiedBeds =
        beds.where((bed) => bed['isOccupied'] == true).length;
    final totalBeds = beds.length;
    final occupancyRate = totalBeds > 0 ? occupiedBeds / totalBeds : 0.0;
    final roomStatus = room['status'] ?? 'available';
    final hasAC = room['hasAC'] ?? false;
    final gender = room['gender'] ?? 'Co-ed';

    Color cardColor;
    if (roomStatus == 'occupied') {
      cardColor = Colors.red.shade50;
    } else if (roomStatus == 'maintenance') {
      cardColor = Colors.yellow.shade50;
    } else {
      cardColor = Colors.green.shade50;
    }

    Color statusColor;
    if (roomStatus == 'occupied') {
      statusColor = Colors.red;
    } else if (roomStatus == 'maintenance') {
      statusColor = Colors.yellow.shade700;
    } else {
      statusColor = Colors.green;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showRoomDetails(room, floorIndex, roomIndex);
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: statusColor,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    room['number'] ?? 'Room ${roomIndex + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      roomStatus.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Rent: ₹${room['rent'] ?? 'N/A'}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      room['type'] ?? 'Standard',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                    ),
                  ),
                  if (hasAC)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.cyan.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'AC',
                        style: TextStyle(fontSize: 12, color: Colors.cyan.shade700),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      gender,
                      style: TextStyle(fontSize: 12, color: Colors.purple.shade700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Bed indicators
              if (beds.isNotEmpty)
                Row(
                  children: [
                    Text(
                      'Beds: ',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 4),
                    ...beds.asMap().entries.map((entry) {
                      final bed = entry.value as Map<String, dynamic>;
                      final isOccupied = bed['isOccupied'] == true;
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: isOccupied ? Colors.red : Colors.green,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: isOccupied ? Colors.red.shade700 : Colors.green.shade700,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoomDetails(
      Map<String, dynamic> room, int floorIndex, int roomIndex) {
    showDialog(
      context: context,
      builder: (context) {
        final beds = room['beds'] as List<dynamic>? ?? [];
        final roomStatus = room['status'] ?? 'available';
        final hasAC = room['hasAC'] ?? false;
        final gender = room['gender'] ?? 'Co-ed';
        
        return AlertDialog(
          title: Text('Room ${room['number'] ?? 'N/A'} (Floor ${floorIndex + 1})'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Type: ${room['type'] ?? 'N/A'}'),
              Text('Rent: ₹${room['rent'] ?? 'N/A'}'),
              const SizedBox(height: 4),
              Text('Status: ${roomStatus.toUpperCase()}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: roomStatus == 'occupied'
                      ? Colors.red
                      : roomStatus == 'maintenance'
                      ? Colors.orange
                      : Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Text('Gender: $gender'),
              if (hasAC) Text('AC: Yes'),
              const SizedBox(height: 12),
              const Text('Beds:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...beds.asMap().entries.map((entry) {
                final bedIndex = entry.key;
                final bed = entry.value as Map<String, dynamic>;
                final isOccupied = bed['isOccupied'] == true;
                final tenantName = bed['tenantName'] as String?;
                final tenantId = bed['tenantId'] as String?;
                final bedNumber = bed['bedNumber'] ?? (bedIndex + 1).toString();
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: isOccupied ? Colors.red : Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                bedNumber,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bed $bedNumber: ${isOccupied ? 'Occupied' : 'Vacant'}',
                              style: TextStyle(
                                fontWeight: isOccupied ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isOccupied && tenantName != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 24, top: 2),
                          child: Text(
                            'Tenant: $tenantName',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      if (isOccupied && tenantId != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 24, top: 2),
                          child: Text(
                            'ID: $tenantId',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOverviewTab(ViewPropertyViewModel viewModel) {
    final stats = viewModel.propertyStats;
    final amenities = viewModel.amenities;
    final owner = viewModel.ownerInfo;
    final property = viewModel.property!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBillingStatusBadge(property.billingStatus),
          _buildActivationBanner(viewModel),
          _buildMonthlyBillingBanner(viewModel),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard('Total Rooms', '${stats['totalRooms']}',
                  Icons.meeting_room_outlined, Colors.blue.shade600),
              _buildStatCard(
                  'Occupancy Rate',
                  '${(stats['occupancyRate'] * 100).toStringAsFixed(0)}%',
                  Icons.people_outline,
                  Colors.green.shade600),
              _buildStatCard(
                  'Monthly Revenue',
                  '₹ ${(stats['monthlyRevenue'] / 1000).toStringAsFixed(0)}K',
                  Icons.currency_rupee,
                  Colors.orange.shade600),
              _buildStatCard(
                  'Pending Payments',
                  '₹ ${(stats['pendingPayments'] / 1000).toStringAsFixed(0)}K',
                  Icons.pending_actions,
                  Colors.red.shade600),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoCard('Property Information', [
            _buildInfoRow('Type', property.status.isNotEmpty ? property.status : 'Not specified'),
            _buildInfoRow('Address', property.address.isNotEmpty ? property.address : 'Not provided'),
            _buildInfoRow('City', property.city.isNotEmpty ? '${property.city}, ${property.cityCode}' : 'Not specified'),
            _buildInfoRow('Pincode', property.pincode.isNotEmpty ? property.pincode : 'Not provided'),
          ]),
          const SizedBox(height: 16),
          if (property.description.isNotEmpty)
            _buildInfoCard('Description', [
              Text(
                property.description,
                style: TextStyle(color: Colors.grey.shade700, height: 1.5),
              ),
            ])
          else
            _buildInfoCard('Description', [
              Text(
                'No description available',
                style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ]),
          const SizedBox(height: 16),
          _buildInfoCard('Amenities', amenities.isEmpty
              ? [
                  Text(
                    'No amenities configured',
                    style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                  ),
                ]
              : [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: amenities.map((amenity) {
                      return Chip(
                        label: Text(amenity),
                        backgroundColor: Colors.teal.shade50,
                        labelStyle: TextStyle(color: Colors.teal.shade700),
                      );
                    }).toList(),
                  ),
                ]),
          const SizedBox(height: 16),
          _buildInfoCard('Owner Information', [
            _buildInfoRow('Name', owner['name'] ?? 'Not specified'),
            _buildInfoRow('Phone', owner['phone']?.isNotEmpty == true ? owner['phone'] : 'Not provided'),
            _buildInfoRow('WhatsApp', owner['whatsapp']?.isNotEmpty == true ? owner['whatsapp'] : 'Not provided'),
            _buildInfoRow('Email', owner['email']?.isNotEmpty == true ? owner['email'] : 'Not provided'),
          ]),
        ],
      ),
    );
  }

  Widget _buildTenantsTab(ViewPropertyViewModel viewModel) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search tenants by name, room, or phone...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: viewModel.searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => viewModel.updateSearchQuery(''),
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2E7D32)),
              ),
            ),
            onChanged: viewModel.updateSearchQuery,
          ),
        ),
        Expanded(
          child: viewModel.filteredTenants.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  viewModel.searchQuery.isEmpty
                      ? Icons.people_outline
                      : Icons.search_off,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  viewModel.searchQuery.isEmpty
                      ? 'No tenants found'
                      : 'No tenants match your search',
                  style: TextStyle(
                      fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: viewModel.filteredTenants.length,
            itemBuilder: (context, index) {
              final tenant = viewModel.filteredTenants[index]
              as Map<String, dynamic>;
              return _buildTenantCard(tenant, viewModel.property?.name ?? 'Property');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTenantCard(Map<String, dynamic> tenant, String propertyName) {
    // Format the join date properly
    String formatDate(dynamic dateValue) {
      if (dateValue == null) return 'Not recorded';
      
      DateTime? dateTime;
      
      // Handle Firestore Timestamp objects
      if (dateValue.runtimeType.toString().contains('Timestamp')) {
        try {
          // Timestamp has toDate() method
          dateTime = dateValue.toDate() as DateTime;
        } catch (e) {
          return dateValue.toString();
        }
      } else if (dateValue is String) {
        try {
          dateTime = DateTime.parse(dateValue);
        } catch (e) {
          return dateValue; // Return as-is if can't parse
        }
      } else if (dateValue is DateTime) {
        dateTime = dateValue;
      } else {
        return dateValue.toString();
      }
      
      // Format as: "10 Dec 2024"
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          print('🔘 Tenant card tapped - Tenant: ${tenant['name']}');
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TenantDetailScreen(
                tenant: tenant,
                propertyName: propertyName,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenant['name'] ?? 'Unknown Tenant',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (tenant['id'] != null)
                        Text(
                          'ID: ${tenant['id']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tenant['status'] ?? 'Unknown',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.meeting_room, size: 16),
                const SizedBox(width: 4),
                Text('Room: ${tenant['room'] ?? 'Not specified'}'),
                if (tenant['bed'] != null) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.bed, size: 16),
                  const SizedBox(width: 4),
                  Text('Bed: ${tenant['bed']}'),
                ],
                const SizedBox(width: 16),
                const Icon(Icons.currency_rupee, size: 16),
                const SizedBox(width: 4),
                Text('Rent: ₹${tenant['rent'] ?? '0'}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone, size: 16),
                const SizedBox(width: 4),
                Text('Phone: ${tenant['phone'] ?? 'Not provided'}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 4),
                Text('Joined: ${formatDate(tenant['joinDate'])}'),
                const SizedBox(width: 16),
                const Icon(Icons.payment, size: 16),
                const SizedBox(width: 4),
                Text('Last: ${formatDate(tenant['lastPayment'])}'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialsTab(ViewPropertyViewModel viewModel) {
    final financials = viewModel.financials;
    final totalRooms = (viewModel.propertyStats['totalRooms'] as int?) ?? 0;

    // Show empty state if no rooms are configured
    if (totalRooms == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No financial data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Add rooms to this property to see financial metrics',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Financial Overview',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                  'Monthly Revenue',
                  '₹ ${(financials['monthlyRevenue'] / 1000).toStringAsFixed(0)}K',
                  Icons.trending_up,
                  Colors.green.shade600),
              _buildStatCard(
                  'Yearly Revenue',
                  '₹ ${(financials['yearlyRevenue'] / 100000).toStringAsFixed(1)}L',
                  Icons.account_balance,
                  Colors.blue.shade600),
              _buildStatCard(
                  'Pending Payments',
                  '₹ ${(financials['pendingPayments'] / 1000).toStringAsFixed(0)}K',
                  Icons.pending_actions,
                  Colors.red.shade600),
              _buildStatCard('Net Income',
                  '₹ ${(financials['netIncome'] / 1000).toStringAsFixed(0)}K',
                  Icons.savings, Colors.purple.shade600),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoCard('Monthly Breakdown', [
            _buildInfoRow('Total Revenue', '₹ ${financials['monthlyRevenue'].toStringAsFixed(0)}'),
            _buildInfoRow('Expenses', '₹ ${financials['expenses'].toStringAsFixed(0)}'),
            _buildInfoRow('Net Income', '₹ ${financials['netIncome'].toStringAsFixed(0)}'),
            _buildInfoRow('Pending Payments', '₹ ${financials['pendingPayments'].toStringAsFixed(0)}'),
          ]),
        ],
      ),
    );
  }

  // Requests tab
  Widget _buildRequestsTab(ViewPropertyViewModel viewModel) {
    if (viewModel.requestsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.requestsError != null) {
      return Center(
        child: Text(
          'Failed to load requests: ${viewModel.requestsError}',
          style: TextStyle(color: Colors.red.shade400),
        ),
      );
    }
    final requests = viewModel.requests;

    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No requests yet'),
            const SizedBox(height: 4),
            const Text('Share your QR code to start receiving requests'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final TenantRequest r = requests[index]; // Updated type usage
        final isPending = r.status == 'pending';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
            border: Border.all(
              color: isPending
                  ? Colors.orange.shade200
                  : (r.status == 'approved'
                  ? Colors.green.shade200
                  : Colors.red.shade200),
            ),
          ),
          child: InkWell(
            onTap: () async {
              HapticFeedback.lightImpact();
              final changed = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RequestDetailScreen(
                      propertyId: widget.propertyId, request: r),
                ),
              );
              if (changed == true) {
                // Stream updates handled in view model
              }
            },
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal.shade50,
                  child: Icon(Icons.person_outline, color: Colors.teal.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.tenantName,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone,
                                size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(r.phone,
                                style:
                                TextStyle(color: Colors.grey.shade700)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (r.sharingType != null)
                              _chip('${r.sharingType}-Sharing',
                                  Colors.blue.shade50, Colors.blue.shade700),
                            _chip(
                                r.hasAC == true ? 'AC' : 'Non-AC',
                                Colors.purple.shade50,
                                Colors.purple.shade700),
                            _chip(r.status.toUpperCase(), _statusBg(r.status),
                                _statusFg(r.status)),
                          ],
                        ),
                      ]),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.call),
                  color: Colors.teal.shade600,
                  tooltip: 'Call tenant',
                  onPressed: () => _callTenant(r.phone),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey.shade500),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green.shade50;
      case 'rejected':
        return Colors.red.shade50;
      default:
        return Colors.orange.shade50;
    }
  }

  Color _statusFg(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      default:
        return Colors.orange.shade700;
    }
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: TextStyle(
              color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Future<void> _callTenant(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available for this tenant')),
      );
      return;
    }

    final telUri = Uri(scheme: 'tel', path: normalized);
    if (!await launchUrl(telUri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open dialer')),
      );
    }
  }

  // QR tab
  Widget _buildQrTab(ViewPropertyViewModel viewModel) {
    final property = viewModel.property!;
    final payloadUrl = 'https://onestay.app/request?propertyId=${property.id}';
    final deeplink = 'onestay://request?propertyId=${property.id}';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Share QR to Receive Requests',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800),
            ),
            const SizedBox(height: 12),
            Text(
              'Tenants can scan this QR to send a request for ${property.name}.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: payloadUrl,
                    version: QrVersions.auto,
                    size: 220,
                    gapless: false,
                    eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square, color: Colors.black),
                    dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black),
                  ),
                  const SizedBox(height: 12),
                  Text(payloadUrl,
                      style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: payloadUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied')));
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Link'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Share via share_plus if added
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Implement share via share_plus')));
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Deep link: $deeplink',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Icon(icon, color: color, size: 20),
          ],
        ),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800)),
      ]),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child:
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500)),
        ),
        const Text(': '),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}


