// lib/presentation/property_detail/property_detail_actions.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:models/business/property/property_model.dart';
import 'package:models/tenant/tenant_request_model.dart';
import 'package:provider/provider.dart';

import '../../data/providers/business_state_provider.dart';
import '../../utils/permissions.dart';
import '../common/device_actions.dart';
import '../views/checkout_screen.dart';
import '../requests/request_detail_screen.dart';
import '../tenant_detail/tenant_detail_screen.dart';
import 'property_detail_models.dart';

/// Everything the property screen does outside itself: opening other screens,
/// the phone, the clipboard. Faked in tests so they need no Firebase.
abstract class PropertyDetailActions {
  /// Opens a tenant; true when they were removed, so the caller reloads.
  Future<bool> openTenant(
    BuildContext context, {
    required Property property,
    required PropertyTenant tenant,
  });

  Future<void> openRequest(
    BuildContext context, {
    required String propertyId,
    required TenantRequest request,
  });

  /// Opens checkout; true when the payment went through.
  Future<bool> openCheckout(
    BuildContext context, {
    required String propertyId,
    required String purpose,
    String? invoiceId,
  });

  Future<void> call(BuildContext context, String phone);

  Future<void> openUrl(BuildContext context, Uri uri);

  Future<void> copy(BuildContext context, String text, {String? message});
}

/// The real thing.
class DeviceDetailActions implements PropertyDetailActions {
  const DeviceDetailActions();

  @override
  Future<bool> openTenant(
    BuildContext context, {
    required Property property,
    required PropertyTenant tenant,
  }) async {
    var canRemove = false;
    try {
      final role = Provider.of<BusinessStateProvider>(context, listen: false).role;
      canRemove = BusinessPermissions.fromRole(role).canDeleteTenants;
    } catch (_) {
      // No session in scope: leave removal off.
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TenantDetailScreen(
          tenant: tenant.toDetailMap(
            businessId: property.businessId,
            propertyId: property.id ?? '',
          ),
          propertyName: property.name,
          businessId: property.businessId,
          canRemove: canRemove,
        ),
      ),
    );
    return changed == true;
  }

  @override
  Future<void> openRequest(
    BuildContext context, {
    required String propertyId,
    required TenantRequest request,
  }) {
    HapticFeedback.lightImpact();
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            RequestDetailScreen(propertyId: propertyId, request: request),
      ),
    );
  }

  @override
  Future<bool> openCheckout(
    BuildContext context, {
    required String propertyId,
    required String purpose,
    String? invoiceId,
  }) async {
    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          propertyId: propertyId,
          purpose: purpose,
          invoiceId: invoiceId,
        ),
      ),
    );
    return paid == true;
  }

  @override
  Future<void> call(BuildContext context, String phone) => dialPhone(context, phone);

  @override
  Future<void> openUrl(BuildContext context, Uri uri) => openExternal(context, uri);

  @override
  Future<void> copy(BuildContext context, String text, {String? message}) =>
      copyText(context, text, message: message);
}
