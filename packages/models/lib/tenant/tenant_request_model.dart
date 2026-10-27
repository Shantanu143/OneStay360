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

  /// A date from a Firestore timestamp, a [DateTime] or an ISO string.
  static DateTime? _date(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static String? _text(dynamic v) {
    final s = v?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }

  /// Requests written by `submitEnrollmentRequest` call the move-in date
  /// `moveInDate` and the tenant's note `notes`; older documents used
  /// `preferredMoveIn` and `message`. Both are read.
  factory TenantRequest.fromFirestore(String id, Map<String, dynamic> data) {
    return TenantRequest(
      id: id,
      tenantName: data['tenantName'] ?? '',
      phone: data['phone'] ?? data['tenantPhone'] ?? '',
      email: _text(data['email'] ?? data['tenantEmail']),
      status: data['status'] ?? 'pending',
      // A just-written server timestamp is null until the server answers.
      createdAt: _date(data['createdAt']) ?? DateTime.now(),
      updatedAt: _date(data['updatedAt']),
      message: _text(data['message'] ?? data['notes']),
      preferredMoveIn: _date(data['preferredMoveIn'] ?? data['moveInDate']),
      sharingType: _text(data['sharingType']),
      hasAC: data['hasAC'],
      source: data['source'],
      propertyId: data['propertyId'] ?? '',
      businessId: data['businessId'] ?? '',
    );
  }

  factory TenantRequest.fromMap(Map<String, dynamic> data, String id) {
    return TenantRequest.fromFirestore(id, data);
  }

  Map<String, dynamic> toMap() {
    return {
      'tenantName': tenantName,
      'phone': phone,
      'tenantPhone': phone,
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
