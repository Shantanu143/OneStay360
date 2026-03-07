import 'package:flutter/material.dart';
import 'package:onestay360/data/models/business/property/property_model.dart';
import 'package:onestay360/data/repositories/property_repository.dart';

enum PropertyStatusFilter {
  all,
  active,
  vacant,
  maintenance,
}

enum PropertySortOption {
  updated,
  newest,
  occupancy,
}

class BusinessPropertiesViewModel extends ChangeNotifier {
  final PropertyRepository _propertyRepository;

  List<Property> _properties = [];
  bool _isLoading = false;
  String _searchQuery = '';
  PropertyStatusFilter _statusFilter = PropertyStatusFilter.all;
  PropertySortOption _sortOption = PropertySortOption.updated;
  String? _error;

  BusinessPropertiesViewModel({
    required PropertyRepository propertyRepository,
  }) : _propertyRepository = propertyRepository;

  // Getters
  List<Property> get properties => _properties;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  PropertyStatusFilter get statusFilter => _statusFilter;
  PropertySortOption get sortOption => _sortOption;
  String? get error => _error;
  bool get hasError => _error != null;

  List<Property> get filteredProperties {
    return _properties.where((property) {
      // Filter by search query
      final matchesQuery = _searchQuery.isEmpty ||
          property.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          property.address.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          property.city.toLowerCase().contains(_searchQuery.toLowerCase());

      // Filter by status
      final matchesStatus = _statusFilter == PropertyStatusFilter.all ||
          (_statusFilter == PropertyStatusFilter.active && property.status == 'active') ||
          (_statusFilter == PropertyStatusFilter.vacant && property.status == 'vacant') ||
          (_statusFilter == PropertyStatusFilter.maintenance && property.status == 'maintenance');

      return matchesQuery && matchesStatus;
    }).toList()
      ..sort((a, b) {
        switch (_sortOption) {
          case PropertySortOption.newest:
            return b.createdAt.compareTo(a.createdAt);
          case PropertySortOption.occupancy:
            final aRate = getOccupancyRate(a);
            final bRate = getOccupancyRate(b);
            return bRate.compareTo(aRate);
          case PropertySortOption.updated:
          default:
            return b.updatedAt.compareTo(a.updatedAt);
        }
      });
  }

  // Helper methods for property cards
  Color getStatusColor(Property property) {
    switch (property.status) {
      case 'active':
        return Colors.green.shade600;
      case 'vacant':
        return Colors.orange.shade700;
      case 'maintenance':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String getStatusText(Property property) {
    switch (property.status) {
      case 'active':
        return 'Active';
      case 'vacant':
        return 'Vacant';
      case 'maintenance':
        return 'Maintenance';
      default:
        return property.status;
    }
  }

  String getRentRange(Property property) {
    final single = property.pricing.single;
    final doubleRent = property.pricing.double;
    final triple = property.pricing.triple;

    final min = [single, doubleRent, triple].where((v) => v > 0).reduce((a, b) => a < b ? a : b);
    final max = [single, doubleRent, triple].reduce((a, b) => a > b ? a : b);

    return '₹ ${_formatCurrency(min)} - ₹ ${_formatCurrency(max)}';
  }

  double getOccupancyRate(Property property) {
    if (property.totals.beds == 0) return 0.0;
    return (property.totals.beds - property.totals.availableBeds) / property.totals.beds;
  }

  // Main method to load properties - FIXED
  Future<void> loadProperties() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get business ID directly from repository
      final businessId = await _propertyRepository.getCurrentUserBusinessId();

      if (businessId == null || businessId.isEmpty) {
        _error = 'No business account found';
        _properties = [];
        return;
      }

      debugPrint('🔄 Loading properties for business: $businessId');

      _properties = await _propertyRepository.getPropertiesByBusiness(businessId);

      debugPrint('✅ Successfully loaded ${_properties.length} properties');

    } catch (e, stack) {
      debugPrint('❌ Error loading properties: $e');
      debugPrint('Stack trace: $stack');
      _properties = [];
      _error = 'Failed to load properties: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh method - FIXED
  Future<void> refreshProperties() async {
    await loadProperties();
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void updateStatusFilter(PropertyStatusFilter filter) {
    _statusFilter = filter;
    notifyListeners();
  }

  void updateSortOption(PropertySortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _formatCurrency(int amount) {
    if (amount < 1000) return amount.toString();
    if (amount < 100000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return '${(amount / 100000).toStringAsFixed(1)}L';
  }
}