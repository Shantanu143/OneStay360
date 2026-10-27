// lib/presentation/tenant_detail/tenant_detail_actions.dart
import 'package:flutter/material.dart';

import '../common/device_actions.dart';
import '../payments/record_payment_screen.dart';
import 'tenant_detail_models.dart';

/// What the tenant screen does outside itself. Faked in tests.
abstract class TenantDetailActions {
  Future<void> call(BuildContext context, String phone);

  Future<void> openUrl(BuildContext context, Uri uri);

  Future<void> copy(BuildContext context, String text, {String? message});

  /// Opens the record-payment form; true when a payment was recorded.
  Future<bool> recordPayment(BuildContext context, TenantProfile tenant);
}

class DeviceTenantActions implements TenantDetailActions {
  const DeviceTenantActions();

  @override
  Future<void> call(BuildContext context, String phone) => dialPhone(context, phone);

  @override
  Future<void> openUrl(BuildContext context, Uri uri) => openExternal(context, uri);

  @override
  Future<void> copy(BuildContext context, String text, {String? message}) =>
      copyText(context, text, message: message);

  @override
  Future<bool> recordPayment(BuildContext context, TenantProfile tenant) async {
    final recorded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecordPaymentScreen(
          tenant: tenant.toRecordMap(),
          businessId: tenant.businessId,
        ),
      ),
    );
    return recorded == true;
  }
}
