// lib/presentation/view_models/tenant/explore_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:models/business/property/property_model.dart';
import 'package:firebase_services/repositories/property_repository.dart';

enum ExploreFilter {
  all,
  nearMe,
  underTenK,
  girlsOnly,
  boysOnly,
  furnished,
  verified,
  featured,
}

enum ExploreSortOption {
  relevance,
  priceLowToHigh,
  priceHighToLow,
  rating,
  newest,
  occupancy,
}

class ExploreViewModel extends ChangeNotifier {
  final PropertyRepository propertyRepository; // ADD THIS
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State variables
  List<Property> _properties = [];
  final List<Property> _allProperties = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _hasMoreData = true;
  DocumentSnapshot? _lastDocument;

  // Filter and search state
  String _selectedCity = 'Bangalore';
  String _searchQuery = '';
  ExploreFilter _selectedFilter = ExploreFilter.all;
  ExploreSortOption _sortOption = ExploreSortOption.relevance;

  // Constants
  static const int _pageSize = 10;
  static const List<String> _availableCities = [
    'Bangalore',
    'Mumbai',
    'Delhi',
    'Pune',
    'Hyderabad',
    'Chennai',
    'Kolkata',
    'Ahmedabad',
  ];

  static const List<ExploreFilter> _availableFilters = [
    ExploreFilter.all,
    ExploreFilter.nearMe,
    ExploreFilter.underTenK,
    ExploreFilter.girlsOnly,
    ExploreFilter.boysOnly,
    ExploreFilter.furnished,
    ExploreFilter.verified,
    ExploreFilter.featured,
  ];

  // Getters
  List<Property> get properties => _properties;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  bool get hasMoreData => _hasMoreData;
  String get selectedCity => _selectedCity;
  String get searchQuery => _searchQuery;
  ExploreFilter get selectedFilter => _selectedFilter;
  ExploreSortOption get sortOption => _sortOption;
  List<String> get availableCities => _availableCities;
  List<ExploreFilter> get availableFilters => _availableFilters;
  int get propertyCount => _properties.length;

  // UPDATE CONSTRUCTOR
  ExploreViewModel({required this.propertyRepository}) {
    // Don't load data in constructor - let the screen handle it
    // This prevents errors during provider initialization
  }

  void _loadInitialData() {
    if (_properties.isEmpty) {
      loadProperties(refresh: true);
    }
  }

  // Load properties from Firestore - UPDATED QUERY
  Future<void> loadProperties({bool refresh = false}) async {
    if (refresh) {
      _properties.clear();
      _allProperties.clear();
      _lastDocument = null;
      _hasMoreData = true;
      _hasError = false;
      _errorMessage = '';
    }

    if (_isLoading || !_hasMoreData) return;

    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('🔍 DEBUG: Loading properties for city: $_selectedCity');

      // ✅ UPDATED: Query the correct collection structure
      Query query = _firestore
          .collection('properties_by_city')
          .doc(_selectedCity)
          .collection('properties')
          .where('status', isEqualTo: 'active')
          .orderBy('updatedAt', descending: true)
          .limit(_pageSize);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final QuerySnapshot snapshot = await query.get();
      debugPrint('✅ DEBUG: Found ${snapshot.docs.length} properties in $_selectedCity');

      if (snapshot.docs.isEmpty) {
        _hasMoreData = false;
        debugPrint('ℹ️ DEBUG: No more properties to load');
      } else {
        _lastDocument = snapshot.docs.last;

        final List<Property> newProperties = [];
        for (var doc in snapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            debugPrint('📝 DEBUG: Processing property: ${data['name']} - ID: ${doc.id}');

            final property = Property.fromMap(data, doc.id);
            newProperties.add(property);
          } catch (e) {
            debugPrint('❌ DEBUG: Error parsing property ${doc.id}: $e');
          }
        }

        _allProperties.addAll(newProperties);
        _applyFiltersAndSort();
        debugPrint('🎯 DEBUG: Displaying ${_properties.length} properties after filtering');
      }

      _hasError = false;
      _errorMessage = '';
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      debugPrint('❌ DEBUG: Error loading properties: $e');

      // If city collection doesn't exist, try main properties collection as fallback
      if (e.toString().contains('NOT_FOUND')) {
        debugPrint('🔄 DEBUG: Trying fallback query...');
        await _loadPropertiesFallback();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fallback method to query main properties collection
  Future<void> _loadPropertiesFallback() async {
    try {
      debugPrint('🔄 DEBUG: Loading from main properties collection...');

      Query query = _firestore
          .collection('properties')
          .where('status', isEqualTo: 'active')
          .where('city', isEqualTo: _selectedCity)
          .orderBy('updatedAt', descending: true)
          .limit(_pageSize);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final QuerySnapshot snapshot = await query.get();
      debugPrint('✅ DEBUG: Found ${snapshot.docs.length} properties in fallback query');

      if (snapshot.docs.isEmpty) {
        _hasMoreData = false;
      } else {
        _lastDocument = snapshot.docs.last;

        final List<Property> newProperties = [];
        for (var doc in snapshot.docs) {
          try {
            final property = Property.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            newProperties.add(property);
          } catch (e) {
            debugPrint('❌ DEBUG: Error parsing property ${doc.id}: $e');
          }
        }

        _allProperties.addAll(newProperties);
        _applyFiltersAndSort();
      }
    } catch (e) {
      debugPrint('❌ DEBUG: Fallback query also failed: $e');
      rethrow;
    }
  }

  // Load more properties (pagination)
  Future<void> loadMoreProperties() async {
    if (!_hasMoreData || _isLoading) return;
    await loadProperties();
  }

  // Apply filters and sorting to the loaded properties
  void _applyFiltersAndSort() {
    List<Property> filteredProperties = List.from(_allProperties);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredProperties = filteredProperties.where((property) {
        return property.name.toLowerCase().contains(query) ||
            property.address.toLowerCase().contains(query) ||
            (property.landmarks.toLowerCase().contains(query) ?? false) ||
            property.description.toLowerCase().contains(query);
      }).toList();
    }

    // Apply selected filter
    switch (_selectedFilter) {
      case ExploreFilter.all:
      // No additional filtering
        break;
      case ExploreFilter.nearMe:
      // TODO: Implement location-based filtering
        break;
      case ExploreFilter.underTenK:
        filteredProperties = filteredProperties.where((property) {
          return getMinPrice(property) < 10000;
        }).toList();
        break;
      case ExploreFilter.girlsOnly:
        filteredProperties = filteredProperties.where((property) {
          return property.rules.genderAllowed.toLowerCase() == 'female';
        }).toList();
        break;
      case ExploreFilter.boysOnly:
        filteredProperties = filteredProperties.where((property) {
          return property.rules.genderAllowed.toLowerCase() == 'male';
        }).toList();
        break;
      case ExploreFilter.furnished:
        filteredProperties = filteredProperties.where((property) {
          return property.amenities.ac || property.amenities.geyser;
        }).toList();
        break;
      case ExploreFilter.verified:
      // Assuming all properties in database are verified
        break;
      case ExploreFilter.featured:
        filteredProperties = filteredProperties.where((property) {
          return property.featured;
        }).toList();
        break;
    }

    // Apply sorting
    switch (_sortOption) {
      case ExploreSortOption.relevance:
      // Keep current order (by updatedAt)
        break;
      case ExploreSortOption.priceLowToHigh:
        filteredProperties.sort((a, b) {
          return getMinPrice(a).compareTo(getMinPrice(b));
        });
        break;
      case ExploreSortOption.priceHighToLow:
        filteredProperties.sort((a, b) {
          return getMinPrice(b).compareTo(getMinPrice(a));
        });
        break;
      case ExploreSortOption.rating:
        filteredProperties.sort((a, b) {
          if (a.rating.average != b.rating.average) {
            return b.rating.average.compareTo(a.rating.average);
          }
          return b.rating.count.compareTo(a.rating.count);
        });
        break;
      case ExploreSortOption.newest:
        filteredProperties.sort((a, b) {
          return b.updatedAt.compareTo(a.updatedAt);
        });
        break;
      case ExploreSortOption.occupancy:
        filteredProperties.sort((a, b) {
          final occupancyA = getOccupancyRate(a);
          final occupancyB = getOccupancyRate(b);
          return occupancyB.compareTo(occupancyA);
        });
        break;
    }

    _properties = filteredProperties;
  }

  // Update city filter
  void updateCity(String city) {
    if (_selectedCity != city) {
      _selectedCity = city;
      _properties.clear();
      _allProperties.clear();
      _lastDocument = null;
      _hasMoreData = true;
      notifyListeners();
      loadProperties(refresh: true);
    }
  }

  // Update search query
  void updateSearchQuery(String query) {
    _searchQuery = query;
    _applyFiltersAndSort();
    notifyListeners();
  }

  // Clear search
  void clearSearch() {
    _searchQuery = '';
    _applyFiltersAndSort();
    notifyListeners();
  }

  // Update filter
  void updateFilter(ExploreFilter filter) {
    _selectedFilter = filter;
    _applyFiltersAndSort();
    notifyListeners();
  }

  // Update sort option
  void updateSortOption(ExploreSortOption option) {
    _sortOption = option;
    _applyFiltersAndSort();
    notifyListeners();
  }

  // Reset all filters
  void resetFilters() {
    _selectedFilter = ExploreFilter.all;
    _sortOption = ExploreSortOption.relevance;
    _searchQuery = '';
    _applyFiltersAndSort();
    notifyListeners();
  }

  // Refresh data
  Future<void> refreshData() async {
    await loadProperties(refresh: true);
  }

  // Helper methods
  String getFilterDisplayName(ExploreFilter filter) {
    switch (filter) {
      case ExploreFilter.all:
        return 'All';
      case ExploreFilter.nearMe:
        return 'Near Me';
      case ExploreFilter.underTenK:
        return 'Under ₹10k';
      case ExploreFilter.girlsOnly:
        return 'Girls Only';
      case ExploreFilter.boysOnly:
        return 'Boys Only';
      case ExploreFilter.furnished:
        return 'Furnished';
      case ExploreFilter.verified:
        return 'Verified';
      case ExploreFilter.featured:
        return 'Featured';
    }
  }

  String getGenderText(Property property) {
    final gender = property.rules.genderAllowed.toLowerCase();
    if (gender == 'female') {
      return 'Girls';
    } else if (gender == 'male') {
      return 'Boys';
    } else if (gender == 'co-ed') {
      return 'Mixed';
    } else {
      return property.rules.genderAllowed; // Fallback to original value
    }
  }

  Color getGenderColor(Property property) {
    final gender = property.rules.genderAllowed.toLowerCase();
    if (gender == 'female') {
      return const Color(0xFFFCE4EC); // Pink
    } else if (gender == 'male') {
      return const Color(0xFFE3F2FD); // Blue
    } else if (gender == 'co-ed') {
      return const Color(0xFFF3E5F5); // Purple
    } else {
      return const Color(0xFFF5F5F5); // Default gray
    }
  }

  Color getGenderBorderColor(Property property) {
    final gender = property.rules.genderAllowed.toLowerCase();
    if (gender == 'female') {
      return const Color(0xFFF48FB1); // Pink
    } else if (gender == 'male') {
      return const Color(0xFF90CAF9); // Blue
    } else if (gender == 'co-ed') {
      return const Color(0xFFCE93D8); // Purple
    } else {
      return const Color(0xFFE0E0E0); // Default gray
    }
  }

  Color getGenderTextColor(Property property) {
    final gender = property.rules.genderAllowed.toLowerCase();
    if (gender == 'female') {
      return const Color(0xFFC2185B); // Pink
    } else if (gender == 'male') {
      return const Color(0xFF1976D2); // Blue
    } else if (gender == 'co-ed') {
      return const Color(0xFF7B1FA2); // Purple
    } else {
      return const Color(0xFF616161); // Default gray
    }
  }

  String getPriceRange(Property property) {
    final minPrice = getMinPrice(property);
    final maxPrice = getMaxPrice(property);

    if (minPrice == maxPrice) {
      return '₹$minPrice/month';
    } else {
      return '₹$minPrice-₹$maxPrice/month';
    }
  }

  int getMinPrice(Property property) {
    final prices = <int>[];
    if (property.pricing.single > 0) prices.add(property.pricing.single);
    if (property.pricing.double > 0) prices.add(property.pricing.double);
    if (property.pricing.triple > 0) prices.add(property.pricing.triple);
    return prices.isEmpty ? 0 : prices.reduce((a, b) => a < b ? a : b);
  }

  int getMaxPrice(Property property) {
    final prices = <int>[];
    if (property.pricing.single > 0) prices.add(property.pricing.single);
    if (property.pricing.double > 0) prices.add(property.pricing.double);
    if (property.pricing.triple > 0) prices.add(property.pricing.triple);
    return prices.isEmpty ? 0 : prices.reduce((a, b) => a > b ? a : b);
  }

  double getOccupancyRate(Property property) {
    if (property.totals.beds == 0) return 0.0;
    final occupiedBeds = property.totals.beds - property.totals.availableBeds;
    return occupiedBeds / property.totals.beds;
  }

  // Add this temporary debug method
  Future<void> debugCheckFirestoreStructure() async {
    try {
      debugPrint('🔍 DEBUG: Checking Firestore structure...');

      // Check properties_by_city
      final cities = ['Bangalore', 'Pune', 'Mumbai'];
      for (final city in cities) {
        final cityDoc = await _firestore
            .collection('properties_by_city')
            .doc(city)
            .get();

        if (cityDoc.exists) {
          final propertiesSnapshot = await _firestore
              .collection('properties_by_city')
              .doc(city)
              .collection('properties')
              .limit(1)
              .get();

          debugPrint('🏙️ $city: ${propertiesSnapshot.docs.length} properties in properties_by_city');
        } else {
          debugPrint('❌ $city: properties_by_city document does not exist');
        }
      }

      // Check main properties collection
      final mainProperties = await _firestore
          .collection('properties')
          .limit(1)
          .get();

      debugPrint('📊 Main properties collection: ${mainProperties.docs.length} properties');

    } catch (e) {
      debugPrint('❌ DEBUG: Error checking Firestore structure: $e');
    }
  }
}

