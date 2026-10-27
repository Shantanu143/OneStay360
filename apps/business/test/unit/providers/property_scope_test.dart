import 'package:business/data/providers/business_state_provider.dart';
import 'package:business/models/business_membership_model.dart';
import 'package:business/services/business_membership_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeMembership implements BusinessMembershipService {
  FakeMembership(this.role);
  final String role;

  @override
  Future<BusinessMembership?> getActiveMembership(String uid, String businessId) async => BusinessMembership(
        id: uid,
        uid: uid,
        businessId: businessId,
        role: role,
        status: 'active',
        name: 'Priya',
        email: '',
        phone: '',
      );

  @override
  Future<bool> isActiveMember(String uid, String businessId) async => true;

  @override
  Stream<BusinessMembership?> streamActiveMembership(String uid, String businessId) => const Stream.empty();
}

void main() {
  late FakeFirebaseFirestore fs;

  setUp(() async {
    fs = FakeFirebaseFirestore();
    await fs.doc('users/u1').set({'fullName': 'Priya', 'businessName': 'Sunrise', 'businessId': 'B1'});
    for (final p in ['P1', 'P2', 'P3', 'P4']) {
      await fs.doc('businesses/B1/properties/$p').set({'name': 'Property $p'});
    }
  });

  BusinessStateProvider make(String role, {Future<Set<String>?> Function(String, String, String)? loader}) =>
      BusinessStateProvider(
        membershipService: FakeMembership(role),
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')),
        firestore: fs,
        membershipRetryDelay: Duration.zero,
        propertyScopeLoader: loader,
      );

  Future<void> grant(String property, String uid) => fs.doc('businesses/B1/properties/$property/access/$uid').set({'role': 'manager'});

  group('who can open which property', () {
    test('the owner can open everything', () async {
      final p = make('owner');
      addTearDown(p.dispose);

      await p.loadUserData();

      expect(p.propertyScope, isNull);
      expect(p.canOpenProperty('P1'), isTrue);
      expect(p.canOpenProperty('anything'), isTrue);
    });

    test('a manager can open only what they were given', () async {
      await grant('P1', 'u1');
      await grant('P3', 'u1');
      await grant('P2', 'someone-else');
      final p = make('manager');
      addTearDown(p.dispose);

      await p.loadUserData();

      expect(p.propertyScope, {'P1', 'P3'});
      expect(p.canOpenProperty('P1'), isTrue);
      expect(p.canOpenProperty('P2'), isFalse);
      expect(p.canOpenProperty('P4'), isFalse);
      expect(p.canOpenProperty(null), isFalse);
    });

    test('someone given nothing can open nothing', () async {
      final p = make('staff');
      addTearDown(p.dispose);

      await p.loadUserData();

      expect(p.propertyScope, isEmpty);
      expect(p.canOpenProperty('P1'), isFalse);
    });

    test('the scope cannot be changed from outside', () async {
      await grant('P1', 'u1');
      final p = make('manager');
      addTearDown(p.dispose);
      await p.loadUserData();

      expect(() => p.propertyScope!.add('P2'), throwsUnsupportedError);
    });

    test('is read again whenever the session reloads, so new access shows up', () async {
      final p = make('manager');
      addTearDown(p.dispose);
      await p.loadUserData();
      expect(p.propertyScope, isEmpty);

      await grant('P2', 'u1');
      await p.loadUserData();

      expect(p.propertyScope, {'P2'});
    });

    test('is forgotten on sign out', () async {
      await grant('P1', 'u1');
      final p = make('manager');
      addTearDown(p.dispose);
      await p.loadUserData();

      p.reset();

      expect(p.propertyScope, isNull);
    });

    test('if it cannot be read the session fails rather than showing everything', () async {
      final p = make('manager', loader: (_, __, ___) async => throw Exception('permission-denied'));
      addTearDown(p.dispose);

      await p.loadUserData();

      expect(p.status, SessionStatus.error);
      expect(p.propertyScope, isNotNull, reason: 'never null (= everything) for someone who is not the owner');
      expect(p.propertyScope, isEmpty);
    });

    test('a custom loader can say "everything" for tests', () async {
      final p = make('manager', loader: (_, __, ___) async => null);
      addTearDown(p.dispose);

      await p.loadUserData();

      expect(p.propertyScope, isNull);
      expect(p.status, SessionStatus.ready);
    });
  });

  group('requests waiting', () {
    Future<void> request(String id, String property, {String status = 'pending'}) =>
        fs.doc('enrollmentRequests/$id').set({'businessId': 'B1', 'propertyId': property, 'status': status});

    test('the owner is told about every one', () async {
      await request('r1', 'P1');
      await request('r2', 'P3');
      final p = make('owner');
      addTearDown(p.dispose);

      await p.loadUserData();
      await Future<void>.delayed(Duration.zero);

      expect(p.pendingRequestsCount, 2);
    });

    test('a manager is told only about their properties', () async {
      await grant('P1', 'u1');
      await request('r1', 'P1');
      await request('r2', 'P3');
      await request('r3', 'P3');
      await request('r4', 'P1', status: 'approved');
      final p = make('manager');
      addTearDown(p.dispose);

      await p.loadUserData();
      await Future<void>.delayed(Duration.zero);

      expect(p.pendingRequestsCount, 1);
    });
  });
}
