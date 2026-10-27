import 'package:business/presentation/property_detail/firestore_property_detail_source.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../support/property_fixtures.dart';
import '../view_models/business_dashboard_viewmodel_test.mocks.dart';

void main() {
  late FakeFirebaseFirestore fs;
  late MockPropertyRepository repo;
  late FirestorePropertyDetailSource source;

  setUp(() {
    fs = FakeFirebaseFirestore();
    repo = MockPropertyRepository();
    source = FirestorePropertyDetailSource(repository: repo, firestore: fs);
  });

  CollectionReference<Map<String, dynamic>> tenants() =>
      fs.collection('businesses').doc('BUS1').collection('tenants');

  test('property comes from the repository', () async {
    when(repo.getPropertyById('P1')).thenAnswer((_) async => makeProperty(id: 'P1'));
    expect((await source.property('P1'))?.id, 'P1');
  });

  test('a repository failure for a missing property becomes null', () async {
    when(repo.getPropertyById('X')).thenThrow(Exception('Property not found'));
    expect(await source.property('X'), isNull);
  });

  group('activeTenants', () {
    test('returns only active tenants of that property', () async {
      await tenants().doc('T1').set({
        'name': 'Amit', 'phone': '9876543210', 'propertyId': 'P1', 'status': 'active',
        'roomId': '101', 'bedId': '1', 'monthlyRent': 6500,
      });
      await tenants().doc('T2').set({'name': 'Gone', 'propertyId': 'P1', 'status': 'inactive'});
      await tenants().doc('T3').set({'name': 'Elsewhere', 'propertyId': 'P2', 'status': 'active'});

      final list = await source.activeTenants('BUS1', 'P1');

      expect(list.map((t) => t.id), ['T1']);
      expect(list.single.name, 'Amit');
      expect(list.single.roomId, '101');
      expect(list.single.monthlyRent, 6500);
    });

    test('reads room/bed from the number fields when ids are absent', () async {
      await tenants().doc('T1').set({
        'name': 'Neha', 'propertyId': 'P1', 'status': 'active',
        'roomNumber': '202', 'bedNumber': '3',
      });
      final t = (await source.activeTenants('BUS1', 'P1')).single;
      expect(t.roomId, '202');
      expect(t.bedId, '3');
    });

    test('parses Timestamp and ISO check-in dates', () async {
      await tenants().doc('A').set({
        'propertyId': 'P1', 'status': 'active',
        'checkInDate': Timestamp.fromDate(DateTime(2026, 5, 1)),
      });
      await tenants().doc('B').set({
        'propertyId': 'P1', 'status': 'active', 'checkInDate': '2026-06-02T00:00:00.000',
      });
      final byId = {for (final t in await source.activeTenants('BUS1', 'P1')) t.id: t};
      expect(byId['A']!.checkInDate, DateTime(2026, 5, 1));
      expect(byId['B']!.checkInDate, DateTime(2026, 6, 2));
    });
  });

  group('requests', () {
    Future<void> add(String id, Map<String, dynamic> data) =>
        fs.collection('enrollmentRequests').doc(id).set(data);

    test('streams this property\'s requests', () async {
      await add('r1', {
        'propertyId': 'P1', 'businessId': 'BUS1', 'tenantName': 'Mohit', 'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 20)),
      });
      await add('r2', {
        'propertyId': 'P2', 'businessId': 'BUS1', 'tenantName': 'Other', 'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 21)),
      });

      final list = await source.requests('P1').first;

      expect(list.map((r) => r.id), ['r1']);
      expect(list.single.tenantName, 'Mohit');
    });

    test('skips a request that cannot be read instead of failing them all', () async {
      await add('good', {
        'propertyId': 'P1', 'businessId': 'BUS1', 'tenantName': 'Ok', 'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 20)),
      });
      await add('bad', {'propertyId': 'P1', 'status': 5}); // not even a status

      final list = await source.requests('P1').first;

      expect(list.map((r) => r.id), ['good']);
    });

    test('keeps a request whose server timestamp has not arrived yet', () async {
      await add('fresh', {'propertyId': 'P1', 'businessId': 'BUS1', 'tenantName': 'New', 'status': 'pending'});

      final list = await source.requests('P1').first;

      expect(list.map((r) => r.id), ['fresh']);
    });
  });

  test('billing payments are this property\'s, newest first', () async {
    final col = fs.collection('businesses').doc('BUS1').collection('payments_to_onestay360');
    await col.doc('a').set({'propertyId': 'P1', 'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)), 'amount': 100});
    await col.doc('b').set({'propertyId': 'P1', 'createdAt': Timestamp.fromDate(DateTime(2026, 10, 1)), 'amount': 200});
    await col.doc('c').set({'propertyId': 'P2', 'createdAt': Timestamp.fromDate(DateTime(2026, 10, 2)), 'amount': 300});

    final list = await source.billingPayments('BUS1', 'P1');

    expect(list.map((p) => p['id']), ['b', 'a']);
  });

  test('unpaid invoice is delegated to the repository', () async {
    when(repo.getUnpaidInvoiceId(businessId: 'BUS1', propertyId: 'P1'))
        .thenAnswer((_) async => 'INV9');
    expect(await source.unpaidInvoiceId('BUS1', 'P1'), 'INV9');
  });

  group('invoicesFor', () {
    test('reads each tenant\'s invoices for the period only', () async {
      for (final id in ['T1', 'T2']) {
        await tenants().doc(id).set({'status': 'active'});
      }
      await tenants().doc('T1').collection('rent_invoices').add({
        'periodMonth': '2026-10', 'amount': 6500, 'status': 'paid',
      });
      await tenants().doc('T1').collection('rent_invoices').add({
        'periodMonth': '2026-09', 'amount': 6500, 'status': 'paid',
      });
      await tenants().doc('T2').collection('rent_invoices').add({
        'periodMonth': '2026-10', 'amount': 5000, 'status': 'unpaid',
        'dueDate': Timestamp.fromDate(DateTime(2026, 10, 8)),
      });

      final list = await source.invoicesFor('BUS1', ['T1', 'T2'], '2026-10');

      expect(list, hasLength(2));
      final t2 = list.firstWhere((i) => i.tenantId == 'T2');
      expect(t2.amount, 5000);
      expect(t2.status, 'unpaid');
      expect(t2.dueDate, DateTime(2026, 10, 8));
    });

    test('copes with many tenants', () async {
      final ids = [for (var i = 0; i < 25; i++) 'T$i'];
      for (final id in ids) {
        await tenants().doc(id).collection('rent_invoices').add({
          'periodMonth': '2026-10', 'amount': 100, 'status': 'paid',
        });
      }
      expect(await source.invoicesFor('BUS1', ids, '2026-10'), hasLength(25));
    });
  });
}
