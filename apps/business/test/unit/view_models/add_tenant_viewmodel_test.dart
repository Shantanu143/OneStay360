import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_services/services/firestore_service.dart';

import 'package:business/presentation/view_models/add_tenant_viewmodel.dart';

@GenerateMocks([FirestoreService])
import 'add_tenant_viewmodel_test.mocks.dart';

void main() {
  group('AddTenantViewModel Tests', () {
    late AddTenantViewModel viewModel;
    late MockFirestoreService mockFirestoreService;
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;

    setUp(() {
      mockFirestoreService = MockFirestoreService();
      fakeFirestore = FakeFirebaseFirestore();
      mockUser = MockUser(uid: 'owner-uid-123', email: 'owner@test.com');
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

      viewModel = AddTenantViewModel(
        firestoreService: mockFirestoreService,
        auth: mockAuth,
        firestore: fakeFirestore,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    group('Form Validation', () {
      test('should be invalid when all fields are empty', () {
        expect(viewModel.isValidForm, isFalse);
      });

      test('should be invalid with short phone number', () {
        viewModel.fullNameController.text = 'John Doe';
        viewModel.phoneController.text = '12345'; // too short
        viewModel.selectedPropertyId = 'PROP1';
        viewModel.selectedRoomId = 'ROOM1';
        viewModel.selectedBedIndex = 0;
        viewModel.moveInDate = DateTime.now();
        viewModel.monthlyRentController.text = '5000';

        expect(viewModel.isValidForm, isFalse);
      });

      test('should be invalid without property selection', () {
        viewModel.fullNameController.text = 'John Doe';
        viewModel.phoneController.text = '9876543210';
        // No property selected
        viewModel.selectedRoomId = 'ROOM1';
        viewModel.selectedBedIndex = 0;
        viewModel.moveInDate = DateTime.now();
        viewModel.monthlyRentController.text = '5000';

        expect(viewModel.isValidForm, isFalse);
      });

      test('should be invalid without room selection', () {
        viewModel.fullNameController.text = 'John Doe';
        viewModel.phoneController.text = '9876543210';
        viewModel.selectedPropertyId = 'PROP1';
        // No room selected
        viewModel.selectedBedIndex = 0;
        viewModel.moveInDate = DateTime.now();
        viewModel.monthlyRentController.text = '5000';

        expect(viewModel.isValidForm, isFalse);
      });

      test('should be invalid without bed selection', () {
        viewModel.fullNameController.text = 'John Doe';
        viewModel.phoneController.text = '9876543210';
        viewModel.selectedPropertyId = 'PROP1';
        viewModel.selectedRoomId = 'ROOM1';
        // No bed selected
        viewModel.moveInDate = DateTime.now();
        viewModel.monthlyRentController.text = '5000';

        expect(viewModel.isValidForm, isFalse);
      });

      test('should be invalid without move-in date', () {
        viewModel.fullNameController.text = 'John Doe';
        viewModel.phoneController.text = '9876543210';
        viewModel.selectedPropertyId = 'PROP1';
        viewModel.selectedRoomId = 'ROOM1';
        viewModel.selectedBedIndex = 0;
        // No move-in date
        viewModel.monthlyRentController.text = '5000';

        expect(viewModel.isValidForm, isFalse);
      });

      test('should be valid with all required fields', () {
        viewModel.fullNameController.text = 'John Doe';
        viewModel.phoneController.text = '9876543210';
        viewModel.selectedPropertyId = 'PROP1';
        viewModel.selectedRoomId = 'ROOM1';
        viewModel.selectedBedIndex = 0;
        viewModel.moveInDate = DateTime.now();
        viewModel.monthlyRentController.text = '5000';

        expect(viewModel.isValidForm, isTrue);
      });
    });

    group('Property/Room/Bed Selection', () {
      test('should reset room and bed when property changes', () {
        viewModel.selectedPropertyId = 'PROP1';
        viewModel.selectedRoomId = 'ROOM1';
        viewModel.selectedBedIndex = 2;

        viewModel.updateProperty('PROP2');

        expect(viewModel.selectedPropertyId, equals('PROP2'));
        expect(viewModel.selectedRoomId, isNull);
        expect(viewModel.selectedBedIndex, isNull);
      });

      test('should reset bed when room changes', () {
        viewModel.selectedRoomId = 'ROOM1';
        viewModel.selectedBedIndex = 2;

        viewModel.updateRoom('ROOM2');

        expect(viewModel.selectedRoomId, equals('ROOM2'));
        expect(viewModel.selectedBedIndex, isNull);
      });

      test('should update bed index', () {
        viewModel.updateBed(3);
        expect(viewModel.selectedBedIndex, equals(3));
      });
    });

    group('Date Management', () {
      test('should set move-in date', () {
        final date = DateTime(2025, 6, 1);
        viewModel.setMoveInDate(date);
        expect(viewModel.moveInDate, equals(date));
      });

      test('should set move-out date', () {
        final date = DateTime(2026, 6, 1);
        viewModel.setMoveOutDate(date);
        expect(viewModel.moveOutDate, equals(date));
      });

      test('should clear move-out date', () {
        viewModel.setMoveOutDate(DateTime(2026, 6, 1));
        viewModel.setMoveOutDate(null);
        expect(viewModel.moveOutDate, isNull);
      });
    });

    group('Submit', () {
      test('should set error when form is invalid', () async {
        // Empty form
        await viewModel.submit(null as dynamic);

        expect(viewModel.errorMessage, isNotNull);
        expect(viewModel.isSubmitting, isFalse);
      });

      test('should set error when user not authenticated', () async {
        // Fill valid form
        viewModel.fullNameController.text = 'John Doe';
        viewModel.phoneController.text = '9876543210';
        viewModel.selectedPropertyId = 'PROP1';
        viewModel.selectedRoomId = 'ROOM1';
        viewModel.selectedBedIndex = 0;
        viewModel.moveInDate = DateTime.now();
        viewModel.monthlyRentController.text = '5000';

        viewModel.dispose();
        viewModel = AddTenantViewModel(
          firestoreService: mockFirestoreService,
          auth: MockFirebaseAuth(signedIn: false),
          firestore: fakeFirestore,
        );
        viewModel.fullNameController.text = 'John Doe';
        viewModel.phoneController.text = '9876543210';
        viewModel.selectedPropertyId = 'PROP1';
        viewModel.selectedRoomId = 'ROOM1';
        viewModel.selectedBedIndex = 0;
        viewModel.moveInDate = DateTime.now();
        viewModel.monthlyRentController.text = '5000';

        await viewModel.submit(null as dynamic);

        expect(viewModel.errorMessage, isNotNull);
        expect(viewModel.isSubmitting, isFalse);
      });

      test('should handle gender lock violation', () async {
        // Fill valid form
        viewModel.fullNameController.text = 'John Doe';
        viewModel.phoneController.text = '9876543210';
        viewModel.selectedPropertyId = 'PROP1';
        viewModel.selectedRoomId = 'ROOM1';
        viewModel.selectedBedIndex = 0;
        viewModel.moveInDate = DateTime.now();
        viewModel.monthlyRentController.text = '5000';
        viewModel.genderController.text = 'Female';

        when(mockFirestoreService.getBusinessId('owner-uid-123'))
            .thenAnswer((_) async => 'BUS0000001');
        when(mockFirestoreService.generateTenantId())
            .thenAnswer((_) async => 'TEN0000001');

        // Set up room with Male gender lock
        await fakeFirestore
            .collection('businesses')
            .doc('BUS0000001')
            .collection('properties')
            .doc('PROP1')
            .collection('rooms')
            .doc('ROOM1')
            .set({'gender': 'Male', 'roomNumber': 'ROOM1'});

        await viewModel.submit(null as dynamic);

        expect(viewModel.errorMessage, contains('reserved for Male tenants'));
        expect(viewModel.isSubmitting, isFalse);
      });
    });

    group('Preload', () {
      test('should preload property ID', () {
        viewModel.preload(propertyId: 'PROP1');
        expect(viewModel.selectedPropertyId, equals('PROP1'));
      });

      test('should not override existing property ID when null passed', () {
        viewModel.selectedPropertyId = 'PROP1';
        viewModel.preload(propertyId: null);
        expect(viewModel.selectedPropertyId, equals('PROP1'));
      });
    });

    group('Listener Notifications', () {
      test('should notify on property update', () {
        int count = 0;
        viewModel.addListener(() => count++);
        viewModel.updateProperty('PROP1');
        expect(count, equals(1));
      });

      test('should notify on room update', () {
        int count = 0;
        viewModel.addListener(() => count++);
        viewModel.updateRoom('ROOM1');
        expect(count, equals(1));
      });

      test('should notify on bed update', () {
        int count = 0;
        viewModel.addListener(() => count++);
        viewModel.updateBed(2);
        expect(count, equals(1));
      });

      test('should notify on date change', () {
        int count = 0;
        viewModel.addListener(() => count++);
        viewModel.setMoveInDate(DateTime.now());
        expect(count, equals(1));
      });
    });
  });
}
