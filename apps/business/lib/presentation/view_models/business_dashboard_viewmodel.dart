import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:models/business/property/property_model.dart';
import 'package:firebase_services/repositories/property_repository.dart';

class BusinessDashboardViewModel extends ChangeNotifier {
  final PropertyRepository _propertyRepository;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isDisposed = false;
  String? _lastBusinessId;

  bool _isLoading = false;
  String? _error;

  int _totalProperties = 0;
  int _totalCapacity = 0;
  int _activeTenants = 0;
  double _occupancyRate = 0.0;
  double _pendingRentAmount = 0.0;

  BusinessDashboardViewModel({required PropertyRepository propertyRepository})
      : _propertyRepository = propertyRepository;

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

  String get pendingRentString {
    return '₹ ${_formatCurrency(_pendingRentAmount)}';
  }

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
      final properties = await _propertyRepository.getPropertiesByBusiness(businessId);
      _totalProperties = properties.length;
      _totalCapacity = properties.fold(0, (sum, prop) => sum + prop.totals.beds);

      // 2. Fetch active tenants
      final tenantsSnap = await _firestore
          .collection('tenants')
          .where('businessId', isEqualTo: businessId)
          .where('status', isEqualTo: 'active')
          .get();
      _activeTenants = tenantsSnap.docs.length;

      // Calculate Occupancy
      if (_totalCapacity > 0) {
        _occupancyRate = _activeTenants / _totalCapacity;
      } else {
        _occupancyRate = 0.0;
      }

      // 3. Fetch pending rent payments
      final paymentsSnap = await _firestore
          .collectionGroup('payments')
          .where('businessId', isEqualTo: businessId)
          .where('status', isEqualTo: 'pending_verification')
          .get();

      _pendingRentAmount = paymentsSnap.docs.fold(0.0, (sum, doc) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        return sum + amount;
      });

      debugPrint('✅ Successfully loaded dashboard metrics for business: $businessId');
    } catch (e, stack) {
      debugPrint('❌ Error loading dashboard metrics: $e');
      debugPrint('Stack trace: $stack');
      _resetMetrics();
      _error = 'Failed to load dashboard metrics: ${e.toString()}';
    } finally {
      _isLoading = false;
      _notifyListenersSafe();
    }
  }

  Future<void> refreshMetrics(String? businessId) async {
    await loadDashboardMetrics(businessId);
  }

  void _resetMetrics() {
    _totalProperties = 0;
    _totalCapacity = 0;
    _activeTenants = 0;
    _occupancyRate = 0.0;
    _pendingRentAmount = 0.0;
  }

  @override
  void dispose() {
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
