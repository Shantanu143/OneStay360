import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:models/business/property/property_model.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:firebase_services/repositories/enrollment_repository.dart';
import 'package:firebase_services/services/firestore_service.dart';

class PGDetailViewModel extends ChangeNotifier {
  final PropertyRepository propertyRepository;
  final EnrollmentRepository enrollmentRepository = EnrollmentRepository();
  final FirestoreService firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Property? _property;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isFavorite = false;
  int _currentImageIndex = 0;
  int _currentTabIndex = 0;
  bool _isSubmittingEnrollment = false;
  XFile? _kycDocument;

  // UPDATED CONSTRUCTOR
  PGDetailViewModel({required this.propertyRepository});

  // Getters
  // Getters
  Property? get property => _property;
  bool get isSubmittingEnrollment => _isSubmittingEnrollment;
  XFile? get kycDocument => _kycDocument;
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
        debugPrint('📍 Property ID: ${_property!.id}');
        debugPrint('📝 Description: ${_property!.description}');
        debugPrint('🏢 Business ID: ${_property!.businessId}');
        debugPrint('📊 Data source: /businesses/${_property!.businessId}/properties/${_property!.id}');
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
    // Primary: business subcollection is source of truth
    final businessProperty = await _findPropertyInBusinessSubcollection(propertyId);
    if (businessProperty != null) return businessProperty;

    // City index is only a reference; if found, try to hop to business doc using businessId
    final cityProperty = await _findPropertyInCityIndex(propertyId);
    if (cityProperty != null) return cityProperty;

    // Legacy root fallback
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
          final data = doc.data()!;
          final businessId = data['businessId']?.toString();

          if (businessId != null && businessId.isNotEmpty) {
            debugPrint('↗️  City doc points to business $businessId, fetching source of truth');
            final bizDoc = await FirebaseFirestore.instance
                .collection('businesses')
                .doc(businessId)
                .collection('properties')
                .doc(propertyId)
                .get();

            if (bizDoc.exists) {
              debugPrint('✅ Loaded business doc via city pointer');
              return Property.fromMap(bizDoc.data()!, bizDoc.id);
            }
          }

          // Fallback to city doc if business doc missing
          debugPrint('⚠️ Using city doc as fallback');
          return Property.fromMap(data, doc.id);
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
    
    // Clean phone number - remove all non-digit and non-plus characters
    String phoneNumber = _property!.businessPhone.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (phoneNumber.isEmpty) {
      debugPrint('Phone number is empty after cleaning');
      return;
    }

    final telUri = Uri(scheme: 'tel', path: phoneNumber);

    try {
      debugPrint('Attempting to call: $phoneNumber');
      debugPrint('Tel URI: $telUri');
      
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      } else {
        // Try with launchUrl without checking canLaunchUrl first
        try {
          await launchUrl(telUri, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('Error launching URL: $e');
        }
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
    final maxSharing = pricing.maxSharing ?? pricing.sharing.length;

    final prices = <int>[];

    for (final entry in pricing.sharing) {
      if (entry.sharing <= 0 || entry.sharing > maxSharing) continue;
      if (entry.nonAc != null && entry.nonAc! > 0) prices.add(entry.nonAc!);
      if (entry.ac != null && entry.ac! > 0) prices.add(entry.ac!);
    }

    // Fallback to legacy fields if sharing list has no values
    if (prices.isEmpty) {
      if (pricing.single > 0) prices.add(pricing.single);
      if (pricing.double > 0) prices.add(pricing.double);
      if (pricing.triple > 0) prices.add(pricing.triple);
    }

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

  /// Get current tenant's profile data
  Future<Map<String, dynamic>?> getCurrentTenantData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final tenantId = await firestoreService.getTenantId(user.uid);
      if (tenantId == null) return null;

      return await firestoreService.getTenantData(tenantId);
    } catch (e) {
      debugPrint('❌ Error getting tenant data: $e');
      return null;
    }
  }

  /// Submit enrollment request with pre-filled tenant data
  Future<bool> submitEnrollmentRequest({
    required DateTime moveInDate,
    String? roomType,
    String? sharingType,
    String? notes,
  }) async {
    try {
      _isSubmittingEnrollment = true;
      notifyListeners();

      if (_property == null) {
        throw Exception('Property data not loaded');
      }

      // Get current tenant data
      final tenantData = await getCurrentTenantData();
      if (tenantData == null) {
        throw Exception('Failed to load tenant data');
      }

      final tenantNameRaw = tenantData['name'];
      final tenantPhoneRaw = tenantData['phone'];
      
      final String tenantName = (tenantNameRaw is String) ? tenantNameRaw : '';
      final String tenantPhone = (tenantPhoneRaw is String) ? tenantPhoneRaw : '';

      if (tenantName.isEmpty || tenantPhone.isEmpty) {
        throw Exception('Tenant name or phone is missing');
      }

      String? kycUrl;
      if (_kycDocument != null) {
        final storageRef = FirebaseStorage.instance.ref();
        final ext = path.extension(_kycDocument!.path);
        final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
        final kycRef = storageRef.child('enrollments/${_auth.currentUser!.uid}/$fileName');
        await kycRef.putFile(File(_kycDocument!.path));
        kycUrl = await kycRef.getDownloadURL();
      }

      // Submit enrollment request
      await enrollmentRepository.submitEnrollmentRequest(
        propertyId: _property!.id!,
        businessId: _property!.businessId,
        tenantName: tenantName,
        tenantPhone: tenantPhone,
        moveInDate: moveInDate,
        propertyName: _property!.name,
        roomType: roomType,
        sharingType: sharingType,
        notes: notes,
        kycDocumentUrl: kycUrl,
      );

      _kycDocument = null; // reset
      debugPrint('✅ Enrollment request submitted successfully');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to submit request: ${e.toString()}';
      debugPrint('❌ Error submitting enrollment: $e');
      return false;
    } finally {
      _isSubmittingEnrollment = false;
      notifyListeners();
    }
  }

  Future<void> pickKycDocument() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        _kycDocument = image;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error picking KYC document: $e');
      _errorMessage = 'Failed to pick image';
      notifyListeners();
    }
  }

  void removeKycDocument() {
    _kycDocument = null;
    notifyListeners();
  }
}


