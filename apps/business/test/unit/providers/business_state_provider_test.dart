import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

import 'package:business/data/providers/business_state_provider.dart';
import 'package:business/services/business_membership_service.dart';
import 'package:business/models/business_membership_model.dart';

// Generate mocks
@GenerateMocks([BusinessMembershipService])
import 'business_state_provider_test.mocks.dart';

void main() {
  group('BusinessStateProvider Tests', () {
    late BusinessStateProvider provider;
    late MockBusinessMembershipService mockMembershipService;
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;

    setUp(() {
      mockMembershipService = MockBusinessMembershipService();
      fakeFirestore = FakeFirebaseFirestore();
      mockUser = MockUser(
        uid: 'test-uid-123',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

      provider = BusinessStateProvider(
        membershipService: mockMembershipService,
        auth: mockAuth,
        firestore: fakeFirestore,
      );
    });

    group('Initial State', () {
      test('should have correct initial values', () {
        expect(provider.fullName, isEmpty);
        expect(provider.businessName, isEmpty);
        expect(provider.businessId, isNull);
        expect(provider.role, equals('staff'));
        expect(provider.hasActiveMembership, isFalse);
        expect(provider.pendingRequestsCount, equals(0));
        expect(provider.profileCompleted, isFalse);
      });
    });

    group('loadUserData', () {
      test('should handle user not logged in', () async {
        provider = BusinessStateProvider(
          membershipService: mockMembershipService,
          auth: MockFirebaseAuth(signedIn: false),
          firestore: fakeFirestore,
        );

        await provider.loadUserData();

        expect(provider.businessId, isNull);
        expect(provider.hasActiveMembership, isFalse);
      });

      test('should handle user document not found', () async {
        // No user document in Firestore
        await provider.loadUserData();

        expect(provider.businessId, isNull);
        expect(provider.profileCompleted, isFalse);
      });

      test('should load user data successfully with valid membership', () async {
        // Setup user document
        await fakeFirestore.collection('users').doc('test-uid-123').set({
          'fullName': 'John Doe',
          'businessName': 'Test PG Business',
          'businessId': 'BUS0000001',
          'profileCompleted': true,
        });

        // Mock successful membership validation
        final mockMembership = BusinessMembership(
          id: 'membership-123',
          uid: 'test-uid-123',
          businessId: 'BUS0000001',
          role: 'owner',
          status: 'active',
          name: 'John Doe',
          email: 'test@example.com',
          phone: '9876543210',
          createdAt: DateTime.now(),
        );

        when(mockMembershipService.getActiveMembership('test-uid-123', 'BUS0000001'))
            .thenAnswer((_) async => mockMembership);

        await provider.loadUserData();

        expect(provider.fullName, equals('John Doe'));
        expect(provider.businessName, equals('Test PG Business'));
        expect(provider.businessId, equals('BUS0000001'));
        expect(provider.role, equals('owner'));
        expect(provider.hasActiveMembership, isTrue);
        expect(provider.profileCompleted, isTrue);
      });

      test('should handle membership validation failure', () async {
        // Setup user document
        await fakeFirestore.collection('users').doc('test-uid-123').set({
          'fullName': 'John Doe',
          'businessName': 'Test PG Business',
          'businessId': 'BUS0000001',
          'profileCompleted': true,
        });

        // Mock membership validation failure
        when(mockMembershipService.getActiveMembership('test-uid-123', 'BUS0000001'))
            .thenAnswer((_) async => null);

        await provider.loadUserData();

        expect(provider.fullName, equals('John Doe'));
        expect(provider.businessName, equals('Test PG Business'));
        expect(provider.businessId, isNull); // Should be null due to failed membership
        expect(provider.hasActiveMembership, isFalse);
      });

      test('should retry membership validation on failure', () async {
        // Setup user document
        await fakeFirestore.collection('users').doc('test-uid-123').set({
          'fullName': 'John Doe',
          'businessName': 'Test PG Business',
          'businessId': 'BUS0000001',
          'profileCompleted': true,
        });

        final mockMembership = BusinessMembership(
          id: 'membership-123',
          uid: 'test-uid-123',
          businessId: 'BUS0000001',
          role: 'manager',
          status: 'active',
          name: 'John Doe',
          email: 'test@example.com',
          phone: '9876543210',
          createdAt: DateTime.now(),
        );

        var attempts = 0;
        when(mockMembershipService.getActiveMembership('test-uid-123', 'BUS0000001'))
            .thenAnswer((_) async {
          attempts++;
          return attempts == 3 ? mockMembership : null;
        });

        await provider.loadUserData();

        // Should succeed on third retry
        expect(provider.businessId, equals('BUS0000001'));
        expect(provider.role, equals('manager'));
        expect(provider.hasActiveMembership, isTrue);

        // Verify retry attempts
        verify(mockMembershipService.getActiveMembership('test-uid-123', 'BUS0000001'))
            .called(3);
      });

      test('should handle missing businessId in user document', () async {
        // Setup user document without businessId
        await fakeFirestore.collection('users').doc('test-uid-123').set({
          'fullName': 'John Doe',
          'businessName': 'Test PG Business',
          'profileCompleted': true,
          // No businessId field
        });

        await provider.loadUserData();

        expect(provider.fullName, equals('John Doe'));
        expect(provider.businessName, equals('Test PG Business'));
        expect(provider.businessId, isNull);
        expect(provider.hasActiveMembership, isFalse);

        // Should not call membership service if no businessId
        verifyNever(mockMembershipService.getActiveMembership(any, any));
      });

      test('should handle Firestore errors gracefully', () async {
        // Mock Firestore error
        when(mockMembershipService.getActiveMembership(any, any))
            .thenThrow(Exception('Firestore connection failed'));

        await provider.loadUserData();

        expect(provider.businessId, isNull);
        expect(provider.profileCompleted, isFalse);
      });
    });

    group('updatePendingRequestsCount', () {
      test('should update pending requests count and notify listeners', () {
        bool listenerCalled = false;
        provider.addListener(() {
          listenerCalled = true;
        });

        provider.updatePendingRequestsCount(5);

        expect(provider.pendingRequestsCount, equals(5));
        expect(listenerCalled, isTrue);
      });

      test('should handle zero and negative counts', () {
        provider.updatePendingRequestsCount(0);
        expect(provider.pendingRequestsCount, equals(0));

        provider.updatePendingRequestsCount(-1);
        expect(provider.pendingRequestsCount, equals(-1));
      });
    });

    group('Business Access Control', () {
      test('should deny access without active membership', () async {
        // Setup user with businessId but no active membership
        await fakeFirestore.collection('users').doc('test-uid-123').set({
          'fullName': 'John Doe',
          'businessName': 'Test PG Business',
          'businessId': 'BUS0000001',
          'profileCompleted': true,
        });

        when(mockMembershipService.getActiveMembership('test-uid-123', 'BUS0000001'))
            .thenAnswer((_) async => null);

        await provider.loadUserData();

        // Should deny business access
        expect(provider.hasActiveMembership, isFalse);
        expect(provider.businessId, isNull);
      });

      test('should grant access with valid membership', () async {
        // Setup user document
        await fakeFirestore.collection('users').doc('test-uid-123').set({
          'fullName': 'John Doe',
          'businessName': 'Test PG Business',
          'businessId': 'BUS0000001',
          'profileCompleted': true,
        });

        final mockMembership = BusinessMembership(
          id: 'membership-123',
          uid: 'test-uid-123',
          businessId: 'BUS0000001',
          role: 'staff',
          status: 'active',
          name: 'John Doe',
          email: 'test@example.com',
          phone: '9876543210',
          createdAt: DateTime.now(),
        );

        when(mockMembershipService.getActiveMembership('test-uid-123', 'BUS0000001'))
            .thenAnswer((_) async => mockMembership);

        await provider.loadUserData();

        // Should grant business access
        expect(provider.hasActiveMembership, isTrue);
        expect(provider.businessId, equals('BUS0000001'));
        expect(provider.role, equals('staff'));
      });
    });

    group('Role-Based Access', () {
      test('should handle different user roles correctly', () async {
        final roles = ['owner', 'manager', 'staff'];

        for (final role in roles) {
          // Setup user document
          await fakeFirestore.collection('users').doc('test-uid-123').set({
            'fullName': 'John Doe',
            'businessName': 'Test PG Business',
            'businessId': 'BUS0000001',
            'profileCompleted': true,
          });

          final mockMembership = BusinessMembership(
            id: 'membership-123',
            uid: 'test-uid-123',
            businessId: 'BUS0000001',
            role: role,
            status: 'active',
            name: 'John Doe',
            email: 'test@example.com',
            phone: '9876543210',
            createdAt: DateTime.now(),
          );

          when(mockMembershipService.getActiveMembership('test-uid-123', 'BUS0000001'))
              .thenAnswer((_) async => mockMembership);

          await provider.loadUserData();

          expect(provider.role, equals(role));
          expect(provider.hasActiveMembership, isTrue);

          // Reset for next iteration
          reset(mockMembershipService);
        }
      });
    });

    group('Listener Notifications', () {
      test('should notify listeners when data changes', () async {
        int notificationCount = 0;
        provider.addListener(() {
          notificationCount++;
        });

        // Setup user document
        await fakeFirestore.collection('users').doc('test-uid-123').set({
          'fullName': 'John Doe',
          'businessName': 'Test PG Business',
          'businessId': 'BUS0000001',
          'profileCompleted': true,
        });

        final mockMembership = BusinessMembership(
          id: 'membership-123',
          uid: 'test-uid-123',
          businessId: 'BUS0000001',
          role: 'owner',
          status: 'active',
          name: 'John Doe',
          email: 'test@example.com',
          phone: '9876543210',
          createdAt: DateTime.now(),
        );

        when(mockMembershipService.getActiveMembership('test-uid-123', 'BUS0000001'))
            .thenAnswer((_) async => mockMembership);

        await provider.loadUserData();

        // Should notify listeners at least once
        expect(notificationCount, greaterThan(0));
      });
    });
  });
}
