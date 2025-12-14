// cursor test

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:models/business/property/property_model.dart';
import 'package:firebase_services/repositories/property_repository.dart'; // ADDED IMPORT

class PGDetailViewModel extends ChangeNotifier {
  final PropertyRepository propertyRepository; // ADDED
  Property? _property;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isFavorite = false;
  int _currentImageIndex = 0;
  int _currentTabIndex = 0;

  // UPDATED CONSTRUCTOR
  PGDetailViewModel({required this.propertyRepository});

  // Getters
  Property? get property => _property;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  bool get isFavorite => _isFavorite;
  int get currentImageIndex => _currentImageIndex;
  int get currentTabIndex => _currentTabIndex;

  // Load property details from multiple possible locations
  Future<void> loadPropertyDetails(String propertyId) async {
    if (_isLoading) return;

    _setLoading(true);
    _hasError = false;
    _errorMessage = '';

    try {
      debugPrint('🔄 Loading property details for ID: $propertyId');

      // Try multiple possible locations for the property
      final property = await _findPropertyInAllLocations(propertyId);

      if (property != null) {
        _property = property;
        _checkIfFavorite();
        debugPrint('✅ Successfully loaded property: ${_property!.name}');
      } else {
        _hasError = true;
        _errorMessage = 'Property not found in any location';
        debugPrint('❌ Property not found in any location');
      }
    } catch (e) {
      _hasError = true;
      _errorMessage = 'Failed to load property details: ${e.toString()}';
      debugPrint('❌ Error loading property: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Search for property in all possible Firestore locations
  Future<Property?> _findPropertyInAllLocations(String propertyId) async {
    // Try primary location: /businesses/{businessId}/properties/{propertyId}
    final property = await _findPropertyInBusinessSubcollection(propertyId);
    if (property != null) return property;

    // Try city index: /properties_by_city/{city}/properties/{propertyId}
    final cityProperty = await _findPropertyInCityIndex(propertyId);
    if (cityProperty != null) return cityProperty;

    // Try root collection (legacy): /properties/{propertyId}
    final rootProperty = await _findPropertyInRoot(propertyId);
    if (rootProperty != null) return rootProperty;

    return null;
  }

  Future<Property?> _findPropertyInBusinessSubcollection(String propertyId) async {
    try {
      debugPrint('🔍 Searching in business subcollections...');

      // Extract business ID from property ID (BUS0000001PNR001 -> BUS0000001)
      final businessId = _extractBusinessId(propertyId);
      if (businessId == null) {
        debugPrint('❌ Could not extract business ID from property ID');
        return null;
      }

      debugPrint('🏢 Looking in business: $businessId');
      final doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('properties')
          .doc(propertyId)
          .get();

      if (doc.exists) {
        debugPrint('✅ Found in business subcollection');
        return Property.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      debugPrint('❌ Error searching business subcollection: $e');
    }
    return null;
  }

  Future<Property?> _findPropertyInCityIndex(String propertyId) async {
    try {
      debugPrint('🔍 Searching in city index...');

      // Try common cities first
      final cities = ['Pune', 'Bangalore', 'Mumbai', 'Delhi', 'Hyderabad'];

      for (final city in cities) {
        debugPrint('🏙️ Checking city: $city');
        final doc = await FirebaseFirestore.instance
            .collection('properties_by_city')
            .doc(city)
            .collection('properties')
            .doc(propertyId)
            .get();

        if (doc.exists) {
          debugPrint('✅ Found in city: $city');
          return Property.fromMap(doc.data()!, doc.id);
        }
      }
    } catch (e) {
      debugPrint('❌ Error searching city index: $e');
    }
    return null;
  }

  Future<Property?> _findPropertyInRoot(String propertyId) async {
    try {
      debugPrint('🔍 Searching in root collection...');
      final doc = await FirebaseFirestore.instance
          .collection('properties')
          .doc(propertyId)
          .get();

      if (doc.exists) {
        debugPrint('✅ Found in root collection');
        return Property.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      debugPrint('❌ Error searching root collection: $e');
    }
    return null;
  }

  String? _extractBusinessId(String propertyId) {
    try {
      // Extract business ID from property ID format: BUS0000001PNR001
      // Business ID is the first part before the city code
      if (propertyId.length >= 11) {
        return propertyId.substring(0, 11); // BUS0000001
      }
    } catch (e) {
      debugPrint('Error extracting business ID: $e');
    }
    return null;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _checkIfFavorite() {
    // TODO: Implement actual favorite check from Firestore
    _isFavorite = false;
    notifyListeners();
  }

  // Image carousel methods
  void updateImageIndex(int index) {
    if (_currentImageIndex != index) {
      _currentImageIndex = index;
      notifyListeners();
    }
  }

  // Tab methods
  void updateTabIndex(int index) {
    if (_currentTabIndex != index) {
      _currentTabIndex = index;
      notifyListeners();
    }
  }

  // Favorite methods
  Future<void> toggleFavorite() async {
    if (_property == null) return;

    HapticFeedback.lightImpact();
    _isFavorite = !_isFavorite;
    notifyListeners();

    // TODO: Implement actual favorite persistence
    try {
      // await _favoriteService.toggleFavorite(_property!.id, _isFavorite);
    } catch (e) {
      // Revert on error
      _isFavorite = !_isFavorite;
      notifyListeners();
      debugPrint('Error toggling favorite: $e');
    }
  }

  // Share property
  void shareProperty() {
    if (_property == null) return;

    HapticFeedback.lightImpact();
    final shareText = '''
Check out ${_property!.name}!

📍 Location: ${_property!.address}
⭐ Rating: ${_property!.rating.average.toStringAsFixed(1)}/5
💰 Starting from: ${getPriceRange()}
🏠 Rooms: ${_property!.totals.rooms}
🛏️ Available Beds: ${_property!.totals.availableBeds}

Find your perfect PG with OneStay360!
    '''.trim();

    debugPrint('Sharing: $shareText');
    // TODO: Implement share_plus
  }

  // Phone call
  Future<void> makeCall() async {
    if (_property == null || _property!.businessPhone.isEmpty) return;

    HapticFeedback.lightImpact();
    final phoneUrl = 'tel:${_property!.businessPhone}';

    try {
      if (await canLaunchUrl(Uri.parse(phoneUrl))) {
        await launchUrl(Uri.parse(phoneUrl));
      } else {
        throw 'Could not launch $phoneUrl';
      }
    } catch (e) {
      debugPrint('Error making call: $e');
    }
  }

  // Google Maps
  Future<void> openGoogleMaps() async {
    if (_property == null) return;

    HapticFeedback.lightImpact();
    final address = Uri.encodeComponent(_property!.address);
    final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$address';

    try {
      if (await canLaunchUrl(Uri.parse(mapsUrl))) {
        await launchUrl(Uri.parse(mapsUrl));
      } else {
        throw 'Could not launch $mapsUrl';
      }
    } catch (e) {
      debugPrint('Error opening maps: $e');
    }
  }

  // Gender helper methods
  Color getGenderColor() {
    if (_property == null) return Colors.grey.withAlpha((0.1 * 255).round());

    switch (_property!.rules.genderAllowed.toLowerCase()) {
      case 'male':
        return Colors.blue.withAlpha((0.1 * 255).round());
      case 'female':
        return Colors.pink.withAlpha((0.1 * 255).round());
      case 'both':
      case 'co-ed':
        return Colors.purple.withAlpha((0.1 * 255).round());
      default:
        return Colors.grey.withAlpha((0.1 * 255).round());
    }
  }

  Color getGenderBorderColor() {
    if (_property == null) return Colors.grey.withAlpha((0.3 * 255).round());

    switch (_property!.rules.genderAllowed.toLowerCase()) {
      case 'male':
        return Colors.blue.withAlpha((0.3 * 255).round());
      case 'female':
        return Colors.pink.withAlpha((0.3 * 255).round());
      case 'both':
      case 'co-ed':
        return Colors.purple.withAlpha((0.3 * 255).round());
      default:
        return Colors.grey.withAlpha((0.3 * 255).round());
    }
  }

  Color getGenderTextColor() {
    if (_property == null) return Colors.grey[700]!;

    switch (_property!.rules.genderAllowed.toLowerCase()) {
      case 'male':
        return Colors.blue[700]!;
      case 'female':
        return Colors.pink[700]!;
      case 'both':
      case 'co-ed':
        return Colors.purple[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  String getGenderText() {
    if (_property == null) return 'N/A';

    switch (_property!.rules.genderAllowed.toLowerCase()) {
      case 'male':
        return 'Boys Only';
      case 'female':
        return 'Girls Only';
      case 'both':
      case 'co-ed':
        return 'Co-ed';
      default:
        return _property!.rules.genderAllowed;
    }
  }

  // Occupancy helper
  String getOccupancyText() {
    if (_property == null) return '0%';

    final total = _property!.totals.beds;
    final occupied = total - _property!.totals.availableBeds;
    final percentage = total > 0 ? ((occupied / total) * 100).round() : 0;

    return '$percentage%';
  }

  // Price range helper
  String getPriceRange() {
    if (_property == null) return '₹0';

    final pricing = _property!.pricing;
    final prices = <int>[];

    if (pricing.single > 0) prices.add(pricing.single);
    if (pricing.double > 0) prices.add(pricing.double);
    if (pricing.triple > 0) prices.add(pricing.triple);

    if (prices.isEmpty) return '₹0';

    prices.sort();
    final minPrice = prices.first;
    final maxPrice = prices.last;

    if (minPrice == maxPrice) {
      return '₹${_formatPrice(minPrice)}';
    } else {
      return '₹${_formatPrice(minPrice)} - ₹${_formatPrice(maxPrice)}';
    }
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  // Amenities list
  List<Map<String, dynamic>> getAmenityList() {
    if (_property == null) return [];

    return [
      {'icon': Icons.wifi, 'name': 'WiFi', 'available': _property!.amenities.wifi},
      {'icon': Icons.ac_unit, 'name': 'AC', 'available': _property!.amenities.ac},
      {'icon': Icons.local_laundry_service, 'name': 'Laundry', 'available': _property!.amenities.laundry},
      {'icon': Icons.local_parking, 'name': 'Parking', 'available': _property!.amenities.parking},
      {'icon': Icons.power, 'name': 'Power Backup', 'available': _property!.amenities.powerBackup},
      {'icon': Icons.restaurant, 'name': 'Food Included', 'available': _property!.amenities.foodIncluded},
      {'icon': Icons.cleaning_services, 'name': 'Housekeeping', 'available': _property!.amenities.housekeeping},
      {'icon': Icons.hot_tub, 'name': 'Geyser', 'available': _property!.amenities.geyser},
      {'icon': Icons.security, 'name': 'CCTV', 'available': _property!.amenities.cctv},
    ];
  }

  // House rules
  List<String> getHouseRules() {
    if (_property == null) return [];

    final rules = <String>[];
    final propertyRules = _property!.rules;

    rules.add('Gender: ${propertyRules.genderAllowed}');
    rules.add('Smoking: ${propertyRules.smokingAllowed ? 'Allowed' : 'Not Allowed'}');
    rules.add('Alcohol: ${propertyRules.alcoholAllowed ? 'Allowed' : 'Not Allowed'}');
    rules.add('Visitors: ${propertyRules.visitorsAllowed ? 'Allowed' : 'Not Allowed'}');

    if (propertyRules.curfew) {
      rules.add('Curfew: Yes');
    }

    rules.add('Notice Period: ${propertyRules.noticePeriodDays} days');

    return rules;
  }

  // Food plan text
  String getFoodPlanText() {
    if (_property == null || _property!.foodPlan == null) return 'No food plan available';

    final foodPlan = _property!.foodPlan!;
    final meals = <String>[];

    if (foodPlan.plan['breakfast'] == true) meals.add('Breakfast');
    if (foodPlan.plan['lunch'] == true) meals.add('Lunch');
    if (foodPlan.plan['dinner'] == true) meals.add('Dinner');

    if (meals.isEmpty) return 'No meals included';

    String result = meals.join(', ');
    if (foodPlan.notes.isNotEmpty == true) {
      result += '\n${foodPlan.notes}';
    }

    return result;
  }

  // Location details
  String getLocationDetails() {
    if (_property == null) return '';

    final details = <String>[];
    details.add(_property!.address);
    details.add('${_property!.city} (${_property!.cityCode})');

    if (_property!.landmarks.isNotEmpty) {
      details.add('Near: ${_property!.landmarks}');
    }

    return details.join('\n');
  }

  // Contact details
  String getContactDetails() {
    if (_property == null) return '';

    final details = <String>[];
    details.add('Business: ${_property!.businessName}');
    details.add('Phone: ${_property!.businessPhone}');
    details.add('Address: ${_property!.address}');
    details.add('City: ${_property!.city}');

    return details.join('\n');
  }

  // Room types for pricing
  List<Map<String, dynamic>> getRoomTypes() {
    if (_property == null) return [];

    final roomTypes = <Map<String, dynamic>>[];
    final pricing = _property!.pricing;

    if (pricing.single > 0) {
      roomTypes.add({
        'type': 'Single Occupancy',
        'price': pricing.single,
        'icon': Icons.person,
        'description': 'Private room for one person',
      });
    }

    if (pricing.double > 0) {
      roomTypes.add({
        'type': 'Double Sharing',
        'price': pricing.double,
        'icon': Icons.people,
        'description': 'Shared room for two people',
      });
    }

    if (pricing.triple > 0) {
      roomTypes.add({
        'type': 'Triple Sharing',
        'price': pricing.triple,
        'icon': Icons.groups,
        'description': 'Shared room for three people',
      });
    }

    return roomTypes;
  }

  // Payment terms
  String getPaymentTerms() {
    if (_property == null) return '';

    final terms = <String>[];
    final pricing = _property!.pricing;

    terms.add('Security Deposit: ₹${_formatPrice(pricing.securityDeposit)}');
    terms.add('One-time Maintenance: ₹${_formatPrice(pricing.oneTimeMaintenance)}');
    terms.add('Notice Period: ${_property!.rules.noticePeriodDays} days');

    if (pricing.maintenanceDeductedFromDeposit) {
      terms.add('Maintenance charges will be deducted from security deposit');
    }

    return terms.join('\n');
  }
}

