import 'package:flutter_test/flutter_test.dart';
import 'package:tenant/data/sources.dart';
import 'package:tenant/presentation/property/join_viewmodel.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBackend backend;
  late JoinViewModel vm;
  final today = DateTime(2026, 3, 12, 15);

  setUp(() {
    backend = FakeBackend();
    vm = JoinViewModel(
      source: backend,
      property: testProperty(),
      name: 'Asha Rao',
      phone: '+919811100001',
      clock: () => today,
    );
  });

  test('prefills who is asking and offers the priced sharing options', () {
    expect(vm.name, 'Asha Rao');
    expect(vm.phone, '+919811100001');
    expect(vm.sharingOptions, ['Double', 'Single']);
    expect(vm.sharing, isNull);
  });

  test('move-in can be today up to a year ahead', () {
    expect(vm.firstMoveIn, DateTime(2026, 3, 12));
    expect(vm.lastMoveIn, DateTime(2027, 3, 12));
  });

  test('asks for what is missing, only after a try', () async {
    vm.setName(' ');
    vm.setPhone('123');
    expect(vm.nameError, isNull);
    expect(await vm.submit(), isFalse);
    expect(vm.nameError, 'Enter your name.');
    expect(vm.phoneError, 'Enter a 10-digit mobile number.');
    expect(vm.moveInError, 'Pick a move-in date.');
    expect(backend.lastEnrollment, isNull);
  });

  test('sends the request with a tidy phone number', () async {
    vm.setPhone('98111 00001');
    vm.setMoveIn(DateTime(2026, 4, 1));
    vm.setSharing('Double');
    vm.setNotes('  Ground floor please ');
    expect(await vm.submit(), isTrue);

    final d = backend.lastEnrollment!;
    expect(d.propertyId, 'BUS0000001PNR001');
    expect(d.businessId, 'BUS0000001');
    expect(d.propertyName, 'Green Nest');
    expect(d.name, 'Asha Rao');
    expect(d.phone, '+919811100001');
    expect(d.moveIn, DateTime(2026, 4, 1));
    expect(d.sharing, 'Double');
    expect(d.notes, 'Ground floor please');
    expect(vm.sent, isTrue);
  });

  test("explains the backend's refusal", () async {
    vm.setMoveIn(DateTime(2026, 4, 1));
    backend.failure = const TenantFailure('You already have a pending enrollment request.');
    expect(await vm.submit(), isFalse);
    expect(vm.error, 'You already have a pending enrollment request.');
    expect(vm.busy, isFalse);
  });
}
