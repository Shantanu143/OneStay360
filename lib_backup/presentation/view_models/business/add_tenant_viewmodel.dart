import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:onestay360/data/models/business/tenant_model.dart' as biz;
import 'package:onestay360/presentation/services/firestore_service.dart';

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

      // Create a tenant document id
      final tenantDocRef = _firestore.collection('tenants').doc();
      final tenantId = tenantDocRef.id;

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

      // Batched write: tenant master + business subcollection reference
      final batch = _firestore.batch();

      // 1) Master tenant doc
      batch.set(tenantDocRef, tenant.toMap());

      // 2) Business scoped tenants
      final bizTenantRef = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('tenants')
          .doc(tenantId);
      batch.set(bizTenantRef, {
        ...tenant.toMap(),
        'businessId': businessId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3) Optional: mark bed occupancy under property path (if you maintain rooms/beds per property)
      // Safe no-op if path not used by current schema.
      final occupancyRef = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('properties')
          .doc(selectedPropertyId!)
          .collection('rooms')
          .doc(selectedRoomId!);
      batch.set(occupancyRef, {
        'lastUpdated': FieldValue.serverTimestamp(),
        'beds': {
          // Store bed assignment minimally; adapt to your room schema if needed
          (selectedBedIndex! + 1).toString(): {
            'occupied': true,
            'tenantId': tenantId,
            'since': FieldValue.serverTimestamp(),
          },
        },
      }, SetOptions(merge: true));

      await batch.commit();

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


