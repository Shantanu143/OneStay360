// lib/app/deep_links.dart
//
// Everything that can open a screen from outside the app (invite links, push
// notification taps) is turned into an [AppLink] and handed to the
// [DeepLinkCoordinator], which decides *when* it is safe to navigate.
import 'package:flutter/material.dart';

enum PropertyTab { requests, billing }

/// A destination reachable from outside the app.
sealed class AppLink {
  const AppLink();

  /// Whether the user must be signed in with a loaded business first.
  /// Invite links are the exception: they handle sign-in themselves.
  bool get requiresSession => true;

  static const _inviteHost = 'app.onestay360.brandedpatil.in';

  /// `https://app.onestay360.brandedpatil.in/invite?inviteId=…`
  static AppLink? fromUri(Uri uri) {
    if (uri.host != _inviteHost || !uri.path.startsWith('/invite')) return null;
    final id = uri.queryParameters['inviteId'];
    if (id == null || id.isEmpty) return null;
    return InviteLink(id);
  }

  /// Maps the `data` of a business-bound push notification to a destination.
  static AppLink? fromPushData(Map<String, dynamic> data) {
    String? text(String key) {
      final v = data[key]?.toString();
      return (v == null || v.isEmpty) ? null : v;
    }

    switch (text('type')) {
      case 'enrollment_request':
        final propertyId = text('propertyId');
        if (propertyId != null) {
          return PropertyTabLink(propertyId, PropertyTab.requests);
        }
        final requestId = text('requestId');
        return requestId == null ? null : EnrollmentRequestLink(requestId);
      case 'billing_status_change':
        final propertyId = text('propertyId');
        return propertyId == null
            ? null
            : PropertyTabLink(propertyId, PropertyTab.billing);
      case 'payment_submitted':
        return PendingPaymentsLink(
          businessId: text('businessId'),
          propertyId: text('propertyId'),
        );
      case 'rent_received':
        return const NotificationsLink();
      default:
        return null;
    }
  }
}

final class InviteLink extends AppLink {
  const InviteLink(this.inviteId);

  final String inviteId;

  @override
  bool get requiresSession => false;
}

final class PropertyTabLink extends AppLink {
  const PropertyTabLink(this.propertyId, this.tab);

  final String propertyId;
  final PropertyTab tab;
}

final class EnrollmentRequestLink extends AppLink {
  const EnrollmentRequestLink(this.requestId, {this.propertyId});

  final String requestId;
  final String? propertyId;
}

final class PendingPaymentsLink extends AppLink {
  const PendingPaymentsLink({this.businessId, this.propertyId});

  final String? businessId;
  final String? propertyId;
}

final class NotificationsLink extends AppLink {
  const NotificationsLink();
}

typedef LinkRouteBuilder = Route<dynamic>? Function(AppLink link);

/// Opens [AppLink]s at the right moment.
///
/// * Links that need a session wait (latest one wins) until the shell reports
///   [sessionReady], and are dropped on [sessionEnded].
/// * Links that arrive before the navigator exists wait for [navigatorReady].
/// * Invite links open at once and replace the stack, since they work signed out.
class DeepLinkCoordinator {
  DeepLinkCoordinator({required this.navigatorKey, required this.routeFor});

  final GlobalKey<NavigatorState> navigatorKey;
  final LinkRouteBuilder routeFor;

  bool _sessionReady = false;
  AppLink? _waitingForSession;
  AppLink? _waitingForNavigator;
  String? _lastInviteId;

  void handle(AppLink link) {
    if (link is InviteLink) {
      if (_lastInviteId == link.inviteId) return;
      _lastInviteId = link.inviteId;
    }

    if (link.requiresSession && !_sessionReady) {
      _waitingForSession = link;
      return;
    }
    _open(link);
  }

  /// The signed-in app is on screen.
  void sessionReady() {
    _sessionReady = true;
    final link = _waitingForSession;
    if (link == null) return;
    _waitingForSession = null;
    // After the frame so the shell is mounted underneath the new route. A
    // post-frame callback doesn't request a frame itself, so ask for one or
    // an idle app would never open the link.
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) => _open(link));
    binding.ensureVisualUpdate();
  }

  /// The user signed out.
  void sessionEnded() {
    _sessionReady = false;
    _waitingForSession = null;
    _lastInviteId = null;
  }

  /// The root navigator has been built.
  void navigatorReady() {
    final link = _waitingForNavigator;
    if (link == null) return;
    _waitingForNavigator = null;
    _open(link);
  }

  void _open(AppLink link) {
    final nav = navigatorKey.currentState;
    if (nav == null) {
      _waitingForNavigator = link;
      return;
    }
    final route = routeFor(link);
    if (route == null) return;

    if (link is InviteLink) nav.popUntil((r) => r.isFirst);
    nav.push(route);
  }
}
