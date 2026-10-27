// lib/presentation/payments/pending_source.dart
import '../requests/request_models.dart';
import 'pending_models.dart';

/// Where the pending payments screen reads and writes (faked in tests).
abstract class PendingPaymentsSource {
  /// Rent payments waiting to be checked.
  Future<List<PendingRent>> rentPayments(String businessId, {String? propertyId});

  /// Enrollment deposits waiting to be checked, live.
  Stream<List<EnrollmentRequest>> deposits(String businessId, {String? propertyId});

  /// Confirms or rejects one rent payment (through the backend, which also
  /// marks the invoice paid and tells the tenant).
  Future<void> verifyRent({
    required String businessId,
    required String tenantId,
    required String paymentId,
    required bool confirm,
    String? reason,
  });
}
