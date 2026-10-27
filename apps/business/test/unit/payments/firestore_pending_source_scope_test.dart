import 'package:business/presentation/payments/firestore_pending_source.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore fs;

  setUp(() async {
    fs = FakeFirebaseFirestore();
    Future<void> tenant(String id, String property) async {
      final ref = fs.doc('businesses/B1/tenants/$id');
      await ref.set({'name': id, 'status': 'active', 'propertyId': property, 'roomId': '101'});
      await ref.collection('payments').add({'status': 'pending_verification', 'amount': 5000, 'month': 'October 2026'});
    }

    await tenant('T1', 'P1');
    await tenant('T2', 'P2');
    await tenant('T3', 'P3');

    Future<void> deposit(String id, String property) => fs.doc('enrollmentRequests/$id').set({
          'businessId': 'B1',
          'propertyId': property,
          'status': 'payment_submitted',
          'tenantName': id,
        });
    await deposit('D1', 'P1');
    await deposit('D2', 'P2');
  });

  FirestorePendingSource source(Set<String>? Function()? scope) => FirestorePendingSource(firestore: fs, propertyScope: scope);

  group('rent payments waiting', () {
    Future<List<String>> tenants(FirestorePendingSource s, {String? property}) async =>
        [for (final p in await s.rentPayments('B1', propertyId: property)) p.tenantId]..sort();

    test('the owner sees every property\'s', () async {
      expect(await tenants(source(() => null)), ['T1', 'T2', 'T3']);
    });

    test('a manager sees only their properties\'', () async {
      expect(await tenants(source(() => {'P1', 'P3'})), ['T1', 'T3']);
    });

    test('asking for one property they do not have returns nothing', () async {
      expect(await tenants(source(() => {'P1'}), property: 'P2'), isEmpty);
    });

    test('someone given nothing sees nothing', () async {
      expect(await tenants(source(() => <String>{})), isEmpty);
    });
  });

  group('deposits waiting', () {
    Future<List<String>> deposits(FirestorePendingSource s, {String? property}) async =>
        [for (final d in await s.deposits('B1', propertyId: property).first) d.id]..sort();

    test('the owner sees them all', () async {
      expect(await deposits(source(() => null)), ['D1', 'D2']);
    });

    test('a manager sees only their properties\'', () async {
      expect(await deposits(source(() => {'P2'})), ['D2']);
    });

    test('someone given nothing sees nothing', () async {
      expect(await deposits(source(() => <String>{})), isEmpty);
    });
  });
}
