// lib/presentation/property_detail/property_detail_source.dart
import 'package:models/business/property/property_model.dart';
import 'package:models/business/property/property_room_model.dart';
import 'package:models/tenant/tenant_request_model.dart';

import 'property_detail_models.dart';

/// Where the property detail screen reads its data from (faked in tests).
abstract class PropertyDetailSource {
  Future<Property?> property(String propertyId);
  Future<List<PropertyRoom>> rooms(Property property);

  /// Active tenants of the property (members may read these).
  Future<List<PropertyTenant>> activeTenants(String businessId, String propertyId);

  /// Live enrollment requests for the property, newest first.
  Stream<List<TenantRequest>> requests(String propertyId);

  /// What the owner has paid OneStay360 for this property.
  Future<List<Map<String, dynamic>>> billingPayments(String businessId, String propertyId);

  /// The invoice to pay when billing is due/grace/past due.
  Future<String?> unpaidInvoiceId(String businessId, String propertyId);

  /// The rent invoices of [period] ("2026-10") for the given tenants.
  Future<List<InvoiceSummary>> invoicesFor(
    String businessId,
    List<String> tenantIds,
    String period,
  );
}
