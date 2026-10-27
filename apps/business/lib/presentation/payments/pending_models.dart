// lib/presentation/payments/pending_models.dart
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

DateTime? _date(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

String? _text(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty || s == 'N/A' ? null : s;
}

/// A rent payment a tenant says they made, waiting for the owner to check it.
class PendingRent {
  const PendingRent({
    required this.paymentId,
    required this.tenantId,
    required this.tenantName,
    required this.amount,
    required this.month,
    required this.method,
    this.roomNumber,
    this.bedNumber,
    this.transactionId,
    this.screenshotUrl,
    this.submittedAt,
  });

  final String paymentId;
  final String tenantId;
  final String tenantName;
  final double amount;
  final String month;
  final String method;
  final String? roomNumber;
  final String? bedNumber;
  final String? transactionId;
  final String? screenshotUrl;
  final DateTime? submittedAt;

  factory PendingRent.fromMap(String paymentId, String tenantId, Map<String, dynamic> m) {
    return PendingRent(
      paymentId: paymentId,
      tenantId: _text(m['tenantId']) ?? tenantId,
      tenantName: _text(m['tenantName']) ?? 'Tenant',
      amount: (m['amount'] as num?)?.toDouble() ?? 0,
      month: _text(m['month']) ?? 'Rent',
      method: _text(m['method']) ?? 'UPI',
      roomNumber: _text(m['roomNumber']),
      bedNumber: _text(m['bedNumber']),
      transactionId: _text(m['transactionId']),
      screenshotUrl: _text(m['screenshotUrl']),
      submittedAt: _date(m['createdAt'] ?? m['paymentSubmittedAt'] ?? m['date']),
    );
  }

  /// "Room 101 · Bed 1"
  String get location => [
        if (roomNumber != null) 'Room $roomNumber',
        if (bedNumber != null) 'Bed $bedNumber',
      ].join(' · ');
}
