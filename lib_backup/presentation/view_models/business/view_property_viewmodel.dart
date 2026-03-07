import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:onestay360/data/models/business/property/property_model.dart';
import 'package:onestay360/data/models/tenant/tenant_request_model.dart';
import 'package:onestay360/data/repositories/property_repository.dart';
import 'package:onestay360/data/services/property_room_service.dart';
import 'package:onestay360/data/models/business/property/property_room_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewPropertyViewModel extends ChangeNotifier {
  final PropertyRepository _propertyRepository;
  final PropertyRoomService _roomService;

  Property? _property;
  bool _isLoading = true;
  String? _error;
  List<dynamic> _filteredTenants = [];
  String _searchQuery = '';
  int _currentTabIndex = 0;

  // Request-related properties
  final List<TenantRequest> _requests = [];
  bool _requestsLoading = false;
  String? _requestsError;
  StreamSubscription<QuerySnapshot>? _requestsSubscription;

  ViewPropertyViewModel({
    required PropertyRepository propertyRepository,
    PropertyRoomService? roomService,
  }) : _propertyRepository = propertyRepository,
       _roomService = roomService ?? PropertyRoomService();

  List<PropertyRoom>? _roomsFromSubcollection;

  // Getters
  Property? get property => _property;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  List<dynamic> get filteredTenants => _filteredTenants;
  String get searchQuery => _searchQuery;
  int get currentTabIndex => _currentTabIndex;

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
    notifyListeners();

    try {
      debugPrint('🔄 Loading property data for: $propertyId');

      _property = await _propertyRepository.getPropertyById(propertyId);

      // Try to load rooms from subcollection (compatibility helper)
      try {
        _roomsFromSubcollection = await _roomService.getRoomsForProperty(_property!.businessId, _property!.id!);
        if (_roomsFromSubcollection != null && _roomsFromSubcollection!.isNotEmpty) {
          debugPrint('✅ Loaded ${_roomsFromSubcollection!.length} rooms from rooms subcollection');
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

  // DUMMY DATA: Listen to requests for this property
  void listenRequests(String propertyId) {
    if (propertyId.isEmpty) return;

    _requestsLoading = true;
    notifyListeners();

    // Cancel existing subscription
    _requestsSubscription?.cancel();

    try {
      // Simulate loading delay
      Future.delayed(const Duration(seconds: 1), () {
        _generateDummyRequests(propertyId);
        _requestsLoading = false;
        _requestsError = null;
        notifyListeners();
      });
    } catch (e) {
      _requestsLoading = false;
      _requestsError = 'Error setting up requests listener: $e';
      notifyListeners();
    }
  }

  // Generate dummy requests data
  void _generateDummyRequests(String propertyId) {
    _requests.clear();

    // Add dummy requests
    _requests.addAll([
      TenantRequest(
        id: 'req_1',
        tenantName: 'Rahul Sharma',
        phone: '+91 9876543210',
        email: 'rahul.sharma@email.com',
        status: 'pending',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        message: 'Hi, I am interested in taking a single occupancy AC room. Please let me know the availability.',
        preferredMoveIn: DateTime.now().add(const Duration(days: 7)),
        sharingType: 'Single',
        hasAC: true,
        source: 'QR Code',
        propertyId: propertyId,
        businessId: _property?.businessId ?? 'business_123',
      ),
      TenantRequest(
        id: 'req_2',
        tenantName: 'Priya Patel',
        phone: '+91 8765432109',
        email: 'priya.patel@email.com',
        status: 'pending',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        message: 'Looking for a double sharing room with food facility.',
        preferredMoveIn: DateTime.now().add(const Duration(days: 3)),
        sharingType: 'Double',
        hasAC: false,
        source: 'Website',
        propertyId: propertyId,
        businessId: _property?.businessId ?? 'business_123',
      ),
      TenantRequest(
        id: 'req_3',
        tenantName: 'Amit Kumar',
        phone: '+91 7654321098',
        email: null,
        status: 'accepted',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        message: 'Need triple sharing room for 3 months.',
        preferredMoveIn: DateTime.now().add(const Duration(days: 1)),
        sharingType: 'Triple',
        hasAC: true,
        source: 'Referral',
        propertyId: propertyId,
        businessId: _property?.businessId ?? 'business_123',
      ),
      TenantRequest(
        id: 'req_4',
        tenantName: 'Neha Gupta',
        phone: '+91 6543210987',
        email: 'neha.gupta@email.com',
        status: 'rejected',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now().subtract(const Duration(days: 4)),
        message: 'Interested in single room with attached bathroom.',
        preferredMoveIn: DateTime.now().add(const Duration(days: 10)),
        sharingType: 'Single',
        hasAC: true,
        source: 'QR Code',
        propertyId: propertyId,
        businessId: _property?.businessId ?? 'business_123',
      ),
    ]);
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

    // Convert to floor structure with beds
    int floorNumber = 1;
    for (final entry in roomsByFloor.entries) {
      final floorRooms = <Map<String, dynamic>>[];

      for (final room in entry.value) {
        final beds = <Map<String, dynamic>>[];
        final sharingType = room.sharingType ?? 1;

        // Create bed entries based on sharing type
        for (int i = 1; i <= sharingType; i++) {
          // For demo purposes, randomly assign occupancy
          final isOccupied = i % 2 == 0; // Every second bed is occupied
          beds.add({
            'id': 'b$i',
            'isOccupied': isOccupied,
            'tenantName': isOccupied ? _getRandomTenantName() : null,
          });
        }

        floorRooms.add({
          'id': room.roomNumber,
          'number': room.roomNumber,
          'type': _getRoomType(sharingType),
          'rent': _calculateRent(room, sharingType),
          'beds': beds,
        });
      }

      floors.add({
        'floorNumber': floorNumber,
        'rooms': floorRooms,
      });
      floorNumber++;
    }

    // Sort floors in descending order (top floor first)
    floors.sort((a, b) => (b['floorNumber'] as int).compareTo(a['floorNumber'] as int));

    return floors;
  }

  // Get tenants data from property
  List<Map<String, dynamic>> _getTenantsFromProperty() {
    if (_property == null) return [];

    final tenants = <Map<String, dynamic>>[];
    final floors = getFloorsFromProperty();

    for (final floor in floors) {
      final rooms = floor['rooms'] as List<dynamic>;
      for (final room in rooms) {
        final beds = room['beds'] as List<dynamic>;
        for (final bed in beds) {
          if (bed['isOccupied'] == true && bed['tenantName'] != null) {
            tenants.add({
              'id': 't${tenants.length + 1}',
              'name': bed['tenantName'],
              'phone': _generatePhoneNumber(tenants.length + 1),
              'room': room['number'],
              'rent': room['rent'],
              'joinDate': _generateJoinDate(tenants.length + 1),
              'lastPayment': '2024-01-01', // Fixed for demo
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
    final tenants = _getTenantsFromProperty();

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
    // Use property pricing or calculate based on sharing type
    final baseRent = switch (sharingType) {
      1 => _property?.pricing.single ?? 8500,
      2 => _property?.pricing.double ?? 6500,
      3 => _property?.pricing.triple ?? 5500,
      _ => 5000,
    };

    // Add AC premium if applicable
    if (room.hasAC ?? false) {
      return (baseRent * 1.2).toInt(); // 20% premium for AC
    }

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