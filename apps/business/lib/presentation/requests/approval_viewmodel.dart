// lib/presentation/requests/approval_viewmodel.dart
import 'package:flutter/foundation.dart';
import 'package:models/business/property/property_model.dart';

import '../../models/payment_method_model.dart';
import '../view_models/tenant_wizard/assignment.dart';
import '../view_models/tenant_wizard/first_bill.dart';
import 'approval_source.dart';
import 'request_models.dart';

/// State of the "approve this request" form: which bed, what they pay first,
/// and how the tenant is asked to pay.
class ApprovalViewModel extends ChangeNotifier {
  ApprovalViewModel({
    required this.request,
    required ApprovalSource source,
    DateTime Function()? today,
  })  : _source = source,
        _today = today ?? DateTime.now,
        _moveIn = request.moveIn ?? (today ?? DateTime.now)();

  final EnrollmentRequest request;
  final ApprovalSource _source;
  final DateTime Function() _today;
  bool _disposed = false;

  // ─── Loading ─────────────────────────────────────────────────────────
  ApprovalContext? _ctx;
  bool _loading = true;
  bool _defaultsApplied = false;
  String? _error;

  bool get loading => _loading;

  /// The last problem to tell the owner about (load or validation or save).
  String? get error => _error;
  Property? get property => _ctx?.property;
  List<FloorSlot> get floors => _ctx?.floors ?? const [];

  /// Methods a manual bill can use (Razorpay links are not part of this flow).
  List<PaymentMethod> get methods => [
        for (final m in _ctx?.methods ?? const <PaymentMethod>[])
          if (m.type == 'upi' || m.type == 'bank' || m.type == 'cash') m,
      ];

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final ctx = await _source.load(request);
      _ctx = ctx;
      if (!_defaultsApplied) {
        final pricing = ctx.property.pricing;
        _deposit = pricing.securityDeposit.toDouble();
        _maintenance = pricing.oneTimeMaintenance.toDouble();
        _maintenanceFromDeposit = pricing.maintenanceDeductedFromDeposit;
        _defaultsApplied = true;
      }
      if (_upiId.isEmpty) _upiId = ctx.businessUpiId ?? '';
      _ensureMethod();
    } catch (e) {
      debugPrint('❌ [Approval] load: $e');
      _error = "Couldn't load the rooms. Check your connection and try again.";
    } finally {
      _loading = false;
      _notify();
    }
  }

  // ─── Room and bed ────────────────────────────────────────────────────
  RoomSlot? _room;
  String? _bed;
  bool _rentEdited = false;

  RoomSlot? get selectedRoom => _room;

  /// The owner typed the rent, so picking another bed won't overwrite it.
  bool get rentEdited => _rentEdited;
  String? get selectedBed => _bed;

  /// How many sharing the tenant asked for, if they said.
  int? get _requestedSharing {
    final s = request.sharing?.toLowerCase();
    if (s != null) {
      final n = int.tryParse(s);
      if (n != null) return n;
      const words = {'single': 1, 'double': 2, 'triple': 3, 'quad': 4};
      if (words.containsKey(s)) return words[s];
    }
    final t = request.roomType?.toLowerCase() ?? '';
    for (final e in const {'single': 1, 'double': 2, 'triple': 3, 'quad': 4}.entries) {
      if (t.contains(e.key)) return e.value;
    }
    return null;
  }

  /// Whether [room] is what the tenant asked for (no preference matches all).
  bool matchesRequest(RoomSlot room) {
    final want = _requestedSharing;
    if (want != null && room.sharing != want) return false;
    final ac = request.hasAC;
    if (ac != null && room.hasAC != ac) return false;
    return true;
  }

  void selectBed(String roomNumber, String bedNumber) {
    for (final floor in floors) {
      for (final room in floor.rooms) {
        if (room.number != roomNumber) continue;
        final free = room.beds.any((b) => b.number == bedNumber && !b.occupied);
        if (!free) return;
        _room = room;
        _bed = bedNumber;
        _error = null;
        if (!_rentEdited) _rent = _priceFor(room);
        _notify();
        return;
      }
    }
  }

  void clearBed() {
    _room = null;
    _bed = null;
    _notify();
  }

  double _priceFor(RoomSlot room) {
    final pricing = _ctx!.property.pricing;
    var rent = pricing.getPriceFor(room.sharing, acRoom: room.hasAC) ?? 0;
    if (rent <= 0) {
      rent = switch (room.sharing) {
        1 => pricing.single,
        2 => pricing.double,
        3 => pricing.triple,
        _ => pricing.double,
      };
    }
    return rent.toDouble();
  }

  // ─── Money and dates ─────────────────────────────────────────────────
  double _rent = 0;
  double _deposit = 0;
  double _maintenance = 0;
  bool _maintenanceFromDeposit = false;
  bool _foodIncluded = true;
  double _foodDeduction = 0;
  bool _depositNow = true;
  DateTime _moveIn;
  int _billingDate = 1;
  double? _proratedOverride;

  double get rent => _rent;
  double get deposit => _deposit;
  double get maintenance => _maintenance;
  bool get maintenanceFromDeposit => _maintenanceFromDeposit;
  bool get foodIncluded => _foodIncluded;
  double get foodDeduction => _foodDeduction;
  bool get depositNow => _depositNow;
  DateTime get moveIn => _moveIn;
  int get billingDate => _billingDate;
  double? get proratedOverride => _proratedOverride;
  DateTime get today => _today();

  FirstBill get bill => FirstBill(
        monthlyRent: _rent,
        deposit: _deposit,
        maintenance: _maintenance,
        foodIncluded: _foodIncluded,
        foodDeduction: _foodDeduction,
        depositNow: _depositNow,
        maintenanceDeductedFromDeposit: _maintenanceFromDeposit,
        moveIn: _moveIn,
        proratedOverride: _proratedOverride,
      );

  void setRent(double v) => _set(() {
        _rent = v;
        _rentEdited = true;
      });
  void setDeposit(double v) => _set(() => _deposit = v);
  void setMaintenance(double v) => _set(() => _maintenance = v);
  void setFoodIncluded(bool v) => _set(() => _foodIncluded = v);
  void setFoodDeduction(double v) => _set(() => _foodDeduction = v);
  void setDepositNow(bool v) => _set(() => _depositNow = v);
  void setMoveIn(DateTime v) => _set(() => _moveIn = v);
  void setBillingDate(int v) => _set(() => _billingDate = v.clamp(1, 28));
  void setProratedOverride(double? v) => _set(() => _proratedOverride = v);

  // ─── Payment ─────────────────────────────────────────────────────────
  String? _methodId;
  String _upiId = '';

  String? get selectedMethodId => _methodId;
  String get upiId => _upiId;

  void selectMethod(String id) => _set(() => _methodId = id);
  void setUpiId(String v) => _set(() => _upiId = v);

  void _ensureMethod() {
    final list = methods;
    if (list.any((m) => m.id == _methodId)) return;
    _methodId = list.isEmpty
        ? null
        : (list.firstWhere((m) => m.isPreferred, orElse: () => list.first)).id;
  }

  PaymentChoice _paymentChoice() {
    final method = methods.where((m) => m.id == _methodId).firstOrNull;
    if (method == null) return PaymentChoice('upi_manual', {'ownerUpiId': _upiId.trim()});
    switch (method.type) {
      case 'upi':
        return PaymentChoice('upi_manual', {
          'ownerUpiId': method.upiId ?? _upiId.trim(),
          'paymentMethodId': method.id,
        });
      case 'bank':
        return PaymentChoice('bank_transfer', {
          'bankName': method.bankName,
          'accountNumber': method.accountNumber,
          'ifscCode': method.ifscCode,
          'accountHolderName': method.accountHolderName,
          'paymentMethodId': method.id,
        });
      default:
        return PaymentChoice('cash', {'paymentMethodId': method.id});
    }
  }

  /// A UPI id typed here that the business doesn't have saved yet.
  String? get _newUpiId {
    final typed = _upiId.trim();
    if (methods.isNotEmpty || typed.isEmpty || typed == _ctx?.businessUpiId) return null;
    return typed;
  }

  // ─── Submitting ──────────────────────────────────────────────────────
  bool _submitting = false;
  bool get submitting => _submitting;

  ApprovalSubmission _submission() {
    final b = bill;
    return ApprovalSubmission(
      roomNumber: _room!.number,
      bedNumber: _bed!,
      monthlyRent: _rent,
      proratedRent: b.proratedRent,
      deposit: _deposit,
      maintenance: _maintenance,
      foodIncluded: _foodIncluded,
      foodDeduction: b.foodDeductionApplied,
      depositNow: _depositNow,
      total: b.total,
      billingDate: _billingDate,
      moveIn: _moveIn,
    );
  }

  /// Approves and assigns the bed; the owner collects the money themselves.
  Future<bool> approve() async {
    if (_submitting) return false;
    if (_room == null || _bed == null) return _fail('Choose a room and bed first.');
    return _submit(
      () => _source.approve(request.id, _submission(), newUpiId: _newUpiId),
      "Couldn't approve this request. Try again.",
    );
  }

  /// Sends the first bill for the tenant to pay.
  Future<bool> sendBill() async {
    if (_submitting) return false;
    if (_room == null || _bed == null) return _fail('Choose a room and bed first.');
    if (bill.total <= 0) return _fail('The first bill must be more than ₹0.');
    if (methods.isEmpty && _upiId.trim().isEmpty) {
      return _fail('Enter your UPI ID, or add a payment method in Settings.');
    }
    if (methods.isNotEmpty && _methodId == null) {
      return _fail('Choose how the tenant should pay.');
    }
    return _submit(
      () => _source.sendBill(request.id, _submission(), _paymentChoice(), newUpiId: _newUpiId),
      "Couldn't send the bill. Try again.",
    );
  }

  Future<bool> _submit(Future<void> Function() run, String failure) async {
    _submitting = true;
    _error = null;
    _notify();
    try {
      await run();
      return true;
    } catch (e) {
      debugPrint('❌ [Approval] submit: $e');
      _error = failure;
      return false;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  bool _fail(String message) {
    _error = message;
    _notify();
    return false;
  }

  void _set(VoidCallback change) {
    change();
    _error = null;
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
