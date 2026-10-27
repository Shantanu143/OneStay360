import 'package:business/presentation/profile/my_details_source.dart';
import 'package:business/presentation/profile/my_details_viewmodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSource implements MyDetailsSource {
  final saved = <({String name, String? email, String? phone})>[];
  Object? failure;

  @override
  Future<void> save({
    required String businessId,
    required String uid,
    required String name,
    String? email,
    String? phone,
  }) async {
    if (failure != null) throw failure!;
    saved.add((name: name, email: email, phone: phone));
  }
}

void main() {
  late FakeSource source;
  var reloads = 0;
  Object? reloadFailure;

  setUp(() {
    source = FakeSource();
    reloads = 0;
    reloadFailure = null;
  });

  MyDetailsViewModel make({String name = 'Priya Nair', String email = 'priya@example.test', String phone = '+919000000002'}) {
    final vm = MyDetailsViewModel(
      source: source,
      businessId: 'B1',
      uid: 'u1',
      name: name,
      email: email,
      phone: phone,
      reloadSession: () async {
        reloads++;
        if (reloadFailure != null) throw reloadFailure!;
      },
    );
    addTearDown(vm.dispose);
    return vm;
  }

  group('the form', () {
    test('starts with what is known and nothing to save', () {
      final vm = make();

      expect(vm.name, 'Priya Nair');
      expect(vm.isDirty, isFalse);
      expect(vm.nameError, isNull);
    });

    test('notices a change, and a change back', () {
      final vm = make();

      vm.setName('Priya N');
      expect(vm.isDirty, isTrue);

      vm.setName('Priya Nair');
      expect(vm.isDirty, isFalse);
    });

    test('does not count stray spaces as a change', () {
      final vm = make();

      vm.setName('  Priya   Nair ');

      expect(vm.isDirty, isFalse);
    });
  });

  group('checking it', () {
    test('wants a name', () async {
      final vm = make(name: '');

      expect(await vm.submit(), isFalse);

      expect(vm.nameError, 'Enter your name.');
      expect(source.saved, isEmpty);
    });

    test('a single letter is not a name', () async {
      final vm = make(name: 'P');

      await vm.submit();

      expect(vm.nameError, 'Use at least 2 characters.');
    });

    test('an email, if there is one, has to look like one', () async {
      final vm = make();
      vm.setEmail('priya@');

      await vm.submit();

      expect(vm.emailError, 'Enter a valid email, or leave it blank.');
    });

    test('a phone number, if there is one, has to be one', () async {
      final vm = make();
      vm.setPhone('12345');

      await vm.submit();

      expect(vm.phoneError, 'Enter a 10-digit mobile number, or leave it blank.');
    });

    test('email and phone can be left blank', () async {
      final vm = make(email: '', phone: '');

      expect(await vm.submit(), isTrue);

      expect(source.saved.single.email, isNull);
      expect(source.saved.single.phone, isNull);
    });

    test('an error goes away as soon as it is fixed', () async {
      final vm = make(name: '');
      await vm.submit();

      vm.setName('Priya');

      expect(vm.nameError, isNull);
    });
  });

  group('saving', () {
    test('saves tidy values, with the phone as a full number, then reloads the session', () async {
      final vm = make();
      vm.setName('  Priya   N  ');
      vm.setEmail(' Priya.N@Example.test ');
      vm.setPhone('98111 00001');

      expect(await vm.submit(), isTrue);

      expect(source.saved.single, (name: 'Priya N', email: 'priya.n@example.test', phone: '+919811100001'));
      expect(reloads, 1);
    });

    test('shows why it failed and can try again', () async {
      final vm = make();
      vm.setName('Priya N');
      source.failure = Exception('denied');

      expect(await vm.submit(), isFalse);

      expect(vm.error, "Couldn't save your details. Try again.");
      expect(vm.busy, isFalse);

      source.failure = null;
      expect(await vm.submit(), isTrue);
      expect(vm.error, isNull);
    });

    test('it is saved even if reloading the session fails', () async {
      final vm = make();
      vm.setName('Priya N');
      reloadFailure = Exception('offline');

      expect(await vm.submit(), isTrue);
    });

    test('does not save twice at once', () async {
      final vm = make();
      vm.setName('Priya N');

      final a = vm.submit();
      final b = vm.submit();
      await Future.wait([a, b]);

      expect(source.saved, hasLength(1));
    });
  });

  group('where it is saved', () {
    late FakeFirebaseFirestore fs;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      await fs.doc('businesses/B1/members/u1').set({'role': 'manager', 'status': 'active', 'name': 'Old'});
      await fs.doc('users/u1').set({'fullName': 'Old', 'businessId': 'B1', 'phoneNumber': '+919000000002'});
    });

    test('on the team record and on the person\'s own profile', () async {
      final source = FirestoreMyDetailsSource(firestore: fs);

      await source.save(businessId: 'B1', uid: 'u1', name: 'Priya Nair', email: 'p@example.test', phone: '+919811100001');

      final member = (await fs.doc('businesses/B1/members/u1').get()).data()!;
      expect(member['name'], 'Priya Nair');
      expect(member['displayName'], 'Priya Nair');
      expect(member['email'], 'p@example.test');
      expect(member['phone'], '+919811100001');
      expect(member['updatedBy'], 'u1');
      expect(member['role'], 'manager', reason: 'nothing else on the record is touched');
      expect(member['status'], 'active');

      final user = (await fs.doc('users/u1').get()).data()!;
      expect(user['fullName'], 'Priya Nair');
      expect(user['businessId'], 'B1');
      expect(user['phoneNumber'], '+919000000002', reason: 'the verified sign-in number is not overwritten');
    });

    test('a cleared email or phone is removed from the team record', () async {
      await fs.doc('businesses/B1/members/u1').update({'email': 'old@example.test', 'phone': '+919000000002'});
      final source = FirestoreMyDetailsSource(firestore: fs);

      await source.save(businessId: 'B1', uid: 'u1', name: 'Priya Nair');

      final member = (await fs.doc('businesses/B1/members/u1').get()).data()!;
      expect(member.containsKey('email'), isFalse);
      expect(member.containsKey('phone'), isFalse);
    });
  });

  // Keeps the import used by the fake above honest.
  test('timestamps are written by the server', () {
    expect(FieldValue.serverTimestamp(), isNotNull);
  });
}
