import 'dart:async';

import 'package:business/presentation/team/invite_form_viewmodel.dart';
import 'package:business/presentation/team/team_models.dart';
import 'package:business/presentation/team/team_source.dart';
import 'package:business/presentation/team/team_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/team_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 26, 10);
  late FakeTeamSource source;
  late TeamViewModel vm;

  TeamInvite invite(String id, DateTime expires) => TeamInvite(
        id: id,
        phone: '+91981110000$id',
        role: 'staff',
        propertyIds: const ['P1'],
        createdAt: DateTime(2026, 10, 20),
        expiresAt: expires,
      );

  setUp(() {
    source = FakeTeamSource(
      members: [
        member('s1', 'Amit Verma', role: 'staff'),
        member('o1', 'Rajesh Sharma', role: 'owner'),
        member('m1', 'Priya Nair', role: 'manager'),
        member('d1', 'Zoya Khan', role: 'staff', status: 'disabled'),
      ],
      access: {
        'm1': {'P1', 'P2'},
        's1': {'P1'},
      },
    );
    vm = TeamViewModel(source: source, clock: () => now);
  });

  tearDown(() {
    vm.dispose();
    source.dispose();
  });

  group('loading', () {
    test('orders owner, active members by name, then disabled', () async {
      await vm.load('B1');

      expect(vm.members.map((m) => m.displayName), ['Rajesh Sharma', 'Amit Verma', 'Priya Nair', 'Zoya Khan']);
    });

    test('is loading until the members arrive', () async {
      source.membersGate = Completer<void>();
      final pending = vm.load('B1');
      await Future<void>.delayed(Duration.zero);

      expect(vm.loading, isTrue);
      expect(vm.hasLoaded, isFalse);

      source.membersGate!.complete();
      await pending;

      expect(vm.loading, isFalse);
      expect(vm.hasLoaded, isTrue);
    });

    test('says so when members cannot be read, and retries', () async {
      source.membersFailure = Exception('denied');
      await vm.load('B1');

      expect(vm.error, "Couldn't load your team.");
      expect(vm.hasLoaded, isFalse);

      source.membersFailure = null;
      await vm.load('B1');

      expect(vm.error, isNull);
      expect(vm.hasLoaded, isTrue);
    });

    test('says so when the properties cannot be read', () async {
      source.propertiesFailure = Exception('denied');
      await vm.load('B1');

      expect(vm.error, "Couldn't load your team.");
    });

    test('keeps working when only the access summary fails', () async {
      source.accessFailure = Exception('denied');
      await vm.load('B1');

      expect(vm.error, isNull);
      expect(vm.members, isNotEmpty);
      expect(vm.accessSummary(vm.members[1]), 'Access not loaded');
    });

    test('follows the members as they change', () async {
      await vm.load('B1');

      source.emit([member('o1', 'Rajesh Sharma', role: 'owner')]);
      await Future<void>.delayed(Duration.zero);

      expect(vm.members.map((m) => m.uid), ['o1']);
    });

    test('a member list that fails later shows the error', () async {
      await vm.load('B1');

      source.emitError(Exception('lost'));
      await Future<void>.delayed(Duration.zero);

      expect(vm.error, "Couldn't load your team.");
    });
  });

  group('summary', () {
    test('counts members', () async {
      await vm.load('B1');
      expect(vm.summaryLine, '4 members');

      source.emit([member('o1', 'Rajesh', role: 'owner')]);
      await Future<void>.delayed(Duration.zero);
      expect(vm.summaryLine, '1 member');
    });

    test('says how many properties each can open', () async {
      await vm.load('B1');
      final byUid = {for (final m in vm.members) m.uid: m};

      expect(vm.accessSummary(byUid['o1']!), 'All properties');
      expect(vm.accessSummary(byUid['m1']!), '2 properties');
      expect(vm.accessSummary(byUid['s1']!), '1 property');
      expect(vm.accessSummary(byUid['d1']!), 'No properties');
    });
  });

  group('pending invitations', () {
    test('lists the ones still open, soonest to expire first', () async {
      source.invites = [
        invite('1', DateTime(2026, 11, 2)),
        invite('2', DateTime(2026, 10, 28)),
        invite('3', DateTime(2026, 10, 20)),
      ];
      await vm.load('B1');

      expect(vm.invites.map((i) => i.id), ['2', '1']);
    });
  });

  group('inviting', () {
    InviteRequest request() => const InviteRequest(
          phone: '+919811100001',
          email: null,
          role: 'manager',
          propertyIds: ['P1'],
        );

    test('sends it and shows it among the pending invitations', () async {
      await vm.load('B1');

      final result = await vm.invite(request());

      expect(result!.link, contains('inviteId=inv1'));
      expect(source.invited.single.phone, '+919811100001');
      expect(vm.invites.map((i) => i.id), ['inv1']);
      expect(vm.inviteError, isNull);
    });

    test('reports the reason the server gave', () async {
      await vm.load('B1');
      source.inviteFailure = const TeamException('Only the owner can invite team members.');

      final result = await vm.invite(request());

      expect(result, isNull);
      expect(vm.inviteError, 'Only the owner can invite team members.');
    });

    test('says something plain for any other failure', () async {
      await vm.load('B1');
      source.inviteFailure = Exception('boom');

      await vm.invite(request());

      expect(vm.inviteError, "Couldn't send the invitation. Try again.");
    });

    test('is busy while sending', () async {
      await vm.load('B1');
      var sawBusy = false;
      vm.addListener(() => sawBusy = sawBusy || vm.isInviting);

      await vm.invite(request());

      expect(sawBusy, isTrue);
      expect(vm.isInviting, isFalse);
    });

    test('clears an old error when starting again', () async {
      await vm.load('B1');
      source.inviteFailure = Exception('boom');
      await vm.invite(request());
      source.inviteFailure = null;

      await vm.invite(request());

      expect(vm.inviteError, isNull);
    });
  });

  group('turning access off and on', () {
    test('switches a member off and moves them below those who still have access', () async {
      await vm.load('B1');
      final amit = vm.members.firstWhere((m) => m.uid == 's1');

      expect(await vm.setActive(amit, false), isTrue);
      await Future<void>.delayed(Duration.zero);

      expect(source.calls, contains('setMemberActive:s1:false'));
      expect(vm.members.firstWhere((m) => m.uid == 's1').isActive, isFalse);
      expect(vm.members.map((m) => m.uid), ['o1', 'm1', 's1', 'd1']);
    });

    test('switches a member back on', () async {
      await vm.load('B1');
      final zoya = vm.members.firstWhere((m) => m.uid == 'd1');

      expect(await vm.setActive(zoya, true), isTrue);
      await Future<void>.delayed(Duration.zero);

      expect(vm.members.firstWhere((m) => m.uid == 'd1').isActive, isTrue);
      expect(vm.members.map((m) => m.uid), ['o1', 's1', 'm1', 'd1']);
    });

    test('never switches the owner off', () async {
      await vm.load('B1');
      final owner = vm.members.firstWhere((m) => m.isOwner);

      expect(await vm.setActive(owner, false), isFalse);

      expect(source.calls.where((c) => c.startsWith('setMemberActive')), isEmpty);
    });

    test('says so when it fails', () async {
      await vm.load('B1');
      source.activeFailure = Exception('denied');

      final ok = await vm.setActive(vm.members[2], false);

      expect(ok, isFalse);
      expect(vm.actionError, "Couldn't change their access. Try again.");
    });
  });

  group('refresh', () {
    test('reads the invitations and access again', () async {
      await vm.load('B1');
      source.calls.clear();

      await vm.refresh();

      expect(source.calls, containsAll(['loadProperties', 'loadPendingInvites', 'loadAccess']));
      expect(source.calls, isNot(contains('watchMembers')), reason: 'members are live already');
    });

    test('does nothing before a first load', () async {
      await vm.refresh();

      expect(source.calls, isEmpty);
    });
  });

  test('being disposed while loading does not throw', () async {
    source.membersGate = Completer<void>();
    final other = TeamViewModel(source: source, clock: () => now);
    final pending = other.load('B1');

    other.dispose();
    source.membersGate!.complete();

    await expectLater(pending, completes);
  });
}
