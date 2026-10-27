import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:business/presentation/view_models/business_dashboard_viewmodel.dart';

import 'business_dashboard_viewmodel_test.mocks.dart';

const _businessId = 'BUS0000001';

String _period(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

void main() {
  group('BusinessDashboardViewModel rent collections', () {
    late MockPropertyRepository repo;
    late FakeFirebaseFirestore firestore;
    late BusinessDashboardViewModel vm;
    late DateTime now;

    setUp(() {
      repo = MockPropertyRepository();
      firestore = FakeFirebaseFirestore();
      vm = BusinessDashboardViewModel(
        propertyRepository: repo,
        firestore: firestore,
      );
      when(
        repo.getPropertiesByBusiness(_businessId),
      ).thenAnswer((_) async => []);
      now = DateTime.now();
    });

    tearDown(() => vm.dispose());

    Future<void> addTenant(
      String id, {
      String name = 'Tenant',
      String phone = '9876543210',
      String status = 'active',
      Object? checkOutDate,
      List<Map<String, Object?>> invoices = const [],
    }) async {
      final ref = firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('tenants')
          .doc(id);
      await ref.set({
        'name': name,
        'phone': phone,
        'status': status,
        'checkOutDate': checkOutDate,
      });
      for (final invoice in invoices) {
        await ref.collection('rent_invoices').add(invoice);
      }
    }

    Map<String, Object?> invoice(
      double amount,
      String status, {
      DateTime? due,
      String? period,
    }) => {
      'amount': amount,
      'status': status,
      'periodMonth': period ?? _period(now),
      'month': 'This month',
      'dueDate': Timestamp.fromDate(due ?? now.add(const Duration(days: 3))),
    };

    test(
      'totals this month\'s invoices into target, collected and pending',
      () async {
        await addTenant('T1', invoices: [invoice(10000, 'paid')]);
        await addTenant('T2', invoices: [invoice(8000, 'unpaid')]);
        await addTenant(
          'T3',
          invoices: [
            invoice(
              5000,
              'overdue',
              due: now.subtract(const Duration(days: 4)),
            ),
          ],
        );

        await vm.loadDashboardMetrics(_businessId);

        expect(vm.hasLoaded, isTrue);
        expect(vm.collectionsTarget, 23000);
        expect(vm.collectionsCollected, 10000);
        expect(vm.collectionsPending, 13000);
        expect(vm.collectionProgress, closeTo(10000 / 23000, 1e-9));
        expect(vm.hasCollections, isTrue);
      },
    );

    test('ignores invoices from other months and inactive tenants', () async {
      final lastMonth = DateTime(now.year, now.month - 1, 15);
      await addTenant(
        'T1',
        invoices: [
          invoice(10000, 'paid'),
          invoice(9999, 'paid', period: _period(lastMonth)),
        ],
      );
      await addTenant(
        'T2',
        status: 'inactive',
        invoices: [invoice(7000, 'paid')],
      );

      await vm.loadDashboardMetrics(_businessId);

      expect(vm.collectionsTarget, 10000);
      expect(vm.collectionsCollected, 10000);
    });

    test(
      'counts overdue by status or by a past due date, and lists dues',
      () async {
        await addTenant(
          'T1',
          name: 'Overdue By Status',
          invoices: [
            invoice(
              5000,
              'overdue',
              due: now.subtract(const Duration(days: 9)),
            ),
          ],
        );
        await addTenant(
          'T2',
          name: 'Past Due Not Yet Flagged',
          invoices: [
            invoice(6000, 'unpaid', due: now.subtract(const Duration(days: 2))),
          ],
        );
        await addTenant(
          'T3',
          name: 'Not Due Yet',
          invoices: [
            invoice(7000, 'unpaid', due: now.add(const Duration(days: 4))),
          ],
        );
        await addTenant('T4', name: 'Paid', invoices: [invoice(4000, 'paid')]);

        await vm.loadDashboardMetrics(_businessId);

        expect(vm.overdueCount, 2);
        expect(vm.rentDues.map((d) => d.tenantName).toList(), [
          'Overdue By Status', // longest overdue first
          'Past Due Not Yet Flagged',
          'Not Due Yet',
        ]);
        expect(vm.rentDues.map((d) => d.overdue).toList(), [true, true, false]);
      },
    );

    test('reports no collections when nothing has been invoiced', () async {
      await addTenant('T1');

      await vm.loadDashboardMetrics(_businessId);

      expect(vm.hasLoaded, isTrue);
      expect(vm.hasCollections, isFalse);
      expect(vm.collectionProgress, 0);
      expect(vm.rentDues, isEmpty);
    });

    test('counts leases ending within the next 7 days', () async {
      final today = DateTime(now.year, now.month, now.day);
      await addTenant(
        'T1',
        checkOutDate: today.add(const Duration(days: 2)).toIso8601String(),
      );
      await addTenant(
        'T2',
        checkOutDate: Timestamp.fromDate(today.add(const Duration(days: 7))),
      );
      await addTenant(
        'T3',
        checkOutDate: today.add(const Duration(days: 8)).toIso8601String(),
      );
      await addTenant(
        'T4',
        checkOutDate: today.subtract(const Duration(days: 1)).toIso8601String(),
      );
      await addTenant('T5'); // no checkout date

      await vm.loadDashboardMetrics(_businessId);

      expect(vm.leasesEndingThisWeek, 2);
    });

    test(
      'derives vacancy and occupancy from capacity and active tenants',
      () async {
        // No properties in the mock => capacity 0, so nothing is vacant.
        await vm.loadDashboardMetrics(_businessId);
        expect(vm.vacantBeds, 0);
        expect(vm.occupancyFraction, 0);
        expect(vm.occupiedBeds, 0);
      },
    );
  });
}
