// lib/presentation/requests/request_detail_actions.dart
import 'package:flutter/material.dart';

import '../common/device_actions.dart';
import 'approval_screen.dart';
import 'request_models.dart';

/// What the request screen does outside itself. Faked in tests.
abstract class RequestDetailActions {
  Future<void> call(BuildContext context, String phone);

  Future<void> openUrl(BuildContext context, Uri uri);

  Future<void> copy(BuildContext context, String text, {String? message});

  /// Opens the approval form; true when the owner approved or sent a bill.
  Future<bool> openApproval(BuildContext context, EnrollmentRequest request);
}

class DeviceRequestActions implements RequestDetailActions {
  const DeviceRequestActions();

  @override
  Future<void> call(BuildContext context, String phone) => dialPhone(context, phone);

  @override
  Future<void> openUrl(BuildContext context, Uri uri) => openExternal(context, uri);

  @override
  Future<void> copy(BuildContext context, String text, {String? message}) =>
      copyText(context, text, message: message);

  @override
  Future<bool> openApproval(BuildContext context, EnrollmentRequest request) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ApprovalScreen(request: request)),
    );
    return done == true;
  }
}
