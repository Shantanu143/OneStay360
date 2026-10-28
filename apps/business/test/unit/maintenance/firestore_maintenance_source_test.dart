import 'package:business/presentation/maintenance/firestore_maintenance_source.dart';
import 'package:business/presentation/maintenance/maintenance_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore fs;
  late FirestoreMaintenanceSource source;

  setUp(() {
    fs = FakeFirebaseFirestore();
    source = FirestoreMaintenanceSource(firestore: fs);
  });

  test('reads only this business, with what tenants write', () async {
    await fs.collection('maintenanceRequests').doc('m1').set({
      'businessId': 'BUS1',
      'propertyId': 'P1',
      'propertyName': 'Green Nest',
      'tenantName': 'Asha',
      'tenantPhone': '9811100001',
      'roomNumber': '101',
      'bedNumber': '2',
      'category': 'plumbing',
      'title': 'Tap leaking',
      'description': 'Bathroom',
      'priority': 'urgent',
      'status': 'open',
      'createdAt': Timestamp.fromDate(DateTime(2026, 3, 1)),
    });
    await fs.collection('maintenanceRequests').doc('m2').set({'businessId': 'BUS2', 'title': 'x', 'status': 'open'});

    final list = await source.watch('BUS1').first;
    final m = list.single;
    expect(m.id, 'm1');
    expect(m.title, 'Tap leaking');
    expect(m.categoryLabel, 'Plumbing');
    expect(m.urgent, isTrue);
    expect(m.status, MaintenanceState.open);
    expect(m.where, 'Green Nest · Room 101 · Bed 2');
    expect(m.tenantPhone, '9811100001');
  });

  test('updates only the fields the rules allow', () async {
    await fs.collection('maintenanceRequests').doc('m1').set({'businessId': 'BUS1', 'title': 'x', 'status': 'open'});
    await source.update('m1', status: MaintenanceState.resolved, note: 'Done', by: 'owner1');
    final d = (await fs.collection('maintenanceRequests').doc('m1').get()).data()!;
    expect(d['status'], 'resolved');
    expect(d['ownerNote'], 'Done');
    expect(d['updatedBy'], 'owner1');
    expect(d['resolvedAt'], isNotNull);
    expect(d.keys.toSet(), {'businessId', 'title', 'status', 'ownerNote', 'updatedAt', 'updatedBy', 'resolvedAt'});
  });

  test('starting work keeps any earlier note', () async {
    await fs.collection('maintenanceRequests').doc('m1').set({'businessId': 'BUS1', 'title': 'x', 'status': 'open', 'ownerNote': 'Seen'});
    await source.update('m1', status: MaintenanceState.inProgress, by: 'owner1');
    final d = (await fs.collection('maintenanceRequests').doc('m1').get()).data()!;
    expect(d['ownerNote'], 'Seen');
    expect(d.containsKey('resolvedAt'), isFalse);
  });
}
