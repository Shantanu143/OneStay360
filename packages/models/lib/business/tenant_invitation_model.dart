import 'package:cloud_firestore/cloud_firestore.dart';

enum TenantInvitationStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

class TenantInvitation {
  final String id;
  final String tenantId;
  final String tenantName;
  final String tenantPhone;
  final String? tenantEmail;
  final String businessId;
  final String propertyId;
  final String propertyName;
  final String floor;
  final String roomId;
  final String roomNumber;
  final int bedIndex; // 0-based bed index
  final String bedNumber; // Display bed number (1, 2, 3...)
  final DateTime moveInDate;
  final DateTime? moveOutDate;
  final double monthlyRent;
  final double? deposit;
  final double? maintenance;
  final bool? maintenanceDeductedFromDeposit;
  final double? proratedRent;
  final int? billingDay; // day of month (1-31)
  final int? lockInPeriodMonths;
  final int? noticePeriodDays;
  final String paymentCycle;
  final TenantInvitationStatus status;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final Map<String, dynamic>? tenantDetails; // Full tenant data for manual entry
  final String? gender; // For room gender validation

  TenantInvitation({
    required this.id,
    required this.tenantId,
    required this.tenantName,
    required this.tenantPhone,
    this.tenantEmail,
    required this.businessId,
    required this.propertyId,
    required this.propertyName,
    required this.floor,
    required this.roomId,
    required this.roomNumber,
    required this.bedIndex,
    required this.bedNumber,
    required this.moveInDate,
    this.moveOutDate,
    required this.monthlyRent,
    this.deposit,
    this.maintenance,
    this.maintenanceDeductedFromDeposit,
    this.proratedRent,
    this.billingDay,
    this.lockInPeriodMonths,
    this.noticePeriodDays,
    this.paymentCycle = 'Monthly',
    this.status = TenantInvitationStatus.pending,
    required this.createdAt,
    this.approvedAt,
    this.rejectedAt,
    this.rejectionReason,
    this.tenantDetails,
    this.gender,
  });

  factory TenantInvitation.fromMap(Map<String, dynamic> map, String id) {
    return TenantInvitation(
      id: id,
      tenantId: map['tenantId']?.toString() ?? '',
      tenantName: map['tenantName']?.toString() ?? '',
      tenantPhone: map['tenantPhone']?.toString() ?? '',
      tenantEmail: map['tenantEmail']?.toString(),
      businessId: map['businessId']?.toString() ?? '',
      propertyId: map['propertyId']?.toString() ?? '',
      propertyName: map['propertyName']?.toString() ?? '',
      floor: map['floor']?.toString() ?? '',
      roomId: map['roomId']?.toString() ?? '',
      roomNumber: map['roomNumber']?.toString() ?? '',
      bedIndex: (map['bedIndex'] as num?)?.toInt() ?? 0,
      bedNumber: map['bedNumber']?.toString() ?? '1',
      moveInDate: (map['moveInDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      moveOutDate: (map['moveOutDate'] as Timestamp?)?.toDate(),
      monthlyRent: (map['monthlyRent'] as num?)?.toDouble() ?? 0.0,
      deposit: (map['deposit'] as num?)?.toDouble(),
      maintenance: (map['maintenance'] as num?)?.toDouble(),
      maintenanceDeductedFromDeposit: map['maintenanceDeductedFromDeposit'] as bool?,
      proratedRent: (map['proratedRent'] as num?)?.toDouble(),
      billingDay: (map['billingDay'] as num?)?.toInt(),
      lockInPeriodMonths: (map['lockInPeriodMonths'] as num?)?.toInt(),
      noticePeriodDays: (map['noticePeriodDays'] as num?)?.toInt(),
      paymentCycle: map['paymentCycle']?.toString() ?? 'Monthly',
      status: _parseStatus(map['status']?.toString() ?? 'pending'),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedAt: (map['approvedAt'] as Timestamp?)?.toDate(),
      rejectedAt: (map['rejectedAt'] as Timestamp?)?.toDate(),
      rejectionReason: map['rejectionReason']?.toString(),
      tenantDetails: map['tenantDetails'] as Map<String, dynamic>?,
      gender: map['gender']?.toString(),
    );
  }

  static TenantInvitationStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return TenantInvitationStatus.approved;
      case 'rejected':
        return TenantInvitationStatus.rejected;
      case 'cancelled':
        return TenantInvitationStatus.cancelled;
      default:
        return TenantInvitationStatus.pending;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'tenantId': tenantId,
      'tenantName': tenantName,
      'tenantPhone': tenantPhone,
      'tenantEmail': tenantEmail,
      'businessId': businessId,
      'propertyId': propertyId,
      'propertyName': propertyName,
      'floor': floor,
      'roomId': roomId,
      'roomNumber': roomNumber,
      'bedIndex': bedIndex,
      'bedNumber': bedNumber,
      'moveInDate': Timestamp.fromDate(moveInDate),
      'moveOutDate': moveOutDate != null ? Timestamp.fromDate(moveOutDate!) : null,
      'monthlyRent': monthlyRent,
      'deposit': deposit,
      'maintenance': maintenance,
      'maintenanceDeductedFromDeposit': maintenanceDeductedFromDeposit,
      'proratedRent': proratedRent,
      'billingDay': billingDay,
      'lockInPeriodMonths': lockInPeriodMonths,
      'noticePeriodDays': noticePeriodDays,
      'paymentCycle': paymentCycle,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectedAt': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
      'rejectionReason': rejectionReason,
      'tenantDetails': tenantDetails,
      'gender': gender,
    };
  }

  String get statusText {
    switch (status) {
      case TenantInvitationStatus.pending:
        return 'Pending Approval';
      case TenantInvitationStatus.approved:
        return 'Approved';
      case TenantInvitationStatus.rejected:
        return 'Rejected';
      case TenantInvitationStatus.cancelled:
        return 'Cancelled';
    }
  }
}


