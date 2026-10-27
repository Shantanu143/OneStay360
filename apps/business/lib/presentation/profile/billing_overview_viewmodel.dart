// lib/presentation/profile/billing_overview_viewmodel.dart
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:models/business/property/property_model.dart';

import '../property_detail/property_detail_viewmodel.dart';

/// One property's line on the billing overview.
class BillingRow {
  const BillingRow(this.property, this.status, this.monthly);

  final Property property;
  final BillingStatusView status;

  /// What OneStay360 charges for it each month.
  final int monthly;

  bool get needsAction => status.canPay || status.canActivate;

  /// Billing has started (it is not a draft waiting for its first payment).
  bool get isBilling => !status.canActivate;
}

/// What the business owes OneStay360, property by property.
class BillingOverviewViewModel extends ChangeNotifier {
  BillingOverviewViewModel({
    required PropertyRepository repository,
    required this.businessId,
  }) : _repo = repository;

  final PropertyRepository _repo;
  final String businessId;
  bool _disposed = false;

  List<BillingRow> _rows = const [];
  bool _loading = true;
  String? _error;

  List<BillingRow> get rows => _rows;
  bool get loading => _loading;
  String? get error => _error;

  int get monthlyTotal =>
      _rows.where((r) => r.isBilling).fold(0, (n, r) => n + r.monthly);
  int get needAttention => _rows.where((r) => r.needsAction).length;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final properties = await _repo.getPropertiesByBusiness(businessId);
      final rows =
          [
            for (final p in properties)
              BillingRow(
                p,
                BillingStatusView.of(p.billingStatus),
                p.pricePerBed *
                    (p.billedBedCount > 0 ? p.billedBedCount : p.totalBeds),
              ),
          ]..sort((a, b) {
            if (a.needsAction != b.needsAction) return a.needsAction ? -1 : 1;
            return a.property.name.toLowerCase().compareTo(
              b.property.name.toLowerCase(),
            );
          });
      _rows = rows;
    } catch (e) {
      debugPrint('❌ [Billing] load: $e');
      _error = "Couldn't load your properties.";
    } finally {
      _loading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
