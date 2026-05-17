import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:models/business/property/property_model.dart';
import 'package:models/tenant/tenant_request_model.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:firebase_services/services/property_room_service.dart';
import 'package:models/business/property/property_room_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewPropertyViewModel extends ChangeNotifier {
  final PropertyRepository _propertyRepository;
  final PropertyRoomService _roomService;

  Property? _property;
  bool _isLoading = true;
  String? _error;
  final bool _isActivating = false;
  String? _activationError;
  String? _unpaidInvoiceId;
  Map<String, dynamic>? _latestQuote;
  List<dynamic> _filteredTenants = [];
  String _searchQuery = '';
  int _currentTabIndex = 0;

  // Payments
  final List<Map<String, dynamic>> _payments = [];
  bool _paymentsLoading = false;
  String? _paymentsError;

  // Request-related properties
  final List<TenantRequest> _requests = [];
  bool _requestsLoading = false;
  String? _requestsError;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _requestsSubscription;

  ViewPropertyViewModel({
    required PropertyRepository propertyRepository,
    PropertyRoomService? roomService,
  }) : _propertyRepository = propertyRepository,
       _roomService = roomService ?? PropertyRoomService();

  List<PropertyRoom>? _roomsFromSubcollection;
  final Map<String, Map<String, dynamic>> _bedsCache = {}; // roomId -> beds map

  // Getters
  Property? get property => _property;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isActivating => _isActivating;
  String? get activationError => _activationError;
  String? get unpaidInvoiceId => _unpaidInvoiceId;
  Map<String, dynamic>? get latestQuote => _latestQuote;
  bool get hasError => _error != null;
  List<dynamic> get filteredTenants => _filteredTenants;
  String get searchQuery => _searchQuery;
  int get currentTabIndex => _currentTabIndex;
  List<Map<String, dynamic>> get payments => _payments;
  bool get paymentsLoading => _paymentsLoading;
  String? get paymentsError => _paymentsError;

  // Analytics properties
  double _collectedRentCurrentMonth = 0.0;
  double get collectedRentCurrentMonth => _collectedRentCurrentMonth;

  // Request-related getters
  int get pendingRequestsCount => _requests.where((r) => r.status == 'pending').length;
  bool get requestsLoading => _requestsLoading;
  String? get requestsError => _requestsError;
  List<TenantRequest> get requests => _requests;

  // Property statistics calculations
  Map<String, dynamic> get propertyStats {
    if (_property == null) return {};

    final floors = getFloorsFromProperty();
    int totalRooms = 0;
    int occupiedRooms = 0;
    int totalBeds = 0;
    int occupiedBeds = 0;
    double monthlyRevenue = 0;
    double pendingPayments = 0;

    for (final floor in floors) {
      final rooms = floor['rooms'] as List<dynamic>? ?? [];
      totalRooms += rooms.length;

      for (final room in rooms) {
        final beds = room['beds'] as List<dynamic>? ?? [];
        totalBeds += beds.length;

        bool roomOccupied = false;
        for (final bed in beds) {
          if (bed['isOccupied'] == true) {
            occupiedBeds++;
            roomOccupied = true;
            // Calculate revenue from occupied beds
            final rent = (room['rent'] as num?)?.toDouble() ?? 0;
            monthlyRevenue += rent;
          }
        }
        if (roomOccupied) occupiedRooms++;
      }
    }

    // Calculate occupancy rate
    final occupancyRate = totalBeds > 0 ? occupiedBeds / totalBeds : 0.0;

    return {
      'totalRooms': totalRooms,
      'occupiedRooms': occupiedRooms,
      'totalBeds': totalBeds,
      'occupiedBeds': occupiedBeds,
      'occupancyRate': occupancyRate,
      'monthlyRevenue': monthlyRevenue,
      'pendingPayments': pendingPayments,
    };
  }

  // Financial calculations
  Map<String, dynamic> get financials {
    final stats = propertyStats;
    final monthlyRevenue = (stats['monthlyRevenue'] as double?) ?? 0;
    const expenses = 45000.0; // Fixed expenses for now
    final pendingPayments = (stats['pendingPayments'] as double?) ?? 0;
    final netIncome = monthlyRevenue - expenses;

    return {
      'monthlyRevenue': monthlyRevenue,
      'yearlyRevenue': monthlyRevenue * 12,
      'pendingPayments': pendingPayments,
      'expenses': expenses,
      'netIncome': netIncome,
    };
  }

  // Load property data (using actual Firestore)
  Future<void> loadProperty(String propertyId) async {
    if (propertyId.isEmpty) {
      _error = 'Property ID cannot be empty';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    _latestQuote = null;
    notifyListeners();

    try {
      debugPrint('🔄 Loading property data for: $propertyId');

      _property = await _propertyRepository.getPropertyById(propertyId);
      _unpaidInvoiceId = null;
        _payments.clear();

      // Try to load rooms from subcollection (compatibility helper)
      try {
        _roomsFromSubcollection = await _roomService.getRoomsForProperty(_property!.businessId, _property!.id!);
        if (_roomsFromSubcollection != null && _roomsFromSubcollection!.isNotEmpty) {
          debugPrint('✅ Loaded ${_roomsFromSubcollection!.length} rooms from rooms subcollection');
          
          // Load beds for each room
          for (final room in _roomsFromSubcollection!) {
            try {
              final beds = await _roomService.getBedsForRoom(
                _property!.businessId,
                _property!.id!,
                room.roomNumber,
              );
              if (beds.isNotEmpty) {
                _bedsCache[room.roomNumber] = beds;
                debugPrint('✅ Loaded ${beds.length} beds for room ${room.roomNumber}');
              }
            } catch (e) {
              debugPrint('⚠️ Error loading beds for room ${room.roomNumber}: $e');
            }
          }
        } else {
          _roomsFromSubcollection = null;
        }
      } catch (e) {
        _roomsFromSubcollection = null;
      }

      if (_property == null) {
        _error = 'Property not found';
      } else {
        debugPrint('✅ Successfully loaded property: ${_property!.name}');
        _updateFilteredTenants();
        await _loadUnpaidInvoiceIfNeeded();
        await _loadPaymentHistory();
        await _calculateAnalytics();
      }
    } catch (e, stack) {
      debugPrint('❌ Error loading property: $e');
      debugPrint('Stack trace: $stack');
      _error = 'Failed to load property: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUnpaidInvoiceIfNeeded() async {
    if (_property == null) return;
    final status = _property!.billingStatus;
    debugPrint('🔍 _loadUnpaidInvoiceIfNeeded: billingStatus=$status');
    if (status == 'due' || status == 'grace' || status == 'past_due') {
      try {
        debugPrint('🔄 Fetching unpaid invoice for propertyId=${_property!.id}');
        _unpaidInvoiceId = await _propertyRepository.getUnpaidInvoiceId(
          businessId: _property!.businessId,
          propertyId: _property!.id!,
        );
        debugPrint('✅ Got unpaidInvoiceId: $_unpaidInvoiceId');
      } catch (e) {
        debugPrint('❌ Error getting unpaid invoice: $e');
        _unpaidInvoiceId = null;
      }
      notifyListeners();
    }
  }

  Future<void> _loadPaymentHistory() async {
    if (_property == null) return;
    final businessId = _property!.businessId;
    final propertyId = _property!.id;
    if (businessId.isEmpty || propertyId == null) return;

    _paymentsLoading = true;
    _paymentsError = null;
    notifyListeners();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('payments_to_onestay360')
          .where('propertyId', isEqualTo: propertyId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      _payments
        ..clear()
        ..addAll(snap.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }));
    } catch (e) {
      _paymentsError = 'Failed to load payments: $e';
    } finally {
      _paymentsLoading = false;
      notifyListeners();
    }
  }

  Future<void> _calculateAnalytics() async {
    if (_property == null) return;
    final businessId = _property!.businessId;
    final propertyId = _property!.id;
    if (businessId.isEmpty || propertyId == null) return;

    try {
      final now = DateTime.now();
      final monthString = '${now.month.toString().padLeft(2, '0')}-${now.year}';
      
      final paymentsSnap = await FirebaseFirestore.instance
          .collectionGroup('payments')
          .where('businessId', isEqualTo: businessId)
          .where('propertyId', isEqualTo: propertyId)
          .where('status', isEqualTo: 'paid')
          .where('month', isEqualTo: monthString)
          .get();

      _collectedRentCurrentMonth = paymentsSnap.docs.fold(0.0, (sum, doc) {
        final amount = (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
        return sum + amount;
      });
      notifyListeners();
    } catch (e) {
      debugPrint('Error calculating analytics: $e');
    }
  }

  /// Listen to real enrollment requests for this property
  void listenRequests(String propertyId) {
    if (propertyId.isEmpty) return;

    _requestsLoading = true;
    _requestsError = null;
    notifyListeners();

    _requestsSubscription?.cancel();

    try {
      _requestsSubscription = FirebaseFirestore.instance
          .collection('enrollmentRequests')
          .where('propertyId', isEqualTo: propertyId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        _requests
          ..clear()
          ..addAll(snapshot.docs.map(
            (doc) => TenantRequest.fromMap(doc.data(), doc.id),
          ));

        _requestsLoading = false;
        _requestsError = null;
        notifyListeners();
      }, onError: (error) {
        _requestsLoading = false;
        _requestsError = 'Failed to load requests: $error';
        notifyListeners();
      });
    } catch (e) {
      _requestsLoading = false;
      _requestsError = 'Error setting up requests listener: $e';
      notifyListeners();
    }
  }

  // Dispose method to cancel subscriptions
  @override
  void dispose() {
    _requestsSubscription?.cancel();
    super.dispose();
  }

  // Update search query for tenants
  void updateSearchQuery(String query) {
    _searchQuery = query;
    _updateFilteredTenants();
    notifyListeners();
  }

  // Update current tab
  void updateTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  // Refresh property data
  Future<void> refreshProperty(String propertyId) async {
    await loadProperty(propertyId);
  }

  // Step 2: confirm Razorpay payment and activate
  Future<Map<String, dynamic>?> confirmActivationPayment({
    required String orderId,
    required String paymentId,
    required String razorpaySignature,
  }) async {
    if (_property == null || _property!.id == null) {
      _activationError = 'Property not loaded';
      notifyListeners();
      return null;
    }

    _activationError = null;
    notifyListeners();

    final result = await _propertyRepository.confirmActivationPayment(
      orderId: orderId,
      paymentId: paymentId,
      razorpaySignature: razorpaySignature,
    );

    // Refresh property to reflect activation state
    await loadProperty(_property!.id!);
    return result;
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Get floors data from property
  List<Map<String, dynamic>> getFloorsFromProperty() {
    if (_property == null) return [];
    // Prefer rooms from rooms subcollection when available
    final rooms = (_roomsFromSubcollection != null && _roomsFromSubcollection!.isNotEmpty)
        ? _roomsFromSubcollection!
        : _property!.rooms;
    final floors = <Map<String, dynamic>>[];

    // Group rooms by floor
    final roomsByFloor = <String, List<dynamic>>{};
    for (final room in rooms) {
      final floor = room.floor;
      if (!roomsByFloor.containsKey(floor)) {
        roomsByFloor[floor] = [];
      }
      roomsByFloor[floor]!.add(room);
    }

    // Sort floors numerically
    final sortedFloorKeys = roomsByFloor.keys.toList()
        ..sort((a, b) {
          final floorA = int.tryParse(a) ?? 0;
          final floorB = int.tryParse(b) ?? 0;
          return floorA.compareTo(floorB);
        });

    // Convert to floor structure with beds
    for (final floorKey in sortedFloorKeys) {
      final entry = roomsByFloor[floorKey]!;
      final floorRooms = <Map<String, dynamic>>[];

      for (final room in entry) {
        final beds = <Map<String, dynamic>>[];
        final sharingType = room.sharingType ?? 1;

        // Use real bed data from Firebase if available (loaded in loadProperty)
        final cachedBeds = _bedsCache[room.roomNumber];
        if (cachedBeds != null && cachedBeds.isNotEmpty) {
          // Use actual bed data from Firebase
          cachedBeds.forEach((bedId, bedData) {
            beds.add({
              'id': bedId,
              'bedNumber': bedData['bedNumber'] ?? bedId,
              'isOccupied': bedData['isOccupied'] ?? false,
              'tenantName': bedData['tenantName'],
              'tenantId': bedData['tenantId'],
              'occupiedAt': bedData['occupiedAt'],
            });
          });
        } else {
          // Fallback: Create bed entries based on sharing type if no real data
          for (int i = 1; i <= sharingType; i++) {
            beds.add({
              'id': 'b$i',
              'bedNumber': i.toString(),
              'isOccupied': false,
              'tenantName': null,
              'tenantId': null,
              'occupiedAt': null,
            });
          }
        }

        floorRooms.add({
          'id': room.roomNumber,
          'number': room.roomNumber,
          'type': _getRoomType(sharingType),
          'rent': _calculateRent(room, sharingType),
          'beds': beds,
          'status': room.status,
          'gender': room.gender ?? 'Co-ed',
          'hasAC': room.hasAC,
          'occupancyType': room.occupancyType,
          'sharingType': sharingType,
        });
      }

      floors.add({
        'floorNumber': int.tryParse(floorKey) ?? 1,
        'rooms': floorRooms,
      });
    }

    // Sort floors in ascending order (ground floor first)
    floors.sort((a, b) => (a['floorNumber'] as int).compareTo(b['floorNumber'] as int));

    return floors;
  }

  // Get tenants data from property (based on occupied rooms)
  Future<List<Map<String, dynamic>>> _getTenantsFromPropertyAsync() async {
    if (_property == null) return [];

    final tenants = <Map<String, dynamic>>[];
    final floors = getFloorsFromProperty();

    // First, try to get real tenants from occupied beds
    for (final floor in floors) {
      final rooms = floor['rooms'] as List<dynamic>;
      for (final room in rooms) {
        // Check beds for actual tenant data
        final beds = room['beds'] as List<dynamic>? ?? [];
        for (final bed in beds) {
          final bedMap = bed as Map<String, dynamic>;
          if (bedMap['isOccupied'] == true && bedMap['tenantId'] != null) {
            try {
              // Fetch full tenant data from Firestore
              final tenantDoc = await FirebaseFirestore.instance
                  .collection('businesses')
                  .doc(_property!.businessId)
                  .collection('tenants')
                  .doc(bedMap['tenantId'])
                  .get();

              if (tenantDoc.exists) {
                final tenantData = tenantDoc.data()!;
                tenants.add({
                  'id': tenantData['id'] ?? bedMap['tenantId'] ?? 'unknown',
                  'tenantId': tenantData['tenantId'] ?? bedMap['tenantId'] ?? 'unknown',
                  'businessId': _property!.businessId,
                  'propertyId': _property!.id,
                  'roomId': room['id'],
                  'bedId': bedMap['id'] ?? bedMap['bedNumber'],
                  'name': tenantData['name'] ?? bedMap['tenantName'] ?? 'Unknown Tenant',
                  'phone': tenantData['phone'] ?? 'Not provided',
                  'email': tenantData['email'] ?? 'Not provided',
                  'room': room['number'],
                  'bed': bedMap['bedNumber'] ?? 'Unknown',
                  'rent': tenantData['monthlyRent'] ?? room['rent'],
                  'joinDate': tenantData['checkInDate'] ?? bedMap['occupiedAt'] ?? 'Not recorded',
                  'lastPayment': tenantData['lastPaymentDate'] ?? 'No payment',
                  'status': tenantData['status']?.toString().replaceFirst(tenantData['status'].toString()[0], tenantData['status'].toString()[0].toUpperCase()) ?? 'Active',
                });
              }
            } catch (e) {
              print('Error fetching tenant data: $e');
              // Fallback to bed data if fetch fails
              tenants.add({
                'id': bedMap['tenantId'] ?? 'unknown',
                'tenantId': bedMap['tenantId'] ?? 'unknown',
                'businessId': _property!.businessId,
                'propertyId': _property!.id,
                'roomId': room['id'],
                'bedId': bedMap['id'] ?? bedMap['bedNumber'],
                'name': bedMap['tenantName'] ?? 'Unknown Tenant',
                'phone': 'Not provided',
                'room': room['number'],
                'bed': bedMap['bedNumber'] ?? 'Unknown',
                'rent': room['rent'],
                'joinDate': bedMap['occupiedAt'] ?? 'Not recorded',
                'lastPayment': 'No payment',
                'status': 'Active',
              });
            }
          }
        }
      }
    }


    return tenants;
  }

  // Get tenants data from property (synchronous version - returns cached data)
  List<Map<String, dynamic>> _getTenantsFromProperty() {
    if (_property == null) return [];

    final tenants = <Map<String, dynamic>>[];
    final floors = getFloorsFromProperty();

    // Get tenants from occupied beds (using cached data)
    for (final floor in floors) {
      final rooms = floor['rooms'] as List<dynamic>;
      for (final room in rooms) {
        final beds = room['beds'] as List<dynamic>? ?? [];
        for (final bed in beds) {
          final bedMap = bed as Map<String, dynamic>;
          if (bedMap['isOccupied'] == true && bedMap['tenantId'] != null) {
            tenants.add({
              'id': bedMap['tenantId'] ?? 'unknown',
              'tenantId': bedMap['tenantId'] ?? 'unknown',
              'businessId': _property!.businessId,
              'propertyId': _property!.id,
              'roomId': room['id'],
              'bedId': bedMap['id'] ?? bedMap['bedNumber'],
              'name': bedMap['tenantName'] ?? 'Unknown Tenant',
              'phone': bedMap['tenantPhone'] ?? 'Not provided',
              'email': bedMap['tenantEmail'] ?? 'Not provided',
              'room': room['number'],
              'bed': bedMap['bedNumber'] ?? 'Unknown',
              'rent': room['rent'],
              'joinDate': bedMap['occupiedAt'] ?? 'Not recorded',
              'lastPayment': bedMap['lastPaymentDate'] ?? 'No payment',
              'status': 'Active',
            });
          }
        }
      }
    }


    return tenants;
  }

  // Update filtered tenants based on search query
  void _updateFilteredTenants() {
    _updateFilteredTenantsAsync();
  }

  Future<void> _updateFilteredTenantsAsync() async {
    // Try async version first to get real tenant data
    final tenants = await _getTenantsFromPropertyAsync();

    if (_searchQuery.isEmpty) {
      _filteredTenants = tenants;
    } else {
      _filteredTenants = tenants.where((tenant) {
        final name = (tenant['name'] ?? '').toString().toLowerCase();
        final room = (tenant['room'] ?? '').toString().toLowerCase();
        final phone = (tenant['phone'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery.toLowerCase()) ||
            room.contains(_searchQuery.toLowerCase()) ||
            phone.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    notifyListeners();
  }

  // Helper methods
  String _getRoomType(int sharingType) {
    return switch (sharingType) {
      1 => 'Single',
      2 => 'Double',
      3 => 'Triple',
      _ => '$sharingType-Sharing',
    };
  }

  int _calculateRent(dynamic room, int sharingType) {
    // Try to get rent from pricing.sharing array first (new format)
    if (_property != null && _property!.pricing.sharing.isNotEmpty) {
      try {
        final pricingEntry = _property!.pricing.sharing
            .firstWhere((entry) => entry.sharing == sharingType);
        
        final hasAC = room.hasAC ?? false;
        final price = hasAC ? pricingEntry.ac : pricingEntry.nonAc;
        if (price != null && price > 0) {
          return price;
        }
            } catch (e) {
        // Sharing type not found in pricing array, try last entry as fallback
        if (_property!.pricing.sharing.isNotEmpty) {
          final lastEntry = _property!.pricing.sharing.last;
          final hasAC = room.hasAC ?? false;
          final price = hasAC ? lastEntry.ac : lastEntry.nonAc;
          if (price != null && price > 0) {
            return price;
          }
        }
      }
    }

    // Fallback to legacy pricing fields
    final baseRent = switch (sharingType) {
      1 => _property?.pricing.single ?? 8500,
      2 => _property?.pricing.double ?? 6500,
      3 => _property?.pricing.triple ?? 5500,
      _ => 5000,
    };

    return baseRent;
  }

  String _getRandomTenantName() {
    final names = [
      'Alex Johnson', 'Mike Wilson', 'Sarah Davis', 'Tom Brown',
      'John Doe', 'Jane Smith', 'Bob Wilson', 'Alice Brown',
      'Charlie Davis', 'David Lee', 'Emma Wilson', 'James Taylor',
      'Lisa Garcia', 'Mark Johnson', 'Nina Rodriguez', 'Paul Anderson',
      'Rachel White'
    ];
    final roomsCount = (_roomsFromSubcollection != null && _roomsFromSubcollection!.isNotEmpty)
      ? _roomsFromSubcollection!.length
      : (_property?.rooms.length ?? 0);
    if (roomsCount == 0) return names[0];
    return names[roomsCount % names.length];
  }

  String _generatePhoneNumber(int index) {
    return '+91 98765 ${10000 + (index * 123) % 90000}';
  }

  String _generateJoinDate(int index) {
    final months = ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'];
    final month = months[index % months.length];
    final day = 10 + (index * 7) % 20;
    return '2024-$month-${day.toString().padLeft(2, '0')}';
  }

  // Get amenities list from property
  List<String> get amenities {
    if (_property == null) return [];

    final amenities = <String>[];
    final propertyAmenities = _property!.amenities;

    if (propertyAmenities.wifi) amenities.add('WiFi');
    if (propertyAmenities.ac) amenities.add('AC');
    if (propertyAmenities.laundry) amenities.add('Laundry');
    if (propertyAmenities.foodIncluded) amenities.add('Food');
    if (propertyAmenities.parking) amenities.add('Parking');
    if (propertyAmenities.geyser) amenities.add('Geyser');
    if (propertyAmenities.powerBackup) amenities.add('Power Backup');
    if (propertyAmenities.cctv) amenities.add('CCTV');
    if (propertyAmenities.housekeeping) amenities.add('Housekeeping');

    return amenities;
  }

  // Get owner information
  Map<String, dynamic> get ownerInfo {
    return {
      'name': _property?.businessName ?? 'Property Owner',
      'phone': _property?.businessPhone ?? '+91 98765 43210',
      'whatsapp': _property?.businessPhone ?? '+91 98765 43210',
      'email': 'owner@${_property?.businessName.toLowerCase().replaceAll(' ', '') ?? 'property'}.com',
    };
  }

  // Check if property has images
  bool get hasImages {
    return _property?.images != null && _property!.images!.isNotEmpty;
  }

  // Get first image URL or placeholder
  String get firstImageUrl {
    if (hasImages) {
      return _property!.images!.first;
    }
    return 'https://picsum.photos/seed/${_property?.name ?? 'property'}/800/600';
  }

  // Get all image URLs
  List<String> get imageUrls {
    if (hasImages) {
      return _property!.images!;
    }
    return [firstImageUrl];
  }
}

