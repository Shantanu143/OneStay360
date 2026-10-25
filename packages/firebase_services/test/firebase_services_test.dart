import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:firebase_services/firebase_services.dart';

void main() {
  test('IdGenerationService generates sequential business IDs', () async {
    final firestore = FakeFirebaseFirestore();
    final service = IdGenerationService(firestore: firestore);

    expect(await service.generateBusinessId(), 'BUS0000001');
    expect(await service.generateBusinessId(), 'BUS0000002');

    final counter = await firestore.collection('counters').doc('business_counter').get();
    expect(counter.data()?['count'], 2);
  });
}
