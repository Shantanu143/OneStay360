import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_services/repositories/property_repository.dart';

/// A rent invoice for the current month that has not been paid yet.
class RentDue {
  const RentDue({
    required this.tenantId,
    required this.tenantName,
    required this.phone,
    required this.amount,
    required this.month,
    required this.dueDate,
    required this.overdue,
  });

  final String tenantId;
  final String tenantName;
  final String phone;
  final double amount;
  final String month;
  final DateTime? dueDate;
  final bool overdue;
}

class BusinessDashboardViewModel extends ChangeNotifier {
  final PropertyRepository _propertyRepository;
  final FirebaseFirestore _firestore;

  bool _isDisposed = false;
  String? _lastBusinessId;

  bool _isLoading = false;
  String? _error;

  int _totalProperties = 0;
  int _totalCapacity = 0;
  int _activeTenants = 0;
  double _occupancyRate = 0.0;
  int _pendingRentPaymentCount = 0;
  double _pendingRentPaymentAmount = 0.0;
  int _pendingDepositCount = 0;
  double _pendingDepositAmount = 0.0;

  // Current-month rent collection (from tenants' rent_invoices).
  bool _hasLoaded = false;
  double _collectionsTarget = 0.0;
  double _collectionsCollected = 0.0;
  int _overdueCount = 0;
  int _leasesEndingThisWeek = 0;
  List<RentDue> _rentDues = const [];

  /// Rent invoices are read one tenant at a time (rules have no
  /// collection-group access); this bounds how many run concurrently.
  static const _invoiceReadConcurrency = 10;

  final DateTime Function() _clock;
  DateTime? _loadedAt;

  BusinessDashboardViewModel({
    required PropertyRepository propertyRepository,
    FirebaseFirestore? firestore,
    DateTime Function()? clock,
    Set<String>? Function()? propertyScope,
  }) : _propertyRepository = propertyRepository,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _clock = clock ?? DateTime.now,
       _propertyScope = propertyScope;

  /// The ids of the properties this person can open; null means all (owner).
  /// Everything on the dashboard is counted over these only.
  final Set<String>? Function()? _propertyScope;

  /// When the metrics were last loaded successfully (null before the first).
  DateTime? get loadedAt => _loadedAt;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  int get totalProperties => _totalProperties;
  int get totalCapacity => _totalCapacity;
  int get activeTenants => _activeTenants;

  String get occupancyRateString {
    if (_totalCapacity == 0) return '0%';
    return '${(_occupancyRate * 100).toStringAsFixed(1)}%';
  }

  /// Rent + deposit payments the owner still has to confirm.
  String get pendingRentString =>
      '₹ ${_formatCurrency(pendingConfirmationAmount)}';

  /// True once the first load attempt has finished (successfully or not).
  bool get hasLoaded => _hasLoaded;

  double get pendingConfirmationAmount =>
      _pendingRentPaymentAmount + _pendingDepositAmount;
  int get pendingPaymentsCount =>
      _pendingRentPaymentCount + _pendingDepositCount;

  double get collectionsTarget => _collectionsTarget;
  double get collectionsCollected => _collectionsCollected;
  double get collectionsPending =>
      math.max(0.0, _collectionsTarget - _collectionsCollected);
  int get overdueCount => _overdueCount;
  bool get hasCollections => _collectionsTarget > 0;
  double get collectionProgress => _collectionsTarget <= 0
      ? 0.0
      : (_collectionsCollected / _collectionsTarget).clamp(0.0, 1.0);
  List<RentDue> get rentDues => _rentDues;
  int get leasesEndingThisWeek => _leasesEndingThisWeek;

  int get occupiedBeds => math.min(_activeTenants, _totalCapacity);
  int get vacantBeds => math.max(0, _totalCapacity - _activeTenants);
  double get occupancyFraction => _totalCapacity <= 0
      ? 0.0
      : (_activeTenants / _totalCapacity).clamp(0.0, 1.0);

  Future<void> loadDashboardMetrics(String? businessId) async {
    if (businessId == null || businessId.isEmpty) {
      _resetMetrics();
      _error = 'No active business membership';
      _notifyListenersSafe();
      return;
    }

    if (_isLoading && _lastBusinessId == businessId) return;

    _lastBusinessId = businessId;
    _isLoading = true;
    _error = null;
    _notifyListenersSafe();

    try {
      debugPrint('🔄 Loading dashboard metrics for business: $businessId');

      // 1. Fetch properties to get total count and capacity
      final scope = _propertyScope?.call();
      bool inScope(Object? propertyId) =>
          scope == null || (propertyId is String && scope.contains(propertyId));

      final properties = [
        for (final p in await _propertyRepository.getPropertiesByBusiness(businessId))
          if (inScope(p.id)) p,
      ];
      _totalProperties = properties.length;
      _totalCapacity = properties.fold(
        0,
        (sum, prop) => sum + prop.totals.beds,
      );

      // 2. Active tenants. Read from the business's own `tenants` (any member
      // may list those); the global `tenants` collection is owner-only and
      // can't be listed by query under the security rules.
      final tenantsSnap = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('tenants')
          .where('status', isEqualTo: 'active')
          .get();
      final tenantDocs = [
        for (final d in tenantsSnap.docs)
          if (inScope(d.data()['propertyId'])) d,
      ];
      _activeTenants = tenantDocs.length;

      // Calculate Occupancy
      if (_totalCapacity > 0) {
        _occupancyRate = _activeTenants / _totalCapacity;
      } else {
        _occupancyRate = 0.0;
      }

      // 3. Pending payments and this month's rent collection are independent
      // of each other and of the core metrics above: a failure in either one
      // (e.g. missing index or rules) must not blank the whole dashboard.
      await Future.wait([
        _loadPendingDeposits(businessId, inScope),
        _loadRentCollections(businessId, tenantDocs),
      ]);

      _loadedAt = _clock();
      debugPrint(
        '✅ Successfully loaded dashboard metrics for business: $businessId',
      );
    } catch (e, stack) {
      debugPrint('❌ Error loading dashboard metrics: $e');
      debugPrint('Stack trace: $stack');
      _resetMetrics();
      _error = 'Failed to load dashboard metrics: ${e.toString()}';
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      _notifyListenersSafe();
    }
  }

  /// Deposits that tenants have paid for an enrollment and that the owner
  /// still has to confirm (a top-level, businessId-scoped query).
  Future<void> _loadPendingDeposits(String businessId, bool Function(Object? propertyId) inScope) async {
    try {
      final snap = await _firestore
          .collection('enrollmentRequests')
          .where('businessId', isEqualTo: businessId)
          .where('status', isEqualTo: 'payment_submitted')
          .get();
      final docs = [for (final d in snap.docs) if (inScope(d.data()['propertyId'])) d];
      _pendingDepositCount = docs.length;
      _pendingDepositAmount = docs.fold(
        0.0,
        (total, doc) {
          // The bill flow writes totalBillAmount (and totalFirstMonth);
          // totalAmount is what older requests carried.
          final d = doc.data();
          final amount = d['totalBillAmount'] ?? d['totalFirstMonth'] ?? d['totalAmount'];
          return total + ((amount as num?)?.toDouble() ?? 0.0);
        },
      );
    } catch (e) {
      debugPrint('⚠️ Could not load pending deposits: $e');
      _pendingDepositCount = 0;
      _pendingDepositAmount = 0.0;
    }
  }

  /// Rent payments awaiting confirmation, read from the payments of tenants
  /// who still owe (a payment only waits while its invoice is unpaid). The
  /// rules allow reading a tenant's own payments but not a collection-group
  /// query across tenants.
  Future<void> _loadPendingRentPayments(
    Iterable<String> tenantIdsWithDues,
    CollectionReference<Map<String, dynamic>> tenantsRef,
  ) async {
    var count = 0;
    var amount = 0.0;
    final ids = tenantIdsWithDues.toList();
    try {
      for (var i = 0; i < ids.length; i += _invoiceReadConcurrency) {
        final batch = ids.skip(i).take(_invoiceReadConcurrency);
        final results = await Future.wait(
          batch.map(
            (id) => tenantsRef
                .doc(id)
                .collection('payments')
                .where('status', isEqualTo: 'pending_verification')
                .get(),
          ),
        );
        for (final snap in results) {
          for (final doc in snap.docs) {
            count++;
            amount += (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Could not load pending rent payments: $e');
      count = 0;
      amount = 0.0;
    }
    _pendingRentPaymentCount = count;
    _pendingRentPaymentAmount = amount;
  }

  /// Totals this month's rent invoices across the business's active tenants
  /// and collects who still owes what.
  Future<void> _loadRentCollections(
    String businessId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> tenants,
  ) async {
    try {
      final now = _clock();
      final today = DateTime(now.year, now.month, now.day);
      final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      // Leases ending within the next 7 days (today included).
      final weekEnd = today.add(const Duration(days: 8));
      var leasesEnding = 0;
      for (final doc in tenants) {
        final out = _asDate(doc.data()['checkOutDate']);
        if (out != null && !out.isBefore(today) && out.isBefore(weekEnd)) {
          leasesEnding++;
        }
      }

      var target = 0.0;
      var collected = 0.0;
      var overdue = 0;
      final dues = <RentDue>[];

      for (var i = 0; i < tenants.length; i += _invoiceReadConcurrency) {
        final batch = tenants.skip(i).take(_invoiceReadConcurrency).toList();
        final results = await Future.wait(
          batch.map(
            (t) => t.reference
                .collection('rent_invoices')
                .where('periodMonth', isEqualTo: period)
                .get(),
          ),
        );

        for (var j = 0; j < batch.length; j++) {
          final tenant = batch[j].data();
          for (final invoice in results[j].docs) {
            final data = invoice.data();
            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final status = (data['status'] as String?) ?? 'unpaid';
            final dueDate = _asDate(data['dueDate']);

            target += amount;
            if (status == 'paid') {
              collected += amount;
              continue;
            }
            final isOverdue =
                status == 'overdue' ||
                (dueDate != null && dueDate.isBefore(now));
            if (isOverdue) overdue++;
            dues.add(
              RentDue(
                tenantId: batch[j].id,
                tenantName: (tenant['name'] as String?) ?? 'Tenant',
                phone: (tenant['phone'] as String?) ?? '',
                amount: amount,
                month: (data['month'] as String?) ?? '',
                dueDate: dueDate,
                overdue: isOverdue,
              ),
            );
          }
        }
      }

      // Overdue first, longest overdue at the top.
      dues.sort((a, b) {
        if (a.overdue != b.overdue) return a.overdue ? -1 : 1;
        final ad = a.dueDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.dueDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return ad.compareTo(bd);
      });

      await _loadPendingRentPayments(
        dues.map((d) => d.tenantId).toSet(),
        _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('tenants'),
      );

      _collectionsTarget = target;
      _collectionsCollected = collected;
      _overdueCount = overdue;
      _leasesEndingThisWeek = leasesEnding;
      _rentDues = List.unmodifiable(dues);
    } catch (e) {
      debugPrint('⚠️ Could not load rent collections: $e');
      _resetCollections();
    }
  }

  static DateTime? _asDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return null;
  }

  void _resetCollections() {
    _collectionsTarget = 0.0;
    _collectionsCollected = 0.0;
    _overdueCount = 0;
    _leasesEndingThisWeek = 0;
    _rentDues = const [];
  }

  Future<void> refreshMetrics(String? businessId) async {
    await loadDashboardMetrics(businessId);
  }

  /// Reloads only if nothing is loaded or the data is older than [maxAge].
  /// Used when returning to the Home tab, so switching tabs is free but the
  /// numbers don't go stale. The UI keeps showing the old numbers meanwhile.
  Future<void> refreshIfStale(
    String? businessId, {
    required Duration maxAge,
  }) async {
    final at = _loadedAt;
    if (at != null && _clock().difference(at) < maxAge) return;
    await loadDashboardMetrics(businessId);
  }

  void _resetMetrics() {
    _totalProperties = 0;
    _totalCapacity = 0;
    _activeTenants = 0;
    _occupancyRate = 0.0;
    _pendingRentPaymentCount = 0;
    _pendingRentPaymentAmount = 0.0;
    _pendingDepositCount = 0;
    _pendingDepositAmount = 0.0;
    _resetCollections();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    super.dispose();
  }

  void _notifyListenersSafe() {
    if (_isDisposed) return;
    notifyListeners();
  }

  String _formatCurrency(double amount) {
    if (amount == 0) return '0';
    if (amount < 1000) return amount.toInt().toString();
    if (amount < 100000) {
      final k = amount / 1000;
      return k == k.toInt() ? '${k.toInt()}K' : '${k.toStringAsFixed(1)}K';
    }
    final l = amount / 100000;
    return l == l.toInt() ? '${l.toInt()}L' : '${l.toStringAsFixed(2)}L';
  }
}
