// lib/presentation/tenant_detail/tenant_detail_source.dart
import 'tenant_detail_models.dart';

/// Where the tenant screen reads and writes (faked in tests).
abstract class TenantDetailSource {
  /// The tenant's payments, newest first, updating live.
  Stream<List<TenantPayment>> payments(String businessId, String tenantId);

  Future<void> updateContact(
    String businessId,
    String tenantId, {
    required String name,
    required String phone,
    required String email,
  });

  /// Frees the tenant's bed and ends the stay.
  Future<void> vacate({
    required String businessId,
    required String tenantId,
    required String propertyId,
    required String roomId,
    required String bedId,
  });
}
