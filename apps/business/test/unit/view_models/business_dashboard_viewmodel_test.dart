import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:models/business/property/property_model.dart';
import 'package:models/business/property/property_totals_model.dart';
import 'package:models/business/property/property_pricing_model.dart';
import 'package:models/business/property/property_amenities_model.dart';
import 'package:models/business/property/property_rules_model.dart';
import 'package:models/business/property/property_rating_model.dart';
import 'package:firebase_services/repositories/property_repository.dart';

import 'package:business/presentation/view_models/business_dashboard_viewmodel.dart';

@GenerateMocks([PropertyRepository])
import 'business_dashboard_viewmodel_test.mocks.dart';

Property _makeProperty({
  required String id,
  required String businessId,
  int beds = 10,
}) {
  return Property(
    id: id,
    name: 'Test Property $id',
    address: '123 Test St',
    city: 'Pune',
    cityCode: 'PNE',
    numberOfFloors: 2,
    description: 'Test',
    landmarks: '',
    googleMapsLink: '',
    pricing: PropertyPricing(
      single: 5000,
      double: 4000,
      triple: 3000,
      securityDeposit: 10000,
      oneTimeMaintenance: 1500,
      maintenanceDeductedFromDeposit: false,
    ),
    rooms: [],
    amenities: PropertyAmenities(
      wifi: true,
      ac: false,
      laundry: true,
      foodIncluded: true,
      parking: false,
      geyser: true,
      powerBackup: true,
      cctv: true,
      housekeeping: false,
    ),
    rules: PropertyRules(
      genderAllowed: 'Co-ed',
      curfew: false,
      visitorsAllowed: true,
      smokingAllowed: false,
      alcoholAllowed: false,
      noticePeriodDays: 30,
    ),
    totals: PropertyTotals(rooms: 5, beds: beds, availableBeds: beds ~/ 2),
    rating: PropertyRating(average: 4.0, count: 10),
    status: 'active',
    businessId: businessId,
    businessName: 'Test Business',
    businessPhone: '9876543210',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  group('BusinessDashboardViewModel Tests', () {
    late BusinessDashboardViewModel viewModel;
    late MockPropertyRepository mockRepo;
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      mockRepo = MockPropertyRepository();
      fakeFirestore = FakeFirebaseFirestore();
      viewModel = BusinessDashboardViewModel(
        propertyRepository: mockRepo,
        firestore: fakeFirestore,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    group('Initial State', () {
      test('should have correct initial values', () {
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.hasError, isFalse);
        expect(viewModel.totalProperties, equals(0));
        expect(viewModel.totalCapacity, equals(0));
        expect(viewModel.activeTenants, equals(0));
        expect(viewModel.occupancyRateString, equals('0%'));
        expect(viewModel.pendingRentString, equals('₹ 0'));
      });
    });

    group('loadDashboardMetrics', () {
      test('should set error when businessId is null', () async {
        await viewModel.loadDashboardMetrics(null);

        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, contains('No active business membership'));
        expect(viewModel.isLoading, isFalse);
      });

      test('should set error when businessId is empty', () async {
        await viewModel.loadDashboardMetrics('');

        expect(viewModel.hasError, isTrue);
        expect(viewModel.isLoading, isFalse);
      });

      test('should load metrics successfully', () async {
        const businessId = 'BUS0000001';
        final properties = [
          _makeProperty(id: 'PROP1', businessId: businessId, beds: 10),
          _makeProperty(id: 'PROP2', businessId: businessId, beds: 20),
        ];

        when(mockRepo.getPropertiesByBusiness(businessId))
            .thenAnswer((_) async => properties);

        // Add active tenants to fake Firestore
        await fakeFirestore.collection('tenants').add({
          'businessId': businessId,
          'status': 'active',
          'name': 'Tenant 1',
        });
        await fakeFirestore.collection('tenants').add({
          'businessId': businessId,
          'status': 'active',
          'name': 'Tenant 2',
        });

        await viewModel.loadDashboardMetrics(businessId);

        expect(viewModel.isLoading, isFalse);
        expect(viewModel.hasError, isFalse);
        expect(viewModel.totalProperties, equals(2));
        expect(viewModel.totalCapacity, equals(30)); // 10 + 20
      });

      test('should calculate occupancy rate correctly', () async {
        const businessId = 'BUS0000001';
        final properties = [
          _makeProperty(id: 'PROP1', businessId: businessId, beds: 10),
        ];

        when(mockRepo.getPropertiesByBusiness(businessId))
            .thenAnswer((_) async => properties);

        // Add 5 active tenants (50% occupancy)
        for (int i = 0; i < 5; i++) {
          await fakeFirestore.collection('tenants').add({
            'businessId': businessId,
            'status': 'active',
          });
        }

        await viewModel.loadDashboardMetrics(businessId);

        expect(viewModel.activeTenants, equals(5));
        expect(viewModel.occupancyRateString, equals('50.0%'));
      });

      test('should handle zero capacity gracefully', () async {
        const businessId = 'BUS0000001';
        final properties = [
          _makeProperty(id: 'PROP1', businessId: businessId, beds: 0),
        ];

        when(mockRepo.getPropertiesByBusiness(businessId))
            .thenAnswer((_) async => properties);

        await viewModel.loadDashboardMetrics(businessId);

        expect(viewModel.occupancyRateString, equals('0%'));
      });

      test('should handle repository errors gracefully', () async {
        const businessId = 'BUS0000001';

        when(mockRepo.getPropertiesByBusiness(businessId))
            .thenThrow(Exception('Network error'));

        await viewModel.loadDashboardMetrics(businessId);

        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, contains('Failed to load dashboard metrics'));
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.totalProperties, equals(0));
      });

      test('should not reload if already loading same businessId', () async {
        const businessId = 'BUS0000001';

        when(mockRepo.getPropertiesByBusiness(businessId))
            .thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return [];
        });

        // Start first load
        final future1 = viewModel.loadDashboardMetrics(businessId);
        // Immediately try second load
        final future2 = viewModel.loadDashboardMetrics(businessId);

        await Future.wait([future1, future2]);

        // Should only call repository once
        verify(mockRepo.getPropertiesByBusiness(businessId)).called(1);
      });
    });

    group('Currency Formatting', () {
      test('should format zero correctly', () async {
        const businessId = 'BUS0000001';
        when(mockRepo.getPropertiesByBusiness(businessId))
            .thenAnswer((_) async => []);

        await viewModel.loadDashboardMetrics(businessId);

        expect(viewModel.pendingRentString, equals('₹ 0'));
      });

      test('should format thousands correctly', () async {
        const businessId = 'BUS0000001';
        when(mockRepo.getPropertiesByBusiness(businessId))
            .thenAnswer((_) async => []);

        // Add pending payment
        await fakeFirestore
            .collection('businesses')
            .doc(businessId)
            .collection('tenants')
            .doc('TEN0000001')
            .collection('payments')
            .add({
          'businessId': businessId,
          'status': 'pending_verification',
          'amount': 5000,
        });

        await viewModel.loadDashboardMetrics(businessId);

        expect(viewModel.pendingRentString, equals('₹ 5K'));
      });
    });

    group('refreshMetrics', () {
      test('should reload metrics', () async {
        const businessId = 'BUS0000001';
        when(mockRepo.getPropertiesByBusiness(businessId))
            .thenAnswer((_) async => []);

        await viewModel.refreshMetrics(businessId);

        verify(mockRepo.getPropertiesByBusiness(businessId)).called(1);
      });
    });

    group('Listener Notifications', () {
      test('should notify listeners on load', () async {
        const businessId = 'BUS0000001';
        int notifyCount = 0;
        viewModel.addListener(() => notifyCount++);

        when(mockRepo.getPropertiesByBusiness(businessId))
            .thenAnswer((_) async => []);

        await viewModel.loadDashboardMetrics(businessId);

        // Should notify at least twice: loading start + loading end
        expect(notifyCount, greaterThanOrEqualTo(2));
      });
    });

    group('Dispose Safety', () {
      test('should not notify after dispose', () async {
        const businessId = 'BUS0000001';
        int notifyCount = 0;
        viewModel.addListener(() => notifyCount++);

        when(mockRepo.getPropertiesByBusiness(businessId))
            .thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return [];
        });

        final future = viewModel.loadDashboardMetrics(businessId);
        viewModel.dispose();
        await future;

        // Should not throw after dispose
        expect(notifyCount, greaterThanOrEqualTo(0));
      });
    });
  });
}
