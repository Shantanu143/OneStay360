// lib/presentation/team/team_models.dart

/// A property a teammate can be given access to.
class TeamProperty {
  const TeamProperty({required this.id, required this.name});

  final String id;
  final String name;
}

/// Someone on the team: the owner, a manager or staff.
class TeamMember {
  const TeamMember({
    required this.uid,
    required this.name,
    required this.role,
    required this.status,
    this.phone,
    this.email,
  });

  factory TeamMember.fromMap(String uid, Map<String, dynamic> d) {
    String? clean(Object? v) {
      final s = v?.toString().trim() ?? '';
      return s.isEmpty ? null : s;
    }

    return TeamMember(
      uid: uid,
      name: clean(d['name']) ?? clean(d['displayName']),
      role: (clean(d['role']) ?? 'staff').toLowerCase(),
      status: clean(d['status']) ?? '',
      phone: clean(d['phone']) ?? clean(d['phoneNumber']),
      email: clean(d['email']),
    );
  }

  final String uid;
  final String? name;
  final String role;
  final String status;
  final String? phone;
  final String? email;

  /// Never the id: that means nothing to a person.
  String get displayName => name ?? email ?? phone ?? 'Team member';

  String get initials {
    // A phone number or "Team member" has no initials worth showing.
    final source = name ?? email?.split('@').first;
    if (source == null) return 'T';
    final words = source.split(RegExp(r'[\s._-]+')).where((w) => RegExp(r'^\p{L}', unicode: true).hasMatch(w));
    final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
    return letters.isEmpty ? 'T' : letters;
  }

  bool get isOwner => role == 'owner';
  bool get isActive => status == 'active';

  String get roleLabel => switch (role) {
        'owner' => 'Owner',
        'manager' => 'Manager',
        _ => 'Staff',
      };
}

/// An invitation that has been sent and not accepted yet.
class TeamInvite {
  const TeamInvite({
    required this.id,
    required this.phone,
    required this.role,
    required this.propertyIds,
    required this.createdAt,
    required this.expiresAt,
    this.email,
  });

  final String id;
  final String phone;
  final String? email;
  final String role;
  final List<String> propertyIds;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool isExpired(DateTime now) => !expiresAt.isAfter(now);

  /// Whole calendar days until it expires (0 = today).
  int daysLeft(DateTime now) => DateTime(expiresAt.year, expiresAt.month, expiresAt.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;

  String expiryLabel(DateTime now) {
    if (isExpired(now)) return 'Expired';
    final d = daysLeft(now);
    if (d <= 0) return 'Expires today';
    if (d == 1) return 'Expires tomorrow';
    return 'Expires in $d days';
  }

  String get sentTo => email == null ? phone : '$phone · $email';

  String get roleLabel => role == 'manager' ? 'Manager' : 'Staff';
}

/// What the server returns for a new invitation.
class InviteResult {
  const InviteResult({required this.id, required this.link});

  final String id;
  final String link;
}
