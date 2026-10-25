import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:tenant/data/providers/tenant_state_provider.dart';

void main() {
  group('TenantStateProvider Tests', () {
    late TenantStateProvider provider;
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser(
        uid: 'tenant-uid-123',
        email: 'tenant@test.com',
        displayName: 'Test Tenant',
      );
      provider = TenantStateProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    group('Initial State', () {
      test('should have correct initial values', () {
        expect(provider.fullName, isEmpty);
        expect(provider.email, isEmpty);
        expect(provider.phone, isEmpty);
        expect(provider.tenantId, isEmpty);
        expect(provider.currentPG, isEmpty);
        expect(provider.propertyId, isEmpty);
        expect(provider.businessId, isEmpty);
        expect(provider.roomId, isEmpty);
        expect(provider.bedId, isEmpty);
        expect(provider.unreadNotificationsCount, equals(0));
        expect(provider.tenantData, isEmpty);
      });
    });

    group('updateUnreadNotificationsCount', () {
      test('should update count and notify listeners', () {
        int notifyCount = 0;
        provider.addListener(() => notifyCount++);

        provider.updateUnreadNotificationsCount(5);

        expect(provider.unreadNotificationsCount, equals(5));
        expect(notifyCount, equals(1));
      });

      test('should not notify if count unchanged', () {
        provider.updateUnreadNotificationsCount(3);
        int notifyCount = 0;
        provider.addListener(() => notifyCount++);

        provider.updateUnreadNotificationsCount(3); // same value

        expect(notifyCount, equals(0));
      });

      test('should notify when count changes', () {
        provider.updateUnreadNotificationsCount(3);
        int notifyCount = 0;
        provider.addListener(() => notifyCount++);

        provider.updateUnreadNotificationsCount(5); // different value

        expect(notifyCount, equals(1));
        expect(provider.unreadNotificationsCount, equals(5));
      });

      test('should handle zero count', () {
        provider.updateUnreadNotificationsCount(5);
        provider.updateUnreadNotificationsCount(0);
        expect(provider.unreadNotificationsCount, equals(0));
      });
    });

    group('Dispose', () {
      test('should cancel subscriptions on dispose', () {
        // Should not throw
        expect(() => provider.dispose(), returnsNormally);
      });
    });
  });
}
