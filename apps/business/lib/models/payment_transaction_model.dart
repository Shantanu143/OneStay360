import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an immutable payment transaction.
///
/// DESIGN PRINCIPLE (NON-NEGOTIABLE):
/// PaymentTransaction is append-only. It must never be mutated after creation.
/// If a correction is needed, a new transaction is created; the original is never changed.
/// This ensures audit trail integrity and accounting correctness.
///
/// Fields are final. No copyWith. No setters. No update/delete in service.
class PaymentTransaction {
  final String id;
  final String businessId; // REQUIRED: Ensures multi-tenant isolation
  final String tenantId;
  final String propertyId;
  final String paymentMethodId;
  final double amount;
  final String currency; // e.g., "INR"
  final String mode; // "upi" | "bank" | "cash"
  final String? referenceId; // UPI ref, check number, etc.
  final DateTime? createdAt; // null during creation (server timestamp applied by Firestore)
  final String createdBy; // uid of user who recorded transaction

  const PaymentTransaction({
    required this.id,
    required this.businessId,
    required this.tenantId,
    required this.propertyId,
    required this.paymentMethodId,
    required this.amount,
    required this.currency,
    required this.mode,
    this.referenceId,
    this.createdAt,
    required this.createdBy,
  });

  /// Convert model to Firestore document format.
  /// Includes all fields for persistence.
  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'tenantId': tenantId,
      'propertyId': propertyId,
      'paymentMethodId': paymentMethodId,
      'amount': amount,
      'currency': currency,
      'mode': mode,
      'referenceId': referenceId,
      // Prefer provided createdAt; otherwise let Firestore set server time for append-only writes.
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    };
  }

  /// Create model from Firestore document snapshot.
  /// createdAt will always be present in persisted documents.
  factory PaymentTransaction.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return PaymentTransaction(
      id: doc.id,
      businessId: data['businessId'] as String,
      tenantId: data['tenantId'] as String,
      propertyId: data['propertyId'] as String,
      paymentMethodId: data['paymentMethodId'] as String,
      amount: (data['amount'] as num).toDouble(),
      currency: data['currency'] as String? ?? 'INR',
      mode: data['mode'] as String,
      referenceId: data['referenceId'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      createdBy: data['createdBy'] as String,
    );
  }

  @override
  String toString() =>
      'PaymentTransaction(id: $id, businessId: $businessId, tenantId: $tenantId, amount: $amount, mode: $mode, createdAt: $createdAt)';
}
