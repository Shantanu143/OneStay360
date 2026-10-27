import 'package:business/presentation/views/tenants/qr_scan_viewmodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLookup implements TenantLookup {
  final looked = <String>[];
  Map<String, dynamic>? result = {'tenantId': 'TEN0000007', 'name': 'Manish Gupta'};
  Object? failure;

  @override
  Future<Map<String, dynamic>?> find(String tenantId) async {
    looked.add(tenantId);
    if (failure != null) throw failure!;
    return result;
  }
}

void main() {
  group('reading a code', () {
    test('a tenant code has the tenant\'s id in it', () {
      expect(tenantIdFromQr('onestay360:tenant:TEN0000007'), 'TEN0000007');
      expect(tenantIdFromQr('  onestay360:tenant:TEN0000007\n'), 'TEN0000007');
    });

    test('anything else is not one', () {
      expect(tenantIdFromQr('https://example.test'), isNull);
      expect(tenantIdFromQr('onestay360:tenant:'), isNull);
      expect(tenantIdFromQr('onestay360:property:P1'), isNull);
      expect(tenantIdFromQr(''), isNull);
    });
  });

  group('scanning', () {
    late FakeLookup lookup;
    late QrScanViewModel vm;

    setUp(() {
      lookup = FakeLookup();
      vm = QrScanViewModel(lookup: lookup);
    });

    tearDown(() => vm.dispose());

    test('finds the tenant and hands back their details', () async {
      await vm.onCode('onestay360:tenant:TEN0000007');

      expect(lookup.looked, ['TEN0000007']);
      expect(vm.found!['name'], 'Manish Gupta');
      expect(vm.error, isNull);
    });

    test('says when it is some other kind of code', () async {
      await vm.onCode('https://example.test');

      expect(vm.error, "That isn't a OneStay360 tenant code. Ask the tenant to show the QR on their profile.");
      expect(lookup.looked, isEmpty);
      expect(vm.found, isNull);
    });

    test('says when there is no such tenant', () async {
      lookup.result = null;

      await vm.onCode('onestay360:tenant:TEN9999999');

      expect(vm.error, "We couldn't find that tenant. Check the code and try again.");
    });

    test('says when looking them up is not allowed', () async {
      lookup.failure = const QrLookupDenied();

      await vm.onCode('onestay360:tenant:TEN0000007');

      expect(vm.error, contains("can't look up tenants"));
    });

    test('says something plain for any other failure', () async {
      lookup.failure = Exception('offline');

      await vm.onCode('onestay360:tenant:TEN0000007');

      expect(vm.error, "Couldn't look up that tenant. Check your connection and try again.");
    });

    test('the camera sees the same code many times a second: only the first is acted on', () async {
      final first = vm.onCode('onestay360:tenant:TEN0000007');
      await vm.onCode('onestay360:tenant:TEN0000007');
      await first;

      expect(lookup.looked, hasLength(1));
    });

    test('after a failure it is ready for the next code, and the old complaint goes', () async {
      await vm.onCode('nonsense');
      expect(vm.error, isNotNull);

      await vm.onCode('onestay360:tenant:TEN0000007');

      expect(vm.error, isNull);
      expect(vm.found, isNotNull);
    });

    test('is busy while looking up', () async {
      var sawBusy = false;
      vm.addListener(() => sawBusy = sawBusy || vm.busy);

      await vm.onCode('onestay360:tenant:TEN0000007');

      expect(sawBusy, isTrue);
    });

    test('once a tenant has been found nothing more is looked up', () async {
      await vm.onCode('onestay360:tenant:TEN0000007');

      await vm.onCode('onestay360:tenant:TEN0000008');

      expect(lookup.looked, ['TEN0000007']);
    });
  });

  group('looking a tenant up in Firestore', () {
    late FakeFirebaseFirestore fs;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      await fs.doc('tenants/TEN1').set({'userId': 'u9', 'name': 'From tenant doc', 'phone': '+919000000009'});
      await fs.doc('users/u9').set({'fullName': 'Manish Gupta', 'email': 'manish@example.test'});
    });

    test('combines the tenant\'s record and their profile', () async {
      final tenant = await FirestoreTenantLookup(firestore: fs).find('TEN1');

      expect(tenant!['tenantId'], 'TEN1');
      expect(tenant['fullName'], 'Manish Gupta');
      expect(tenant['email'], 'manish@example.test');
      expect(tenant['phone'], '+919000000009');
    });

    test('is null for someone who is not there', () async {
      expect(await FirestoreTenantLookup(firestore: fs).find('TEN404'), isNull);
    });

    test('still works when the tenant has no profile document', () async {
      await fs.doc('tenants/TEN2').set({'name': 'No profile'});

      final tenant = await FirestoreTenantLookup(firestore: fs).find('TEN2');

      expect(tenant!['name'], 'No profile');
    });

    test('a permission refusal is reported as one', () async {
      final lookup = FirestoreTenantLookup(
        firestore: fs,
        read: (_) async => throw FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );

      await expectLater(lookup.find('TEN1'), throwsA(isA<QrLookupDenied>()));
    });
  });
}
