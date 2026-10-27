import 'package:business/presentation/view_models/tenant_wizard/assignment_data_source.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_services/services/property_room_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore fs;

  setUp(() async {
    fs = FakeFirebaseFirestore();
    for (final entry in {'P1': 'active', 'P2': 'active', 'P3': 'draft'}.entries) {
      await fs.doc('businesses/B1/properties/${entry.key}').set({
        'name': 'Property ${entry.key}',
        'status': entry.value,
        'address': 'Somewhere',
        'city': 'Pune',
      });
    }
  });

  FirestoreAssignmentSource source(Set<String>? Function()? scope) =>
      FirestoreAssignmentSource(firestore: fs, rooms: PropertyRoomService(firestore: fs), propertyScope: scope);

  Future<List<String>> ids(FirestoreAssignmentSource s) async => [for (final p in await s.propertiesFor('B1')) p.id!]..sort();

  test('the owner can place a tenant in any property that is not a draft', () async {
    expect(await ids(source(() => null)), ['P1', 'P2']);
  });

  test('with no scope given it is the same', () async {
    expect(await ids(source(null)), ['P1', 'P2']);
  });

  test('a manager can place a tenant only in their own properties', () async {
    expect(await ids(source(() => {'P2'})), ['P2']);
  });

  test('not in a draft, even one they were given', () async {
    expect(await ids(source(() => {'P1', 'P3'})), ['P1']);
  });

  test('someone given nothing cannot place anyone', () async {
    expect(await ids(source(() => <String>{})), isEmpty);
  });
}
