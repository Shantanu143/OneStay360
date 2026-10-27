// lib/app/routes.dart
//
// One place that knows how to open each pushed screen, used by tabs,
// notifications and push messages alike.
import 'package:flutter/cupertino.dart';
import 'package:models/business/property/property_model.dart';

import '../data/models.dart';
import '../presentation/invitations/invitation_screen.dart';
import '../presentation/maintenance/maintenance_screen.dart';
import '../presentation/notifications/notification_target.dart';
import '../presentation/notifications/notifications_screen.dart';
import '../presentation/payments/payment_history_screen.dart';
import '../presentation/payments/rent_payment_screen.dart';
import '../presentation/payments/request_screen.dart';
import '../presentation/profile/documents_screen.dart';
import '../presentation/profile/edit_profile_screen.dart';
import '../presentation/profile/saved_screen.dart';
import '../presentation/property/property_screen.dart';
import 'tenant_shell.dart';

Future<T?> _push<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(CupertinoPageRoute(builder: (_) => page));

Future<void> openRequest(BuildContext context, String requestId) => _push(context, RequestScreen(requestId: requestId));

Future<void> openInvitation(BuildContext context, String invitationId) =>
    _push(context, InvitationScreen(invitationId: invitationId));

Future<void> openNotifications(BuildContext context) => _push(context, const NotificationsScreen());

Future<void> openRentPayment(BuildContext context, {RentInvoice? invoice}) =>
    _push(context, RentPaymentScreen(invoice: invoice));

Future<void> openPaymentHistory(BuildContext context) => _push(context, const PaymentHistoryScreen());

Future<void> openMaintenance(BuildContext context, {bool startNew = false}) =>
    _push(context, MaintenanceScreen(startNew: startNew));

Future<void> openEditProfile(BuildContext context) => _push(context, const EditProfileScreen());

Future<void> openDocuments(BuildContext context) => _push(context, const DocumentsScreen());

Future<void> openSaved(BuildContext context) => _push(context, const SavedScreen());

Future<void> openProperty(BuildContext context, String propertyId, {Property? preview}) =>
    _push(context, PropertyScreen(propertyId: propertyId, preview: preview));

/// Follows a notification: pushes its screen or switches tab.
void openTarget(BuildContext context, NotificationTarget target, {ShellController? shell}) {
  switch (target) {
    case RequestTarget(:final requestId):
      openRequest(context, requestId);
    case InvitationTarget(:final invitationId):
      openInvitation(context, invitationId);
    case StayTarget():
      Navigator.of(context).popUntil((r) => r.isFirst);
      shell?.goTo(ShellTab.stay);
    case MaintenanceTarget():
      openMaintenance(context);
    case NoTarget():
      break;
  }
}
