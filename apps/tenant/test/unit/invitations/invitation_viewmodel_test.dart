import 'package:flutter_test/flutter_test.dart';
import 'package:tenant/data/models.dart';
import 'package:tenant/data/sources.dart';
import 'package:tenant/presentation/invitations/invitation_viewmodel.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBackend backend;
  late InvitationViewModel vm;
  const invite = PendingInvitation(
    id: 'I1',
    businessId: 'B',
    propertyId: 'P',
    propertyName: 'Green Nest',
    roomNumber: '101',
    bedNumber: '2',
    monthlyRent: 9000,
    deposit: 18000,
  );

  setUp(() {
    backend = FakeBackend()..invitation = invite;
    vm = InvitationViewModel(source: backend, invitationId: 'I1');
  });

  test('loads the invitation', () async {
    expect(vm.loading, isTrue);
    await vm.load();
    expect(vm.invitation!.propertyName, 'Green Nest');
    expect(vm.outcome, InvitationOutcome.none);
  });

  test('a load failure is explained', () async {
    backend.failure = const TenantFailure('This invitation was sent to someone else.');
    await vm.load();
    expect(vm.error, 'This invitation was sent to someone else.');
    expect(vm.invitation, isNull);
  });

  test('accepting joins the PG', () async {
    await vm.load();
    expect(await vm.accept(), isTrue);
    expect(backend.calls, contains('accept:I1'));
    expect(vm.outcome, InvitationOutcome.accepted);
  });

  test('declining passes the reason', () async {
    await vm.load();
    expect(await vm.decline('Found another place'), isTrue);
    expect(backend.calls, contains('decline:I1:Found another place'));
    expect(vm.outcome, InvitationOutcome.declined);
  });

  test('an answered invitation cannot be answered again', () async {
    backend.invitation = const PendingInvitation(id: 'I1', businessId: 'B', propertyId: 'P', status: 'accepted');
    await vm.load();
    expect(vm.canRespond, isFalse);
    expect(await vm.accept(), isFalse);
  });

  test('a failed accept keeps the invitation open with the reason', () async {
    await vm.load();
    backend.failure = const TenantFailure('That bed has just been taken.');
    expect(await vm.accept(), isFalse);
    expect(vm.error, 'That bed has just been taken.');
    expect(vm.outcome, InvitationOutcome.none);
  });
}
