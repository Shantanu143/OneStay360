// lib/presentation/property_detail/property_detail_viewmodel.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:models/business/property/property_model.dart';
import 'package:models/tenant/tenant_request_model.dart';

import '../view_models/tenant_wizard/assignment.dart';
import 'property_detail_models.dart';
import 'property_detail_source.dart';

/// The tabs, in the order deep links refer to them by index
/// (billing = 4, requests = 5).
enum PropertyDetailTab { overview, layout, tenants, analytics, payments, requests, qr }

/// How the Payments tab describes the property's subscription.
class BillingStatusView {
  const BillingStatusView(this.label, this.tone, {this.canPay = false, this.canActivate = false});

  final String label;

  /// 'success' | 'warning' | 'danger' | 'neutral'
  final String tone;

  /// A monthly invoice is waiting to be paid.
  final bool canPay;

  /// The property still needs its first (activation) payment.
  final bool canActivate;

  static BillingStatusView of(String? status) {
    switch (status) {
      case 'paid':
        return const BillingStatusView('Billing active', 'success');
      case 'due':
      case 'grace':
        return const BillingStatusView('Payment due', 'warning', canPay: true);
      case 'past_due':
        return const BillingStatusView('Overdue', 'warning', canPay: true);
      case 'suspended':
        return const BillingStatusView('Service suspended', 'danger', canPay: true);
      case 'payment_due':
      case '':
      case null:
        return const BillingStatusView('Activation pending', 'warning', canActivate: true);
      default:
        return const BillingStatusView('Billing status', 'neutral');
    }
  }
}

/// State of the property detail screen. The core (property, rooms, tenants) is
/// loaded at once; payments and analytics only when their tab is opened, so
/// the screen opens fast and does no work the owner never looks at.
class PropertyDetailViewModel extends ChangeNotifier {
  PropertyDetailViewModel({required PropertyDetailSource source, DateTime Function()? clock})
      : _source = source,
        _clock = clock ?? DateTime.now;

  final PropertyDetailSource _source;
  final DateTime Function() _clock;
  bool _disposed = false;

  // ─── Core ────────────────────────────────────────────────────────────
  Property? _property;
  List<PropertyTenant> _tenants = const [];
  List<FloorSlot> _floors = const [];
  Map<String, PropertyTenant> _byBed = const {};
  PropertyStats _stats = const PropertyStats(
      totalRooms: 0, occupiedRooms: 0, totalBeds: 0, occupiedBeds: 0, expectedMonthlyRent: 0);
  bool _loading = true;
  String? _error;
  String _search = '';

  Property? get property => _property;
  List<PropertyTenant> get tenants => _tenants;
  List<FloorSlot> get floors => _floors;
  PropertyStats get stats => _stats;
  bool get loading => _loading;
  String? get error => _error;
  String get search => _search;

  PropertyTenant? occupantAt(String roomId, String bedNumber) => _byBed['$roomId|$bedNumber'];

  List<PropertyTenant> get visibleTenants => _tenants.where((t) => t.matches(_search)).toList();

  void setSearch(String q) {
    if (_search == q) return;
    _search = q;
    _notify();
  }

  /// Loads the property. Pass [silent] to keep what's on screen while
  /// refreshing.
  Future<void> load(String propertyId, {bool silent = false}) async {
    if (propertyId.isEmpty) {
      _error = 'Property ID cannot be empty';
      _loading = false;
      _notify();
      return;
    }
    if (!silent || _property == null) {
      _loading = true;
      _error = null;
      _notify();
    }
    try {
      final property = await _source.property(propertyId);
      if (property == null) {
        _error = 'Property not found';
        _property = null;
        return;
      }
      final results = await Future.wait([
        _source.rooms(property),
        _source.activeTenants(property.businessId, propertyId),
      ]);
      final rooms = results[0] as List<dynamic>;
      final tenants = [...(results[1] as List<PropertyTenant>)]..sort((a, b) {
          final byRoom = naturalCompare(a.roomId, b.roomId);
          return byRoom != 0 ? byRoom : naturalCompare(a.bedId, b.bedId);
        });

      _property = property;
      _tenants = tenants;
      _floors = buildFloors(rooms.cast(), occupiedBedsOf(tenants));
      _byBed = {for (final t in tenants) '${t.roomId}|${t.bedId}': t};
      _stats = statsFor(_floors, tenants);
      _error = null;
      _loadTabData();
    } catch (e, stack) {
      debugPrint('❌ [PropertyDetail] load failed: $e\n$stack');
      _error = "Couldn't load this property. Check your connection and try again.";
    } finally {
      _loading = false;
      _notify();
    }
  }

  // ─── Requests (live) ─────────────────────────────────────────────────
  List<TenantRequest> _requests = const [];
  bool _requestsLoading = false;
  String? _requestsError;
  StreamSubscription<List<TenantRequest>>? _requestsSub;
  String? _requestsFor;

  List<TenantRequest> get requests => _requests;
  bool get requestsLoading => _requestsLoading;
  String? get requestsError => _requestsError;
  int get pendingRequestsCount => _requests.where((r) => r.status == 'pending').length;

  void listenRequests(String propertyId) {
    if (propertyId.isEmpty || _requestsFor == propertyId) return;
    _requestsSub?.cancel();
    _requestsFor = propertyId;
    _requestsLoading = true;
    _requestsError = null;
    _notify();
    _requestsSub = _source.requests(propertyId).listen(
      (list) {
        _requests = [...list]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _requestsLoading = false;
        _requestsError = null;
        _notify();
      },
      onError: (Object e) {
        debugPrint('❌ [PropertyDetail] requests: $e');
        _requestsLoading = false;
        _requestsError = "Couldn't load requests.";
        _notify();
      },
    );
  }

  // ─── Billing (payments tab) ──────────────────────────────────────────
  List<Map<String, dynamic>> _payments = const [];
  String? _unpaidInvoiceId;
  bool _billingLoaded = false;
  bool _billingLoading = false;
  String? _billingError;

  List<Map<String, dynamic>> get payments => _payments;
  String? get unpaidInvoiceId => _unpaidInvoiceId;
  bool get billingLoading => _billingLoading;
  String? get billingError => _billingError;
  BillingStatusView get billingStatus => BillingStatusView.of(_property?.billingStatus);

  Future<void> ensureBilling({bool force = false}) async {
    final p = _property;
    if (p == null || p.id == null) return;
    if (_billingLoaded && !force) return;
    if (_billingLoading) return;
    _billingLoading = true;
    _billingError = null;
    _notify();
    try {
      _payments = await _source.billingPayments(p.businessId, p.id!);
      final s = p.billingStatus;
      _unpaidInvoiceId = (s == 'due' || s == 'grace' || s == 'past_due')
          ? await _source.unpaidInvoiceId(p.businessId, p.id!)
          : null;
      _billingLoaded = true;
    } catch (e) {
      debugPrint('❌ [PropertyDetail] billing: $e');
      _billingError = "Couldn't load payments.";
    } finally {
      _billingLoading = false;
      _notify();
    }
  }

  // ─── Analytics ───────────────────────────────────────────────────────
  MonthCollection _collection = MonthCollection.empty;
  bool _analyticsLoaded = false;
  bool _analyticsLoading = false;
  String? _analyticsError;

  MonthCollection get collection => _collection;
  bool get analyticsLoading => _analyticsLoading;
  String? get analyticsError => _analyticsError;

  Future<void> ensureAnalytics({bool force = false}) async {
    final p = _property;
    if (p == null) return;
    if (_analyticsLoaded && !force) return;
    if (_analyticsLoading) return;
    _analyticsLoading = true;
    _analyticsError = null;
    _notify();
    try {
      final now = _clock();
      final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      if (_tenants.isEmpty) {
        _collection = MonthCollection.empty;
      } else {
        final invoices = await _source.invoicesFor(
          p.businessId,
          [for (final t in _tenants) t.id],
          period,
        );
        var expected = 0.0, collected = 0.0;
        var paid = 0, unpaid = 0, overdue = 0;
        for (final i in invoices) {
          expected += i.amount;
          if (i.status == 'paid') {
            collected += i.amount;
            paid++;
          } else {
            unpaid++;
            final late = i.status == 'overdue' || (i.dueDate != null && i.dueDate!.isBefore(now));
            if (late) overdue++;
          }
        }
        _collection = MonthCollection(
          expected: expected,
          collected: collected,
          paidCount: paid,
          unpaidCount: unpaid,
          overdueCount: overdue,
        );
      }
      _analyticsLoaded = true;
    } catch (e) {
      debugPrint('❌ [PropertyDetail] analytics: $e');
      _analyticsError = "Couldn't load this month's collections.";
    } finally {
      _analyticsLoading = false;
      _notify();
    }
  }

  // ─── Tabs & refresh ──────────────────────────────────────────────────
  PropertyDetailTab _tab = PropertyDetailTab.overview;
  PropertyDetailTab get tab => _tab;

  void selectTab(PropertyDetailTab tab) {
    _tab = tab;
    _notify();
    _loadTabData();
  }

  /// Loads what the open tab needs. Runs when the tab changes and again once
  /// the property arrives, so a screen opened straight onto Payments (from a
  /// notification) still gets its data.
  void _loadTabData() {
    switch (_tab) {
      case PropertyDetailTab.analytics:
        unawaited(ensureAnalytics());
      case PropertyDetailTab.payments:
        unawaited(ensureBilling());
      default:
        break;
    }
  }

  Future<void> refresh(String propertyId) async {
    await load(propertyId, silent: true);
    await Future.wait([
      if (_analyticsLoaded) ensureAnalytics(force: true),
      if (_billingLoaded) ensureBilling(force: true),
    ]);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestsSub?.cancel();
    super.dispose();
  }
}
