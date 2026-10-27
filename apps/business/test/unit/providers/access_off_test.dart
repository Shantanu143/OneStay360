import 'dart:async';

import 'package:business/data/providers/business_state_provider.dart';
import 'package:business/models/business_membership_model.dart';
import 'package:business/services/business_membership_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

BusinessMembership membership({String role = 'manager'}) => BusinessMembership(
      id: 'u1',
      uid: 'u1',
      businessId: 'B1',
      role: role,
      status: 'active',
      name: 'Priya',
      email: '',
      phone: '',
    );

class FakeMembership implements BusinessMembershipService {
  BusinessMembership? current = membership();
  final stream = StreamController<BusinessMembership?>.broadcast();
  int reads = 0;

  @override
  Future<BusinessMembership?> getActiveMembership(String uid, String businessId) async {
    reads++;
    return current;
  }

  @override
  Future<bool> isActiveMember(String uid, String businessId) async => current != null;

  @override
  Stream<BusinessMembership?> streamActiveMembership(String uid, String businessId) => stream.stream;
}

void main() {
  late FakeFirebaseFirestore fs;
  late FakeMembership service;
  late BusinessStateProvider provider;

  setUp(() async {
    fs = FakeFirebaseFirestore();
    service = FakeMembership();
    await fs.doc('users/u1').set({'fullName': 'Priya', 'businessName': 'Sunrise Stays', 'businessId': 'B1'});
    await fs.doc('businesses/B1/members/u1').set({'role': 'manager', 'status': 'active'});
    provider = BusinessStateProvider(
      membershipService: service,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')),
      firestore: fs,
      membershipRetryDelay: const Duration(seconds: 30),
      propertyScopeLoader: (_, __, ___) async => <String>{},
    );
  });

  tearDown(() {
    provider.dispose();
    service.stream.close();
  });

  test('someone whose access was turned off is told so at sign in, without waiting for retries', () async {
    service.current = null;
    await fs.doc('businesses/B1/members/u1').update({'status': 'disabled'});

    await provider.loadUserData();

    expect(provider.status, SessionStatus.accessOff);
    expect(provider.businessName, 'Sunrise Stays', reason: 'so the message can name it');
    expect(provider.hasActiveMembership, isFalse);
    expect(service.reads, 1, reason: 'no 30 second retries for someone who is known to be off');
  });

  test('someone with no membership at all is still just "no business"', () async {
    service.current = null;
    await fs.doc('businesses/B1/members/u1').delete();
    final quick = BusinessStateProvider(
      membershipService: service,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')),
      firestore: fs,
      membershipRetryDelay: Duration.zero,
      propertyScopeLoader: (_, __, ___) async => <String>{},
    );
    addTearDown(quick.dispose);

    await quick.loadUserData();

    expect(quick.status, SessionStatus.noBusiness);
  });

  test('while working, being turned off shows it at once', () async {
    await provider.loadUserData();
    expect(provider.status, SessionStatus.ready);

    service.stream.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(provider.status, SessionStatus.accessOff);
  });

  test('a normal membership update changes nothing', () async {
    await provider.loadUserData();

    service.stream.add(membership(role: 'staff'));
    await Future<void>.delayed(Duration.zero);

    expect(provider.status, SessionStatus.ready);
  });

  test('once turned back on, loading again gets them in', () async {
    service.current = null;
    await fs.doc('businesses/B1/members/u1').update({'status': 'disabled'});
    await provider.loadUserData();
    expect(provider.status, SessionStatus.accessOff);

    service.current = membership();
    await fs.doc('businesses/B1/members/u1').update({'status': 'active'});
    await provider.loadUserData();

    expect(provider.status, SessionStatus.ready);
  });

  test('signing out forgets it', () async {
    await provider.loadUserData();

    provider.reset();
    service.stream.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(provider.status, SessionStatus.idle);
  });
}
