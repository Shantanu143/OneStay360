// lib/presentation/notifications/notification_target.dart
import '../../data/models.dart';

/// Where tapping a notification (push or in-app) takes the tenant.
sealed class NotificationTarget {
  const NotificationTarget();
}

/// An enrollment request's status page (bill, payment, approval).
final class RequestTarget extends NotificationTarget {
  const RequestTarget(this.requestId);

  final String requestId;

  @override
  bool operator ==(Object other) => other is RequestTarget && other.requestId == requestId;

  @override
  int get hashCode => requestId.hashCode;
}

final class InvitationTarget extends NotificationTarget {
  const InvitationTarget(this.invitationId);

  final String invitationId;

  @override
  bool operator ==(Object other) => other is InvitationTarget && other.invitationId == invitationId;

  @override
  int get hashCode => invitationId.hashCode;
}

/// The My stay tab (rent, payments).
final class StayTarget extends NotificationTarget {
  const StayTarget();

  @override
  bool operator ==(Object other) => other is StayTarget;

  @override
  int get hashCode => 1;
}

final class MaintenanceTarget extends NotificationTarget {
  const MaintenanceTarget();

  @override
  bool operator ==(Object other) => other is MaintenanceTarget;

  @override
  int get hashCode => 2;
}

final class NoTarget extends NotificationTarget {
  const NoTarget();

  @override
  bool operator ==(Object other) => other is NoTarget;

  @override
  int get hashCode => 0;
}

String? _id(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

NotificationTarget _route(String? type, {String? requestId, String? invitationId}) {
  switch (type) {
    case 'bill_received':
    case 'bill_sent':
    case 'enrollment_approved':
    case 'enrollment_rejected':
    case 'payment_submitted':
      return requestId == null ? const NoTarget() : RequestTarget(requestId);
    case 'tenant_invitation':
      return invitationId == null ? const NoTarget() : InvitationTarget(invitationId);
    case 'rent_due':
    case 'rent_overdue':
    case 'rent_payment_update':
    case 'rent_payment_verified':
    case 'tenant_linked':
      return const StayTarget();
    case 'maintenance_update':
      return const MaintenanceTarget();
    default:
      return const NoTarget();
  }
}

/// For a push message's data payload.
NotificationTarget pushTarget(Map<String, dynamic> data) => _route(
      _id(data['type']),
      requestId: _id(data['requestId']) ?? _id(data['enrollmentRequestId']),
      invitationId: _id(data['invitationId']),
    );

/// For an in-app notification.
NotificationTarget notificationTarget(TenantNotification n) =>
    _route(n.type, requestId: n.enrollmentRequestId, invitationId: n.invitationId);
