// lib/presentation/requests/request_source.dart
import 'request_models.dart';

/// Where the request screen reads and writes (faked in tests).
abstract class RequestSource {
  /// The live request; null when it no longer exists.
  Stream<EnrollmentRequest?> watch(String requestId);

  Future<void> reject(String requestId);

  /// The owner has checked their account: the tenant has paid.
  Future<void> confirmPayment(String requestId);

  /// Sends the bill back so the tenant can pay again.
  Future<void> rejectPayment(String requestId, String reason);
}

/// Where the requests list reads from.
abstract class RequestListSource {
  /// Every request of the business, newest first, updating live.
  Stream<List<EnrollmentRequest>> watchAll(String businessId);
}
