import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:models/business/property/property_model.dart';
import 'package:firebase_services/repositories/property_repository.dart';

enum PropertyStatusFilter { all, active, vacant, maintenance, draft }

enum PropertySortOption { updated, newest, occupancy }

class BusinessPropertiesViewModel extends ChangeNotifier {
  final PropertyRepository _propertyRepository;

  bool _isDisposed = false;
  String? _lastBusinessId;
  final Set<String> _loadedBusinessIds = {};

  List<Property> _properties = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String _searchQuery = '';
  PropertyStatusFilter _statusFilter = PropertyStatusFilter.all;
  PropertySortOption _sortOption = PropertySortOption.updated;
  String? _error;

  // filteredProperties is read several times per build; recompute only when
  // the data, search, filter or sort changed.
  List<Property>? _filteredCache;

  /// [occupancyLoader] counts the tenants living in each property (property
  /// id to beds in use). Without it, or when it fails, the counter stored on
  /// each property is used, which can be out of date.
  BusinessPropertiesViewModel({
    required PropertyRepository propertyRepository,
    Future<Map<String, int>> Function(String businessId)? occupancyLoader,
    Set<String>? Function()? propertyScope,
  }) : _propertyRepository = propertyRepository,
       _occupancyLoader = occupancyLoader,
       _propertyScope = propertyScope;

  /// The ids of the properties this person can open; null means all (owner).
  final Set<String>? Function()? _propertyScope;

  final Future<Map<String, int>> Function(String businessId)? _occupancyLoader;

  /// Beds in use per property id, or null when they could not be counted.
  Map<String, int>? _occupied;

  // ─── State ──────────────────────────────────────────────────────────────

  List<Property> get properties => _properties;
  bool get isLoading => _isLoading;

  /// True once the first load attempt has finished (successfully or not).
  bool get hasLoaded => _hasLoaded;
  String get searchQuery => _searchQuery;
  PropertyStatusFilter get statusFilter => _statusFilter;
  PropertySortOption get sortOption => _sortOption;
  String? get error => _error;
  bool get hasError => _error != null;

  /// "4 properties · Pune" / "3 properties · 2 cities" / "No properties yet".
  String get summaryLine {
    final n = _properties.length;
    if (n == 0) return 'No properties yet';
    final noun = n == 1 ? 'property' : 'properties';

    final cities = <String, String>{};
    for (final p in _properties) {
      final city = p.city.trim();
      if (city.isNotEmpty) cities.putIfAbsent(city.toLowerCase(), () => city);
    }
    if (cities.isEmpty) return '$n $noun';
    if (cities.length == 1) return '$n $noun · ${cities.values.first}';
    return '$n $noun · ${cities.length} cities';
  }

  int get draftCount => _properties.where(_isDraft).length;
  Property? get firstDraft {
    for (final p in _properties) {
      if (_isDraft(p)) return p;
    }
    return null;
  }

  int countFor(PropertyStatusFilter filter) =>
      _properties.where((p) => _matchesStatus(p, filter)).length;

  List<Property> get filteredProperties {
    return _filteredCache ??= _computeFiltered();
  }

  List<Property> _computeFiltered() {
    final query = _searchQuery.trim().toLowerCase();
    final result = _properties.where((property) {
      final matchesQuery =
          query.isEmpty ||
          property.name.toLowerCase().contains(query) ||
          property.address.toLowerCase().contains(query) ||
          property.city.toLowerCase().contains(query);
      return matchesQuery && _matchesStatus(property, _statusFilter);
    }).toList();

    result.sort((a, b) {
      switch (_sortOption) {
        case PropertySortOption.newest:
          return b.createdAt.compareTo(a.createdAt);
        case PropertySortOption.occupancy:
          return getOccupancyRate(b).compareTo(getOccupancyRate(a));
        case PropertySortOption.updated:
          return b.updatedAt.compareTo(a.updatedAt);
      }
    });
    return result;
  }

  static bool _isDraft(Property p) => p.status == 'draft';

  static bool _matchesStatus(Property p, PropertyStatusFilter filter) {
    switch (filter) {
      case PropertyStatusFilter.all:
        return true;
      case PropertyStatusFilter.active:
        return p.status == 'active';
      case PropertyStatusFilter.vacant:
        return p.status == 'vacant';
      case PropertyStatusFilter.maintenance:
        return p.status == 'maintenance';
      case PropertyStatusFilter.draft:
        return _isDraft(p);
    }
  }

  // ─── Card facts ─────────────────────────────────────────────────────────

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

  String getStatusText(Property property) => statusLabel(property);

  String statusLabel(Property property) {
    final s = property.status;
    if (s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1);
  }

  /// "₹6.5K–12K", "₹9K", or null when no price has been set.
  String? rentRange(Property property) {
    final prices = [
      property.pricing.single,
      property.pricing.double,
      property.pricing.triple,
    ].where((v) => v > 0).toList();
    if (prices.isEmpty) return null;

    final min = prices.reduce((a, b) => a < b ? a : b);
    final max = prices.reduce((a, b) => a > b ? a : b);
    if (min == max) return '₹${_compact(min)}';
    return '₹${_compact(min)}–${_compact(max)}';
  }

  /// Kept for older call sites; prefer [rentRange].
  String getRentRange(Property property) => rentRange(property) ?? '—';

  /// "Baner Rd, Pune" - the city is added only if the address lacks it.
  String locationLine(Property p) {
    final address = p.address.trim();
    final city = p.city.trim();
    if (city.isEmpty) return address;
    if (address.isEmpty) return city;
    if (address.toLowerCase().contains(city.toLowerCase())) return address;
    return '$address, $city';
  }

  int bedsOf(Property p) => p.totals.beds;
  int roomsOf(Property p) => p.totals.rooms;
  int occupiedBedsOf(Property p) {
    final counted = _occupied;
    if (counted != null) return (counted[p.id] ?? 0).clamp(0, p.totals.beds);
    return (p.totals.beds - p.totals.availableBeds).clamp(0, p.totals.beds);
  }

  double getOccupancyRate(Property property) {
    if (property.totals.beds == 0) return 0.0;
    return occupiedBedsOf(property) / property.totals.beds;
  }

  /// "Just now", "20m ago", "3h ago", "Yesterday", "4d ago", "26 Sep".
  String updatedAgo(Property property, {DateTime? now}) {
    final at = property.updatedAt;
    final diff = (now ?? DateTime.now()).difference(at);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(at);
  }

  static String _compact(int amount) {
    String trim(double v) {
      final s = v.toStringAsFixed(1);
      return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
    }

    if (amount < 1000) return '$amount';
    if (amount < 100000) return '${trim(amount / 1000)}K';
    return '${trim(amount / 100000)}L';
  }

  // ─── Loading ────────────────────────────────────────────────────────────

  /// Loads the business's properties. A no-op when they are already loaded
  /// for this business; use [refreshProperties] to force a reload.
  Future<void> loadProperties(String? businessId) async {
    if (businessId == null || businessId.isEmpty) {
      _properties = [];
      _isLoading = false;
      _hasLoaded = true;
      _error = 'No active business membership';
      _invalidate();
      return;
    }

    if (_isLoading && _lastBusinessId == businessId) return;

    if (_lastBusinessId == businessId &&
        _error == null &&
        _loadedBusinessIds.contains(businessId)) {
      return;
    }

    await _fetch(businessId);
  }

  /// Reloads from the server. If it fails, whatever is on screen stays.
  Future<void> refreshProperties(String? businessId) async {
    if (businessId == null || businessId.isEmpty) {
      await loadProperties(businessId);
      return;
    }
    if (_isLoading && _lastBusinessId == businessId) return;
    await _fetch(businessId);
  }

  Future<void> _fetch(String businessId) async {
    _lastBusinessId = businessId;
    _isLoading = true;
    _error = null;
    _notifyListenersSafe();

    try {
      final all = await _propertyRepository.getPropertiesByBusiness(
        businessId,
      );
      final scope = _propertyScope?.call();
      _properties = scope == null
          ? all
          : [for (final p in all) if (p.id != null && scope.contains(p.id)) p];
      _loadedBusinessIds.add(businessId);
      await _countOccupancy(businessId);
    } catch (e, stack) {
      debugPrint('❌ Error loading properties: $e');
      debugPrint('Stack trace: $stack');
      _error = 'Failed to load properties: ${e.toString()}';
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      _invalidate();
    }
  }

  Future<void> _countOccupancy(String businessId) async {
    final loader = _occupancyLoader;
    if (loader == null) return;
    try {
      _occupied = await loader(businessId);
    } catch (e) {
      debugPrint('⚠️ Could not count beds in use, using stored totals: $e');
      _occupied = null;
    }
  }

  // ─── Controls ───────────────────────────────────────────────────────────

  void updateSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _invalidate();
  }

  void updateStatusFilter(PropertyStatusFilter filter) {
    if (_statusFilter == filter) return;
    _statusFilter = filter;
    _invalidate();
  }

  void updateSortOption(PropertySortOption option) {
    if (_sortOption == option) return;
    _sortOption = option;
    _invalidate();
  }

  void clearError() {
    _error = null;
    _notifyListenersSafe();
  }

  void _invalidate() {
    _filteredCache = null;
    _notifyListenersSafe();
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
}
