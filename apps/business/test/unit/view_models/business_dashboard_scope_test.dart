import 'package:business/presentation/view_models/business_dashboard_viewmodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../support/property_fixtures.dart';
import 'business_dashboard_viewmodel_test.mocks.dart';

const _businessId = 'BUS0000001';

String _period(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

void main() {
  late MockPropertyRepository repo;
  late FakeFirebaseFirestore firestore;
  late DateTime now;

  setUp(() async {
    repo = MockPropertyRepository();
    firestore = FakeFirebaseFirestore();
    now = DateTime.now();
    when(repo.getPropertiesByBusiness(_businessId)).thenAnswer(
      (_) async => [
        makeProperty(id: 'P1', beds: 10),
        makeProperty(id: 'P2', beds: 20),
        makeProperty(id: 'P3', beds: 30),
      ],
    );

    Future<void> tenant(String id, String property, double rent, String status) async {
      final ref = firestore.collection('businesses').doc(_businessId).collection('tenants').doc(id);
      await ref.set({'name': id, 'phone': '9876543210', 'status': 'active', 'propertyId': property});
      await ref.collection('rent_invoices').add({
        'amount': rent,
        'status': status,
        'periodMonth': _period(now),
        'month': 'This month',
        'dueDate': Timestamp.fromDate(now.add(const Duration(days: 3))),
      });
    }

    await tenant('T1', 'P1', 10000, 'paid');
    await tenant('T2', 'P1', 8000, 'unpaid');
    await tenant('T3', 'P2', 5000, 'paid');
    await tenant('T4', 'P3', 7000, 'unpaid');
    await tenant('T5', 'P3', 6000, 'paid');

    Future<void> deposit(String id, String property, double amount) =>
        firestore.doc('enrollmentRequests/$id').set({
          'businessId': _businessId,
          'propertyId': property,
          'status': 'payment_submitted',
          'totalBillAmount': amount,
        });
    await deposit('D1', 'P1', 17500);
    await deposit('D2', 'P3', 22000);
  });

  BusinessDashboardViewModel make(Set<String>? Function()? scope) =>
      BusinessDashboardViewModel(propertyRepository: repo, firestore: firestore, propertyScope: scope);

  test('the owner sees the whole business', () async {
    final vm = make(() => null);
    addTearDown(vm.dispose);

    await vm.loadDashboardMetrics(_businessId);

    expect(vm.totalProperties, 3);
    expect(vm.activeTenants, 5);
    expect(vm.collectionsTarget, 36000);
    expect(vm.collectionsCollected, 21000);
    expect(vm.pendingPaymentsCount, 2);
    expect(vm.pendingConfirmationAmount, 39500);
  });

  test('with no scope given it is the whole business too', () async {
    final vm = make(null);
    addTearDown(vm.dispose);

    await vm.loadDashboardMetrics(_businessId);

    expect(vm.activeTenants, 5);
  });

  test('a manager sees only the properties they were given', () async {
    final vm = make(() => {'P1'});
    addTearDown(vm.dispose);

    await vm.loadDashboardMetrics(_businessId);

    expect(vm.totalProperties, 1);
    expect(vm.totalCapacity, 10);
    expect(vm.activeTenants, 2);
    expect(vm.occupiedBeds, 2);
    expect(vm.collectionsTarget, 18000);
    expect(vm.collectionsCollected, 10000);
    expect(vm.pendingPaymentsCount, 1);
    expect(vm.pendingConfirmationAmount, 17500);
    expect(vm.rentDues.map((d) => d.tenantId), ['T2']);
  });

  test('two properties add up', () async {
    final vm = make(() => {'P1', 'P3'});
    addTearDown(vm.dispose);

    await vm.loadDashboardMetrics(_businessId);

    expect(vm.totalProperties, 2);
    expect(vm.totalCapacity, 40);
    expect(vm.activeTenants, 4);
    expect(vm.collectionsTarget, 31000);
    expect(vm.pendingPaymentsCount, 2);
  });

  test('someone given nothing sees nothing', () async {
    final vm = make(() => <String>{});
    addTearDown(vm.dispose);

    await vm.loadDashboardMetrics(_businessId);

    expect(vm.totalProperties, 0);
    expect(vm.activeTenants, 0);
    expect(vm.collectionsTarget, 0);
    expect(vm.pendingPaymentsCount, 0);
    expect(vm.rentDues, isEmpty);
  });

  test('a tenant with no property is not counted for a manager', () async {
    await firestore
        .collection('businesses')
        .doc(_businessId)
        .collection('tenants')
        .doc('T9')
        .set({'name': 'Stray', 'status': 'active'});
    final vm = make(() => {'P1'});
    addTearDown(vm.dispose);

    await vm.loadDashboardMetrics(_businessId);

    expect(vm.activeTenants, 2);
  });
}
