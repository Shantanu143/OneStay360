// lib/presentation/notifications/notification_target.dart
import 'package:models/business/business_notification_model.dart';

import '../property_detail/property_detail_viewmodel.dart';

/// Where tapping a notification should take the owner.
sealed class NotificationTarget {
  const NotificationTarget();
}

/// A property, opened on [tab] (an index into [PropertyDetailTab]).
final class PropertyTarget extends NotificationTarget {
  const PropertyTarget(this.propertyId, this.tab);

  static final int requestsTab = PropertyDetailTab.requests.index;
  static final int billingTab = PropertyDetailTab.payments.index;

  final String propertyId;
  final int tab;
}

final class PendingPaymentsTarget extends NotificationTarget {
  const PendingPaymentsTarget(this.businessId, {this.propertyId});

  final String businessId;
  final String? propertyId;
}

/// Only the request is known; its property has to be looked up first.
final class RequestLookupTarget extends NotificationTarget {
  const RequestLookupTarget(this.requestId);

  final String requestId;
}

/// Nothing identifies the request, so show the whole requests list.
final class RequestsListTarget extends NotificationTarget {
  const RequestsListTarget();
}

/// The notification lacks what it needs to open anything.
final class MissingTarget extends NotificationTarget {
  const MissingTarget(this.reason);

  final String reason;
}

/// Informational only.
final class NoTarget extends NotificationTarget {
  const NoTarget();
}

bool _has(String? s) => s != null && s.isNotEmpty;

NotificationTarget targetFor(BusinessNotification n) {
  switch (n.type) {
    case BusinessNotificationType.enrollmentRequest:
      if (_has(n.propertyId)) return PropertyTarget(n.propertyId!, PropertyTarget.requestsTab);
      if (_has(n.requestId)) return RequestLookupTarget(n.requestId!);
      return const RequestsListTarget();
    case BusinessNotificationType.payment:
      if (!_has(n.businessId)) return const MissingTarget('Business information missing');
      return PendingPaymentsTarget(
        n.businessId,
        propertyId: _has(n.propertyId) ? n.propertyId : null,
      );
    case BusinessNotificationType.billing:
      if (!_has(n.propertyId)) return const MissingTarget('Property information missing');
      return PropertyTarget(n.propertyId!, PropertyTarget.billingTab);
    case BusinessNotificationType.tenantEvent:
    case BusinessNotificationType.general:
      return const NoTarget();
  }
}
