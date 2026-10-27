// lib/presentation/property_detail/property_detail_screen.dart
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:flutter/material.dart';
import 'package:models/business/property/property_model.dart';
import 'package:provider/provider.dart';

import '../design/components/biz_chips.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_states.dart';
import '../design/tokens.dart';
import '../views/properties/property_card.dart' show PropertyImageBuilder;
import 'firestore_property_detail_source.dart';
import 'property_detail_actions.dart';
import 'property_detail_models.dart';
import 'property_detail_source.dart';
import 'property_detail_viewmodel.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/detail_common.dart';
import 'tabs/layout_tab.dart';
import 'tabs/overview_tab.dart';
import 'tabs/payments_tab.dart';
import 'tabs/qr_tab.dart';
import 'tabs/requests_tab.dart';
import 'tabs/tenants_tab.dart';

/// One property: occupancy, rooms, tenants, collections, subscription,
/// requests and the QR code tenants scan.
class PropertyDetailScreen extends StatefulWidget {
  const PropertyDetailScreen({
    super.key,
    required this.propertyId,
    this.initialTabIndex,
    this.source,
    this.actions = const DeviceDetailActions(),
    this.clock,
    this.imageBuilder,
  });

  final String propertyId;

  /// Index into [PropertyDetailTab] (4 = payments, 5 = requests, as deep
  /// links use it). Out of range opens Overview.
  final int? initialTabIndex;

  /// Where data comes from; defaults to Firestore through the app's
  /// [PropertyRepository].
  final PropertyDetailSource? source;
  final PropertyDetailActions actions;
  final DateTime Function()? clock;
  final PropertyImageBuilder? imageBuilder;

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  late final PropertyDetailViewModel _vm;
  late final TextEditingController _search;
  late final DateTime Function() _clock;

  @override
  void initState() {
    super.initState();
    _clock = widget.clock ?? DateTime.now;
    _search = TextEditingController();
    final source =
        widget.source ??
        FirestorePropertyDetailSource(repository: context.read<PropertyRepository>());
    _vm = PropertyDetailViewModel(source: source, clock: _clock);

    final index = widget.initialTabIndex;
    if (index != null && index >= 0 && index < PropertyDetailTab.values.length) {
      _vm.selectTab(PropertyDetailTab.values[index]);
    }
    _vm.load(widget.propertyId);
    _vm.listenRequests(widget.propertyId);
  }

  @override
  void dispose() {
    _search.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _reload() => _vm.refresh(widget.propertyId);

  Future<void> _checkout(String purpose, {String? invoiceId}) async {
    final paid = await widget.actions.openCheckout(
      context,
      propertyId: widget.propertyId,
      purpose: purpose,
      invoiceId: invoiceId,
    );
    if (paid && mounted) await _reload();
  }

  Future<void> _openTenant(PropertyTenant tenant) async {
    final property = _vm.property;
    if (property == null) return;
    final removed = await widget.actions.openTenant(context, property: property, tenant: tenant);
    if (removed && mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final property = _vm.property;
        return BizScaffold(
          title: property?.name ?? 'Property',
          eyebrow: property == null
              ? null
              : [
                  if (property.city.trim().isNotEmpty) property.city.trim(),
                  titleCase(property.status),
                ].where((s) => s.isNotEmpty).join(' · '),
          showBack: true,
          belowHeader: property == null ? null : _tabBar(),
          body: _body(context),
        );
      },
    );
  }

  Widget _tabBar() {
    final pending = _vm.pendingRequestsCount;
    const labels = {
      PropertyDetailTab.overview: 'Overview',
      PropertyDetailTab.layout: 'Layout',
      PropertyDetailTab.tenants: 'Tenants',
      PropertyDetailTab.analytics: 'Analytics',
      PropertyDetailTab.payments: 'Payments',
      PropertyDetailTab.requests: 'Requests',
      PropertyDetailTab.qr: 'QR',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BizFilterChips(
        chips: [
          for (final tab in PropertyDetailTab.values)
            BizChipData(
              labels[tab]!,
              count: tab == PropertyDetailTab.requests && pending > 0 ? pending : null,
            ),
        ],
        selectedIndex: _vm.tab.index,
        onSelected: (i) => _vm.selectTab(PropertyDetailTab.values[i]),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final property = _vm.property;
    if (property == null) {
      if (_vm.error != null) {
        return BizErrorState(message: _vm.error!, onRetry: () => _vm.load(widget.propertyId));
      }
      return const Padding(
        padding: EdgeInsets.fromLTRB(kDetailGutter, 8, kDetailGutter, 0),
        child: BizSkeletonList(count: 3, cardHeight: 120),
      );
    }

    final bottom = MediaQuery.viewPaddingOf(context).bottom + 32;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      child: RefreshIndicator(
        key: ValueKey(_vm.tab),
        color: BizColors.green,
        onRefresh: _reload,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _tab(property),
            SliverToBoxAdapter(child: SizedBox(height: bottom)),
          ],
        ),
      ),
    );
  }

  Widget _tab(Property property) {
    final now = _clock();
    switch (_vm.tab) {
      case PropertyDetailTab.overview:
        return OverviewTab(
          vm: _vm,
          actions: widget.actions,
          imageBuilder: widget.imageBuilder,
          onActivate: () => _checkout('activation'),
          onOpenPayments: () => _vm.selectTab(PropertyDetailTab.payments),
        );
      case PropertyDetailTab.layout:
        return LayoutTab(vm: _vm, onOpenTenant: _openTenant);
      case PropertyDetailTab.tenants:
        return TenantsTab(
          vm: _vm,
          searchController: _search,
          onOpenTenant: _openTenant,
          onCall: (t) => widget.actions.call(context, t.phone),
        );
      case PropertyDetailTab.analytics:
        return AnalyticsTab(vm: _vm, now: now);
      case PropertyDetailTab.payments:
        return PaymentsTab(
          vm: _vm,
          onActivate: () => _checkout('activation'),
          onPay: (invoiceId) => _checkout('monthly', invoiceId: invoiceId),
        );
      case PropertyDetailTab.requests:
        return RequestsTab(
          vm: _vm,
          now: now,
          onOpen: (r) => widget.actions.openRequest(
            context,
            propertyId: widget.propertyId,
            request: r,
          ),
        );
      case PropertyDetailTab.qr:
        return QrTab(property: property, actions: widget.actions);
    }
  }
}
