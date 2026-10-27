// lib/data/models.dart
//
// What the tenant app reads from Firestore, parsed defensively: documents are
// written by several clients and Cloud Functions over time, so keys vary.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart' show IconData, Icons;

DateTime? readDate(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  return null;
}

String? readText(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

double? readNum(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

/// `users/{uid}`.
class TenantAccount {
  const TenantAccount({
    required this.uid,
    this.tenantId,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.profileComplete = false,
    this.favorites = const {},
  });

  final String uid;

  /// The sequential tenant id (TEN0000001) once the account has one.
  final String? tenantId;
  final String name;
  final String email;
  final String phone;
  final bool profileComplete;
  final Set<String> favorites;

  factory TenantAccount.fromMap(String uid, Map<String, dynamic> m) {
    return TenantAccount(
      uid: uid,
      tenantId: readText(m['tenantId']),
      name: readText(m['fullName']) ?? readText(m['name']) ?? readText(m['displayName']) ?? '',
      email: readText(m['email']) ?? '',
      phone: readText(m['phone']) ?? readText(m['mobileNumber']) ?? '',
      profileComplete: m['profileComplete'] == true,
      favorites: {...?(m['favoritePropertyIds'] as List?)?.map((e) => e.toString())},
    );
  }
}

/// The tenant's current stay: `tenants/{TEN}/stays/{id}` with status active.
class Stay {
  const Stay({
    required this.id,
    required this.businessId,
    required this.propertyId,
    this.propertyName = '',
    this.roomId = '',
    this.roomNumber = '',
    this.bedId = '',
    this.bedNumber = '',
    this.monthlyRent = 0,
    this.checkInDate,
  });

  final String id;
  final String businessId;
  final String propertyId;
  final String propertyName;
  final String roomId;
  final String roomNumber;
  final String bedId;
  final String bedNumber;
  final double monthlyRent;
  final DateTime? checkInDate;

  String get roomLabel => 'Room $roomNumber · Bed $bedNumber';

  /// Rent is billed on the move-in day of each month.
  int? get billingDay => checkInDate?.day;

  factory Stay.fromMap(String id, Map<String, dynamic> m) {
    final roomId = readText(m['roomId']) ?? readText(m['roomNumber']) ?? '';
    final bedId = readText(m['bedId']) ?? readText(m['bedNumber']) ?? '';
    return Stay(
      id: id,
      businessId: readText(m['businessId']) ?? '',
      propertyId: readText(m['propertyId']) ?? '',
      propertyName: readText(m['propertyName']) ?? '',
      roomId: roomId,
      roomNumber: readText(m['roomNumber']) ?? roomId,
      bedId: bedId,
      bedNumber: readText(m['bedNumber']) ?? bedId,
      monthlyRent: readNum(m['monthlyRent']) ?? 0,
      checkInDate: readDate(m['checkInDate']),
    );
  }
}

/// Where a request to join a PG is: pending -> bill sent -> paid -> confirmed.
enum EnrollmentStage {
  pending('Waiting for owner', 0),
  approved('Approved', 1),
  billSent('Payment due', 1),
  paymentSubmitted('Payment being checked', 2),
  confirmed('Confirmed', 3),
  rejected('Not accepted', -1),
  failed('Owner is finishing up', 2),
  other('In progress', 0);

  const EnrollmentStage(this.label, this.step);

  final String label;

  /// Position on the four-step track (requested, approved, paid, moved in).
  final int step;

  bool get isOpen => this != confirmed && this != rejected;

  static EnrollmentStage of(String? status) => switch (status) {
    'pending' => pending,
    'approved' => approved,
    'bill_sent' => billSent,
    'payment_submitted' => paymentSubmitted,
    'confirmed' || 'accepted' => confirmed,
    'rejected' => rejected,
    'approval_failed' => failed,
    _ => other,
  };
}

enum BillPaymentMode { upi, bank, cash, immediate, other }

class BankDetails {
  const BankDetails({this.bankName, this.accountNumber, this.ifscCode, this.accountHolderName});

  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final String? accountHolderName;
}

class BillLine {
  const BillLine(this.label, this.amount);

  final String label;
  final double amount;
}

/// `enrollmentRequests/{id}`, as the tenant sees it.
class EnrollmentRequest {
  const EnrollmentRequest({
    required this.id,
    required this.stage,
    this.propertyId = '',
    this.businessId = '',
    this.propertyName = '',
    this.createdAt,
    this.moveIn,
    this.roomNumber,
    this.bedNumber,
    this.monthlyRent,
    this.lines = const [],
    this.total = 0,
    this.paymentMode = BillPaymentMode.other,
    this.ownerUpiId,
    this.bank,
    this.transactionId,
    this.paymentRejectionReason,
    this.rejectionReason,
  });

  final String id;
  final EnrollmentStage stage;
  final String propertyId;
  final String businessId;
  final String propertyName;
  final DateTime? createdAt;
  final DateTime? moveIn;
  final String? roomNumber;
  final String? bedNumber;
  final double? monthlyRent;

  /// What the first bill is made of.
  final List<BillLine> lines;
  final double total;
  final BillPaymentMode paymentMode;
  final String? ownerUpiId;
  final BankDetails? bank;
  final String? transactionId;

  /// Why the owner sent a previous payment back.
  final String? paymentRejectionReason;

  /// Why the owner turned the request down.
  final String? rejectionReason;

  String? get placement => roomNumber == null
      ? null
      : ['Room $roomNumber', if (bedNumber != null) 'Bed $bedNumber'].join(' · ');

  factory EnrollmentRequest.fromMap(String id, Map<String, dynamic> m) {
    final prorated = readNum(m['proratedRent']);
    final advance = readNum(m['advanceAmount']);
    final deposit = readNum(m['depositAmount']);
    final maintenance = readNum(m['maintenanceAmount']);
    final food = readNum(m['foodDeduction']);
    final lines = <BillLine>[
      if (prorated != null && prorated > 0) BillLine('Rent (first period)', prorated),
      if (advance != null && advance > 0) BillLine('Advance rent', advance),
      if (deposit != null && deposit > 0) BillLine('Security deposit', deposit),
      if (maintenance != null && maintenance > 0) BillLine('Maintenance', maintenance),
      if (food != null && food > 0) BillLine('Food discount', -food),
    ];
    final total = readNum(m['totalBillAmount']) ??
        readNum(m['totalFirstMonth']) ??
        lines.fold<double>(0, (sum, l) => sum + l.amount);
    final mode = switch (readText(m['paymentMode'])) {
      'upi_manual' || 'upi' => BillPaymentMode.upi,
      'bank_transfer' => BillPaymentMode.bank,
      'cash' => BillPaymentMode.cash,
      'immediate' => BillPaymentMode.immediate,
      null => readText(m['ownerUpiId']) != null ? BillPaymentMode.upi : BillPaymentMode.other,
      _ => BillPaymentMode.other,
    };
    return EnrollmentRequest(
      id: id,
      stage: EnrollmentStage.of(readText(m['status'])),
      propertyId: readText(m['propertyId']) ?? '',
      businessId: readText(m['businessId']) ?? '',
      propertyName: readText(m['propertyName']) ?? 'PG',
      createdAt: readDate(m['createdAt']),
      moveIn: readDate(m['moveInDate']),
      roomNumber: readText(m['roomNumber']) ?? readText(m['roomId']),
      bedNumber: readText(m['bedNumber']) ?? readText(m['bedId']),
      monthlyRent: readNum(m['monthlyRent']),
      lines: lines,
      total: total,
      paymentMode: mode,
      ownerUpiId: readText(m['ownerUpiId']),
      bank: mode == BillPaymentMode.bank
          ? BankDetails(
              bankName: readText(m['bankName']),
              accountNumber: readText(m['accountNumber']),
              ifscCode: readText(m['ifscCode']),
              accountHolderName: readText(m['accountHolderName']),
            )
          : null,
      transactionId: readText(m['transactionId']),
      paymentRejectionReason: readText(m['paymentRejectionReason']),
      rejectionReason: readText(m['rejectionReason']),
    );
  }
}

enum InvoiceStatus { unpaid, overdue, paid, other }

/// `businesses/{b}/tenants/{TEN}/rent_invoices/{id}` (server-written).
class RentInvoice {
  const RentInvoice({
    required this.id,
    required this.status,
    this.amount = 0,
    this.month = '',
    this.periodMonth = '',
    this.dueDate,
    this.paidAt,
  });

  final String id;
  final InvoiceStatus status;
  final double amount;
  final String month;

  /// "2026-03", sortable.
  final String periodMonth;
  final DateTime? dueDate;
  final DateTime? paidAt;

  bool get isOpen => status == InvoiceStatus.unpaid || status == InvoiceStatus.overdue;

  bool isOverdueAt(DateTime now) {
    if (status == InvoiceStatus.overdue) return true;
    if (status != InvoiceStatus.unpaid || dueDate == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    return dueDate!.isBefore(today);
  }

  factory RentInvoice.fromMap(String id, Map<String, dynamic> m) {
    return RentInvoice(
      id: id,
      status: switch (readText(m['status'])) {
        'unpaid' => InvoiceStatus.unpaid,
        'overdue' => InvoiceStatus.overdue,
        'paid' => InvoiceStatus.paid,
        _ => InvoiceStatus.other,
      },
      amount: readNum(m['amount']) ?? 0,
      month: readText(m['month']) ?? '',
      periodMonth: readText(m['periodMonth']) ?? '',
      dueDate: readDate(m['dueDate']),
      paidAt: readDate(m['paidAt']),
    );
  }
}

enum PaymentState { pending, paid, rejected }

/// `businesses/{b}/tenants/{TEN}/payments/{id}`.
class RentPayment {
  const RentPayment({
    required this.id,
    required this.state,
    this.amount = 0,
    this.month = '',
    this.date,
    this.method = '',
    this.transactionId,
    this.rejectionReason,
    this.description,
    this.invoiceId,
  });

  final String id;
  final PaymentState state;

  /// The rent invoice this pays, when it was paid against one.
  final String? invoiceId;
  final double amount;
  final String month;
  final DateTime? date;
  final String method;
  final String? transactionId;
  final String? rejectionReason;
  final String? description;

  String get methodLabel => switch (method.toLowerCase()) {
    'upi' || 'upi_manual' => 'UPI',
    'cash' => 'Cash',
    'razorpay' || 'online' || 'onestay' => 'Online',
    'bank_transfer' => 'Bank transfer',
    '' || 'not specified' => 'Payment',
    _ => method,
  };

  factory RentPayment.fromMap(String id, Map<String, dynamic> m) {
    final status = (readText(m['status']) ?? '').toLowerCase();
    return RentPayment(
      id: id,
      state: switch (status) {
        'paid' || 'verified' || 'confirmed' || 'success' || 'captured' => PaymentState.paid,
        'rejected' || 'failed' => PaymentState.rejected,
        _ => PaymentState.pending,
      },
      amount: readNum(m['amount']) ?? 0,
      month: readText(m['month']) ?? '',
      date: readDate(m['date']) ?? readDate(m['createdAt']),
      method: readText(m['method']) ?? readText(m['paymentMode']) ?? '',
      transactionId: readText(m['transactionId']),
      rejectionReason: readText(m['rejectionReason']),
      description: readText(m['description']),
      invoiceId: readText(m['rentInvoiceId']),
    );
  }
}

/// `tenants/{TEN}/notifications/{id}`.
class TenantNotification {
  const TenantNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body = '',
    this.createdAt,
    this.read = false,
    this.invitationId,
    this.enrollmentRequestId,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime? createdAt;
  final bool read;
  final String? invitationId;
  final String? enrollmentRequestId;

  factory TenantNotification.fromMap(String id, Map<String, dynamic> m) {
    return TenantNotification(
      id: id,
      type: readText(m['type']) ?? 'general',
      title: readText(m['title']) ?? 'Notification',
      body: readText(m['message']) ?? readText(m['body']) ?? '',
      createdAt: readDate(m['createdAt']),
      read: m['read'] == true,
      invitationId: readText(m['invitationId']),
      enrollmentRequestId: readText(m['enrollmentRequestId']) ?? readText(m['requestId']),
    );
  }
}

enum PinCategory {
  social('Social', '☕'),
  sports('Sports', '🏸'),
  lostFound('Lost & found', '🔑'),
  marketplace('Marketplace', '📦');

  const PinCategory(this.label, this.emoji);

  final String label;
  final String emoji;

  String get wire => this == lostFound ? 'lost_found' : name;

  static PinCategory of(String? v) =>
      values.firstWhere((c) => c.wire == v, orElse: () => social);
}

/// `pinboard/{id}`: 48-hour notes residents of a property share.
class PinNote {
  const PinNote({
    required this.id,
    required this.authorId,
    required this.content,
    this.authorName = 'Resident',
    this.authorPhone = '',
    this.category = PinCategory.social,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorPhone;
  final PinCategory category;
  final String content;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  factory PinNote.fromMap(String id, Map<String, dynamic> m) {
    return PinNote(
      id: id,
      authorId: readText(m['authorId']) ?? '',
      authorName: readText(m['authorName']) ?? 'Resident',
      authorPhone: readText(m['authorPhone']) ?? '',
      category: PinCategory.of(readText(m['category'])),
      content: readText(m['content']) ?? '',
      createdAt: readDate(m['createdAt']),
      expiresAt: readDate(m['expiresAt']),
    );
  }
}

enum MaintenanceCategory {
  electrical('Electrical', Icons.bolt_rounded),
  plumbing('Plumbing', Icons.water_drop_rounded),
  cleaning('Cleaning', Icons.cleaning_services_rounded),
  internet('Wi-Fi', Icons.wifi_rounded),
  furniture('Furniture', Icons.chair_rounded),
  appliance('Appliance', Icons.kitchen_rounded),
  other('Other', Icons.build_rounded);

  const MaintenanceCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  static MaintenanceCategory of(String? v) =>
      values.firstWhere((c) => c.name == v, orElse: () => other);
}

enum MaintenanceStatus {
  open('open', 'Open'),
  inProgress('in_progress', 'In progress'),
  resolved('resolved', 'Resolved'),
  cancelled('cancelled', 'Cancelled');

  const MaintenanceStatus(this.wire, this.label);

  final String wire;
  final String label;

  bool get isActive => this == open || this == inProgress;

  static MaintenanceStatus of(String? v) =>
      values.firstWhere((s) => s.wire == v, orElse: () => open);
}

/// `maintenanceRequests/{id}`.
class MaintenanceRequest {
  const MaintenanceRequest({
    required this.id,
    required this.title,
    this.description = '',
    this.category = MaintenanceCategory.other,
    this.urgent = false,
    this.status = MaintenanceStatus.open,
    this.createdAt,
    this.updatedAt,
    this.ownerNote,
    this.propertyName = '',
    this.roomNumber = '',
  });

  final String id;
  final String title;
  final String description;
  final MaintenanceCategory category;
  final bool urgent;
  final MaintenanceStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? ownerNote;
  final String propertyName;
  final String roomNumber;

  bool get canCancel => status == MaintenanceStatus.open;

  factory MaintenanceRequest.fromMap(String id, Map<String, dynamic> m) {
    return MaintenanceRequest(
      id: id,
      title: readText(m['title']) ?? 'Request',
      description: readText(m['description']) ?? '',
      category: MaintenanceCategory.of(readText(m['category'])),
      urgent: m['priority'] == 'urgent',
      status: MaintenanceStatus.of(readText(m['status'])),
      createdAt: readDate(m['createdAt']),
      updatedAt: readDate(m['updatedAt']),
      ownerNote: readText(m['ownerNote']),
      propertyName: readText(m['propertyName']) ?? '',
      roomNumber: readText(m['roomNumber']) ?? '',
    );
  }
}

/// An owner's invitation to join a PG, from the listMyTenantInvitations /
/// getMyTenantInvitation callables (dates as epoch millis).
class PendingInvitation {
  const PendingInvitation({
    required this.id,
    required this.businessId,
    required this.propertyId,
    this.propertyName = '',
    this.roomNumber = '',
    this.bedNumber = '',
    this.monthlyRent = 0,
    this.deposit = 0,
    this.maintenance = 0,
    this.proratedRent = 0,
    this.billingDay,
    this.noticePeriodDays,
    this.lockInMonths,
    this.moveIn,
    this.status = 'pending',
  });

  final String id;
  final String businessId;
  final String propertyId;
  final String propertyName;
  final String roomNumber;
  final String bedNumber;
  final double monthlyRent;
  final double deposit;
  final double maintenance;
  final double proratedRent;
  final int? billingDay;
  final int? noticePeriodDays;
  final int? lockInMonths;
  final DateTime? moveIn;
  final String status;

  bool get isPending => status == 'pending';

  String get placement => 'Room $roomNumber · Bed $bedNumber';

  factory PendingInvitation.fromMap(Map<String, dynamic> m) {
    return PendingInvitation(
      id: readText(m['id']) ?? '',
      businessId: readText(m['businessId']) ?? '',
      propertyId: readText(m['propertyId']) ?? '',
      propertyName: readText(m['propertyName']) ?? 'PG',
      roomNumber: readText(m['roomNumber']) ?? '',
      bedNumber: readText(m['bedNumber']) ?? '',
      monthlyRent: readNum(m['monthlyRent']) ?? 0,
      deposit: readNum(m['deposit']) ?? 0,
      maintenance: readNum(m['maintenance']) ?? 0,
      proratedRent: readNum(m['proratedRent']) ?? 0,
      billingDay: readNum(m['billingDay'])?.toInt(),
      noticePeriodDays: readNum(m['noticePeriodDays'])?.toInt(),
      lockInMonths: readNum(m['lockInPeriodMonths'])?.toInt(),
      moveIn: readDate(m['moveInDate']),
      status: readText(m['status']) ?? 'pending',
    );
  }
}

/// `businesses/{b}/settings/razorpay` (readable by any signed-in user).
class PaymentSettings {
  const PaymentSettings({this.onlineEnabled = false, this.upiId});

  final bool onlineEnabled;
  final String? upiId;
}

/// The room a stay is in.
class RoomInfo {
  const RoomInfo({this.sharing, this.hasAC = false, this.floor});

  final int? sharing;
  final bool hasAC;
  final String? floor;

  String? get sharingLabel => switch (sharing) {
    null => null,
    1 => 'Single',
    2 => 'Double sharing',
    3 => 'Triple sharing',
    final n => '$n sharing',
  };
}

/// The property card on Home and My Stay.
class PropertyContact {
  const PropertyContact({
    this.address = '',
    this.city = '',
    this.phone = '',
    this.ownerName = '',
    this.amenities = const [],
  });

  final String address;
  final String city;
  final String phone;
  final String ownerName;

  /// Amenity keys set to true on the property doc.
  final List<String> amenities;

  String get location => [address, city].where((s) => s.trim().isNotEmpty).join(', ');
}
