// lib/presentation/requests/request_models.dart
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import 'package:models/tenant/tenant_request_model.dart';

import '../views/home/home_format.dart';

DateTime? _date(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

String? _text(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

double? _number(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

/// Where an enrollment request is in its life:
/// pending -> approved | bill_sent -> payment_submitted -> confirmed,
/// or rejected.
enum RequestStage {
  pending('Pending', 'warning', 'Review the request, then approve it with a room and a first bill.'),
  approved('Approved', 'info', 'Approved. The tenant is being added to their room.'),
  billSent('Bill sent', 'info', 'Waiting for the tenant to pay the first bill.'),
  paymentSubmitted(
    'Payment to confirm',
    'warning',
    'The tenant says they paid. Check your account, then confirm.',
  ),
  confirmed('Confirmed', 'success', 'Payment confirmed. The tenant has joined.'),
  rejected('Rejected', 'danger', 'This request was rejected.'),
  approvalFailed(
    "Couldn't add tenant",
    'danger',
    'The payment was confirmed but adding the tenant failed. Fix the problem, then try again.',
  ),
  other('Unknown', 'neutral', '');

  const RequestStage(this.label, this.tone, this.nextStep);

  final String label;

  /// 'success' | 'warning' | 'danger' | 'info' | 'neutral'
  final String tone;
  final String nextStep;

  /// The owner has something to do.
  bool get needsOwner => this == pending || this == paymentSubmitted || this == approvalFailed;

  static RequestStage of(String status) {
    switch (status) {
      case 'pending':
        return pending;
      case 'approved':
        return approved;
      case 'bill_sent':
        return billSent;
      case 'payment_submitted':
        return paymentSubmitted;
      case 'confirmed':
      case 'accepted':
        return confirmed;
      case 'rejected':
        return rejected;
      case 'approval_failed':
        return approvalFailed;
      default:
        return other;
    }
  }
}

/// The first bill the owner sent.
class RequestBill {
  const RequestBill({
    this.roomNumber,
    this.bedNumber,
    this.monthlyRent,
    this.proratedRent,
    this.deposit,
    this.maintenance,
    this.foodAddon,
    this.foodDeduction,
    this.total,
    this.paymentMode,
    this.ownerUpiId,
    this.sentAt,
  });

  final String? roomNumber;
  final String? bedNumber;
  final double? monthlyRent;
  final double? proratedRent;
  final double? deposit;
  final double? maintenance;
  final bool? foodAddon;
  final double? foodDeduction;
  final double? total;
  final String? paymentMode;
  final String? ownerUpiId;
  final DateTime? sentAt;

  String get location => [
        if (roomNumber != null) 'Room $roomNumber',
        if (bedNumber != null) 'Bed $bedNumber',
      ].join(' · ');

  String? get paymentLabel {
    switch (paymentMode) {
      case 'upi_manual':
        return 'UPI';
      case 'bank_transfer':
        return 'Bank transfer';
      case 'cash':
        return 'Cash';
      case 'immediate':
        return 'Collected directly';
      case null:
        return null;
      default:
        return paymentMode;
    }
  }
}

/// What the tenant did about paying.
class RequestPayment {
  const RequestPayment({
    this.transactionId,
    this.submittedAt,
    this.confirmedAt,
    this.rejectionReason,
  });

  final String? transactionId;
  final DateTime? submittedAt;
  final DateTime? confirmedAt;

  /// Why the owner turned a previous payment down.
  final String? rejectionReason;
}

/// One enrollment request, with everything its stages add.
class EnrollmentRequest {
  const EnrollmentRequest({
    required this.id,
    required this.tenantName,
    required this.phone,
    required this.status,
    required this.createdAt,
    required this.propertyId,
    required this.businessId,
    this.propertyName,
    this.email,
    this.updatedAt,
    this.moveIn,
    this.sharing,
    this.roomType,
    this.hasAC,
    this.notes,
    this.source,
    this.bill,
    this.payment,
    this.approvalError,
  });

  final String id;
  final String tenantName;
  final String phone;
  final String status;
  final DateTime createdAt;
  final String propertyId;
  final String businessId;
  final String? propertyName;
  final String? email;
  final DateTime? updatedAt;
  final DateTime? moveIn;
  final String? sharing;
  final String? roomType;
  final bool? hasAC;
  final String? notes;
  final String? source;
  final RequestBill? bill;
  final RequestPayment? payment;

  /// Why adding the tenant failed, when it did.
  final String? approvalError;

  factory EnrollmentRequest.fromMap(String id, Map<String, dynamic> m) {
    final hasBill = m['roomNumber'] != null ||
        m['roomId'] != null ||
        m['totalBillAmount'] != null ||
        m['totalFirstMonth'] != null;
    final hasPayment = m['transactionId'] != null ||
        m['paymentSubmittedAt'] != null ||
        m['paymentRejectionReason'] != null ||
        m['confirmedAt'] != null;

    return EnrollmentRequest(
      id: id,
      tenantName: _text(m['tenantName']) ?? '',
      phone: _text(m['tenantPhone'] ?? m['phone']) ?? '',
      email: _text(m['tenantEmail'] ?? m['email']),
      status: _text(m['status']) ?? 'pending',
      // A just-written server timestamp is null until the server answers.
      createdAt: _date(m['createdAt']) ?? DateTime.now(),
      updatedAt: _date(m['updatedAt']),
      propertyId: _text(m['propertyId']) ?? '',
      businessId: _text(m['businessId']) ?? '',
      propertyName: _text(m['propertyName']),
      moveIn: _date(m['moveInDate'] ?? m['preferredMoveIn']),
      sharing: _text(m['sharingType']),
      roomType: _text(m['roomType']),
      hasAC: m['hasAC'] is bool ? m['hasAC'] as bool : null,
      notes: _text(m['notes'] ?? m['message']),
      source: _text(m['source']),
      bill: hasBill
          ? RequestBill(
              roomNumber: _text(m['roomNumber'] ?? m['roomId']),
              bedNumber: _text(m['bedNumber'] ?? m['bedId']),
              monthlyRent: _number(m['monthlyRent']),
              proratedRent: _number(m['proratedRent']),
              deposit: _number(m['depositAmount']),
              maintenance: _number(m['maintenanceAmount']),
              foodAddon: m['foodAddon'] is bool ? m['foodAddon'] as bool : null,
              foodDeduction: _number(m['foodDeduction']),
              total: _number(m['totalBillAmount'] ?? m['totalFirstMonth']),
              paymentMode: _text(m['paymentMode']),
              ownerUpiId: _text(m['ownerUpiId']),
              sentAt: _date(m['billSentAt']),
            )
          : null,
      approvalError: _text(m['approvalError']),
      payment: hasPayment
          ? RequestPayment(
              transactionId: _text(m['transactionId']),
              submittedAt: _date(m['paymentSubmittedAt']),
              confirmedAt: _date(m['confirmedAt']),
              rejectionReason: _text(m['paymentRejectionReason']),
            )
          : null,
    );
  }

  /// What the requests list already knows, to show while the live copy loads.
  factory EnrollmentRequest.fromTenantRequest(TenantRequest r) {
    return EnrollmentRequest(
      id: r.id,
      tenantName: r.tenantName,
      phone: r.phone,
      email: r.email,
      status: r.status,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      propertyId: r.propertyId,
      businessId: r.businessId,
      moveIn: r.preferredMoveIn,
      sharing: r.sharingType,
      hasAC: r.hasAC,
      notes: r.message,
      source: r.source,
    );
  }

  RequestStage get stage => RequestStage.of(status);

  /// [approvalError] if an owner can act on it (a taken bed, a room reserved
  /// for the other gender); a plain sentence for anything technical.
  String? get approvalProblem {
    final e = approvalError;
    if (e == null) return null;
    final readable = RegExp(r'already occupied|is reserved for', caseSensitive: false).hasMatch(e) &&
        !e.contains('\n');
    return readable
        ? e
        : 'Something went wrong on our side. Try again; if it keeps failing, contact support.';
  }

  bool get hasName => tenantName.trim().isNotEmpty;
  String get displayName => hasName ? tenantName.trim() : 'Unnamed request';
  String get initials => hasName ? initialsOf(tenantName) : '?';

  /// "2-sharing" for a number, the text itself otherwise, else the room type.
  String? get sharingLabel {
    final s = sharing;
    if (s != null) {
      return int.tryParse(s) != null ? '$s-sharing' : s[0].toUpperCase() + s.substring(1);
    }
    return roomType;
  }
}
