import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import

class TenantRequest {
  final String id;
  final String tenantName;
  final String phone;
  final String? email;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? message;
  final DateTime? preferredMoveIn;
  final String? sharingType;
  final bool? hasAC;
  final String? source;
  final String propertyId;
  final String businessId;

  TenantRequest({
    required this.id,
    required this.tenantName,
    required this.phone,
    this.email,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.message,
    this.preferredMoveIn,
    this.sharingType,
    this.hasAC,
    this.source,
    required this.propertyId,
    required this.businessId,
  });

  factory TenantRequest.fromFirestore(String id, Map<String, dynamic> data) {
    return TenantRequest(
      id: id,
      tenantName: data['tenantName'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'],
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      message: data['message'],
      preferredMoveIn: data['preferredMoveIn'] != null ? (data['preferredMoveIn'] as Timestamp).toDate() : null,
      sharingType: data['sharingType'],
      hasAC: data['hasAC'],
      source: data['source'],
      propertyId: data['propertyId'] ?? '',
      businessId: data['businessId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tenantName': tenantName,
      'phone': phone,
      'email': email,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'message': message,
      'preferredMoveIn': preferredMoveIn != null ? Timestamp.fromDate(preferredMoveIn!) : null,
      'sharingType': sharingType,
      'hasAC': hasAC,
      'source': source,
      'propertyId': propertyId,
      'businessId': businessId,
    };
  }
}
