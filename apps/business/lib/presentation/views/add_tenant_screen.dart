import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_code_tools/qr_code_tools.dart';
import 'widgets/business_scaffold.dart';
import 'package:provider/provider.dart';
import '../view_models/add_tenant_invitation_viewmodel.dart';
import './home_screen.dart';
import 'package:firebase_services/services/tenant_search_service.dart';
import 'package:models/business/property/property_model.dart';
import 'package:models/business/property/property_room_model.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_services/services/property_room_service.dart';

class AddTenantScreen extends StatefulWidget {
  final String? propertyId;
  final String? propertyName;

  const AddTenantScreen({
    super.key,
    this.propertyId,
    this.propertyName,
  });

  @override
  State<AddTenantScreen> createState() => _AddTenantScreenState();
}

class _AddTenantScreenState extends State<AddTenantScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  int _currentTabIndex = 0;
  late TabController _tabController;

  // Tenant info
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _altPhoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Personal details
  final _dobCtrl = TextEditingController();
  final _currentAddressCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _motherTongueCtrl = TextEditingController();
  final _aadharCtrl = TextEditingController();

  // Office/Institute
  final _officeInstituteNameCtrl = TextEditingController();
  final _officeInstituteIdCtrl = TextEditingController();

  // KYC
  final _idNumberCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Lease details
  final _rentCtrl = TextEditingController();
  final _depositCtrl = TextEditingController();
  final _maintenanceCtrl = TextEditingController();
  final _proratedRentCtrl = TextEditingController();
  final _foodDeductionCtrl = TextEditingController();
  final _durationMonthsCtrl = TextEditingController(text: '12');
  final _lockInPeriodCtrl = TextEditingController();
  final _noticePeriodCtrl = TextEditingController();

  // State
  String _gender = 'Male';
  String _idType = 'Aadhaar';
  DateTime? _moveInDate;
  DateTime? _moveOutDate;
  String _paymentCycle = 'Monthly';
  String _tenantType = 'Bachelor';
  String _rentBillingType = 'Monthly';
  bool _foodAddon = true; // Default to true (food included)
  String? _foodPreference; // Veg, Non-Veg, or Both
  DateTime? _billingDate; // Billing date (1st of month)
  bool _paySecurityDepositNow = true; // Whether to pay security deposit now or later

  // Assignment state
  String? _selectedPropertyId;
  String? _selectedPropertyName;
  String? _selectedFloor;
  String? _selectedRoomId;
  String? _selectedRoomNumber;
  int? _selectedBedIndex;

  // Mode selection: 'qr', 'search', or 'manual'
  String _mode = 'manual';
  TenantSearchResult? _selectedTenant;
  
  // Inline search state
  final _searchController = TextEditingController();
  final _searchService = TenantSearchService();
  List<TenantSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  // Debounce timer for prorated rent input
  Timer? _proratedDebounceTimer;
  
  // Property selection state
  List<Property> _availableProperties = [];
  Property? _selectedPropertyObj;
  Map<String, List<Map<String, dynamic>>> _propertyRoomsByFloor = {};
  bool _isLoadingProperties = false;
  late PropertyRoomService _roomService;
  List<PropertyRoom> _currentRoomsList = [];
  
  // QR Scanner state
  bool _showQRScanner = false;
  final MobileScannerController _qrController = MobileScannerController();
  bool _isProcessingQR = false;


  // Real property and room data will be loaded from Firestore via
  // `_loadProperties()` into `_availableProperties` and
  // `_propertyRoomsByFloor` at runtime.

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      initialIndex: _currentTabIndex,
      vsync: this,
    );
    _tabController.addListener(() {
      setState(() => _currentTabIndex = _tabController.index);
    });

    // Start with any properties passed via constructor; otherwise defer
    // selection until `_loadProperties()` populates `_availableProperties`.
    _selectedPropertyId = widget.propertyId;
    _selectedPropertyName = widget.propertyName;
    _selectedFloor = null;
    
    // Load properties
    _loadProperties();

    _roomService = PropertyRoomService();
    
    // Real property and room data is loaded at runtime from Firestore via
    // `_loadProperties()` and stored in `_availableProperties` and
    // `_propertyRoomsByFloor`.
  }

  // Load properties for the current business and select the first property
  // when none was provided via constructor.
  Future<void> _loadProperties() async {
    setState(() {
      _isLoadingProperties = true;
    });

    try {
      final businessId = await _getBusinessId();
      if (businessId == null) return;

      final propertiesSnapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('properties')
          .get();

      _availableProperties = propertiesSnapshot.docs
          .map((doc) => Property.fromMap({...doc.data()}, doc.id))
          .toList();

      if (_availableProperties.isNotEmpty && (_selectedPropertyId == null || _selectedPropertyName == null)) {
        _selectedPropertyObj = _availableProperties.first;
        _selectedPropertyId = _selectedPropertyObj!.id;
        _selectedPropertyName = _selectedPropertyObj!.name;
        await _loadRoomsForProperty(_selectedPropertyObj!);
      }
    } catch (e) {
      print('Error loading properties: $e');
    } finally {
      setState(() {
        _isLoadingProperties = false;
      });
    }
  }
  
  Future<void> _loadRoomsForProperty(Property property) async {
    try {
      print('🔍 Loading rooms for property: ${property.id} - ${property.name}');
      print('📊 Loading rooms (prefers subcollection)');
      // Try to load rooms from rooms subcollection via compatibility service
      List<PropertyRoom> roomsFromSub = [];
      try {
        final businessId = await _getBusinessId();
        if (businessId != null) {
          roomsFromSub = await _roomService.getRoomsForProperty(businessId, property.id!);
        }
      } catch (e) {
        print('⚠️ Failed to load rooms from subcollection: $e');
      }

      final roomsToUse = (roomsFromSub.isNotEmpty) ? roomsFromSub : property.rooms;
      _currentRoomsList = roomsToUse;
      
      final businessId = await _getBusinessId();
      if (businessId == null) {
        print('❌ Business ID is null');
        return;
      }
      
      // Check if property has rooms
      if (roomsToUse.isEmpty) {
        print('⚠️ Property has no rooms');
        setState(() {
          _propertyRoomsByFloor = {};
        });
        return;
      }
      
      // Map: roomId -> Set of occupied bedIds
      final occupiedBeds = <String, Set<String>>{};
      
      // Try to get all active tenants for this property to check bed availability
      // If this fails due to permissions, we'll proceed with all beds as available
      try {
        final tenantsSnapshot = await FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .collection('tenants')
            .where('propertyId', isEqualTo: property.id)
            .where('status', isEqualTo: 'active')
            .get();
        
        print('👥 Found ${tenantsSnapshot.docs.length} active tenants for this property');
        
        for (final tenantDoc in tenantsSnapshot.docs) {
          final tenantData = tenantDoc.data();
          final roomId = tenantData['roomId']?.toString() ?? '';
          final bedId = tenantData['bedId']?.toString() ?? '';
          if (roomId.isNotEmpty && bedId.isNotEmpty) {
            occupiedBeds.putIfAbsent(roomId, () => <String>{}).add(bedId);
            print('🛏️ Room $roomId has bed $bedId occupied');
          }
        }
      } catch (e, stackTrace) {
        print('⚠️ Could not load tenant data (permission issue or no tenants): $e');
        print('📋 Proceeding with all beds as available');
        print('Stack trace: $stackTrace');
        // Continue with empty occupiedBeds - all beds will show as available
        // Don't rethrow - we can still organize rooms without tenant data
      }
      
      // Organize rooms by floor
      final roomsByFloor = <String, List<Map<String, dynamic>>>{};
      for (final room in roomsToUse) {
        final floor = room.floor.toString();
        print('🏢 Processing room ${room.roomNumber} on floor $floor');
        
        roomsByFloor.putIfAbsent(floor, () => []);
        
        final sharingType = room.sharingType ?? 2;
        final roomId = room.roomNumber;
        final occupiedBedsForRoom = occupiedBeds[roomId] ?? <String>{};
        final availableBeds = sharingType - occupiedBedsForRoom.length;
        
        print('   - Sharing type: $sharingType');
        print('   - Occupied beds: ${occupiedBedsForRoom.length}');
        print('   - Available beds: $availableBeds');
        
        // Create beds list
        final beds = <Map<String, dynamic>>[];
        for (int i = 0; i < sharingType; i++) {
          final bedNumber = (i + 1).toString();
          final isOccupied = occupiedBedsForRoom.contains(bedNumber);
          beds.add({
            'index': i,
            'number': bedNumber,
            'isOccupied': isOccupied,
          });
        }
        
        roomsByFloor[floor]!.add({
          'id': roomId,
          'number': room.roomNumber,
          'sharingType': sharingType,
          'hasAC': room.hasAC,
          'status': room.status,
          'beds': beds,
          'availableBeds': availableBeds,
          'totalBeds': sharingType,
          'occupiedBeds': occupiedBedsForRoom.length,
        });
      }
      
      print('✅ Organized ${roomsByFloor.length} floors with rooms');
      for (final floor in roomsByFloor.keys) {
        print('   Floor $floor: ${roomsByFloor[floor]!.length} rooms');
      }
      
      setState(() {
        _propertyRoomsByFloor = roomsByFloor;
      });
    } catch (e, stackTrace) {
      print('❌ Error loading rooms: $e');
      print('Stack trace: $stackTrace');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading rooms: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }
    
    if (query.length >= 2) {
      _performSearch(query);
    }
  }
  
  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });
    
    try {
      final results = await _searchService.searchTenants(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
    }
  }
  
  void _showQRScannerDialog() {
    HapticFeedback.lightImpact();
    _qrController.start();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          height: 400,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                MobileScanner(
                  controller: _qrController,
                  onDetect: _handleQRCode,
                ),
                if (_isProcessingQR)
                  Container(
                    color: Colors.black.withOpacity(0.7),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Processing...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      _qrController.stop();
                      Navigator.pop(context);
                    },
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.flash_on, color: Colors.white),
                        onPressed: () => _qrController.toggleTorch(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cameraswitch, color: Colors.white),
                        onPressed: () => _qrController.switchCamera(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.image_search, color: Colors.white),
                        tooltip: 'Scan from Gallery',
                        onPressed: () async {
                          _qrController.stop();
                          Navigator.pop(context);
                          await _scanQRFromGallery();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      _qrController.stop();
    });
  }

  Future<void> _handleQRCode(BarcodeCapture barcodeCapture) async {
    if (_isProcessingQR) return;
    if (barcodeCapture.barcodes.isEmpty) return;
    
    final barcode = barcodeCapture.barcodes.first;
    if (barcode.rawValue == null || barcode.rawValue!.isEmpty) return;
    
    final scannedData = barcode.rawValue!;
    if (!scannedData.startsWith('onestay360:tenant:')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid QR code. Please scan a tenant profile QR code.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    setState(() {
      _isProcessingQR = true;
    });
    
    try {
      final tenantId = scannedData.replaceFirst('onestay360:tenant:', '');
      if (tenantId.isEmpty) {
        throw Exception('Invalid tenant ID in QR code');
      }
      
      // Fetch tenant data
      final tenantDoc = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .get();
      
      if (!tenantDoc.exists) {
        throw Exception('Tenant not found');
      }
      
      final tenantData = tenantDoc.data()!;
      final userId = tenantData['userId']?.toString();
      Map<String, dynamic>? userData;
      
      if (userId != null && userId.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userDoc.exists) {
          userData = userDoc.data();
        }
      }
      
      final mergedData = {
        ...tenantData,
        ...?userData,
        'tenantId': tenantId,
      };
      
      // Stop scanner first
      await _qrController.stop();
      
      // Close dialog
      if (mounted) {
        Navigator.pop(context);
      }
      
      // Populate form
      _populateFormFromQR(mergedData);
      setState(() {
        _mode = 'manual';
        _showQRScanner = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tenant details loaded from QR code'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingQR = false;
        });
      }
    }
  }

  Future<void> _scanQRFromGallery() async {
    try {
      final ImagePicker imagePicker = ImagePicker();
      final XFile? image = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        _isProcessingQR = true;
      });

      // Decode QR code from image using qr_code_tools
      String? result;
      try {
        result = await QrCodeToolsPlugin.decodeFrom(image.path);
      } catch (e) {
        // Fallback or alternative method
        print('QR decode error: $e');
      }
      
      if (result != null && result.isNotEmpty) {
        // QR code found and decoded
        final scannedData = result;
        
        if (scannedData.startsWith('onestay360:tenant:')) {
          // Parse tenant QR code
          final tenantId = scannedData.replaceFirst('onestay360:tenant:', '');
          
          // Fetch tenant data from Firestore
          final tenantDoc = await FirebaseFirestore.instance
              .collection('tenants')
              .doc(tenantId)
              .get();
          
          if (tenantDoc.exists) {
            final tenantData = tenantDoc.data()!;
            final userId = tenantData['userId']?.toString();
            Map<String, dynamic>? userData;
            
            if (userId != null && userId.isNotEmpty) {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .get();
              if (userDoc.exists) {
                userData = userDoc.data();
              }
            }
            
            final mergedData = {
              ...tenantData,
              ...?userData,
              'tenantId': tenantId,
            };
            
            // Populate form with tenant data
            _populateFormFromQR(mergedData);
            
            setState(() {
              _mode = 'manual';
            });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tenant details loaded from QR code'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            throw Exception('Tenant not found');
          }
        } else {
          // Try to parse as generic QR data (format: "name|email|phone|city")
          final parts = scannedData.split('|');
          if (parts.length >= 3) {
            _fullNameCtrl.text = parts[0];
            _emailCtrl.text = parts[1];
            _phoneCtrl.text = parts[2];
            if (parts.length >= 4) {
              // Could be city or other field
            }
            
            setState(() => _mode = 'manual');
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('QR data decoded successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            throw Exception('Invalid QR code format');
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No QR code found in image'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      setState(() {
        _isProcessingQR = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning QR: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isProcessingQR = false;
      });
    }
  }

  Future<String?> _getBusinessId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        return userData['businessId']?.toString();
      }
    }
    return null;
  }

  @override
  void dispose() {
    // Cancel debounce timer if active
    _proratedDebounceTimer?.cancel();
    _tabController.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _altPhoneCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    _currentAddressCtrl.dispose();
    _nationalityCtrl.dispose();
    _motherTongueCtrl.dispose();
    _aadharCtrl.dispose();
    _officeInstituteNameCtrl.dispose();
    _officeInstituteIdCtrl.dispose();
    _idNumberCtrl.dispose();
    _addressCtrl.dispose();
    _searchController.dispose();
    _qrController.dispose();
    _rentCtrl.dispose();
    _depositCtrl.dispose();
    _maintenanceCtrl.dispose();
    _proratedRentCtrl.dispose();
    _foodDeductionCtrl.dispose();
    _durationMonthsCtrl.dispose();
    _lockInPeriodCtrl.dispose();
    _noticePeriodCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBillingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billingDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select Billing Date (Day of Month)',
    );
    if (picked != null) {
      // Store the selected day for billing (1-31)
      setState(() {
        _billingDate = picked;
      });
    }
  }

  Future<void> _pickDate(bool isMoveIn) async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isMoveIn ? (_moveInDate ?? now) : (_moveOutDate ?? now),
      firstDate: now.subtract(const Duration(days: 0)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        if (isMoveIn) {
          _moveInDate = picked;
          // Recalculate prorated rent when move-in date changes
          _recalculateProratedRent();
        } else {
          _moveOutDate = picked;
        }
      });
    }
  }
  
  void _recalculateProratedRent() {
    if (_moveInDate == null) return;
    
    final monthlyRent = double.tryParse(_rentCtrl.text.trim()) ?? 0.0;
    if (monthlyRent <= 0) return;
    
    // Apply food deduction to monthly rent if food addon is unchecked
    double monthlyFoodDeduction = 0.0;
    if (!_foodAddon) {
      monthlyFoodDeduction = double.tryParse(_foodDeductionCtrl.text.trim()) ?? 0.0;
    }
    
    // Calculate adjusted monthly rent (after food deduction)
    double adjustedMonthlyRent = (monthlyRent - monthlyFoodDeduction).clamp(0.0, double.infinity);
    
    final moveIn = _moveInDate!;
    final moveInDay = moveIn.day;
    
    double calculatedProratedRent;
    if (moveInDay >= 1 && moveInDay <= 15) {
      // Full month rent
      calculatedProratedRent = adjustedMonthlyRent;
    } else if (moveInDay >= 16 && moveInDay <= 31) {
      // Half month rent
      calculatedProratedRent = adjustedMonthlyRent / 2;
    } else {
      // Fallback
      calculatedProratedRent = adjustedMonthlyRent;
    }
    
    // Only update if field is empty or was previously auto-calculated (value matches a calculation)
    // This preserves manual edits
    final currentValue = double.tryParse(_proratedRentCtrl.text.trim()) ?? 0.0;
    if (_proratedRentCtrl.text.trim().isEmpty || currentValue == 0.0) {
      _proratedRentCtrl.text = calculatedProratedRent.toStringAsFixed(2);
    }
  }

  void _onSelectProperty(BuildContext context) async {
    HapticFeedback.lightImpact();
    final chosen = await showModalBottomSheet<Property>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select Property',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _availableProperties.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = _availableProperties[i];
                      return ListTile(
                        leading: const Icon(Icons.apartment_outlined),
                        title: Text(p.name),
                        onTap: () => Navigator.pop(ctx, p),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (chosen != null) {
      // chosen is a `Property` object
      setState(() {
        _selectedPropertyObj = chosen;
        _selectedPropertyId = chosen.id;
        _selectedPropertyName = chosen.name;
        _selectedRoomId = null;
        _selectedRoomNumber = null;
        _selectedBedIndex = null;
      });

      // Load rooms for the selected property and pick a default floor if available
      await _loadRoomsForProperty(chosen);
      setState(() {
        _selectedFloor = _propertyRoomsByFloor.keys.isNotEmpty ? _propertyRoomsByFloor.keys.first : null;
      });
    }
  }

  void _onSelectRoom(BuildContext context) async {
    HapticFeedback.lightImpact();
    final floor = _selectedFloor;
    if (floor == null) return;
    final rooms = _propertyRoomsByFloor[floor] ?? [];

    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Select Room • Floor $floor',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: rooms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final r = rooms[i];
                      final occupied = (r['bedOccupied'] as List<bool>)
                          .where((b) => b)
                          .length;
                      final total = r['beds'] as int;

                      return ListTile(
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side:
                          BorderSide(color: Colors.grey.shade200, width: 1),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade50,
                          child: Text(r['number']),
                        ),
                        title: Text('Room ${r['number']} • ${r['type']}'),
                        subtitle: Text(
                          'Beds: $occupied/$total occupied • Rent: ₹${r['rent']}',
                        ),
                        onTap: () => Navigator.pop(ctx, r),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (chosen != null) {
      setState(() {
        _selectedRoomId = chosen['id'];
        _selectedRoomNumber = chosen['number'];
        _selectedBedIndex = null;
        _rentCtrl.text = (chosen['rent'] ?? '').toString();
      });
    }
  }

  void _onSelectBed(int bedIndex) {
    if (_selectedFloor == null || _selectedRoomId == null) return;
    final rooms = _propertyRoomsByFloor[_selectedFloor] ?? [];
    if (rooms.isEmpty) return;

    final room = rooms.firstWhere(
          (r) => r['id'] == _selectedRoomId,
      orElse: () => {},
    );
    if (room.isEmpty) return;
    final occupied = (room['bedOccupied'] as List<bool>);

    if (occupied[bedIndex]) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('This bed is already occupied. Please choose another.'),
      ));
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _selectedBedIndex = bedIndex);
  }

  void _prefillFinancialDetails(Property property) {
    final pricing = property.pricing;
    PropertyRoom? selectedRoom;
    
    // Try to find selected room from the currently loaded rooms (subcollection preferred)
    if (_selectedRoomNumber != null && _selectedRoomNumber!.isNotEmpty) {
      selectedRoom = _currentRoomsList.firstWhere(
        (r) => r.roomNumber == _selectedRoomNumber,
        orElse: () => PropertyRoom(
          roomNumber: '',
          floor: '1',
          occupancyType: 'Double',
          sharingType: 2,
          hasAC: false,
        ),
      );
    }
    
    // Get rent based on room sharing type and AC status
    int monthlyRent = 0;
    if (selectedRoom != null && selectedRoom.sharingType != null) {
      final rent = pricing.getPriceFor(selectedRoom.sharingType!, acRoom: selectedRoom.hasAC);
      if (rent != null && rent > 0) {
        monthlyRent = rent;
      }
    }
    
    // Fallback to legacy pricing if dynamic pricing not available
    if (monthlyRent == 0) {
      if (selectedRoom != null) {
        if (selectedRoom.sharingType == 1) {
          monthlyRent = pricing.single;
        } else if (selectedRoom.sharingType == 2) {
          monthlyRent = pricing.double;
        } else if (selectedRoom.sharingType == 3) {
          monthlyRent = pricing.triple;
        } else {
          monthlyRent = pricing.double; // Default
        }
      } else {
        monthlyRent = pricing.double; // Default if no room selected
      }
    }
    
    setState(() {
      // Only update if fields are empty to avoid overwriting user input
      if (_rentCtrl.text.trim().isEmpty) {
        _rentCtrl.text = monthlyRent.toString();
      }
      if (_depositCtrl.text.trim().isEmpty) {
        _depositCtrl.text = pricing.securityDeposit.toString();
      }
      if (_maintenanceCtrl.text.trim().isEmpty) {
        _maintenanceCtrl.text = pricing.oneTimeMaintenance.toString();
      }
    });
  }

  void _populateFormFromQR(Map<String, dynamic> tenantData) {
    setState(() {
      // Basic Information
      _fullNameCtrl.text = tenantData['name']?.toString() ?? 
                          tenantData['fullName']?.toString() ?? '';
      _phoneCtrl.text = tenantData['phone']?.toString() ?? 
                       tenantData['mobileNumber']?.toString() ?? '';
      _altPhoneCtrl.text = tenantData['alternatePhone']?.toString() ?? '';
      _emailCtrl.text = tenantData['email']?.toString() ?? '';
      _gender = tenantData['gender']?.toString() ?? 'Male';

      // Personal Details
      if (tenantData['dateOfBirth'] != null) {
        final dob = tenantData['dateOfBirth'];
        if (dob is DateTime) {
          _dobCtrl.text = '${dob.day}/${dob.month}/${dob.year}';
        } else if (dob is Map && dob['_seconds'] != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(dob['_seconds'] * 1000);
          _dobCtrl.text = '${date.day}/${date.month}/${date.year}';
        } else if (dob is Timestamp) {
          final date = dob.toDate();
          _dobCtrl.text = '${date.day}/${date.month}/${date.year}';
        }
      }
      _currentAddressCtrl.text = tenantData['addressLine1']?.toString() ?? 
                                 tenantData['address']?.toString() ?? '';
      _nationalityCtrl.text = tenantData['nationality']?.toString() ?? '';
      _motherTongueCtrl.text = tenantData['motherTongue']?.toString() ?? '';
      _aadharCtrl.text = tenantData['idNumber']?.toString() ?? '';
      // Normalize idType to match dropdown options
      final idTypeFromData = tenantData['idType']?.toString() ?? '';
      final normalizedIdType = _normalizeIdType(idTypeFromData);
      _idType = normalizedIdType;
      _idNumberCtrl.text = tenantData['idNumber']?.toString() ?? '';
      _addressCtrl.text = tenantData['addressLine1']?.toString() ?? 
                         (tenantData['city']?.toString() ?? '');

      // Office/Institute
      _officeInstituteNameCtrl.text = tenantData['officeInstituteName']?.toString() ?? '';
      _officeInstituteIdCtrl.text = tenantData['officeInstituteId']?.toString() ?? '';
    });
  }

  Future<void> _submitAddTenant(BuildContext providerContext) async {
    // Validate based on mode
    if (_mode == 'search') {
      if (_selectedTenant == null) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a tenant.')),
        );
        return;
      }
    } else {
      if (!_formKey.currentState!.validate()) {
        HapticFeedback.mediumImpact();
        return;
      }
    }

    if (_moveInDate == null) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a move-in date.')),
      );
      return;
    }

    if (_selectedPropertyId == null ||
        _selectedRoomId == null ||
        _selectedBedIndex == null) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please assign property, room and bed.')),
      );
      return;
    }

    HapticFeedback.lightImpact();

    final businessId = await _getBusinessId();
    if (businessId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business ID not found')),
      );
      return;
    }

    // Use AddTenantInvitationViewModel - read from the provider context
    final vm = providerContext.read<AddTenantInvitationViewModel>();

    // Set mode
    vm.setMode(_mode);

    // Set tenant data
    if (_mode == 'search' && _selectedTenant != null) {
      vm.setSelectedTenant(_selectedTenant);
    } else {
      // Manual mode - prepare tenant data
      final tenantData = {
        'name': _fullNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'alternatePhone': _altPhoneCtrl.text.trim(),
        'gender': _gender,
        'dateOfBirth': _dobCtrl.text.trim(),
        'address': _currentAddressCtrl.text.trim(),
        'addressLine1': _currentAddressCtrl.text.trim(),
        'nationality': _nationalityCtrl.text.trim(),
        'motherTongue': _motherTongueCtrl.text.trim(),
        'idType': _idType,
        'idNumber': _idNumberCtrl.text.trim(),
        'officeInstituteName': _officeInstituteNameCtrl.text.trim(),
        'officeInstituteId': _officeInstituteIdCtrl.text.trim(),
      };
      vm.setManualTenantData(tenantData);
    }

    // Set assignment
    vm.setAssignment(
      propertyId: _selectedPropertyId,
      propertyName: _selectedPropertyObj?.name ?? _selectedPropertyName,
      floor: _selectedFloor ?? '',
      roomId: _selectedRoomId,
      roomNumber: _selectedRoomNumber,
      bedIndex: _selectedBedIndex,
      bedNumber: (_selectedBedIndex! + 1).toString(),
    );

    // Set lease details
    vm.setMoveInDate(_moveInDate);
    vm.setMoveOutDate(_moveOutDate);
    vm.setMonthlyRent(double.tryParse(_rentCtrl.text.trim()) ?? 0.0);
    vm.setDeposit(_depositCtrl.text.trim().isNotEmpty
        ? double.tryParse(_depositCtrl.text.trim())
        : null);
    vm.setMaintenance(_maintenanceCtrl.text.trim().isNotEmpty
        ? double.tryParse(_maintenanceCtrl.text.trim())
        : null);
    vm.setLockInPeriodMonths(_lockInPeriodCtrl.text.trim().isNotEmpty
        ? int.tryParse(_lockInPeriodCtrl.text.trim())
        : null);
    vm.setNoticePeriodDays(_noticePeriodCtrl.text.trim().isNotEmpty
        ? int.tryParse(_noticePeriodCtrl.text.trim())
        : null);
    vm.setPaymentCycle(_paymentCycle);

    // Set food preference
    vm.setFoodPreference(_foodPreference);

    // Persist prorated rent and billing day before submit
    final parsedProrated = double.tryParse(_proratedRentCtrl.text.trim());
    vm.setProratedRent(parsedProrated);
    vm.setBillingDay(_billingDate?.day);
    // Persist whether maintenance is deducted from deposit (from selected property pricing)
    vm.setMaintenanceDeductedFromDeposit(_selectedPropertyObj?.pricing.maintenanceDeductedFromDeposit ?? false);

    // Submit
    await vm.submit();

    if (!mounted) return;
    if (vm.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.errorMessage!)),
      );
      return;
    }

    // Success - show confirmation and navigate to Business home
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invitation Sent'),
        content: Text(
          _mode == 'search'
              ? 'Invitation has been sent to ${_selectedTenant!.name}. They will receive a notification to approve.'
              : 'Invitation has been sent to ${_fullNameCtrl.text.trim()}. They will receive a notification to approve.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(ctx);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => BusinessHomeScreen(businessId: businessId),
                ),
              );
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final floorKeys = _propertyRoomsByFloor.keys.toList()..sort((a, b) => b.compareTo(a));

    return ChangeNotifierProvider(
      create: (_) => AddTenantInvitationViewModel(),
      child: Consumer<AddTenantInvitationViewModel>(
        builder: (context, vm, _) {
          return BusinessScaffold(
            currentTab: BusinessTab.tenants,
            showBackButton: false,
            body: SafeArea(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'Property'),
                          Tab(text: 'Tenant Info'),
                          Tab(text: 'Lease'),
                          Tab(text: 'Personal'),
                          Tab(text: 'Bill'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPropertyTab(floorKeys),
                          _buildTenantInfoTab(),
                          _buildLeaseDetailsTab(),
                          _buildPersonalDetailsTab(),
                          _buildBillTab(),
                        ],
                      ),
                    ),
                    // Navigation buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Row(
                        children: [
                          // Show Send Invitation button only on last tab (Bill tab)
                          if (_currentTabIndex == 4)
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: vm.isSubmitting ? null : () => _submitAddTenant(context),
                                icon: vm.isSubmitting
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.person_add_alt_1),
                                label: const Text('Send Invitation'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  minimumSize: const Size(double.infinity, 50),
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  if (_currentTabIndex < 4) {
                                    _tabController.animateTo(_currentTabIndex + 1);
                                  }
                                },
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text('Next'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  minimumSize: const Size(double.infinity, 50),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPropertyTab(List<String> floorKeys) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Property Selection - Dropdown
        _section(
          'Property Assignment',
          [
            if (_isLoadingProperties)
              const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ))
            else if (_availableProperties.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No properties available. Please add a property first.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<Property>(
                initialValue: _selectedPropertyObj,
                decoration: const InputDecoration(
                  labelText: 'Select Property',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.apartment),
                ),
                items: _availableProperties
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p.name),
                        ))
                    .toList(),
                onChanged: (property) async {
                  if (property != null) {
                    HapticFeedback.lightImpact();
                    print('📋 Property selected: ${property.id} - ${property.name}');
                    print('📊 Loading rooms for selected property (subcollection preferred)');
                    
                    setState(() {
                      _selectedPropertyObj = property;
                      _selectedPropertyId = property.id;
                      _selectedPropertyName = property.name;
                      _selectedFloor = null;
                      _selectedRoomId = null;
                      _selectedRoomNumber = null;
                      _selectedBedIndex = null;
                      _propertyRoomsByFloor = {}; // Clear previous data
                    });
                    
                    // Pre-fill financial details from property pricing (will update when room is selected)
                    if (_selectedRoomNumber != null) {
                      _prefillFinancialDetails(property);
                    }
                    
                    await _loadRoomsForProperty(property);
                    
                    // Debug: Check if rooms were loaded
                    print('🔍 After loading, _propertyRoomsByFloor has ${_propertyRoomsByFloor.length} floors');
                  }
                },
              ),
          ],
        ),
        
        // Floor Selection - Show floors with available bed numbers
        if (_selectedPropertyObj != null) ...[
          const SizedBox(height: 16),
          if (_propertyRoomsByFloor.isEmpty)
            _section(
              'Select Floor',
              [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'This property has no rooms. Please add rooms to the property first.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            _section(
              'Select Floor',
              [
              // Calculate available beds per floor
              ..._propertyRoomsByFloor.keys.map((floor) {
                final roomsOnFloor = _propertyRoomsByFloor[floor] ?? [];
                int totalAvailableBeds = 0;
                int totalBeds = 0;
                for (final room in roomsOnFloor) {
                  totalAvailableBeds += room['availableBeds'] as int? ?? 0;
                  totalBeds += room['totalBeds'] as int? ?? 0;
                }
                
                final isSelected = _selectedFloor == floor;
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: Colors.teal.shade50,
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.teal.shade600 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        floor,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    'Floor $floor',
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '$totalAvailableBeds/$totalBeds beds available',
                    style: TextStyle(
                      color: totalAvailableBeds > 0 ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check_circle, color: Colors.teal.shade600) : null,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedFloor = floor;
                      _selectedRoomId = null;
                      _selectedRoomNumber = null;
                      _selectedBedIndex = null;
                    });
                  },
                );
              }),
            ],
          ),
        ],
        
        // Room Selection - Show rooms on selected floor with available occupancy
        if (_selectedFloor != null && _propertyRoomsByFloor[_selectedFloor] != null && _propertyRoomsByFloor[_selectedFloor]!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _section(
            'Select Room (Floor $_selectedFloor)',
            [
              ..._propertyRoomsByFloor[_selectedFloor]!.map((room) {
                final roomId = room['id'] as String;
                final roomNumber = room['number'] as String;
                final isSelected = _selectedRoomId == roomId;
                final availableBeds = room['availableBeds'] as int? ?? 0;
                final totalBeds = room['totalBeds'] as int? ?? 0;
                final sharingType = room['sharingType'] as int? ?? totalBeds;
                final hasAC = room['hasAC'] as bool? ?? false;
                
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: Colors.blue.shade50,
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        roomNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        'Room $roomNumber',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (hasAC) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.ac_unit, size: 12, color: Colors.blue.shade700),
                              const SizedBox(width: 2),
                              Text(
                                'AC',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '$sharingType-sharing • $availableBeds/$totalBeds beds available',
                    style: TextStyle(
                      color: availableBeds > 0 ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check_circle, color: Colors.blue.shade600) : null,
                  onTap: availableBeds > 0 ? () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedRoomId = roomId;
                      _selectedRoomNumber = roomNumber;
                      _selectedBedIndex = null;
                    });
                    // Pre-fill financial details when room is selected
                    if (_selectedPropertyObj != null) {
                      _prefillFinancialDetails(_selectedPropertyObj!);
                    }
                  } : null,
                );
              }),
            ],
          ),
        ],
        
        // Bed Selection - Show beds in selected room
        if (_selectedRoomId != null) ...[
          const SizedBox(height: 16),
          _buildBedSelectionSection(),
        ],
        
        // Assignment Summary
        if (_selectedPropertyId != null &&
            _selectedRoomId != null &&
            _selectedBedIndex != null) ...[
          const SizedBox(height: 16),
          _buildAssignmentSummary(),
        ],
      ],
    );
  }

  Widget _buildBedSelectionSection() {
    final rooms = _propertyRoomsByFloor[_selectedFloor] ?? [];
    final selectedRoom = rooms.firstWhere(
      (r) => r['id'] == _selectedRoomId,
      orElse: () => <String, dynamic>{},
    );
    
    if (selectedRoom.isEmpty) return const SizedBox.shrink();
    
    final beds = selectedRoom['beds'] as List<dynamic>? ?? [];
    final roomNumber = selectedRoom['number'] as String;
    final availableBeds = beds.where((b) => !(b['isOccupied'] as bool? ?? false)).toList();
    
    return _section(
      'Select Bed (Room $roomNumber)',
      [
        if (availableBeds.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.red.shade700),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'No available beds in this room. Please select another room.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: beds.map((bed) {
              final bedIndex = bed['index'] as int;
              final bedNumber = bed['number'] as String;
              final isOccupied = bed['isOccupied'] as bool? ?? false;
              final isBedSelected = _selectedBedIndex == bedIndex;
              
              if (isOccupied) {
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bed, color: Colors.grey.shade500, size: 28),
                      const SizedBox(height: 4),
                      Text(
                        'Bed $bedNumber',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'Occupied',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedBedIndex = bedIndex;
                  });
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isBedSelected ? Colors.green.shade600 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isBedSelected ? Colors.green.shade700 : Colors.green.shade300,
                      width: isBedSelected ? 3 : 2,
                    ),
                    boxShadow: isBedSelected
                        ? [
                            BoxShadow(
                              color: Colors.green.shade200,
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bed,
                        color: isBedSelected ? Colors.white : Colors.green.shade700,
                        size: 32,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bed $bedNumber',
                        style: TextStyle(
                          color: isBedSelected ? Colors.white : Colors.green.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isBedSelected) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'Selected',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildAssignmentSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Assignment Selected',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Property', _selectedPropertyName ?? ''),
          if (_selectedFloor != null)
            _buildDetailRow('Floor', _selectedFloor!),
          if (_selectedRoomNumber != null)
            _buildDetailRow('Room', _selectedRoomNumber!),
          if (_selectedBedIndex != null)
            _buildDetailRow('Bed', '${_selectedBedIndex! + 1}'),
        ],
      ),
    );
  }


  Widget _buildTenantInfoTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Mode Selection - All in same row
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Scan QR Code'),
                      selected: _mode == 'qr',
                      onSelected: (selected) {
                        if (selected) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _mode = 'qr';
                            _selectedTenant = null;
                          });
                          _showQRScannerDialog();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Search Tenant'),
                      selected: _mode == 'search',
                      onSelected: (selected) {
                        if (selected) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _mode = 'search';
                            _selectedTenant = null;
                            _showQRScanner = false;
                          });
                          _qrController.stop();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Add Manually'),
                      selected: _mode == 'manual',
                      onSelected: (selected) {
                        if (selected) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _mode = 'manual';
                            _selectedTenant = null;
                            _showQRScanner = false;
                          });
                          _qrController.stop();
                        }
                      },
                    ),
                  ),
                ],
              ),
              // QR Scanner button (shown when QR mode is selected)
              if (_mode == 'qr') ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _showQRScannerDialog,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Open QR Scanner'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
              // Tenant Search (shown when search mode is selected)
              if (_mode == 'search') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _showSearchResults = true;
                    });
                  },
                ),
                if (_showSearchResults && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final tenant = _searchResults[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: tenant.profileImage != null
                                ? NetworkImage(tenant.profileImage!)
                                : null,
                            child: tenant.profileImage == null
                                ? Text(tenant.name.isNotEmpty
                                    ? tenant.name[0].toUpperCase()
                                    : 'T')
                                : null,
                          ),
                          title: Text(tenant.name),
                          subtitle: Text(tenant.phone),
                          onTap: () {
                            setState(() {
                              _selectedTenant = tenant;
                              _showSearchResults = false;
                              _searchController.clear();
                            });
                          },
                        );
                      },
                    ),
                  ),
                if (_selectedTenant != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    color: Colors.green.shade50,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: _selectedTenant!.profileImage != null
                            ? NetworkImage(_selectedTenant!.profileImage!)
                            : null,
                        child: _selectedTenant!.profileImage == null
                            ? Text(_selectedTenant!.name.isNotEmpty
                                ? _selectedTenant!.name[0].toUpperCase()
                                : 'T')
                            : null,
                      ),
                      title: Text(_selectedTenant!.name),
                      subtitle: Text(_selectedTenant!.phone),
                      trailing: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _selectedTenant = null;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // If search mode and tenant selected, show tenant info
        if (_mode == 'search' && _selectedTenant != null)
          _section(
            'Selected Tenant',
            [
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: _selectedTenant!.profileImage != null
                      ? NetworkImage(_selectedTenant!.profileImage!)
                      : null,
                  child: _selectedTenant!.profileImage == null
                      ? Text(_selectedTenant!.name.isNotEmpty
                          ? _selectedTenant!.name[0].toUpperCase()
                          : 'T')
                      : null,
                ),
                title: Text(_selectedTenant!.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedTenant!.phone),
                    if (_selectedTenant!.email != null)
                      Text(_selectedTenant!.email!),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _selectedTenant = null;
                    });
                  },
                ),
              ),
            ],
          ),
        // Manual mode - show form
        if (_mode == 'manual' || (_mode == 'qr' && _selectedTenant == null))
          _section(
          'Basic Information',
          [
            _textField(
              controller: _fullNameCtrl,
              label: 'Full Name',
              hint: 'Enter full name',
              validator: (v) =>
              v == null || v.trim().isEmpty ? 'Required' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _phoneCtrl,
              label: 'Phone',
              hint: '+91 9xxxxxxxxx',
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) =>
              v != null && v.length >= 10 ? null : 'Invalid phone',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _altPhoneCtrl,
              label: 'Alternate Phone',
              hint: '+91 9xxxxxxxxx',
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _emailCtrl,
              label: 'Email',
              hint: 'name@example.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final ok = RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim());
                return ok ? null : 'Invalid email';
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _genderChips(),
          ],
        ),
        const SizedBox(height: 16),
        _section(
          'Tenant Type & Preferences',
          [
            _dropdown(
              label: 'Tenant Type',
              value: _tenantType,
              items: const ['Student', 'Bachelor', 'Family', 'Professional'],
              onChanged: (v) {
                if (v == null) return;
                HapticFeedback.selectionClick();
                setState(() => _tenantType = v);
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Food Preference',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Vegetarian'),
                  selected: _foodPreference == 'Vegetarian',
                  onSelected: (selected) {
                    if (selected) {
                      HapticFeedback.selectionClick();
                      setState(() => _foodPreference = 'Vegetarian');
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Non-Vegetarian'),
                  selected: _foodPreference == 'Non-Vegetarian',
                  onSelected: (selected) {
                    if (selected) {
                      HapticFeedback.selectionClick();
                      setState(() => _foodPreference = 'Non-Vegetarian');
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Both'),
                  selected: _foodPreference == 'Both',
                  onSelected: (selected) {
                    if (selected) {
                      HapticFeedback.selectionClick();
                      setState(() => _foodPreference = 'Both');
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeaseDetailsTab() {
    // Set billing date to 1st of current month if not set
    if (_billingDate == null) {
      final now = DateTime.now();
      _billingDate = DateTime(now.year, now.month, 1);
    }
    
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _section(
          'Billing Cycle',
          [
            _dropdown(
              label: 'Payment Cycle',
              value: _paymentCycle,
              items: const ['Daily', 'Weekly', 'Monthly', 'Quarterly', 'Yearly'],
              onChanged: (v) {
                if (v == null) return;
                HapticFeedback.selectionClick();
                setState(() => _paymentCycle = v);
              },
            ),
            const SizedBox(height: 12),
            _selectorTile(
              label: 'Billing Date',
              value: _billingDate != null
                  ? '${_formatDayOrdinal(_billingDate!.day)} of every month'
                  : '1st of every month',
              icon: Icons.calendar_month,
              onTap: () => _pickBillingDate(),
            ),
            const SizedBox(height: 12),
            _selectorTile(
              label: 'Move-in Date',
              value: _moveInDate != null
                  ? '${_moveInDate!.day}/${_moveInDate!.month}/${_moveInDate!.year}'
                  : 'Select date',
              icon: Icons.event_outlined,
              onTap: () => _pickDate(true),
            ),
            const SizedBox(height: 12),
            _selectorTile(
              label: 'Move-out Date',
              value: _moveOutDate != null
                  ? '${_moveOutDate!.day}/${_moveOutDate!.month}/${_moveOutDate!.year}'
                  : 'Select date',
              icon: Icons.event_outlined,
              onTap: () => _pickDate(false),
            ),
            const SizedBox(height: 12),
          ],
        ),
        const SizedBox(height: 16),
        _section(
          'Financial Details',
          [
            _textField(
              controller: _rentCtrl,
              label: 'Monthly Rent (₹)',
              hint: 'e.g. 6500',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) =>
              v == null || v.trim().isEmpty ? 'Required' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _depositCtrl,
              label: 'Security Deposit (₹)',
              hint: 'e.g. 13000',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) =>
              v == null || v.trim().isEmpty ? 'Required' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _maintenanceCtrl,
              label: 'Maintenance (₹)',
              hint: 'e.g. 500',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _section(
          'Lease Terms',
          [
            _textField(
              controller: _durationMonthsCtrl,
              label: 'Lease Duration (months)',
              hint: 'e.g. 12',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) =>
              v == null || v.trim().isEmpty ? 'Required' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _lockInPeriodCtrl,
              label: 'Lock-in Period (months)',
              hint: 'e.g. 3',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _noticePeriodCtrl,
              label: 'Notice Period (days)',
              hint: 'e.g. 30',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _dropdown(
              label: 'Rent Billing Type',
              value: _rentBillingType,
              items: const ['Manual', 'Daily', 'Weekly', 'Monthly'],
              onChanged: (v) {
                if (v == null) return;
                HapticFeedback.selectionClick();
                setState(() => _rentBillingType = v);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBillTab() {
    // Calculate prorated rent if move-in is mid-month
    double monthlyRent = double.tryParse(_rentCtrl.text.trim()) ?? 0.0;
    double securityDeposit = double.tryParse(_depositCtrl.text.trim()) ?? 0.0;
    double maintenance = double.tryParse(_maintenanceCtrl.text.trim()) ?? 0.0;
    
    // Check if maintenance is deducted from deposit
    bool maintenanceDeductedFromDeposit = false;
    if (_selectedPropertyObj != null) {
      maintenanceDeductedFromDeposit = _selectedPropertyObj!.pricing.maintenanceDeductedFromDeposit;
    }
    
    // First, apply food deduction to monthly rent if food addon is unchecked
    // Food deduction is based on monthly amount, not prorated
    double monthlyFoodDeduction = 0.0;
    if (!_foodAddon) {
      monthlyFoodDeduction = double.tryParse(_foodDeductionCtrl.text.trim()) ?? 0.0;
    }
    
    // Calculate adjusted monthly rent (after food deduction)
    double adjustedMonthlyRent = (monthlyRent - monthlyFoodDeduction).clamp(0.0, double.infinity);
    
    // Calculate prorated rent based on move-in date
    // Rule: 1-15 = full month, 16-31 = half month
    String proratedExplanation = '';
    double calculatedProratedRent = 0.0;
    
    if (_moveInDate != null && adjustedMonthlyRent > 0) {
      final moveIn = _moveInDate!;
      final moveInDay = moveIn.day;
      
      if (moveInDay >= 1 && moveInDay <= 15) {
        // Full month rent
        calculatedProratedRent = adjustedMonthlyRent;
        proratedExplanation = 'Full month rent (move-in date: ${moveIn.day}/${moveIn.month}/${moveIn.year} - between 1st to 15th)';
      } else if (moveInDay >= 16 && moveInDay <= 31) {
        // Half month rent
        calculatedProratedRent = adjustedMonthlyRent / 2;
        proratedExplanation = 'Half month rent (move-in date: ${moveIn.day}/${moveIn.month}/${moveIn.year} - between 16th to end of month)';
      } else {
        // Fallback (shouldn't happen, but just in case)
        calculatedProratedRent = adjustedMonthlyRent;
        proratedExplanation = 'Full month rent';
      }
      
      // Auto-fill controller with calculated value if it's empty or matches previous calculation
      // This allows manual editing while still auto-calculating when move-in date changes
      final currentProratedRent = double.tryParse(_proratedRentCtrl.text.trim()) ?? 0.0;
      if (_proratedRentCtrl.text.trim().isEmpty || 
          (currentProratedRent == 0.0 && calculatedProratedRent > 0)) {
        _proratedRentCtrl.text = calculatedProratedRent.toStringAsFixed(2);
      }
    } else if (adjustedMonthlyRent > 0) {
      // If no move-in date but monthly rent is set, use full month
      calculatedProratedRent = adjustedMonthlyRent;
      if (_proratedRentCtrl.text.trim().isEmpty) {
        _proratedRentCtrl.text = calculatedProratedRent.toStringAsFixed(2);
      }
    }
    
    // Use prorated rent from controller (user can edit it)
    double proratedRent = double.tryParse(_proratedRentCtrl.text.trim()) ?? calculatedProratedRent;
    if (proratedRent == 0.0 && calculatedProratedRent > 0) {
      proratedRent = calculatedProratedRent;
    }
    
    // Store base prorated rent for display (before any additional deductions)
    
    // Calculate total - charge FULL security deposit now
    // Maintenance will be deducted from security deposit refund when tenant vacates
    // Security deposit is only added if "pay now" is selected
    double totalFirstMonth = proratedRent;
    if (_paySecurityDepositNow) {
      // Always charge full security deposit
      totalFirstMonth += securityDeposit;
    }
    
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _section(
          'First Month Charges',
          [
            if (_moveInDate == null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Please select move-in date in Lease tab to calculate charges.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Prorated Rent - Editable
              _textField(
                controller: _proratedRentCtrl,
                label: 'Prorated Rent (₹)',
                hint: 'Enter prorated rent amount',
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final value = double.tryParse(v.trim());
                  if (value == null || value < 0) return 'Invalid amount';
                  return null;
                },
              ),
              if (proratedExplanation.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          proratedExplanation,
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Show food deduction calculation if applicable
              if (!_foodAddon && monthlyFoodDeduction > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.restaurant, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Food Deduction Applied',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Monthly Rent: ₹${monthlyRent.toStringAsFixed(2)} - Food Deduction: ₹${monthlyFoodDeduction.toStringAsFixed(2)} = Adjusted Monthly Rent: ₹${adjustedMonthlyRent.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(),
              // Food Addon - Default checked, with deduction option when unchecked
              CheckboxListTile(
                title: const Text('Food Addon'),
                subtitle: Text(
                  _foodAddon
                      ? 'Food included in rent'
                      : 'Food not included - deduction will be applied',
                ),
                value: _foodAddon,
                onChanged: (value) {
                  setState(() {
                    _foodAddon = value ?? true;
                    if (!_foodAddon && _foodDeductionCtrl.text.trim().isEmpty) {
                      // Suggest a default deduction (e.g., 10% of monthly rent or a fixed amount)
                      final monthlyRent = double.tryParse(_rentCtrl.text.trim()) ?? 0.0;
                      if (monthlyRent > 0) {
                        // Default to 10% of monthly rent as deduction
                        _foodDeductionCtrl.text = (monthlyRent * 0.1).toStringAsFixed(2);
                      }
                    }
                    // Recalculate prorated rent when food addon changes
                    _recalculateProratedRent();
                  });
                },
                secondary: Icon(
                  _foodAddon ? Icons.restaurant : Icons.restaurant_outlined,
                  color: _foodAddon ? Colors.green : Colors.grey,
                ),
              ),
              // Show deduction field when food addon is unchecked
              if (!_foodAddon) ...[
                const SizedBox(height: 8),
                _textField(
                  controller: _foodDeductionCtrl,
                  label: 'Food Deduction Amount (₹)',
                  hint: 'Enter amount to deduct from monthly rent',
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  validator: (v) {
                    if (!_foodAddon && (v == null || v.trim().isEmpty)) {
                      return 'Required when food is not included';
                    }
                    if (v != null && v.trim().isNotEmpty) {
                      final value = double.tryParse(v.trim());
                      if (value == null || value < 0) return 'Invalid amount';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              const Divider(),
              // Security Deposit - Selectable (pay now or later)
              CheckboxListTile(
                title: const Text('Security Deposit'),
                subtitle: Text(
                  _paySecurityDepositNow
                      ? '₹${securityDeposit.toStringAsFixed(2)} (Pay now)'
                      : '₹${securityDeposit.toStringAsFixed(2)} (Pay later)',
                ),
                value: _paySecurityDepositNow,
                onChanged: (value) {
                  setState(() {
                    _paySecurityDepositNow = value ?? true;
                  });
                },
                secondary: Icon(
                  _paySecurityDepositNow ? Icons.payment : Icons.payment_outlined,
                  color: _paySecurityDepositNow ? Colors.green : Colors.grey,
                ),
              ),
              // Maintenance - Show info that it will be deducted at vacating
              if (maintenance > 0 && maintenanceDeductedFromDeposit) ...[
                const Divider(),
                ListTile(
                  title: const Text('Maintenance'),
                  subtitle: const Text(
                    'Will be deducted from security deposit refund at vacating',
                  ),
                  trailing: Text(
                    '₹${maintenance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Note: Full security deposit (₹${securityDeposit.toStringAsFixed(2)}) is charged now. Maintenance (₹${maintenance.toStringAsFixed(2)}) will be deducted from the refund when tenant vacates. Refund amount: ₹${(securityDeposit - maintenance).toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 2, thickness: 2),
              ListTile(
                title: const Text(
                  'Total First Month Charge',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                trailing: Text(
                  '₹${totalFirstMonth.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calculate, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Breakdown',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildBreakdownRow('Monthly Rent', monthlyRent),
                    if (!_foodAddon && monthlyFoodDeduction > 0) ...[
                      _buildBreakdownRow('Less: Food Deduction', monthlyFoodDeduction, note: 'Food not included (monthly)'),
                      _buildBreakdownRow('Adjusted Monthly Rent', adjustedMonthlyRent),
                    ] else if (_foodAddon)
                      _buildBreakdownRow('Food Included', 0.0, note: 'No deduction'),
                    if (_moveInDate != null) ...[
                      if (_moveInDate!.day >= 1 && _moveInDate!.day <= 15)
                        _buildBreakdownRow('Prorated Rent (Full Month)', proratedRent, note: 'Move-in between 1st-15th: Full month charged')
                      else if (_moveInDate!.day >= 16 && _moveInDate!.day <= 31)
                        _buildBreakdownRow('Prorated Rent (Half Month)', proratedRent, note: 'Move-in between 16th-31st: Half month charged')
                    ] else
                      _buildBreakdownRow('Prorated Rent', proratedRent),
                    if (_paySecurityDepositNow)
                      _buildBreakdownRow('Security Deposit', securityDeposit)
                    else
                      _buildBreakdownRow('Security Deposit', 0.0, note: '(Pay later)'),
                    if (maintenanceDeductedFromDeposit && maintenance > 0)
                      _buildBreakdownRow('Maintenance', 0.0, note: '₹${maintenance.toStringAsFixed(2)} (deducted from refund at vacating)'),
                    const Divider(height: 24),
                    _buildBreakdownRow('Total', totalFirstMonth, isTotal: true),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, double amount, {bool isTotal = false, String? note}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  fontSize: isTotal ? 16 : 14,
                ),
              ),
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  fontSize: isTotal ? 18 : 14,
                  color: isTotal ? Colors.green.shade700 : null,
                ),
              ),
            ],
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 2.0),
              child: Text(
                note,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonalDetailsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _section(
          'Personal Information',
          [
            _textField(
              controller: _dobCtrl,
              label: 'Date of Birth',
              hint: 'DD/MM/YYYY',
              keyboardType: TextInputType.datetime,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _currentAddressCtrl,
              label: 'Current Address',
              hint: 'Full address',
              maxLines: 3,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _nationalityCtrl,
              label: 'Nationality',
              hint: 'e.g. Indian',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _motherTongueCtrl,
              label: 'Mother Tongue',
              hint: 'e.g. Hindi',
              textInputAction: TextInputAction.next,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _section(
          'Identification',
          [
            _textField(
              controller: _aadharCtrl,
              label: 'Aadhar Number',
              hint: 'XXXX XXXX XXXX',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _dropdown(
              label: 'ID Type',
              value: _idType,
              items: const ['Aadhaar', 'PAN', 'Passport', 'Driving License'],
              onChanged: (v) {
                if (v == null) return;
                HapticFeedback.selectionClick();
                setState(() => _idType = v);
              },
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _idNumberCtrl,
              label: 'ID Number',
              hint: 'Enter ID number',
              validator: (v) =>
              v == null || v.trim().isEmpty ? 'Required' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _addressCtrl,
              label: 'Address (from ID)',
              hint: 'Full address',
              maxLines: 3,
              validator: (v) =>
              v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'ID proof upload placeholder. Integrate file picker.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Attach ID Proof'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _section(
          'Office/Institute Details',
          [
            _textField(
              controller: _officeInstituteNameCtrl,
              label: 'Office/Institute Name',
              hint: 'e.g. ABC Corporation',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _officeInstituteIdCtrl,
              label: 'Office/Institute ID',
              hint: 'e.g. EMP123456',
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectorTile({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return ListTile(
      dense: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      leading: Icon(icon, color: Colors.teal),
      title: Text(label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          )),
      subtitle: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  String _normalizeIdType(String idType) {
    if (idType.isEmpty) return 'Aadhaar';
    
    final normalized = idType.toLowerCase().trim();
    
    // Map various idType formats to dropdown options
    if (normalized.contains('aadhar') || normalized.contains('aadhaar')) {
      return 'Aadhaar';
    } else if (normalized.contains('pan')) {
      return 'PAN';
    } else if (normalized.contains('passport')) {
      return 'Passport';
    } else if (normalized.contains('driving') || normalized.contains('license')) {
      return 'Driving License';
    }
    
    // Default to Aadhaar if no match
    return 'Aadhaar';
  }

  String _formatDayOrdinal(int day) {
    if (day <= 0) return day.toString();
    final mod100 = day % 100;
    final mod10 = day % 10;
    String suffix;
    if (mod10 == 1 && mod100 != 11) {
      suffix = 'st';
    } else if (mod10 == 2 && mod100 != 12) {
      suffix = 'nd';
    } else if (mod10 == 3 && mod100 != 13) {
      suffix = 'rd';
    } else {
      suffix = 'th';
    }
    return '$day$suffix';
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    // Ensure value is in items list, otherwise use first item or null
    final validValue = items.contains(value) ? value : (items.isNotEmpty ? items.first : null);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: validValue,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    TextInputAction? textInputAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          textInputAction: textInputAction,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _genderChips() {
    final options = ['Male', 'Female', 'Other'];
    return Wrap(
      spacing: 8,
      children: options.map((g) {
        final sel = _gender == g;
        return ChoiceChip(
          label: Text(g),
          selected: sel,
          onSelected: (s) {
            if (!s) return;
            HapticFeedback.selectionClick();
            setState(() => _gender = g);
          },
        );
      }).toList(),
    );
  }

  Widget _checkboxTile({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
  

  Widget _legendSwatch(Color bg, Color fg, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: fg.withOpacity(0.5)),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.grey.shade700)),
      ],
    );
  }
}


