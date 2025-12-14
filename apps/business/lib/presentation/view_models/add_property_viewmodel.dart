import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:models/business/property/property_model.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:firebase_services/services/image_service.dart';
import 'package:models/business/property/meal_enum.dart';
import 'package:models/business/property/property_pricing_model.dart';
import 'package:models/business/property/property_room_model.dart';
import 'package:models/business/property/property_amenities_model.dart';
import 'package:models/business/property/property_food_plan_model.dart';
import 'package:models/business/property/property_rules_model.dart';
import 'package:models/business/property/property_totals_model.dart';
import 'package:models/business/property/property_rating_model.dart';

class AddPropertyViewModel extends ChangeNotifier {
  final ImageService _imageService;
  final PropertyRepository _propertyRepository;

  List<XFile> _selectedImages = [];
  List<String> _uploadedImageUrls = [];
  bool _isUploadingImages = false;
  bool _isLoading = false;
  int? _expandedRoomIndex; // Add this for room expansion state

  // Form controllers
  final TextEditingController propertyNameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController landmarksController = TextEditingController();
  final TextEditingController googleMapsLinkController = TextEditingController();
  final TextEditingController numberOfFloorsController = TextEditingController();
  final TextEditingController maxSharingController = TextEditingController();
  final TextEditingController securityDepositController = TextEditingController();
  final TextEditingController oneTimeMaintenanceChargeController = TextEditingController();
  final TextEditingController noticePeriodController = TextEditingController();
  final TextEditingController foodNotesController = TextEditingController();

  // Dynamic pricing controllers
  List<Map<String, dynamic>> sharingRows = [];

  // Form state
  String? selectedCity;
  final List<Map<String, dynamic>> roomDetails = [];
  bool hasWifi = false;
  bool hasAC = false;
  bool hasLaundry = false;
  bool hasFood = false;
  bool hasParking = false;
  bool hasGeyser = false;
  bool hasPowerBackup = false;
  bool hasCCTV = false;
  bool hasHousekeeping = false;
  bool selectAllAmenities = false;
  String? genderAllowed;
  bool hasCurfew = false;
  bool visitorsAllowed = false;
  bool smokingAllowed = false;
  bool alcoholAllowed = false;
  bool isMaintenanceDeductedFromDeposit = false;

  // Food plan
  final List<String> days = const [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  late Map<String, Set<Meal>> weeklyMeals;

  // Cities data
  final Map<String, String> cities = {
    'Pune': 'PNR',
    'Mumbai': 'MBR',
    'Bangalore': 'BLR',
    'Chennai': 'CHR',
    'Delhi': 'DLR',
    'Noida': 'NPR',
    'Gurgaon': 'GRR',
    'Kolkata': 'KTR',
    'Kochi': 'KCR',
  };

  AddPropertyViewModel({
    required ImageService imageService,
    required PropertyRepository propertyRepository,
  }) : _imageService = imageService, _propertyRepository = propertyRepository {
    weeklyMeals = {for (final day in days) day: <Meal>{}};

    // Listen to max sharing changes to update dynamic pricing rows
    maxSharingController.addListener(_updateSharingRows);
  }

  // Getters
  bool get isLoading => _isLoading;
  bool get isUploadingImages => _isUploadingImages;
  List<XFile> get selectedImages => _selectedImages;
  List<String> get uploadedImageUrls => _uploadedImageUrls;
  int get currentMaxSharing => int.tryParse(maxSharingController.text.trim()) ?? 0;
  int? get expandedRoomIndex => _expandedRoomIndex; // Add getter
  set expandedRoomIndex(int? value) { // Add setter
    _expandedRoomIndex = value;
    notifyListeners();
  }

  void _updateSharingRows() {
    final max = currentMaxSharing;

    // Remove extra rows
    while (sharingRows.length > max && sharingRows.isNotEmpty) {
      final removed = sharingRows.removeLast();
      (removed['nonAcController'] as TextEditingController).dispose();
      (removed['acController'] as TextEditingController).dispose();
    }

    // Add new rows
    for (int s = sharingRows.length + 1; s <= max; s++) {
      sharingRows.add({
        'sharing': s,
        'nonAcController': TextEditingController(),
        'acController': TextEditingController(),
      });
    }

    notifyListeners();
  }

  @override
  void dispose() {
    propertyNameController.dispose();
    addressController.dispose();
    pincodeController.dispose();
    descriptionController.dispose();
    landmarksController.dispose();
    googleMapsLinkController.dispose();
    numberOfFloorsController.dispose();
    maxSharingController.dispose();
    securityDepositController.dispose();
    oneTimeMaintenanceChargeController.dispose();
    noticePeriodController.dispose();
    foodNotesController.dispose();

    // Dispose dynamic pricing controllers
    for (final row in sharingRows) {
      (row['nonAcController'] as TextEditingController).dispose();
      (row['acController'] as TextEditingController).dispose();
    }

    // Dispose room controllers
    for (final room in roomDetails) {
      (room['roomNumberController'] as TextEditingController).dispose();
    }

    super.dispose();
  }

  // Image handling
  Future<void> pickImages() async { // Renamed from pickAndUploadImages
    try {
      final images = await _imageService.pickImages();
      if (images.isNotEmpty) {
        _selectedImages = images;
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Error selecting images: ${e.toString()}');
    }
  }

  void removeImageAt(int index) {
    if (index >= 0 && index < _selectedImages.length) {
      _selectedImages.removeAt(index);
      notifyListeners();
    }
  }

  // Room management
  void addRoom() {
    final defaultSharing = currentMaxSharing > 0 ? currentMaxSharing : null;
    roomDetails.add({
      'roomNumberController': TextEditingController(),
      'floor': null,
      'sharingType': defaultSharing,
      'hasAC': false,
    });
    _expandedRoomIndex = roomDetails.length - 1; // Expand the new room
    notifyListeners();
  }

  void removeRoom(int index) {
    if (index >= 0 && index < roomDetails.length) {
      (roomDetails[index]['roomNumberController'] as TextEditingController).dispose();
      roomDetails.removeAt(index);
      if (_expandedRoomIndex != null) {
        if (roomDetails.isEmpty) {
          _expandedRoomIndex = null;
        } else {
          _expandedRoomIndex = (_expandedRoomIndex!.clamp(0, roomDetails.length - 1));
        }
      }
      notifyListeners();
    }
  }

  int getTotalRooms() => roomDetails.length;

  int getTotalBeds() {
    int total = 0;
    for (final room in roomDetails) {
      final st = room['sharingType'] as int? ?? 1;
      total += st;
    }
    return total;
  }

  // Amenities
  void toggleSelectAllAmenities(bool value) { // Changed parameter type
    selectAllAmenities = value;
    hasWifi = value;
    hasAC = value;
    hasLaundry = value;
    hasFood = value;
    hasParking = value;
    hasGeyser = value;
    hasPowerBackup = value;
    hasCCTV = value;
    hasHousekeeping = value;

    if (hasFood) {
      applyPresetWeekdayBF_DinnerWeekendAll();
    } else {
      clearFoodPlan();
    }
    notifyListeners();
  }

  // Add missing methods for updating individual amenities and rules
  void updateAmenity(String type, bool value) {
    switch (type) {
      case 'wifi':
        hasWifi = value;
        break;
      case 'ac':
        hasAC = value;
        break;
      case 'laundry':
        hasLaundry = value;
        break;
      case 'food':
        hasFood = value;
        if (hasFood && weeklyMeals.values.every((s) => s.isEmpty)) {
          applyPresetWeekdayBF_DinnerWeekendAll();
        }
        if (!hasFood) clearFoodPlan();
        break;
      case 'parking':
        hasParking = value;
        break;
      case 'geyser':
        hasGeyser = value;
        break;
      case 'powerBackup':
        hasPowerBackup = value;
        break;
      case 'cctv':
        hasCCTV = value;
        break;
      case 'housekeeping':
        hasHousekeeping = value;
        break;
    }
    notifyListeners();
  }

  void updateRule(String type, bool value) {
    switch (type) {
      case 'curfew':
        hasCurfew = value;
        break;
      case 'visitors':
        visitorsAllowed = value;
        break;
      case 'smoking':
        smokingAllowed = value;
        break;
      case 'alcohol':
        alcoholAllowed = value;
        break;
    }
    notifyListeners();
  }

  // Food plan methods
  void toggleMeal(String day, Meal meal) {
    final set = weeklyMeals[day]!;
    if (set.contains(meal)) {
      set.remove(meal);
    } else {
      set.add(meal);
    }
    notifyListeners();
  }

  void clearDayMeals(String day) { // Add this missing method
    weeklyMeals[day] = <Meal>{};
    notifyListeners();
  }

  void applyPresetAllMealsAllDays() {
    for (final day in days) {
      weeklyMeals[day] = {Meal.breakfast, Meal.lunch, Meal.dinner};
    }
    foodNotesController.text = 'All meals (Breakfast, Lunch, Dinner) provided daily.';
    notifyListeners();
  }

  void applyPresetWeekdayBF_DinnerWeekendAll() {
    for (final day in days) {
      weeklyMeals[day] = <Meal>{};
    }
    for (int i = 0; i < 5; i++) {
      weeklyMeals[days[i]] = {Meal.breakfast, Meal.dinner};
    }
    weeklyMeals['Saturday'] = {Meal.breakfast, Meal.lunch, Meal.dinner};
    weeklyMeals['Sunday'] = {Meal.breakfast, Meal.lunch, Meal.dinner};
    foodNotesController.text = 'Mon-Fri: Breakfast & Dinner; Sat-Sun: Breakfast, Lunch & Dinner.';
    notifyListeners();
  }

  void clearFoodPlan() {
    for (final day in days) {
      weeklyMeals[day] = <Meal>{};
    }
    foodNotesController.clear();
    notifyListeners();
  }

  String sharingLabel(int? sharingType) { // Add this missing method
    if (sharingType == null) return '';
    return switch (sharingType) {
      1 => 'Single',
      2 => 'Double',
      3 => 'Triple',
      _ => '$sharingType-Sharing',
    };
  }

  Map<String, dynamic> foodPlanToJson() {
    final map = <String, dynamic>{};
    for (final day in days) {
      final meals = weeklyMeals[day]!;
      map[day] = meals
          .map((m) => switch (m) {
        Meal.breakfast => 'Breakfast',
        Meal.lunch => 'Lunch',
        Meal.dinner => 'Dinner',
      })
          .toList();
    }
    return {
      'plan': map,
      'notes': foodNotesController.text.trim(),
    };
  }

  // In AddPropertyViewModel - update the addProperty method
  Future<void> addProperty(
      String businessId,  // This should be BUS0000001, not the Firebase UID
      String businessName,
      String businessPhone,
      BuildContext context,
      ) async {

    // Add debug to check what's being passed
    debugPrint('=== DEBUG: Property Creation ===');
    debugPrint('Received Business ID: $businessId');
    debugPrint('Expected format: BUS0000001 (custom business ID)');

    if (businessId.isEmpty) {
      throw ArgumentError('Business ID cannot be empty');
    }

    // Verify it's a valid business ID format (starts with BUS)
    if (!businessId.startsWith('BUS')) {
      throw ArgumentError('Invalid business ID format. Expected BUS0000001, got: $businessId');
    }

    _isLoading = true;
    _isUploadingImages = true;
    notifyListeners();

    try {
      debugPrint('=== Starting property creation process ===');
      debugPrint('Business ID: $businessId');
      debugPrint('Business Name: $businessName');
      debugPrint('Business Phone: $businessPhone');

      // Rest of your method remains the same...

      // Reserve/generate a final property ID before uploading images so images can be stored under final path
      final cityCode = selectedCity == null ? '' : (cities[selectedCity] ?? '');
      final reservedPropertyId = await _propertyRepository.generatePropertyId(
        businessId,
        cityCode.isNotEmpty ? cityCode : 'GEN',
      );

      // Upload images using the reserved property ID
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        debugPrint('Uploading ${_selectedImages.length} images to property $reservedPropertyId...');
        try {
          imageUrls = await _imageService.uploadPropertyImages(_selectedImages, reservedPropertyId);
          _uploadedImageUrls = imageUrls;
          debugPrint('✅ Successfully uploaded ${imageUrls.length} images');
        } catch (e) {
          debugPrint('❌ Image upload error: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image upload failed: ${e.toString()}')),
          );
        }
      }

      _isUploadingImages = false;
      notifyListeners();

      // Create dynamic pricing entries
      debugPrint('Creating pricing entries...');
      final sharingPricing = sharingRows.map((row) {
        final nonAcText = (row['nonAcController'] as TextEditingController).text.trim();
        final acText = (row['acController'] as TextEditingController).text.trim();
        return SharingPricingEntry(
          sharing: row['sharing'] as int,
          nonAc: nonAcText.isEmpty ? null : int.tryParse(nonAcText),
          ac: acText.isEmpty ? null : int.tryParse(acText),
        );
      }).toList();

      debugPrint('Pricing entries created: ${sharingPricing.length}');

      // Create property model - ID will be generated by repository
      final property = Property(
        id: reservedPropertyId,
        name: propertyNameController.text.trim(),
        address: addressController.text.trim(),
        city: selectedCity ?? '',
        cityCode: selectedCity == null ? '' : cities[selectedCity] ?? '',
        pincode: pincodeController.text.trim(),
        numberOfFloors: int.tryParse(numberOfFloorsController.text.trim()) ?? 0,
        description: descriptionController.text.trim(),
        landmarks: landmarksController.text.trim(),
        googleMapsLink: googleMapsLinkController.text.trim(),
        pricing: PropertyPricing(
          single: 0,
          double: 0,
          triple: 0,
          securityDeposit: int.tryParse(securityDepositController.text.trim()) ?? 0,
          oneTimeMaintenance: int.tryParse(oneTimeMaintenanceChargeController.text.trim()) ?? 0,
          maintenanceDeductedFromDeposit: isMaintenanceDeductedFromDeposit,
          sharing: sharingPricing,
          maxSharing: currentMaxSharing,
        ),
        rooms: roomDetails
            .map((room) => PropertyRoom(
          roomNumber: (room['roomNumberController'] as TextEditingController).text.trim(),
          floor: room['floor']?.toString() ?? 'Ground',
          occupancyType: sharingLabel(room['sharingType'] as int?),
          sharingType: room['sharingType'] as int?,
          hasAC: room['hasAC'] as bool? ?? false,
          status: 'available',
        ))
            .toList(),
        amenities: PropertyAmenities(
          wifi: hasWifi,
          ac: hasAC,
          laundry: hasLaundry,
          foodIncluded: hasFood,
          parking: hasParking,
          geyser: hasGeyser,
          powerBackup: hasPowerBackup,
          cctv: hasCCTV,
          housekeeping: hasHousekeeping,
        ),
        foodPlan: hasFood ? PropertyFoodPlan.fromMap(foodPlanToJson()) : null,
        rules: PropertyRules(
          genderAllowed: genderAllowed ?? 'Co-ed',
          curfew: hasCurfew,
          visitorsAllowed: visitorsAllowed,
          smokingAllowed: smokingAllowed,
          alcoholAllowed: alcoholAllowed,
          noticePeriodDays: int.tryParse(noticePeriodController.text.trim()) ?? 30,
        ),
        totals: PropertyTotals(
          rooms: getTotalRooms(),
          beds: getTotalBeds(),
          availableBeds: getTotalBeds(),
        ),
        images: imageUrls,
        rating: PropertyRating(average: 0, count: 0),
        status: 'active',
        businessId: businessId, // This should be BUS0000001
        businessName: businessName,
        businessPhone: businessPhone,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Validate property data
      debugPrint('Validating property data...');
      if (property.name.isEmpty) throw Exception('Property name is required');
      if (property.address.isEmpty) throw Exception('Property address is required');
      if (property.city.isEmpty) throw Exception('City is required');
      if (property.pincode.isEmpty) throw Exception('Pincode is required');
      if (currentMaxSharing <= 0) throw Exception('Max sharing must be greater than 0');
      if (property.rooms.isEmpty) throw Exception('At least one room is required');

      debugPrint('✅ Property validation passed');
      debugPrint('Saving to Firestore...');

      // Save to Firestore - repository will generate the proper ID
      await _propertyRepository.addProperty(property);

      debugPrint('✅ Property saved to Firestore successfully!');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property added successfully!')),
      );

      resetForm();

    } catch (e) {
      debugPrint('❌ Error adding property: $e');
      debugPrint('Stack trace: ${e.toString()}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add property: ${e.toString()}')),
      );
      rethrow;
    } finally {
      _isLoading = false;
      _isUploadingImages = false;
      notifyListeners();
    }
  }

  // (removed duplicate sharing label helper)

  void resetForm() {
    propertyNameController.clear();
    addressController.clear();
    pincodeController.clear();
    descriptionController.clear();
    landmarksController.clear();
    googleMapsLinkController.clear();
    numberOfFloorsController.clear();
    maxSharingController.clear();
    securityDepositController.clear();
    oneTimeMaintenanceChargeController.clear();
    noticePeriodController.clear();
    foodNotesController.clear();

    // Clear dynamic pricing
    for (final row in sharingRows) {
      (row['nonAcController'] as TextEditingController).clear();
      (row['acController'] as TextEditingController).clear();
    }

    // Clear rooms
    for (final room in roomDetails) {
      (room['roomNumberController'] as TextEditingController).dispose();
    }
    roomDetails.clear();

    // Reset other fields
    selectedCity = null;
    _selectedImages.clear();
    _uploadedImageUrls.clear();
    hasWifi = false;
    hasAC = false;
    hasLaundry = false;
    hasFood = false;
    hasParking = false;
    hasGeyser = false;
    hasPowerBackup = false;
    hasCCTV = false;
    hasHousekeeping = false;
    selectAllAmenities = false;
    genderAllowed = null;
    hasCurfew = false;
    visitorsAllowed = false;
    smokingAllowed = false;
    alcoholAllowed = false;
    isMaintenanceDeductedFromDeposit = false;
    _expandedRoomIndex = null;

    weeklyMeals = {for (final day in days) day: <Meal>{}};
    notifyListeners();
  }
}

