import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:models/tenant/tenant_document_model.dart';
import 'package:firebase_services/services/image_service.dart';

class TenantProfileViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ImageService _imageService;

  TenantProfileViewModel({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ImageService? imageService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _imageService = imageService ?? ImageService();

  // Dropdown options
  final List<String> nationalityOptions = [
    'Indian',
    'Other'
  ];

  final List<String> motherTongueOptions = [
    'Hindi',
    'English',
    'Bengali',
    'Telugu',
    'Marathi',
    'Tamil',
    'Gujarati',
    'Urdu',
    'Kannada',
    'Odia',
    'Malayalam',
    'Punjabi',
    'Assamese',
    'Maithili',
    'Other'
  ];

  final List<String> idTypeOptions = [
    'Aadhar Card Only'
  ];

  final List<String> genderOptions = [
    'Male',
    'Female',
    'Other'
  ];

  // Selected dropdown values
  String? selectedNationality;
  String? selectedMotherTongue;
  String? selectedIdType;
  String? selectedGender;
  DateTime? selectedDateOfBirth;

  // Editable fields - Overview Tab
  final TextEditingController nameController = TextEditingController();
  final TextEditingController mobileNumberController = TextEditingController();
  final TextEditingController alternatePhoneController = TextEditingController();
  final TextEditingController emergencyContactNameController = TextEditingController();
  final TextEditingController emergencyContactPhoneController = TextEditingController();
  final TextEditingController officeInstituteNameController = TextEditingController();
  final TextEditingController officeInstituteIdController = TextEditingController();

  // Editable fields - KYC Tab
  final TextEditingController idNumberController = TextEditingController();
  final TextEditingController addressLine1Controller = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();

  bool isSaving = false;
  String? errorMessage;
  bool isUploadingDocument = false;
  
  // Edit mode flags
  bool _isOverviewEditMode = false;
  bool _isKYCEditMode = false;
  bool _isAddressEditMode = false;
  
  bool get isOverviewEditMode => _isOverviewEditMode;
  bool get isKYCEditMode => _isKYCEditMode;
  bool get isAddressEditMode => _isAddressEditMode;
  
  void toggleOverviewEditMode() {
    _isOverviewEditMode = !_isOverviewEditMode;
    notifyListeners();
  }
  
  void toggleKYCEditMode() {
    _isKYCEditMode = !_isKYCEditMode;
    notifyListeners();
  }
  
  void toggleAddressEditMode() {
    _isAddressEditMode = !_isAddressEditMode;
    notifyListeners();
  }
  
  void exitOverviewEditMode() {
    _isOverviewEditMode = false;
    notifyListeners();
  }
  
  void exitKYCEditMode() {
    _isKYCEditMode = false;
    notifyListeners();
  }
  
  void exitAddressEditMode() {
    _isAddressEditMode = false;
    notifyListeners();
  }
  
  // Documents
  List<TenantDocument> _documents = [];
  List<TenantDocument> get documents => _documents;
  
  // QR Code data
  String? _tenantId;
  String? get tenantId => _tenantId;
  String? get qrCodeData {
    if (_tenantId == null || _tenantId!.isEmpty) return null;
    // Encode tenantId in QR code format: "onestay360:tenant:{tenantId}"
    return 'onestay360:tenant:$_tenantId';
  }
  
  // Profile completeness check
  bool get isProfileComplete {
    // Required fields for profile completion
    final hasName = nameController.text.trim().isNotEmpty;
    final hasMobile = mobileNumberController.text.trim().isNotEmpty;
    final hasGender = selectedGender != null && selectedGender!.isNotEmpty;
    final hasDateOfBirth = selectedDateOfBirth != null;
    final hasIdNumber = idNumberController.text.trim().isNotEmpty;
    final hasAddress = addressLine1Controller.text.trim().isNotEmpty &&
                      cityController.text.trim().isNotEmpty &&
                      pincodeController.text.trim().isNotEmpty;
    
    return hasName && hasMobile && hasGender && hasDateOfBirth && hasIdNumber && hasAddress;
  }

  Future<void> load() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    final tenantIdFromUser = userData['tenantId']?.toString();
    _tenantId = tenantIdFromUser;

    final Map<String, dynamic> data = Map<String, dynamic>.from(userData);
    if (tenantIdFromUser != null && tenantIdFromUser.isNotEmpty) {
      final tenantDoc = await _firestore.collection('tenants').doc(tenantIdFromUser).get();
      final tenantData = tenantDoc.data();
      if (tenantData != null) {
        data.addAll(tenantData); // Prefer tenants/{tenantId} fields when present
      }
    }

    // Overview fields - use fullName if name is not available
    nameController.text = (data['name'] ?? data['fullName'] ?? '').toString();
    mobileNumberController.text = (data['mobileNumber'] ?? data['phone'] ?? '').toString();
    alternatePhoneController.text = (data['alternatePhone'] ?? '').toString();
    emergencyContactNameController.text = (data['emergencyContactName'] ?? '').toString();
    emergencyContactPhoneController.text = (data['emergencyContactPhone'] ?? '').toString();
    officeInstituteNameController.text = (data['officeInstituteName'] ?? '').toString();
    officeInstituteIdController.text = (data['officeInstituteId'] ?? '').toString();

    // KYC fields
    selectedNationality = (data['nationality'] ?? 'Indian').toString();
    selectedMotherTongue = (data['motherTongue'] ?? 'Hindi').toString();
    selectedIdType = (data['idType'] ?? 'Aadhar Card Only').toString();
    selectedGender = (data['gender'] ?? 'Male').toString();
    idNumberController.text = (data['idNumber'] ?? '').toString();
    addressLine1Controller.text = (data['addressLine1'] ?? '').toString();
    cityController.text = (data['city'] ?? '').toString();
    pincodeController.text = (data['pincode'] ?? '').toString();

    // Load date of birth
    final dobTimestamp = data['dateOfBirth'];
    if (dobTimestamp is Timestamp) {
      selectedDateOfBirth = dobTimestamp.toDate();
    } else if (dobTimestamp is DateTime) {
      selectedDateOfBirth = dobTimestamp;
    } else {
      selectedDateOfBirth = null;
    }

    // Load documents
    await _loadDocuments(user.uid);

    notifyListeners();
  }

  Future<void> _loadDocuments(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final tenantId = userDoc.data()?['tenantId']?.toString();
      
      if (tenantId == null || tenantId.isEmpty) return;

      final docsSnapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('documents')
          .orderBy('uploadedAt', descending: true)
          .get();

      _documents = docsSnapshot.docs
          .map((doc) => TenantDocument.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error loading documents: $e');
      _documents = [];
    }
  }

  Future<void> save() async {
    errorMessage = null;
    isSaving = true;
    notifyListeners();
    
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Check profile completeness
      final profileComplete = isProfileComplete;

      final tenantUpdates = {
        // Overview fields - also update fullName for consistency
        'name': nameController.text.trim(),
        'fullName': nameController.text.trim(), // Keep both for compatibility
        'mobileNumber': mobileNumberController.text.trim(),
        'phone': mobileNumberController.text.trim(), // Keep both for compatibility
        'alternatePhone': alternatePhoneController.text.trim(),
        'emergencyContactName': emergencyContactNameController.text.trim(),
        'emergencyContactPhone': emergencyContactPhoneController.text.trim(),
        'officeInstituteName': officeInstituteNameController.text.trim(),
        'officeInstituteId': officeInstituteIdController.text.trim(),
        
        // KYC fields
        'nationality': selectedNationality,
        'motherTongue': selectedMotherTongue,
        'idType': selectedIdType,
        'gender': selectedGender,
        'dateOfBirth': selectedDateOfBirth != null ? Timestamp.fromDate(selectedDateOfBirth!) : null,
        'idNumber': idNumberController.text.trim(),
        'addressLine1': addressLine1Controller.text.trim(),
        'city': cityController.text.trim(),
        'pincode': pincodeController.text.trim(),
        'alternatePhone': alternatePhoneController.text.trim(),
        'emergencyContactName': emergencyContactNameController.text.trim(),
        'emergencyContactPhone': emergencyContactPhoneController.text.trim(),
        'officeInstituteName': officeInstituteNameController.text.trim(),
        'officeInstituteId': officeInstituteIdController.text.trim(),
        
        // Set profile complete flag
        'profileComplete': profileComplete,
        
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final userDocRef = _firestore.collection('users').doc(user.uid);
      final existingUserData = await userDocRef.get();
      final tenantId = existingUserData.data()?['tenantId']?.toString();

      // Keep /users doc minimal (identity + flags only)
      final userUpdates = {
        'name': nameController.text.trim(),
        'fullName': nameController.text.trim(),
        'mobileNumber': mobileNumberController.text.trim(),
        'phone': mobileNumberController.text.trim(),
        'email': user.email ?? '',
        'userType': 'tenant',
        if (tenantId != null && tenantId.isNotEmpty) 'tenantId': tenantId,
        'profileComplete': profileComplete,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await userDocRef.set(userUpdates, SetOptions(merge: true));

      // Mirror detailed fields into tenants collection if tenantId exists
      if (tenantId != null && tenantId.isNotEmpty) {
        await _firestore.collection('tenants').doc(tenantId).set({
          ...tenantUpdates,
          'userId': user.uid,
          'tenantId': tenantId,
        }, SetOptions(merge: true));
      }

      // TenantStateProvider will update automatically via Firestore listener
      
      // Exit edit modes after successful save
      exitOverviewEditMode();
      exitKYCEditMode();
      exitAddressEditMode();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  // Document upload methods
  Future<void> uploadDocument(DocumentType type, XFile file) async {
    isUploadingDocument = true;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final tenantId = userDoc.data()?['tenantId']?.toString();
      
      if (tenantId == null || tenantId.isEmpty) {
        throw Exception('Tenant ID not found');
      }

      // Upload document to Firebase Storage
      final documentUrl = await _imageService.uploadTenantDocument(
        file,
        tenantId,
        type.toString().split('.').last,
      );

      // Save document metadata to Firestore
      final documentData = {
        'tenantId': tenantId,
        'type': type.toString().split('.').last,
        'documentUrl': documentUrl,
        'fileName': file.name,
        'uploadedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('documents')
          .add(documentData);

      // Reload documents
      await _loadDocuments(user.uid);
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isUploadingDocument = false;
      notifyListeners();
    }
  }

  Future<void> deleteDocument(String documentId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final tenantId = userDoc.data()?['tenantId']?.toString();
      
      if (tenantId == null || tenantId.isEmpty) {
        throw Exception('Tenant ID not found');
      }

      // Get document to delete its storage file
      final docSnapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('documents')
          .doc(documentId)
          .get();

      if (docSnapshot.exists) {
        final docData = docSnapshot.data()!;
        final documentUrl = docData['documentUrl']?.toString();
        
        // Delete from storage
        if (documentUrl != null && documentUrl.isNotEmpty) {
          try {
            await _imageService.deleteImages([documentUrl]);
          } catch (e) {
            debugPrint('Error deleting document from storage: $e');
            // Continue with Firestore deletion even if storage deletion fails
          }
        }

        // Delete from Firestore
        await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('documents')
            .doc(documentId)
            .delete();

        // Reload documents
        await _loadDocuments(user.uid);
      }
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    }
  }

  void selectDateOfBirth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDateOfBirth) {
      selectedDateOfBirth = picked;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    mobileNumberController.dispose();
    alternatePhoneController.dispose();
    emergencyContactNameController.dispose();
    emergencyContactPhoneController.dispose();
    officeInstituteNameController.dispose();
    officeInstituteIdController.dispose();
    idNumberController.dispose();
    addressLine1Controller.dispose();
    cityController.dispose();
    pincodeController.dispose();
    super.dispose();
  }
}

