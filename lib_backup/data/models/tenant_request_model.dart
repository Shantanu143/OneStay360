import 'package:cloud_firestore/cloud_firestore.dart';

class TenantRequest {
  final String id;
  final String propertyId;
  final String? tenantId;
  final String tenantName;
  final String phone;
  final String? altPhone;
  final String? email;
  final String? message;
  final DateTime? preferredMoveIn;
  final DateTime? moveOutDate;
  final int? sharingType;
  final bool? hasAC;
  final String status;
  final DateTime createdAt;
  final String? source;
  final String? roomId;
  final String? bedId;
  final String? dob;
  final String? gender;
  final String? currentAddress;
  final String? nationality;
  final String? motherTongue;
  final String? aadharNumber;
  final String? officeInstituteName;
  final String? officeInstituteId;
  final String? tenantType; // student, bachelor, family
  final String? rentBillingType; // manual, daily, weekly, monthly
  final double? monthlyRent;
  final double? deposit;
  final double? maintenance;
  final int? lockInPeriod; // in months
  final int? noticePeriod; // in days
  final bool? foodAddon;
  final int? leaseDurationMonths;
  final String? paymentCycle;

  TenantRequest({
    required this.id,
    required this.propertyId,
    this.tenantId,
    required this.tenantName,
    required this.phone,
    this.altPhone,
    this.email,
    this.message,
    this.preferredMoveIn,
    this.moveOutDate,
    this.sharingType,
    this.hasAC,
    required this.status,
    required this.createdAt,
    this.source,
    this.roomId,
    this.bedId,
    this.dob,
    this.gender,
    this.currentAddress,
    this.nationality,
    this.motherTongue,
    this.aadharNumber,
    this.officeInstituteName,
    this.officeInstituteId,
    this.tenantType,
    this.rentBillingType,
    this.monthlyRent,
    this.deposit,
    this.maintenance,
    this.lockInPeriod,
    this.noticePeriod,
    this.foodAddon,
    this.leaseDurationMonths,
    this.paymentCycle,
  });

  factory TenantRequest.fromMap(Map<String, dynamic> map, String id) {
    return TenantRequest(
      id: id,
      propertyId: map['propertyId']?.toString() ?? '',
      tenantId: map['tenantId']?.toString(),
      tenantName: map['tenantName']?.toString() ?? 'Unknown',
      phone: map['phone']?.toString() ?? '',
      altPhone: map['altPhone']?.toString(),
      email: map['email']?.toString(),
      message: map['message']?.toString(),
      preferredMoveIn: (map['preferredMoveIn'] is Timestamp)
          ? (map['preferredMoveIn'] as Timestamp).toDate()
          : (map['preferredMoveIn'] != null ? DateTime.tryParse(map['preferredMoveIn'].toString()) : null),
      moveOutDate: (map['moveOutDate'] is Timestamp)
          ? (map['moveOutDate'] as Timestamp).toDate()
          : (map['moveOutDate'] != null ? DateTime.tryParse(map['moveOutDate'].toString()) : null),
      sharingType: (map['sharingType'] as num?)?.toInt(),
      hasAC: map['hasAC'] as bool?,
      status: map['status']?.toString() ?? 'pending',
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      source: map['source']?.toString(),
      roomId: map['roomId']?.toString(),
      bedId: map['bedId']?.toString(),
      dob: map['dob']?.toString(),
      gender: map['gender']?.toString(),
      currentAddress: map['currentAddress']?.toString(),
      nationality: map['nationality']?.toString(),
      motherTongue: map['motherTongue']?.toString(),
      aadharNumber: map['aadharNumber']?.toString(),
      officeInstituteName: map['officeInstituteName']?.toString(),
      officeInstituteId: map['officeInstituteId']?.toString(),
      tenantType: map['tenantType']?.toString(),
      rentBillingType: map['rentBillingType']?.toString(),
      monthlyRent: (map['monthlyRent'] as num?)?.toDouble(),
      deposit: (map['deposit'] as num?)?.toDouble(),
      maintenance: (map['maintenance'] as num?)?.toDouble(),
      lockInPeriod: (map['lockInPeriod'] as num?)?.toInt(),
      noticePeriod: (map['noticePeriod'] as num?)?.toInt(),
      foodAddon: map['foodAddon'] as bool?,
      leaseDurationMonths: (map['leaseDurationMonths'] as num?)?.toInt(),
      paymentCycle: map['paymentCycle']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'tenantId': tenantId,
      'tenantName': tenantName,
      'phone': phone,
      'altPhone': altPhone,
      'email': email,
      'message': message,
      'preferredMoveIn': preferredMoveIn != null ? Timestamp.fromDate(preferredMoveIn!) : null,
      'moveOutDate': moveOutDate != null ? Timestamp.fromDate(moveOutDate!) : null,
      'sharingType': sharingType,
      'hasAC': hasAC,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'source': source,
      'roomId': roomId,
      'bedId': bedId,
      'dob': dob,
      'gender': gender,
      'currentAddress': currentAddress,
      'nationality': nationality,
      'motherTongue': motherTongue,
      'aadharNumber': aadharNumber,
      'officeInstituteName': officeInstituteName,
      'officeInstituteId': officeInstituteId,
      'tenantType': tenantType,
      'rentBillingType': rentBillingType,
      'monthlyRent': monthlyRent,
      'deposit': deposit,
      'maintenance': maintenance,
      'lockInPeriod': lockInPeriod,
      'noticePeriod': noticePeriod,
      'foodAddon': foodAddon,
      'leaseDurationMonths': leaseDurationMonths,
      'paymentCycle': paymentCycle,
    };
  }
}
