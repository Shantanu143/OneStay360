import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:models/business/tenant_model.dart' as biz;
import 'package:firebase_services/services/firestore_service.dart';

class AddTenantViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AddTenantViewModel({
    FirestoreService? firestoreService,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _firestoreService = firestoreService ?? FirestoreService(),
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  // Form controllers
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController monthlyRentController = TextEditingController();
  final TextEditingController genderController = TextEditingController(); // for gender lock enforcement

  // Assignment selections
  String? selectedPropertyId;
  String? selectedRoomId;
  int? selectedBedIndex; // 0-based

  // Dates
  DateTime? moveInDate;
  DateTime? moveOutDate;

  // UI state
  bool isSubmitting = false;
  String? errorMessage;

  // Optional: preload from screen params
  void preload({String? propertyId}) {
    selectedPropertyId = propertyId ?? selectedPropertyId;
    notifyListeners();
  }

  void updateProperty(String? propertyId) {
    selectedPropertyId = propertyId;
    // Reset dependent selections
    selectedRoomId = null;
    selectedBedIndex = null;
    notifyListeners();
  }

  void updateRoom(String? roomId) {
    selectedRoomId = roomId;
    selectedBedIndex = null;
    notifyListeners();
  }

  void updateBed(int? bedIndex) {
    selectedBedIndex = bedIndex;
    notifyListeners();
  }

  void setMoveInDate(DateTime date) {
    moveInDate = date;
    notifyListeners();
  }

  void setMoveOutDate(DateTime? date) {
    moveOutDate = date;
    notifyListeners();
  }

  bool get isValidForm {
    if (fullNameController.text.trim().isEmpty) return false;
    if (phoneController.text.trim().length < 10) return false;
    if (selectedPropertyId == null || selectedPropertyId!.isEmpty) return false;
    if (selectedRoomId == null || selectedRoomId!.isEmpty) return false;
    if (selectedBedIndex == null) return false;
    if (moveInDate == null) return false;
    if (monthlyRentController.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> submit(BuildContext context) async {
    errorMessage = null;
    if (!isValidForm) {
      errorMessage = 'Please complete all required fields.';
      notifyListeners();
      return;
    }

    try {
      isSubmitting = true;
      notifyListeners();

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Not authenticated');
      }

      final businessId = await _firestoreService.getBusinessId(user.uid);
      if (businessId == null || businessId.isEmpty) {
        throw Exception('Business account not found');
      }

      // Generate actual tenantId (TEN...)
      final tenantId = await _firestoreService.generateTenantId();
      final tenantDocRef = _firestore.collection('tenants').doc(tenantId);

      // Build model
      final tenant = biz.Tenant(
        id: tenantId,
        name: fullNameController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
        propertyId: selectedPropertyId!,
        roomId: selectedRoomId!,
        bedId: (selectedBedIndex! + 1).toString(),
        checkInDate: moveInDate!,
        checkOutDate: moveOutDate,
        monthlyRent: double.tryParse(monthlyRentController.text.trim()) ?? 0,
        status: 'active',
      );

      // ── Gender lock enforcement ──
      // Read the room document to check if it's gender-locked.
      final roomDoc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('properties')
          .doc(selectedPropertyId!)
          .collection('rooms')
          .doc(selectedRoomId!)
          .get();

      final roomGender = roomDoc.data()?['gender'] as String?;
      final tenantGender = genderController?.text.trim(); // from form if available

      if (roomGender != null && roomGender.isNotEmpty &&
          tenantGender != null && tenantGender.isNotEmpty &&
          roomGender != tenantGender) {
        throw Exception(
          'Room $selectedRoomId is reserved for $roomGender tenants only. '
          'This tenant is $tenantGender.',
        );
      }

      final now = FieldValue.serverTimestamp();

      // Batched write: tenant master + business subcollection + bed status
      await _firestore.runTransaction((transaction) async {
        // 1) Master tenant doc
        transaction.set(tenantDocRef, {
          ...tenant.toMap(),
          'tenantId': tenantId, // Friendly TEN... ID
          'createdAt': now,
          'updatedAt': now,
        });

        // 2) Business scoped tenants
        final bizTenantRef = _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('tenants')
            .doc(tenantId);
        transaction.set(bizTenantRef, {
          ...tenant.toMap(),
          'tenantId': tenantId, // Friendly TEN... ID
          'businessId': businessId,
          'createdAt': now,
          'updatedAt': now,
        });

        // 3) Mark bed occupancy (Correct path: .../rooms/{roomId}/beds/{bedId})
        final bedId = (selectedBedIndex! + 1).toString();
        final bedRef = _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('properties')
            .doc(selectedPropertyId!)
            .collection('rooms')
            .doc(selectedRoomId!)
            .collection('beds')
            .doc(bedId);
        
        transaction.set(bedRef, {
          'occupied': true,
          'isOccupied': true,
          'tenantId': tenantId,
          'tenantName': tenant.name,
          'occupiedAt': now,
          'updatedAt': now,
        }, SetOptions(merge: true));

        // 4) Update property occupancy count
        final propertyRef = _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('properties')
            .doc(selectedPropertyId!);
        
        transaction.update(propertyRef, {
          'occupiedBeds': FieldValue.increment(1),
          'updatedAt': now,
        });
      });

    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    fullNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    monthlyRentController.dispose();
    super.dispose();
  }
}




