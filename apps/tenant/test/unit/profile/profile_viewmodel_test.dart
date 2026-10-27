import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:models/tenant/tenant_document_model.dart';
import 'package:tenant/presentation/profile/profile_viewmodel.dart';

class FakeStore implements DocumentStore {
  final uploads = <String>[];
  final deleted = <String>[];

  @override
  Future<String> upload(XFile file, String tenantId, String type) async {
    uploads.add('$tenantId/$type/${file.name}');
    return 'https://files/${file.name}';
  }

  @override
  Future<void> delete(String url) async => deleted.add(url);
}

void main() {
  late FakeFirebaseFirestore fs;
  late FakeStore store;
  late ProfileViewModel vm;

  setUp(() async {
    fs = FakeFirebaseFirestore();
    store = FakeStore();
    await fs.doc('users/u1').set({'tenantId': 'TEN1', 'fullName': 'Asha', 'phone': '9811100001', 'email': 'a@b.co'});
    await fs.doc('tenants/TEN1').set({
      'userId': 'u1',
      'name': 'Asha Rao',
      'gender': 'Female',
      'dateOfBirth': Timestamp.fromDate(DateTime(2000, 5, 1)),
      'idNumber': '123412341234',
      'addressLine1': '12 MG Road',
      'city': 'Pune',
      'pincode': '411001',
      'emergencyContactName': 'Ravi',
    });
    vm = ProfileViewModel(firestore: fs, uid: 'u1', email: 'a@b.co', store: store);
  });

  test('loads from the user and tenant documents, tenant first', () async {
    await vm.load();
    expect(vm.loading, isFalse);
    expect(vm.tenantId, 'TEN1');
    expect(vm.value(ProfileField.name), 'Asha Rao');
    expect(vm.value(ProfileField.phone), '9811100001');
    expect(vm.gender, 'Female');
    expect(vm.dateOfBirth, DateTime(2000, 5, 1));
    expect(vm.value(ProfileField.emergencyName), 'Ravi');
    expect(vm.completion, 1.0);
    expect(vm.isComplete, isTrue);
  });

  test('completion counts the fields an owner needs', () async {
    await vm.load();
    vm.set(ProfileField.pincode, '');
    vm.setGender(null);
    expect(vm.completion, closeTo(6 / 8, 0.001));
    expect(vm.missing, containsAll(['Gender', 'PIN code']));
  });

  test('checks formats only after a save attempt', () async {
    await vm.load();
    vm.set(ProfileField.phone, '123');
    vm.set(ProfileField.pincode, '41100');
    vm.set(ProfileField.idNumber, '1234');
    vm.set(ProfileField.emergencyPhone, '55');
    expect(vm.errorFor(ProfileField.phone), isNull);

    expect(await vm.save(), isFalse);
    expect(vm.errorFor(ProfileField.phone), 'Enter a 10-digit mobile number.');
    expect(vm.errorFor(ProfileField.pincode), 'PIN codes have 6 digits.');
    expect(vm.errorFor(ProfileField.idNumber), 'Aadhaar numbers have 12 digits.');
    expect(vm.errorFor(ProfileField.emergencyPhone), 'Enter a 10-digit mobile number.');
  });

  test('saves the identity on users and the details on the tenant doc', () async {
    await vm.load();
    vm.set(ProfileField.name, ' Asha R ');
    vm.set(ProfileField.altPhone, '98111 00002');
    vm.setDateOfBirth(DateTime(2000, 6, 2));
    expect(await vm.save(), isTrue);

    final user = (await fs.doc('users/u1').get()).data()!;
    expect(user['fullName'], 'Asha R');
    expect(user['name'], 'Asha R');
    expect(user['userType'], 'tenant');
    expect(user['profileComplete'], isTrue);
    expect(user.containsKey('idNumber'), isFalse, reason: 'KYC stays off the user doc');

    final tenant = (await fs.doc('tenants/TEN1').get()).data()!;
    expect(tenant['fullName'], 'Asha R');
    expect(tenant['alternatePhone'], '98111 00002');
    expect((tenant['dateOfBirth'] as Timestamp).toDate(), DateTime(2000, 6, 2));
    expect(tenant['idNumber'], '123412341234');
    expect(tenant['userId'], 'u1');
    expect(tenant['profileComplete'], isTrue);
  });

  test('saves an incomplete profile as incomplete', () async {
    await vm.load();
    vm.set(ProfileField.city, '');
    expect(await vm.save(), isTrue);
    expect((await fs.doc('users/u1').get()).data()!['profileComplete'], isFalse);
  });

  test('without a tenant id only the user doc is written', () async {
    await fs.doc('users/u2').set({'fullName': 'New'});
    final fresh = ProfileViewModel(firestore: fs, uid: 'u2', email: '', store: store);
    await fresh.load();
    fresh.set(ProfileField.phone, '9811100003');
    expect(await fresh.save(), isTrue);
    expect((await fs.doc('users/u2').get()).data()!['phone'], '9811100003');
    expect(fresh.canUploadDocuments, isFalse);
  });

  group('documents', () {
    test('uploads, lists newest first, and deletes', () async {
      await vm.load();
      await vm.uploadDocument(DocumentType.aadhar, XFile('/tmp/aadhaar.jpg', name: 'aadhaar.jpg'));
      expect(store.uploads, ['TEN1/aadhar/aadhaar.jpg']);
      expect(vm.documents.single.typeName, 'Aadhaar Card');
      expect(vm.documents.single.documentUrl, 'https://files/aadhaar.jpg');

      await vm.deleteDocument(vm.documents.single);
      expect(store.deleted, ['https://files/aadhaar.jpg']);
      expect(vm.documents, isEmpty);
      expect((await fs.collection('tenants/TEN1/documents').get()).docs, isEmpty);
    });
  });
}
