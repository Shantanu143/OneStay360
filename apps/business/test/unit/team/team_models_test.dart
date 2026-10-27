import 'package:business/presentation/team/team_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TeamMember', () {
    TeamMember member(Map<String, dynamic> data, {String uid = 'uid-123456789'}) => TeamMember.fromMap(uid, data);

    test('is named by what we know, never by its id', () {
      expect(member({'name': 'Priya Nair', 'phone': '+919000000002'}).displayName, 'Priya Nair');
      expect(member({'displayName': 'Priya N', 'phone': '+919000000002'}).displayName, 'Priya N');
      expect(member({'email': 'priya@example.test', 'phone': '+919000000002'}).displayName, 'priya@example.test');
      expect(member({'phone': '+919000000002'}).displayName, '+919000000002');
      expect(member({}).displayName, 'Team member');
    });

    test('ignores blank names', () {
      expect(member({'name': '  ', 'phone': '+919000000002'}).displayName, '+919000000002');
    });

    test('has initials from its name, or a stand-in', () {
      expect(member({'name': 'Priya Nair'}).initials, 'PN');
      expect(member({'name': 'Amit'}).initials, 'A');
      expect(member({}).initials, 'T');
    });

    test('reads its role and whether it is the owner', () {
      expect(member({'role': 'owner'}).isOwner, isTrue);
      expect(member({'role': 'Manager'}).isOwner, isFalse);
      expect(member({'role': 'Manager'}).role, 'manager');
      expect(member({'role': 'manager'}).roleLabel, 'Manager');
      expect(member({'role': 'staff'}).roleLabel, 'Staff');
      expect(member({'role': 'owner'}).roleLabel, 'Owner');
      expect(member({}).role, 'staff');
    });

    test('is active only when its status says so', () {
      expect(member({'status': 'active'}).isActive, isTrue);
      expect(member({'status': 'disabled'}).isActive, isFalse);
      expect(member({}).isActive, isFalse);
    });

    test('keeps its contact details', () {
      final m = member({'phone': '+919000000002', 'email': 'p@example.test'});
      expect(m.phone, '+919000000002');
      expect(m.email, 'p@example.test');
      expect(member({}).phone, isNull);
    });
  });

  group('TeamInvite', () {
    final now = DateTime(2026, 10, 26, 10);

    TeamInvite invite({DateTime? expires, String? email}) => TeamInvite(
          id: 'inv1',
          phone: '+919811100001',
          email: email,
          role: 'manager',
          propertyIds: const ['P1'],
          createdAt: DateTime(2026, 10, 24),
          expiresAt: expires ?? DateTime(2026, 10, 31, 10),
        );

    test('counts the days left', () {
      expect(invite().daysLeft(now), 5);
      expect(invite(expires: DateTime(2026, 10, 27, 9)).daysLeft(now), 1);
      expect(invite(expires: DateTime(2026, 10, 26, 18)).daysLeft(now), 0);
    });

    test('is expired once its time has passed', () {
      expect(invite().isExpired(now), isFalse);
      expect(invite(expires: DateTime(2026, 10, 26, 9)).isExpired(now), isTrue);
    });

    test('says how long is left in words', () {
      expect(invite().expiryLabel(now), 'Expires in 5 days');
      expect(invite(expires: DateTime(2026, 10, 27, 9)).expiryLabel(now), 'Expires tomorrow');
      expect(invite(expires: DateTime(2026, 10, 26, 18)).expiryLabel(now), 'Expires today');
      expect(invite(expires: DateTime(2026, 10, 25)).expiryLabel(now), 'Expired');
    });

    test('names who it is for: the email if there is one, else the number', () {
      expect(invite().sentTo, '+919811100001');
      expect(invite(email: 'a@example.test').sentTo, '+919811100001 · a@example.test');
    });
  });
}
