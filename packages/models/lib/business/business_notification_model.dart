import 'package:cloud_firestore/cloud_firestore.dart';

/// General business notification categories supported in the business app.
enum BusinessNotificationType {
  enrollmentRequest,
  tenantEvent,
  payment,
  billing,
  maintenance,
  general,
}

BusinessNotificationType _notificationTypeFromString(String? value) {
  switch ((value ?? '').toLowerCase()) {
    case 'enrollment_request':
      return BusinessNotificationType.enrollmentRequest;
    case 'tenant_event':
    case 'tenant_joined': // Tenant accepted an invitation
    case 'tenant_invitation_declined':
      return BusinessNotificationType.tenantEvent;
    case 'maintenance_request':
      return BusinessNotificationType.maintenance;
    case 'payment':
    case 'payment_submitted': // Tenant submitted payment confirmation
    case 'rent_received': // Paid online (Razorpay webhook)
      return BusinessNotificationType.payment;
    case 'billing':
    case 'billing_status_change': // Platform billing notification
      return BusinessNotificationType.billing;
    default:
      return BusinessNotificationType.general;
  }
}

String _notificationTypeToString(BusinessNotificationType type) {
  switch (type) {
    case BusinessNotificationType.enrollmentRequest:
      return 'enrollment_request';
    case BusinessNotificationType.tenantEvent:
      return 'tenant_event';
    case BusinessNotificationType.payment:
      return 'payment';
    case BusinessNotificationType.billing:
      return 'billing';
    case BusinessNotificationType.maintenance:
      return 'maintenance_request';
    case BusinessNotificationType.general:
      return 'general';
  }
}

/// Firestore-backed business notification entity used across the apps/services.
class BusinessNotification {
  final String id;
  final String businessId;
  final String title;
  final String message;
  final BusinessNotificationType type;
  final bool read;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? requestId;
  final String? propertyId;
  final String? propertyName;
  final String? tenantId;
  final String? tenantName;
  final String? tenantPhone;
  final Map<String, dynamic>? metadata;

  bool get isUnread => !read;

  const BusinessNotification({
    required this.id,
    required this.businessId,
    required this.title,
    required this.message,
    required this.type,
    required this.read,
    required this.createdAt,
    this.readAt,
    this.requestId,
    this.propertyId,
    this.propertyName,
    this.tenantId,
    this.tenantName,
    this.tenantPhone,
    this.metadata,
  });

  /// The payment-submitted notification (and ones stored before the schema
  /// settled) use `body` and `enrollmentRequestId` rather than `message` and
  /// `requestId`; both spellings are read.
  factory BusinessNotification.fromMap(String id, Map<String, dynamic> data) {
    final routing = data['routing'];
    final routedRequest = routing is Map ? routing['requestId'] : null;
    return BusinessNotification(
      id: id,
      businessId: data['businessId']?.toString() ?? '',
      title: data['title']?.toString() ?? 'Notification',
      message: (data['message'] ?? data['body'])?.toString() ?? '',
      type: _notificationTypeFromString(data['type']?.toString()),
      read: data['read'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      requestId: (data['requestId'] ?? data['enrollmentRequestId'] ?? routedRequest)?.toString(),
      propertyId: data['propertyId']?.toString(),
      propertyName: data['propertyName']?.toString(),
      tenantId: data['tenantId']?.toString(),
      tenantName: data['tenantName']?.toString(),
      tenantPhone: data['tenantPhone']?.toString(),
      metadata: (data['metadata'] as Map<String, dynamic>?)?.cast<String, dynamic>(),
    );
  }

  factory BusinessNotification.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    // businesses/{businessId}/notifications/{id}: the business is in the path
    // even when the document doesn't repeat it.
    final fromPath = doc.reference.parent.parent?.id;
    return BusinessNotification.fromMap(doc.id, {
      if (fromPath != null) 'businessId': fromPath,
      ...data,
    });
  }

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'title': title,
      'message': message,
      'type': _notificationTypeToString(type),
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
      if (readAt != null) 'readAt': Timestamp.fromDate(readAt!),
      if (requestId != null) 'requestId': requestId,
      if (propertyId != null) 'propertyId': propertyId,
      if (propertyName != null) 'propertyName': propertyName,
      if (tenantId != null) 'tenantId': tenantId,
      if (tenantName != null) 'tenantName': tenantName,
      if (tenantPhone != null) 'tenantPhone': tenantPhone,
      if (metadata != null) 'metadata': metadata,
    };
  }
}
