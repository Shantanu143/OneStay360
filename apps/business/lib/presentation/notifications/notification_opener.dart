// lib/presentation/notifications/notification_opener.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:models/business/business_notification_model.dart';

import '../../app/app_routes.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_dialogs.dart';
import '../maintenance/maintenance_screen.dart';
import '../payments/pending_payments_screen.dart';
import '../views/view_property_screen.dart';
import 'notification_target.dart';

/// Takes the owner to whatever [notification] is about.
Future<void> openNotification(BuildContext context, BusinessNotification notification) async {
  final target = targetFor(notification);
  final navigator = Navigator.of(context);

  switch (target) {
    case PropertyTarget(:final propertyId, :final tab):
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ViewPropertyScreen(propertyId: propertyId, initialTabIndex: tab),
        ),
      );
    case PendingPaymentsTarget(:final businessId, :final propertyId):
      navigator.push(
        MaterialPageRoute(
          builder: (_) => PendingPaymentsScreen(businessId: businessId, propertyId: propertyId),
        ),
      );
    case RequestLookupTarget(:final requestId):
      String? propertyId;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('enrollmentRequests')
            .doc(requestId)
            .get();
        propertyId = doc.data()?['propertyId']?.toString();
      } catch (_) {
        if (context.mounted) {
          showBizToast(context, "Couldn't find the property for this request.", tone: BizTone.danger);
        }
        return;
      }
      if (!context.mounted) return;
      if (propertyId != null && propertyId.isNotEmpty) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => ViewPropertyScreen(
              propertyId: propertyId!,
              initialTabIndex: PropertyTarget.requestsTab,
            ),
          ),
        );
      } else {
        navigator.pushNamed(AppRoutes.enrollmentRequests, arguments: {'requestId': requestId});
      }
    case MaintenanceListTarget():
      navigator.push(MaterialPageRoute(builder: (_) => const MaintenanceScreen()));
    case RequestsListTarget():
      navigator.pushNamed(AppRoutes.enrollmentRequests);
    case MissingTarget(:final reason):
      showBizToast(context, reason, tone: BizTone.danger);
    case NoTarget():
      break;
  }
}
