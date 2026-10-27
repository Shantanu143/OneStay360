import 'package:business/presentation/common/active_occupancy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> tenant(String property, {String status = 'active'}) =>
    {'propertyId': property, 'status': status};

void main() {
  group('countActiveTenants', () {
    test('counts one bed per active tenant, by property', () {
      final counts = countActiveTenants([
        tenant('P1'),
        tenant('P1'),
        tenant('P2'),
      ]);

      expect(counts, {'P1': 2, 'P2': 1});
    });

    test('leaves out tenants who have left or never moved in', () {
      final counts = countActiveTenants([
        tenant('P1'),
        tenant('P1', status: 'vacated'),
        tenant('P1', status: 'invited'),
      ]);

      expect(counts, {'P1': 1});
    });

    test('ignores a tenant with no property', () {
      expect(countActiveTenants([tenant('')]), isEmpty);
      expect(countActiveTenants([{'status': 'active'}]), isEmpty);
    });

    test('nobody means no counts', () {
      expect(countActiveTenants(const []), isEmpty);
    });
  });

  group('loadActiveOccupancy', () {
    test('reads the business\'s active tenants and counts them', () async {
      final fs = FakeFirebaseFirestore();
      await fs.doc('businesses/B1/tenants/t1').set(tenant('P1'));
      await fs.doc('businesses/B1/tenants/t2').set(tenant('P1'));
      await fs.doc('businesses/B1/tenants/t3').set(tenant('P2', status: 'vacated'));
      await fs.doc('businesses/B2/tenants/t9').set(tenant('P1'));

      final counts = await loadActiveOccupancy(fs, 'B1');

      expect(counts, {'P1': 2});
    });
  });
}
