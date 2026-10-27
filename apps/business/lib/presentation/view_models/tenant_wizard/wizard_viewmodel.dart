// lib/presentation/view_models/tenant_wizard/wizard_viewmodel.dart
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:firebase_services/services/tenant_search_service.dart';
import 'package:flutter/foundation.dart';
import 'package:models/business/property/property_model.dart';

import 'assignment.dart';
import 'assignment_data_source.dart';
import 'draft_store.dart';
import 'first_bill.dart';

enum TenantEntryMode { search, qr, manual }

/// Text inputs in the wizard (and the keys validation errors are reported under).
enum WizardField {
  bed,
  fullName,
  phone,
  altPhone,
  email,
  dob,
  currentAddress,
  nationality,
  motherTongue,
  idNumber,
  idAddress,
  officeName,
  officeId,
  moveIn,
  moveOut,
  rent,
  deposit,
  maintenance,
  duration,
  lockIn,
  notice,
  foodDeduction,
  prorated,
}

/// Everything the invitation needs, gathered from the wizard.
class WizardSubmission {
  const WizardSubmission({
    required this.mode,
    required this.tenant,
    required this.tenantData,
    required this.propertyId,
    required this.propertyName,
    required this.floor,
    required this.roomId,
    required this.roomNumber,
    required this.bedIndex,
    required this.bedNumber,
    required this.moveIn,
    required this.moveOut,
    required this.monthlyRent,
    required this.deposit,
    required this.maintenance,
    required this.maintenanceDeductedFromDeposit,
    required this.proratedRent,
    required this.billingDay,
    required this.lockInMonths,
    required this.noticeDays,
    required this.paymentCycle,
    required this.foodPreference,
  });

  final TenantEntryMode mode;

  /// Set in search mode.
  final TenantSearchResult? tenant;

  /// Set in manual/QR mode.
  final Map<String, dynamic> tenantData;
  final String propertyId;
  final String propertyName;
  final String floor;
  final String roomId;
  final String roomNumber;
  final int bedIndex;
  final String bedNumber;
  final DateTime moveIn;
  final DateTime? moveOut;
  final double monthlyRent;
  final double? deposit;
  final double? maintenance;
  final bool maintenanceDeductedFromDeposit;
  final double? proratedRent;
  final int? billingDay;
  final int? lockInMonths;
  final int? noticeDays;
  final String paymentCycle;
  final String? foodPreference;
}

/// Sends the invitation. Returns an error message, or null on success.
typedef InvitationSubmitter =
    Future<String?> Function(WizardSubmission submission);

/// State and rules of the Add Tenant wizard: which bed, who the tenant is, the
/// lease, the first bill and the personal details.
class AddTenantWizardViewModel extends ChangeNotifier {
  AddTenantWizardViewModel({
    required AssignmentDataSource assignments,
    required InvitationSubmitter submitter,
    WizardDraftStore? drafts,
    DateTime Function()? clock,
  }) : _assignments = assignments,
       _submitter = submitter,
       _drafts = drafts,
       _clock = clock ?? DateTime.now;

  static const stepNames = [
    'Property',
    'Tenant info',
    'Lease',
    'Bill',
    'Personal',
  ];
  static const lastStep = 4;

  final AssignmentDataSource _assignments;
  final InvitationSubmitter _submitter;
  final WizardDraftStore? _drafts;
  // ignore: unused_field
  final DateTime Function() _clock;

  bool _disposed = false;
  String? _businessId;

  // ─── Loading ──────────────────────────────────────────────────────────
  bool _loading = false;
  String? _loadError;
  bool _loadingRooms = false;
  int _roomsToken = 0;
  bool _draftAvailable = false;
  List<Property> _properties = const [];
  Property? _property;
  List<FloorSlot> _floors = const [];

  bool get loading => _loading;
  bool get loadingRooms => _loadingRooms;
  String? get loadError => _loadError;
  bool get draftAvailable => _draftAvailable;
  List<Property> get properties => _properties;
  Property? get property => _property;
  List<FloorSlot> get floors => _floors;
  int get totalBeds => totalBedsOf(_floors);
  int get freeBeds => totalFreeBeds(_floors);

  static int totalBedsOf(List<FloorSlot> f) =>
      f.fold(0, (n, x) => n + x.totalBeds);

  Future<void> load(String businessId, {String? propertyId}) async {
    _businessId = businessId;
    _loading = true;
    _loadError = null;
    _notify();
    try {
      _properties = await _assignments.propertiesFor(businessId);
      Property? initial;
      if (_properties.isNotEmpty) {
        initial = _properties.firstWhere(
          (p) => p.id == propertyId,
          orElse: () => _properties.first,
        );
      }
      if (initial != null) await selectProperty(initial);
      _draftAvailable = (await _drafts?.read()) != null;
    } catch (e) {
      debugPrint('❌ [AddTenantWizard] load failed: $e');
      _loadError =
          "Couldn't load your properties. Check your connection and try again.";
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> selectProperty(Property p) async {
    final businessId = _businessId;
    if (businessId == null) return;
    final token = ++_roomsToken;
    _property = p;
    _selectedRoomId = null;
    _selectedBedNumber = null;
    _floors = const [];
    _selectedFloor = null;
    _loadingRooms = true;
    _notify();
    try {
      final rooms = await _assignments.roomsFor(businessId, p);
      final occupied = p.id == null
          ? <String, Set<String>>{}
          : await _assignments.occupiedBeds(businessId, p.id!);
      if (token != _roomsToken) return; // a newer selection superseded this one
      _floors = buildFloors(rooms, occupied);
      final firstOpen = _floors.where((f) => f.hasFreeBeds);
      _selectedFloor = firstOpen.isNotEmpty
          ? firstOpen.first.floor
          : (_floors.isNotEmpty ? _floors.first.floor : null);
    } finally {
      if (token == _roomsToken) {
        _loadingRooms = false;
        _notify();
      }
    }
  }

  // ─── Bed selection ────────────────────────────────────────────────────
  String? _selectedFloor;
  String? _selectedRoomId;
  String? _selectedBedNumber;

  String? get selectedFloor => _selectedFloor;
  FloorSlot? get floor {
    for (final f in _floors) {
      if (f.floor == _selectedFloor) return f;
    }
    return null;
  }

  RoomSlot? get selectedRoom {
    for (final f in _floors) {
      for (final r in f.rooms) {
        if (r.id == _selectedRoomId) return r;
      }
    }
    return null;
  }

  BedSlot? get selectedBed {
    final room = selectedRoom;
    if (room == null) return null;
    for (final b in room.beds) {
      if (b.number == _selectedBedNumber) return b;
    }
    return null;
  }

  void selectFloor(String floorId) {
    if (_selectedFloor == floorId) return;
    _selectedFloor = floorId;
    _selectedRoomId = null;
    _selectedBedNumber = null;
    _notify();
  }

  /// Returns false (and changes nothing) for a bed that is already taken.
  bool selectBed(RoomSlot room, BedSlot bed) {
    if (bed.occupied) return false;
    _selectedFloor = room.floor;
    _selectedRoomId = room.id;
    _selectedBedNumber = bed.number;
    _prefillFromPricing();
    _notify();
    return true;
  }

  // ─── Text fields ──────────────────────────────────────────────────────
  final Map<WizardField, String> _text = {WizardField.duration: '12'};
  final Set<WizardField> _touched = {};
  int _prefillVersion = 0;

  /// Bumps when a prefill changed field values, so bound inputs can refresh.
  int get prefillVersion => _prefillVersion;

  String text(WizardField f) => _text[f] ?? '';

  void setText(WizardField f, String value) {
    _text[f] = value;
    _touched.add(f);
    _notify();
  }

  void _setPrefill(WizardField f, String value) {
    if (_touched.contains(f) || _text[f] == value) return;
    _text[f] = value;
    _prefillVersion++;
  }

  void _prefillFromPricing() {
    final p = _property;
    final room = selectedRoom;
    if (p == null) return;
    final pricing = p.pricing;

    var rent = 0;
    if (room != null) {
      rent = pricing.getPriceFor(room.sharing, acRoom: room.hasAC) ?? 0;
      if (rent <= 0) {
        rent = switch (room.sharing) {
          1 => pricing.single,
          2 => pricing.double,
          3 => pricing.triple,
          _ => pricing.double,
        };
      }
    } else {
      rent = pricing.double;
    }

    _setPrefill(WizardField.rent, rent > 0 ? '$rent' : '');
    _setPrefill(WizardField.deposit, '${pricing.securityDeposit}');
    _setPrefill(WizardField.maintenance, '${pricing.oneTimeMaintenance}');
  }

  // ─── Choices ──────────────────────────────────────────────────────────
  TenantEntryMode _mode = TenantEntryMode.manual;
  TenantSearchResult? _selectedTenant;
  String _gender = 'Male';
  String _tenantType = 'Bachelor';
  String? _foodPreference;
  String _idType = 'Aadhaar';
  String _paymentCycle = 'Monthly';
  String _rentBillingType = 'Monthly';
  int? _billingDay;
  DateTime? _moveIn;
  DateTime? _moveOut;
  bool _foodIncluded = true;
  bool _depositNow = true;

  TenantEntryMode get mode => _mode;
  TenantSearchResult? get selectedTenant => _selectedTenant;
  String get gender => _gender;
  String get tenantType => _tenantType;
  String? get foodPreference => _foodPreference;
  String get idType => _idType;
  String get paymentCycle => _paymentCycle;
  String get rentBillingType => _rentBillingType;
  int? get billingDay => _billingDay ?? _moveIn?.day;
  DateTime? get moveIn => _moveIn;
  DateTime? get moveOut => _moveOut;
  bool get foodIncluded => _foodIncluded;
  bool get depositNow => _depositNow;

  void setMode(TenantEntryMode m) {
    _mode = m;
    _notify();
  }

  void selectTenant(TenantSearchResult t) {
    _selectedTenant = t;
    _mode = TenantEntryMode.search;
    _notify();
  }

  void clearTenant() {
    _selectedTenant = null;
    _notify();
  }

  void setGender(String v) => _set(() => _gender = v);
  void setTenantType(String v) => _set(() => _tenantType = v);
  void setFoodPreference(String? v) => _set(() => _foodPreference = v);
  void setIdType(String v) => _set(() => _idType = v);
  void setPaymentCycle(String v) => _set(() => _paymentCycle = v);
  void setRentBillingType(String v) => _set(() => _rentBillingType = v);
  void setBillingDay(int? v) => _set(() => _billingDay = v);
  void setMoveIn(DateTime? v) => _set(() => _moveIn = v);
  void setMoveOut(DateTime? v) => _set(() => _moveOut = v);
  void setFoodIncluded(bool v) => _set(() => _foodIncluded = v);
  void setDepositNow(bool v) => _set(() => _depositNow = v);

  void _set(VoidCallback change) {
    change();
    _notify();
  }

  /// Fills the manual form from a scanned tenant profile.
  void applyScannedTenant(Map<String, dynamic> data) {
    String s(List<String> keys) {
      for (final k in keys) {
        final v = data[k]?.toString();
        if (v != null && v.isNotEmpty) return v;
      }
      return '';
    }

    void put(WizardField f, String v) {
      _text[f] = v;
      _touched.add(f);
    }

    put(WizardField.fullName, s(['name', 'fullName']));
    put(WizardField.phone, s(['phone', 'mobileNumber']));
    put(WizardField.altPhone, s(['alternatePhone']));
    put(WizardField.email, s(['email']));
    put(WizardField.dob, _formatDob(data['dateOfBirth']));
    put(WizardField.currentAddress, s(['addressLine1', 'address']));
    put(WizardField.nationality, s(['nationality']));
    put(WizardField.motherTongue, s(['motherTongue']));
    put(WizardField.idNumber, s(['idNumber']));
    put(WizardField.idAddress, s(['addressLine1', 'city']));
    put(WizardField.officeName, s(['officeInstituteName']));
    put(WizardField.officeId, s(['officeInstituteId']));
    final g = s(['gender']);
    if (g.isNotEmpty) _gender = g;
    _idType = normalizeIdType(s(['idType']));
    _mode = TenantEntryMode.manual;
    _prefillVersion++;
    _notify();
  }

  static String _formatDob(Object? dob) {
    DateTime? d;
    if (dob is DateTime) {
      d = dob;
    } else if (dob is Timestamp) {
      d = dob.toDate();
    } else if (dob is Map && dob['_seconds'] != null) {
      d = DateTime.fromMillisecondsSinceEpoch(
        (dob['_seconds'] as num).toInt() * 1000,
      );
    } else if (dob is String) {
      return dob;
    }
    return d == null ? '' : '${d.day}/${d.month}/${d.year}';
  }

  /// Maps free-text ID types onto the dropdown options.
  static String normalizeIdType(String raw) {
    final n = raw.toLowerCase();
    if (n.contains('aadhar') || n.contains('aadhaar')) return 'Aadhaar';
    if (n.contains('pan')) return 'PAN';
    if (n.contains('passport')) return 'Passport';
    if (n.contains('driv') || n.contains('licen')) return 'Driving License';
    return 'Aadhaar';
  }

  // ─── Bill ─────────────────────────────────────────────────────────────
  static double? _num(String raw) {
    final t = raw.trim().replaceAll(',', '');
    return t.isEmpty ? null : double.tryParse(t);
  }

  FirstBill get bill {
    final override = _num(text(WizardField.prorated));
    return FirstBill(
      monthlyRent: _num(text(WizardField.rent)) ?? 0,
      deposit: _num(text(WizardField.deposit)) ?? 0,
      maintenance: _num(text(WizardField.maintenance)) ?? 0,
      foodIncluded: _foodIncluded,
      foodDeduction: _num(text(WizardField.foodDeduction)) ?? 0,
      depositNow: _depositNow,
      maintenanceDeductedFromDeposit:
          _property?.pricing.maintenanceDeductedFromDeposit ?? false,
      moveIn: _moveIn,
      proratedOverride: (override != null && override >= 0) ? override : null,
    );
  }

  // ─── Steps ────────────────────────────────────────────────────────────
  int _step = 0;
  bool _showErrors = false;

  int get step => _step;
  bool get isLastStep => _step == lastStep;
  bool get showErrors => _showErrors;

  Map<WizardField, String> get errors => errorsFor(_step);
  bool get canContinue => errorsFor(_step).isEmpty;

  Map<WizardField, String> errorsFor(int step) {
    final e = <WizardField, String>{};
    switch (step) {
      case 0:
        if (selectedBed == null)
          e[WizardField.bed] = 'Pick a free bed to continue';
      case 1:
        if (_mode == TenantEntryMode.search) {
          if (_selectedTenant == null)
            e[WizardField.fullName] = 'Search and pick a tenant';
        } else {
          if (text(WizardField.fullName).trim().isEmpty) {
            e[WizardField.fullName] = 'Enter the tenant\'s name';
          }
          if (text(WizardField.phone).replaceAll(RegExp(r'\D'), '').length <
              10) {
            e[WizardField.phone] = 'Enter a valid 10-digit phone number';
          }
          final email = text(WizardField.email).trim();
          if (email.isNotEmpty &&
              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
            e[WizardField.email] = 'That email doesn\'t look right';
          }
        }
      case 2:
        if (_moveIn == null) e[WizardField.moveIn] = 'Pick a move-in date';
        final rent = _num(text(WizardField.rent));
        if (rent == null || rent <= 0)
          e[WizardField.rent] = 'Enter the monthly rent';
        final deposit = _num(text(WizardField.deposit));
        if (deposit == null || deposit < 0)
          e[WizardField.deposit] = 'Enter the security deposit';
        final months = int.tryParse(text(WizardField.duration).trim());
        if (months == null || months < 1)
          e[WizardField.duration] = 'Enter the lease length in months';
        if (_moveIn != null &&
            _moveOut != null &&
            !_moveOut!.isAfter(_moveIn!)) {
          e[WizardField.moveOut] = 'Move-out must be after move-in';
        }
      case 3:
        if (_moveIn == null)
          e[WizardField.moveIn] = 'Pick a move-in date on the Lease step';
        final raw = text(WizardField.prorated).trim();
        if (raw.isNotEmpty) {
          final v = _num(raw);
          if (v == null || v < 0)
            e[WizardField.prorated] = 'Enter a valid amount';
        }
      case 4:
        if (_mode != TenantEntryMode.search) {
          if (text(WizardField.idNumber).trim().isEmpty) {
            e[WizardField.idNumber] = 'Enter the ID number';
          }
          if (text(WizardField.idAddress).trim().isEmpty) {
            e[WizardField.idAddress] = 'Enter the address on the ID';
          }
        }
    }
    return e;
  }

  bool next() {
    if (!canContinue) {
      _showErrors = true;
      _notify();
      return false;
    }
    if (_step < lastStep) _step++;
    _showErrors = false;
    _notify();
    return true;
  }

  void back() {
    if (_step == 0) return;
    _step--;
    _showErrors = false;
    _notify();
  }

  /// Jumps to an earlier step. Later steps are reached with [next].
  bool goTo(int i) {
    if (i < 0 || i > _step) return false;
    _step = i;
    _showErrors = false;
    _notify();
    return true;
  }

  // ─── Submitting ───────────────────────────────────────────────────────
  bool _submitting = false;
  bool _submitted = false;
  String? _submitError;

  bool get submitting => _submitting;
  bool get submitted => _submitted;
  String? get submitError => _submitError;

  Map<String, dynamic> get _tenantData => {
    'name': text(WizardField.fullName).trim(),
    'phone': text(WizardField.phone).trim(),
    'email': text(WizardField.email).trim(),
    'alternatePhone': text(WizardField.altPhone).trim(),
    'gender': _gender,
    'tenantType': _tenantType,
    'dateOfBirth': text(WizardField.dob).trim(),
    'address': text(WizardField.currentAddress).trim(),
    'addressLine1': text(WizardField.currentAddress).trim(),
    'nationality': text(WizardField.nationality).trim(),
    'motherTongue': text(WizardField.motherTongue).trim(),
    'idType': _idType,
    'idNumber': text(WizardField.idNumber).trim(),
    'idAddress': text(WizardField.idAddress).trim(),
    'officeInstituteName': text(WizardField.officeName).trim(),
    'officeInstituteId': text(WizardField.officeId).trim(),
  };

  Future<bool> submit() async {
    if (_submitting) return false;

    for (var i = 0; i <= lastStep; i++) {
      if (errorsFor(i).isNotEmpty) {
        _step = i;
        _showErrors = true;
        _notify();
        return false;
      }
    }

    _submitting = true;
    _submitError = null;
    _notify();

    try {
      final room = selectedRoom!;
      final bed = selectedBed!;
      final b = bill;
      final error = await _submitter(
        WizardSubmission(
          mode: _mode,
          tenant: _mode == TenantEntryMode.search ? _selectedTenant : null,
          tenantData: _mode == TenantEntryMode.search ? const {} : _tenantData,
          propertyId: _property!.id!,
          propertyName: _property!.name,
          floor: room.floor,
          roomId: room.id,
          roomNumber: room.number,
          bedIndex: bed.index,
          bedNumber: bed.number,
          moveIn: _moveIn!,
          moveOut: _moveOut,
          monthlyRent: _num(text(WizardField.rent)) ?? 0,
          deposit: _num(text(WizardField.deposit)),
          maintenance: _num(text(WizardField.maintenance)),
          maintenanceDeductedFromDeposit: b.maintenanceDeductedFromDeposit,
          proratedRent: b.proratedRent,
          billingDay: billingDay,
          lockInMonths: int.tryParse(text(WizardField.lockIn).trim()),
          noticeDays: int.tryParse(text(WizardField.notice).trim()),
          paymentCycle: _paymentCycle,
          foodPreference: _foodPreference,
        ),
      );
      if (error != null) {
        _submitError = error;
        return false;
      }
      _submitted = true;
      await _drafts?.clear();
      return true;
    } catch (e) {
      _submitError = e.toString();
      return false;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  // ─── Drafts ───────────────────────────────────────────────────────────
  Map<String, dynamic> toDraft() => {
    'v': 1,
    'step': _step,
    'mode': _mode.name,
    'fields': {for (final e in _text.entries) e.key.name: e.value},
    'touched': [for (final f in _touched) f.name],
    'gender': _gender,
    'tenantType': _tenantType,
    'foodPreference': _foodPreference,
    'idType': _idType,
    'paymentCycle': _paymentCycle,
    'rentBillingType': _rentBillingType,
    'billingDay': _billingDay,
    'moveIn': _moveIn?.toIso8601String(),
    'moveOut': _moveOut?.toIso8601String(),
    'foodIncluded': _foodIncluded,
    'depositNow': _depositNow,
    'selection': {
      'propertyId': _property?.id,
      'floor': _selectedFloor,
      'roomId': _selectedRoomId,
      'bedNumber': _selectedBedNumber,
    },
  };

  Future<void> saveDraft() async {
    await _drafts?.write(toDraft());
    _draftAvailable = true;
    _notify();
  }

  Future<void> discardDraft() async {
    await _drafts?.clear();
    _draftAvailable = false;
    _notify();
  }

  /// Loads a saved draft. A damaged draft is ignored.
  Future<void> restoreDraft() async {
    final d = await _drafts?.read();
    if (d == null) return;
    try {
      final fields = d['fields'] as Map<String, dynamic>? ?? const {};
      for (final f in WizardField.values) {
        final v = fields[f.name];
        if (v is String) _text[f] = v;
      }
      for (final name in (d['touched'] as List? ?? const [])) {
        final f = WizardField.values.where((x) => x.name == name);
        if (f.isNotEmpty) _touched.add(f.first);
      }
      _mode = TenantEntryMode.values.firstWhere(
        (m) => m.name == d['mode'],
        orElse: () => TenantEntryMode.manual,
      );
      _gender = d['gender'] as String? ?? _gender;
      _tenantType = d['tenantType'] as String? ?? _tenantType;
      _foodPreference = d['foodPreference'] as String?;
      _idType = d['idType'] as String? ?? _idType;
      _paymentCycle = d['paymentCycle'] as String? ?? _paymentCycle;
      _rentBillingType = d['rentBillingType'] as String? ?? _rentBillingType;
      _billingDay = d['billingDay'] as int?;
      _moveIn = DateTime.tryParse(d['moveIn'] as String? ?? '');
      _moveOut = DateTime.tryParse(d['moveOut'] as String? ?? '');
      _foodIncluded = d['foodIncluded'] as bool? ?? true;
      _depositNow = d['depositNow'] as bool? ?? true;

      final sel = d['selection'] as Map<String, dynamic>? ?? const {};
      final propertyId = sel['propertyId'] as String?;
      if (propertyId != null) {
        final match = _properties.where((p) => p.id == propertyId);
        if (match.isNotEmpty && match.first.id != _property?.id) {
          await selectProperty(match.first);
        }
        final floorId = sel['floor'] as String?;
        if (floorId != null && _floors.any((f) => f.floor == floorId)) {
          _selectedFloor = floorId;
          final roomId = sel['roomId'] as String?;
          final bedNumber = sel['bedNumber'] as String?;
          final room = floor?.rooms.where((r) => r.id == roomId);
          if (room != null && room.isNotEmpty) {
            final bed = room.first.beds.where(
              (b) => b.number == bedNumber && !b.occupied,
            );
            if (bed.isNotEmpty) {
              _selectedRoomId = room.first.id;
              _selectedBedNumber = bed.first.number;
            }
          }
        }
      }

      final step = d['step'];
      _step = (step is int && selectedBed != null)
          ? math.min(math.max(step, 0), lastStep)
          : 0;
      _prefillVersion++;
      _showErrors = false;
    } catch (e) {
      debugPrint('⚠️ [AddTenantWizard] ignoring unreadable draft: $e');
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
