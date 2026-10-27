import 'package:business/presentation/onboarding/invite_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 26, 10);

  Map<String, dynamic> doc([Map<String, dynamic> extra = const {}]) => {
        'businessId': 'B1',
        'businessName': 'Sunrise Stays',
        'inviterName': 'Rajesh Sharma',
        'role': 'manager',
        'phone': '+919811100001',
        'email': 'new@example.test',
        'propertyIds': ['P1', 'P2'],
        'propertyNames': ['Sunrise Boys PG', 'Lotus Ladies Hostel'],
        'status': 'pending',
        'expiresAt': Timestamp.fromDate(DateTime(2026, 10, 31, 10)),
        ...extra,
      };

  test('reads what the server stored', () {
    final i = Invitation.fromMap('inv1', doc());

    expect(i.id, 'inv1');
    expect(i.businessName, 'Sunrise Stays');
    expect(i.inviterName, 'Rajesh Sharma');
    expect(i.role, 'manager');
    expect(i.roleLabel, 'Manager');
    expect(i.phone, '+919811100001');
    expect(i.propertyNames, ['Sunrise Boys PG', 'Lotus Ladies Hostel']);
  });

  test('an older invitation without names still reads', () {
    final i = Invitation.fromMap('old', {
      'businessId': 'B1',
      'role': 'staff',
      'phone': '+919811100001',
      'propertyIds': ['P1'],
      'status': 'pending',
    });

    expect(i.businessName, isNull);
    expect(i.businessLabel, 'a business');
    expect(i.propertyNames, isEmpty);
    expect(i.propertyCount, 1);
    expect(i.roleLabel, 'Staff');
  });

  group('whether it can be used', () {
    test('a pending, unexpired one is ready', () {
      expect(Invitation.fromMap('i', doc()).availability(now), InviteAvailability.ready);
    });

    test('an accepted one has been used', () {
      expect(Invitation.fromMap('i', doc({'status': 'accepted'})).availability(now), InviteAvailability.used);
    });

    test('one past its date has expired, even if nobody marked it', () {
      final late = doc({'expiresAt': Timestamp.fromDate(DateTime(2026, 10, 25))});
      expect(Invitation.fromMap('i', late).availability(now), InviteAvailability.expired);
    });

    test('one marked expired has expired', () {
      expect(Invitation.fromMap('i', doc({'status': 'expired'})).availability(now), InviteAvailability.expired);
    });

    test('any other status is no longer open', () {
      expect(Invitation.fromMap('i', doc({'status': 'revoked'})).availability(now), InviteAvailability.used);
    });

    test('one with no date is not treated as expired', () {
      final d = doc()..remove('expiresAt');
      expect(Invitation.fromMap('i', d).availability(now), InviteAvailability.ready);
    });
  });

  test('says how long is left', () {
    expect(Invitation.fromMap('i', doc()).expiryLabel(now), 'Expires in 5 days');
    expect(Invitation.fromMap('i', doc({'expiresAt': Timestamp.fromDate(DateTime(2026, 10, 27, 9))})).expiryLabel(now), 'Expires tomorrow');
    expect(Invitation.fromMap('i', doc({'expiresAt': Timestamp.fromDate(DateTime(2026, 10, 26, 20))})).expiryLabel(now), 'Expires today');
    final d = doc()..remove('expiresAt');
    expect(Invitation.fromMap('i', d).expiryLabel(now), isNull);
  });
}
