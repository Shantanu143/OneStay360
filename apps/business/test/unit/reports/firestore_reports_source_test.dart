import 'package:business/presentation/reports/firestore_reports_source.dart';
import 'package:business/presentation/reports/reports_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

const props = [ReportProperty(id: 'P1', name: 'Sunrise', totalBeds: 10, occupiedBeds: 7)];

void main() {
  late FakeFirebaseFirestore fs;
  late FirestoreReportsSource source;
  var propertyLoads = 0;

  setUp(() {
    fs = FakeFirebaseFirestore();
    propertyLoads = 0;
    source = FirestoreReportsSource(
      firestore: fs,
      loadProperties: (businessId) async {
        propertyLoads++;
        expect(businessId, 'B1');
        return props;
      },
    );
  });

  Future<void> tenant(String id, {String name = 'Asha', String status = 'active', String property = 'P1'}) =>
      fs.doc('businesses/B1/tenants/$id').set({'name': name, 'status': status, 'propertyId': property});

  Future<void> invoice(String tenantId, String period, Map<String, Object?> extra) =>
      fs.collection('businesses/B1/tenants/$tenantId/rent_invoices').add({
        'periodMonth': period,
        'amount': 5000,
        'status': 'unpaid',
        ...extra,
      });

  test('returns the properties from the loader', () async {
    final data = await source.load('B1', ['2026-10']);

    expect(data.properties.map((p) => p.id), ['P1']);
    expect(propertyLoads, 1);
  });

  group('beds in use', () {
    test('are the active tenants, not the counter stored on the property', () async {
      // The property says 7 beds are in use; only two people actually live there.
      await tenant('t1');
      await tenant('t2');
      await tenant('t3', status: 'vacated');

      final p = (await source.load('B1', ['2026-10'])).properties.single;

      expect(p.occupiedBeds, 2);
      expect(p.totalBeds, 10);
    });

    test('is zero for a property nobody lives in', () async {
      final p = (await source.load('B1', ['2026-10'])).properties.single;

      expect(p.occupiedBeds, 0);
    });

    test('never exceeds the beds the property has', () async {
      for (var i = 0; i < 12; i++) {
        await tenant('t$i');
      }

      final p = (await source.load('B1', ['2026-10'])).properties.single;

      expect(p.occupiedBeds, 10);
    });

    test('tenants of other properties do not count', () async {
      await tenant('t1', property: 'P9');

      final p = (await source.load('B1', ['2026-10'])).properties.single;

      expect(p.occupiedBeds, 0);
    });
  });

  test('no tenants means no invoices', () async {
    final data = await source.load('B1', ['2026-10']);

    expect(data.invoices, isEmpty);
  });

  test('reads invoices of every tenant, including ones who have left', () async {
    await tenant('t1');
    await tenant('t2', name: 'Ravi', status: 'vacated');
    await invoice('t1', '2026-10', {});
    await invoice('t2', '2026-09', {'status': 'paid'});

    final data = await source.load('B1', ['2026-09', '2026-10']);

    expect(data.invoices.map((i) => i.tenantId), unorderedEquals(['t1', 't2']));
  });

  test('leaves out invoices of other months', () async {
    await tenant('t1');
    await invoice('t1', '2026-10', {});
    await invoice('t1', '2026-03', {});

    final data = await source.load('B1', ['2026-10']);

    expect(data.invoices.single.periodMonth, '2026-10');
  });

  test('reads the fields reports need', () async {
    await tenant('t1', name: 'Asha');
    await invoice('t1', '2026-10', {
      'amount': 7500,
      'status': 'paid',
      'mode': 'upi',
      'propertyId': 'P1',
      'dueDate': Timestamp.fromDate(DateTime(2026, 10, 5)),
    });

    final i = (await source.load('B1', ['2026-10'])).invoices.single;

    expect(i.tenantName, 'Asha');
    expect(i.amount, 7500.0);
    expect(i.status, 'paid');
    expect(i.mode, 'upi');
    expect(i.propertyId, 'P1');
    expect(i.dueDate, DateTime(2026, 10, 5));
  });

  test('falls back to the tenant\'s property and to "unpaid" when the invoice lacks them', () async {
    await tenant('t1', property: 'P1');
    await fs.collection('businesses/B1/tenants/t1/rent_invoices').add({'periodMonth': '2026-10', 'amount': 100});

    final i = (await source.load('B1', ['2026-10'])).invoices.single;

    expect(i.propertyId, 'P1');
    expect(i.status, 'unpaid');
    expect(i.mode, isNull);
    expect(i.dueDate, isNull);
  });

  test('copes with an amount stored as text or missing', () async {
    await tenant('t1');
    await invoice('t1', '2026-10', {'amount': '1200'});
    await invoice('t1', '2026-10', {'amount': null});

    final amounts = (await source.load('B1', ['2026-10'])).invoices.map((i) => i.amount).toList()..sort();

    expect(amounts, [0.0, 1200.0]);
  });

  test('reads every tenant when there are more than one batch', () async {
    for (var i = 0; i < 27; i++) {
      await tenant('t$i');
      await invoice('t$i', '2026-10', {});
    }

    final data = await source.load('B1', ['2026-10']);

    expect(data.invoices, hasLength(27));
  });

  test('a failing property loader fails the whole load rather than showing partial numbers', () async {
    final failing = FirestoreReportsSource(
      firestore: fs,
      loadProperties: (_) async => throw Exception('boom'),
    );

    await expectLater(failing.load('B1', ['2026-10']), throwsException);
  });
}
