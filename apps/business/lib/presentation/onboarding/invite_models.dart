// lib/presentation/onboarding/invite_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum InviteAvailability { ready, used, expired }

/// An invitation to join a business, as the invitee sees it before signing in.
class Invitation {
  const Invitation({
    required this.id,
    required this.role,
    required this.phone,
    required this.status,
    required this.propertyIds,
    required this.propertyNames,
    this.businessName,
    this.inviterName,
    this.email,
    this.expiresAt,
  });

  factory Invitation.fromMap(String id, Map<String, dynamic> d) {
    String? text(Object? v) {
      final s = v?.toString().trim() ?? '';
      return s.isEmpty ? null : s;
    }

    final expires = d['expiresAt'];
    return Invitation(
      id: id,
      businessName: text(d['businessName']),
      inviterName: text(d['inviterName']),
      role: text(d['role']) ?? 'staff',
      phone: text(d['phone']) ?? '',
      email: text(d['email']),
      status: text(d['status']) ?? 'pending',
      propertyIds: [for (final p in (d['propertyIds'] as List? ?? const [])) p.toString()],
      propertyNames: [for (final p in (d['propertyNames'] as List? ?? const [])) p.toString()],
      expiresAt: expires is Timestamp ? expires.toDate() : (expires is DateTime ? expires : null),
    );
  }

  final String id;
  final String? businessName;
  final String? inviterName;
  final String role;
  final String phone;
  final String? email;
  final String status;
  final List<String> propertyIds;
  final List<String> propertyNames;
  final DateTime? expiresAt;

  String get roleLabel => role == 'manager' ? 'Manager' : 'Staff';

  /// What to call the business when the invitation did not carry its name.
  String get businessLabel => businessName ?? 'a business';

  int get propertyCount => propertyNames.isNotEmpty ? propertyNames.length : propertyIds.length;

  InviteAvailability availability(DateTime now) {
    if (status == 'expired') return InviteAvailability.expired;
    if (status != 'pending') return InviteAvailability.used;
    final at = expiresAt;
    if (at != null && !at.isAfter(now)) return InviteAvailability.expired;
    return InviteAvailability.ready;
  }

  String? expiryLabel(DateTime now) {
    final at = expiresAt;
    if (at == null) return null;
    final days = DateTime(at.year, at.month, at.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days <= 0) return 'Expires today';
    if (days == 1) return 'Expires tomorrow';
    return 'Expires in $days days';
  }
}

/// What accepting an invitation gives access to.
class AcceptedInvite {
  const AcceptedInvite({required this.businessId, required this.role, required this.propertyIds});

  final String businessId;
  final String role;
  final List<String> propertyIds;
}
