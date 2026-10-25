import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:business/services/business_membership_service.dart';
import 'package:business/models/business_membership_model.dart';

void main() {
  group('BusinessMembershipService Tests', () {
    late BusinessMembershipService service;
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = BusinessMembershipService(firestore: fakeFirestore);
    });

    Future<void> seedMembership({
      required String uid,
      required String businessId,
      required String role,
      required String status,
    }) async {
      await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('members')
          .doc(uid)
          .set({
        'uid': uid,
        'businessId': businessId,
        'role': role,
        'status': status,
        'name': 'Test User',
        'email': 'test@example.com',
        'phone': '9876543210',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    }

    group('getActiveMembership', () {
      test('should return membership for active member', () async {
        await seedMembership(
          uid: 'user-123',
          businessId: 'BUS0000001',
          role: 'owner',
          status: 'active',
        );

        final membership = await service.getActiveMembership(
          'user-123',
          'BUS0000001',
        );

        expect(membership, isNotNull);
        expect(membership!.uid, equals('user-123'));
        expect(membership.businessId, equals('BUS0000001'));
        expect(membership.role, equals('owner'));
        expect(membership.status, equals('active'));
      });

      test('should return null for inactive member', () async {
        await seedMembership(
          uid: 'user-456',
          businessId: 'BUS0000001',
          role: 'staff',
          status: 'inactive',
        );

        final membership = await service.getActiveMembership(
          'user-456',
          'BUS0000001',
        );

        expect(membership, isNull);
      });

      test('should return null for non-existent member', () async {
        final membership = await service.getActiveMembership(
          'non-existent-uid',
          'BUS0000001',
        );

        expect(membership, isNull);
      });

      test('should return null for pending member', () async {
        await seedMembership(
          uid: 'user-789',
          businessId: 'BUS0000001',
          role: 'manager',
          status: 'pending',
        );

        final membership = await service.getActiveMembership(
          'user-789',
          'BUS0000001',
        );

        expect(membership, isNull);
      });

      test('should handle different roles correctly', () async {
        final roles = ['owner', 'manager', 'staff'];

        for (final role in roles) {
          final uid = 'user-$role';
          await seedMembership(
            uid: uid,
            businessId: 'BUS0000001',
            role: role,
            status: 'active',
          );

          final membership = await service.getActiveMembership(
            uid,
            'BUS0000001',
          );

          expect(membership, isNotNull);
          expect(membership!.role, equals(role));
        }
      });

      test('should not return membership from different business', () async {
        await seedMembership(
          uid: 'user-cross',
          businessId: 'BUS0000002',
          role: 'owner',
          status: 'active',
        );

        final membership = await service.getActiveMembership(
          'user-cross',
          'BUS0000001', // Different business
        );

        expect(membership, isNull);
      });
    });
  });
}
