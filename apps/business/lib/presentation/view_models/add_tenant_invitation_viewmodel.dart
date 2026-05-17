import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:models/business/tenant_invitation_model.dart';
import 'package:firebase_services/services/tenant_invitation_service.dart';
import 'package:firebase_services/services/tenant_search_service.dart';
import 'package:firebase_services/services/firestore_service.dart';

class AddTenantInvitationViewModel extends ChangeNotifier {
  final TenantInvitationService _invitationService;
  final TenantSearchService _searchService;
  final FirestoreService _firestoreService;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  // Mode: 'search' or 'manual'
  String _mode = 'search';
  TenantSearchResult? _selectedTenant;
  Map<String, dynamic>? _manualTenantData;

  // Food Preference
  String? _foodPreference;

  // Assignment
  String? _propertyId;
  String? _propertyName;
  String? _floor;
  String? _roomId;
  String? _roomNumber;
  int? _bedIndex;
  String? _bedNumber;

  // Lease details
  DateTime? _moveInDate;
  DateTime? _moveOutDate;
  double _monthlyRent = 0.0;
  double? _deposit;
  double? _maintenance;
  bool? _maintenanceDeductedFromDeposit;
  double? _proratedRent;
  int? _billingDay;
  int? _lockInPeriodMonths;
  int? _noticePeriodDays;
  String _paymentCycle = 'Monthly';

  // UI state
  bool _isSubmitting = false;
  String? _errorMessage;

  AddTenantInvitationViewModel({
    TenantInvitationService? invitationService,
    TenantSearchService? searchService,
    FirestoreService? firestoreService,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _invitationService =
            invitationService ?? TenantInvitationService(),
        _searchService = searchService ?? TenantSearchService(),
        _firestoreService =
            firestoreService ?? FirestoreService(),
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  // Getters
  String get mode => _mode;
  TenantSearchResult? get selectedTenant => _selectedTenant;
  Map<String, dynamic>? get manualTenantData => _manualTenantData;
  String? get propertyId => _propertyId;
  String? get propertyName => _propertyName;
  String? get floor => _floor;
  String? get roomId => _roomId;
  String? get roomNumber => _roomNumber;
  int? get bedIndex => _bedIndex;
  String? get bedNumber => _bedNumber;
  DateTime? get moveInDate => _moveInDate;
  DateTime? get moveOutDate => _moveOutDate;
  double get monthlyRent => _monthlyRent;
  double? get deposit => _deposit;
  double? get maintenance => _maintenance;
  int? get lockInPeriodMonths => _lockInPeriodMonths;
  int? get noticePeriodDays => _noticePeriodDays;
  String get paymentCycle => _paymentCycle;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get foodPreference => _foodPreference;
  double? get proratedRent => _proratedRent;
  int? get billingDay => _billingDay;
  bool? get maintenanceDeductedFromDeposit => _maintenanceDeductedFromDeposit;

  // Setters
  void setMode(String mode) {
    if (mode == 'search' || mode == 'manual') {
      _mode = mode;
      if (mode == 'search') {
        _manualTenantData = null;
      } else {
        _selectedTenant = null;
      }
      notifyListeners();
    }
  }

  void setSelectedTenant(TenantSearchResult? tenant) {
    _selectedTenant = tenant;
    notifyListeners();
  }

  void setManualTenantData(Map<String, dynamic> data) {
    _manualTenantData = data;
    notifyListeners();
  }

  void setAssignment({
    String? propertyId,
    String? propertyName,
    String? floor,
    String? roomId,
    String? roomNumber,
    int? bedIndex,
    String? bedNumber,
  }) {
    _propertyId = propertyId;
    _propertyName = propertyName;
    _floor = floor;
    _roomId = roomId;
    _roomNumber = roomNumber;
    _bedIndex = bedIndex;
    _bedNumber = bedNumber;
    notifyListeners();
  }

  void setMoveInDate(DateTime? date) {
    _moveInDate = date;
    notifyListeners();
  }

  void setMoveOutDate(DateTime? date) {
    _moveOutDate = date;
    notifyListeners();
  }

  void setMonthlyRent(double rent) {
    _monthlyRent = rent;
    notifyListeners();
  }

  void setDeposit(double? deposit) {
    _deposit = deposit;
    notifyListeners();
  }

  void setMaintenance(double? maintenance) {
    _maintenance = maintenance;
    notifyListeners();
  }

  void setMaintenanceDeductedFromDeposit(bool? value) {
    _maintenanceDeductedFromDeposit = value;
    notifyListeners();
  }

  void setLockInPeriodMonths(int? months) {
    _lockInPeriodMonths = months;
    notifyListeners();
  }

  void setNoticePeriodDays(int? days) {
    _noticePeriodDays = days;
    notifyListeners();
  }

  void setPaymentCycle(String cycle) {
    _paymentCycle = cycle;
    notifyListeners();
  }

  void setProratedRent(double? amount) {
    _proratedRent = amount;
    notifyListeners();
  }

  void setBillingDay(int? day) {
    _billingDay = day;
    notifyListeners();
  }

  void setFoodPreference(String? preference) {
    _foodPreference = preference;
    notifyListeners();
  }

  bool get isValid {
    if (_mode == 'search') {
      if (_selectedTenant == null) return false;
    } else {
      if (_manualTenantData == null) return false;
    }

    if (_propertyId == null ||
        _propertyName == null ||
        _floor == null ||
        _roomId == null ||
        _roomNumber == null ||
        _bedIndex == null ||
        _bedNumber == null) {
      return false;
    }

    if (_moveInDate == null) return false;
    if (_monthlyRent <= 0) return false;

    return true;
  }

  Future<void> submit() async {
    _errorMessage = null;
    if (!isValid) {
      _errorMessage = 'Please complete all required fields.';
      notifyListeners();
      return;
    }

    try {
      _isSubmitting = true;
      notifyListeners();

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Not authenticated');
      }

      final businessId = await _firestoreService.getBusinessId(user.uid);
      print('[DEBUG] Retrieved businessId: $businessId for user: ${user.uid}');
      if (businessId == null || businessId.isEmpty) {
        throw Exception('Business account not found. Please ensure your business profile is complete.');
      }

      String tenantId;
      String tenantName;
      String tenantPhone;
      String? tenantEmail;
      Map<String, dynamic>? tenantDetails;

      if (_mode == 'search' && _selectedTenant != null) {
        tenantId = _selectedTenant!.tenantId;
        tenantName = _selectedTenant!.name;
        tenantPhone = _selectedTenant!.phone;
        tenantEmail = _selectedTenant!.email;
        tenantDetails = _selectedTenant!.fullData;
      } else if (_mode == 'manual' && _manualTenantData != null) {
        // For manual entry, we need to create or find tenant
        tenantId = _manualTenantData!['tenantId']?.toString() ?? '';
        tenantName = _manualTenantData!['name']?.toString() ?? '';
        tenantPhone = _manualTenantData!['phone']?.toString() ?? '';
        tenantEmail = _manualTenantData!['email']?.toString();
        tenantDetails = _manualTenantData;

        // Add food preference to tenantDetails
        if (_foodPreference != null) {
          (tenantDetails as Map<String, dynamic>)['foodPreference'] = _foodPreference;
        }

        // Tenant record creation happens server-side in createTenantInvitation
      } else {
        throw Exception('Invalid mode or missing tenant data');
      }

      // Validate room gender if needed
      final tenantGender = tenantDetails?['gender']?.toString();
      if (tenantGender != null) {
        final isRoomEmpty = await _invitationService.isRoomEmpty(
          businessId: businessId,
          propertyId: _propertyId!,
          roomId: _roomId!,
        );

        if (!isRoomEmpty) {
          final roomGender = await _invitationService.getRoomGender(
            businessId: businessId,
            propertyId: _propertyId!,
            roomId: _roomId!,
          );

          if (roomGender != null &&
              roomGender.toLowerCase() != tenantGender.toLowerCase()) {
            throw Exception(
              'Room is already assigned to ${roomGender == 'Male' ? 'males' : 'females'}. '
              'Cannot assign ${tenantGender == 'Male' ? 'male' : 'female'} tenant to this room.',
            );
          }
        }
      }

      // Create invitation
      final invitation = TenantInvitation(
        id: '', // Will be generated by service
        tenantId: tenantId,
        tenantName: tenantName,
        tenantPhone: tenantPhone,
        tenantEmail: tenantEmail,
        businessId: businessId,
        propertyId: _propertyId!,
        propertyName: _propertyName!,
        floor: _floor!,
        roomId: _roomId!,
        roomNumber: _roomNumber!,
        bedIndex: _bedIndex!,
        bedNumber: _bedNumber!,
        moveInDate: _moveInDate!,
        moveOutDate: _moveOutDate,
        monthlyRent: _monthlyRent,
        deposit: _deposit,
        maintenance: _maintenance,
        maintenanceDeductedFromDeposit: _maintenanceDeductedFromDeposit,
        proratedRent: _proratedRent,
        billingDay: _billingDay,
        lockInPeriodMonths: _lockInPeriodMonths,
        noticePeriodDays: _noticePeriodDays,
        paymentCycle: _paymentCycle,
        status: TenantInvitationStatus.pending,
        createdAt: DateTime.now(),
        tenantDetails: tenantDetails,
        gender: tenantDetails?['gender']?.toString(),
      );

      await _invitationService.createInvitation(invitation);
    } catch (e) {
      // Parse Firebase permission errors
      String errorMsg = e.toString();
      if (errorMsg.contains('permission-denied') || errorMsg.contains('PERMISSION_DENIED')) {
        _errorMessage = 'Permission denied: Unable to create invitation. Please check your business account setup and try again.';
        print('Firestore Error Details: $errorMsg');
      } else if (errorMsg.contains('Business account not found')) {
        _errorMessage = 'Business account not found. Please contact support.';
      } else {
        _errorMessage = errorMsg;
      }
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}



