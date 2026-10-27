// lib/app/app_routes.dart
import 'package:flutter/material.dart';

import '../presentation/notifications/notifications_screen.dart';
import '../presentation/requests/requests_list_screen.dart';
import '../presentation/onboarding/invite_landing_screen.dart';
import '../presentation/payments/pending_payments_screen.dart';
import '../presentation/views/view_property_screen.dart';
import 'deep_links.dart';

/// Named routes (kept because screens and old notification code push them by
/// name) and the mapping from an [AppLink] to a route.
abstract final class AppRoutes {
  static const enrollmentRequests = '/enrollment-requests';
  static const invite = '/invite';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>?;
    switch (settings.name) {
      case enrollmentRequests:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => EnrollmentRequestsScreen(
            initialRequestId: args?['requestId'] as String?,
            initialPropertyId: args?['propertyId'] as String?,
          ),
        );
      case invite:
        final inviteId = args?['inviteId'] as String?;
        if (inviteId == null) return null;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => InviteLandingScreen(inviteId: inviteId),
        );
    }
    return null;
  }

  /// [businessId] supplies the current business for links that don't carry one.
  static Route<dynamic>? forLink(AppLink link, {required String? Function() businessId}) {
    switch (link) {
      case InviteLink(:final inviteId):
        return MaterialPageRoute(builder: (_) => InviteLandingScreen(inviteId: inviteId));
      case PropertyTabLink(:final propertyId, :final tab):
        return MaterialPageRoute(
          builder: (_) => ViewPropertyScreen(
            propertyId: propertyId,
            initialTabIndex: tab == PropertyTab.requests
                ? ViewPropertyScreen.requestsTabIndex
                : ViewPropertyScreen.billingTabIndex,
          ),
        );
      case EnrollmentRequestLink(:final requestId, :final propertyId):
        return MaterialPageRoute(
          builder: (_) => EnrollmentRequestsScreen(
            initialRequestId: requestId,
            initialPropertyId: propertyId,
          ),
        );
      case PendingPaymentsLink(businessId: final linkBusiness, :final propertyId):
        final id = linkBusiness ?? businessId();
        if (id == null || id.isEmpty) return null;
        return MaterialPageRoute(
          builder: (_) => PendingPaymentsScreen(businessId: id, propertyId: propertyId),
        );
      case NotificationsLink():
        return MaterialPageRoute(builder: (_) => const BusinessNotificationsScreen());
    }
  }
}
