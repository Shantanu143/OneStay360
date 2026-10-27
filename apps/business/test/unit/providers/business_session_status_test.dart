import 'package:business/data/providers/business_state_provider.dart';
import 'package:business/models/business_membership_model.dart';
import 'package:business/services/business_membership_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hand-written fake so a test can script success, "no membership" and
/// failures without generated mocks.
class _FakeMembershipService implements BusinessMembershipService {
  Object? failure;
  BusinessMembership? membership;
  int calls = 0;

  @override
  Future<BusinessMembership?> getActiveMembership(
    String uid,
    String businessId,
  ) async {
    calls++;
    final f = failure;
    if (f != null) throw f;
    return membership;
  }

  @override
  Future<bool> isActiveMember(String uid, String businessId) async =>
      (await getActiveMembership(uid, businessId)) != null;

  @override
  Stream<BusinessMembership?> streamActiveMembership(
    String uid,
    String businessId,
  ) => const Stream.empty();
}

BusinessMembership _membership({String role = 'owner'}) => BusinessMembership(
  id: 'test-uid',
  businessId: 'BUS1',
  uid: 'test-uid',
  role: role,
  status: 'active',
  name: 'Rajesh Sharma',
  email: 'a@b.c',
  phone: '',
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  late FakeFirebaseFirestore firestore;
  late _FakeMembershipService membership;
  late BusinessStateProvider provider;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    membership = _FakeMembershipService()..membership = _membership();
    provider = BusinessStateProvider(
      membershipService: membership,
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'test-uid', email: 'a@b.c'),
      ),
      firestore: firestore,
      membershipRetryDelay: Duration.zero,
    );
    await firestore.collection('users').doc('test-uid').set({
      'fullName': 'Rajesh Sharma',
      'businessName': 'Apex Living',
      'businessId': 'BUS1',
      'profileCompleted': true,
    });
  });

  group('session status', () {
    test('starts idle', () {
      expect(provider.status, SessionStatus.idle);
      expect(provider.loadError, isNull);
      expect(provider.isReady, isFalse);
    });

    test('goes loading -> ready for a valid membership', () async {
      final seen = <SessionStatus>[];
      provider.addListener(() => seen.add(provider.status));

      await provider.loadUserData();

      expect(seen.first, SessionStatus.loading);
      expect(provider.status, SessionStatus.ready);
      expect(provider.isReady, isTrue);
      expect(provider.businessId, 'BUS1');
      expect(provider.role, 'owner');
    });

    test('is noBusiness when the user document is missing', () async {
      await firestore.collection('users').doc('test-uid').delete();

      await provider.loadUserData();

      expect(provider.status, SessionStatus.noBusiness);
      expect(provider.businessId, isNull);
    });

    test('is noBusiness when the user has no businessId', () async {
      await firestore.collection('users').doc('test-uid').set({
        'fullName': 'R',
      });

      await provider.loadUserData();

      expect(provider.status, SessionStatus.noBusiness);
    });

    test('is noBusiness when there is no active membership', () async {
      membership.membership = null;

      await provider.loadUserData();

      expect(provider.status, SessionStatus.noBusiness);
      expect(provider.businessId, isNull);
      expect(provider.fullName, 'Rajesh Sharma');
    });

    test('is error (not noBusiness) when loading fails', () async {
      membership.failure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'App attestation failed',
      );

      await provider.loadUserData();

      expect(provider.status, SessionStatus.error);
      expect(provider.loadError, isNotNull);
      expect(provider.businessId, isNull);
    });

    test('keeps the last good business when a refresh fails', () async {
      await provider.loadUserData();
      expect(provider.status, SessionStatus.ready);

      membership.failure = Exception('network down');
      await provider.loadUserData();

      expect(provider.status, SessionStatus.error);
      expect(
        provider.businessId,
        'BUS1',
        reason: 'a blip must not eject the user',
      );
      expect(provider.role, 'owner');
    });

    test('recovers to ready after an error', () async {
      membership.failure = Exception('network down');
      await provider.loadUserData();
      expect(provider.status, SessionStatus.error);

      membership.failure = null;
      await provider.loadUserData();

      expect(provider.status, SessionStatus.ready);
      expect(provider.loadError, isNull);
    });

    test('concurrent loads share one request', () async {
      final a = provider.loadUserData();
      final b = provider.loadUserData();
      await Future.wait([a, b]);

      expect(membership.calls, 1);
      expect(provider.status, SessionStatus.ready);
    });

    test('does nothing (stays idle) when nobody is signed in', () async {
      provider = BusinessStateProvider(
        membershipService: membership,
        auth: MockFirebaseAuth(signedIn: false),
        firestore: firestore,
      );

      await provider.loadUserData();

      expect(provider.status, SessionStatus.idle);
    });
  });

  group('pending enrollment requests', () {
    Future<void> addRequest(
      String id, {
      String status = 'pending',
      String business = 'BUS1',
    }) => firestore.collection('enrollmentRequests').doc(id).set({
      'businessId': business,
      'status': status,
    });

    Future<void> pumpEvents() =>
        Future<void>.delayed(const Duration(milliseconds: 20));

    test('counts pending requests once the business is ready, live', () async {
      await addRequest('r1');
      await addRequest('r2', status: 'approved');
      await addRequest('r3', business: 'OTHER');

      await provider.loadUserData();
      await pumpEvents();
      expect(provider.pendingRequestsCount, 1);

      await addRequest('r4');
      await pumpEvents();
      expect(provider.pendingRequestsCount, 2);

      await firestore.collection('enrollmentRequests').doc('r1').update({
        'status': 'approved',
      });
      await pumpEvents();
      expect(provider.pendingRequestsCount, 1);
    });

    test(
      'watches a business once, however often the profile reloads',
      () async {
        await provider.loadUserData();
        await provider.loadUserData();
        await addRequest('r1');
        await pumpEvents();

        expect(provider.pendingRequestsCount, 1);
      },
    );

    test('stops watching after reset', () async {
      await provider.loadUserData();
      provider.reset();

      await addRequest('r1');
      await pumpEvents();

      expect(provider.pendingRequestsCount, 0);
    });
  });

  group('reset', () {
    test('clears everything so the next user starts clean', () async {
      await provider.loadUserData();
      provider.updatePendingRequestsCount(4);

      provider.reset();

      expect(provider.status, SessionStatus.idle);
      expect(provider.businessId, isNull);
      expect(provider.fullName, isEmpty);
      expect(provider.businessName, isEmpty);
      expect(provider.role, 'staff');
      expect(provider.pendingRequestsCount, 0);
      expect(provider.profileCompleted, isFalse);
    });

    test('notifies listeners', () async {
      await provider.loadUserData();
      var notified = 0;
      provider.addListener(() => notified++);

      provider.reset();

      expect(notified, 1);
    });
  });
}
