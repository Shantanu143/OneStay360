import 'package:business/presentation/team/member_viewmodel.dart';
import 'package:business/presentation/team/team_models.dart';
import 'package:business/presentation/team/team_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/team_fakes.dart';

void main() {
  late FakeTeamSource source;

  MemberViewModel vmFor(TeamMember m) => MemberViewModel(
        businessId: 'B1',
        member: m,
        properties: source.properties,
        source: source,
      );

  setUp(() {
    source = FakeTeamSource(access: {
      'm1': {'P1'},
      'o1': {},
    });
  });

  tearDown(() => source.dispose());

  group('opening a member', () {
    test('shows their role and the properties they can open', () async {
      final vm = vmFor(member('m1', 'Priya Nair', role: 'manager'));
      addTearDown(vm.dispose);

      await vm.load();

      expect(vm.role, 'manager');
      expect(vm.selected, {'P1'});
      expect(vm.isDirty, isFalse);
      expect(vm.canEdit, isTrue);
    });

    test('is loading until access arrives', () async {
      final vm = vmFor(member('m1', 'Priya Nair'));
      addTearDown(vm.dispose);

      final pending = vm.load();
      expect(vm.loading, isTrue);
      await pending;

      expect(vm.loading, isFalse);
    });

    test('says so when their access cannot be read, and offers to retry', () async {
      source.accessFailure = Exception('denied');
      final vm = vmFor(member('m1', 'Priya Nair'));
      addTearDown(vm.dispose);

      await vm.load();

      expect(vm.loadError, "Couldn't load their access.");
      expect(vm.canEdit, isFalse, reason: 'saving blind could remove what they have');

      source.accessFailure = null;
      await vm.load();

      expect(vm.loadError, isNull);
      expect(vm.selected, {'P1'});
    });

    test('someone not listed has no properties yet', () async {
      final vm = vmFor(member('x9', 'New Person', role: 'staff'));
      addTearDown(vm.dispose);

      await vm.load();

      expect(vm.selected, isEmpty);
    });
  });

  group('who can be edited', () {
    test('not the owner', () async {
      final vm = vmFor(member('o1', 'Rajesh', role: 'owner'));
      addTearDown(vm.dispose);
      await vm.load();

      expect(vm.canEdit, isFalse);
      vm.setRole('staff');
      vm.toggleProperty('P2');
      expect(vm.role, 'owner');
      expect(vm.selected, isEmpty);
      expect(await vm.save(), isFalse);
      expect(source.updates, isEmpty);
    });

    test('not someone whose access is off', () async {
      final vm = vmFor(member('d1', 'Zoya', role: 'staff', status: 'disabled'));
      addTearDown(vm.dispose);
      await vm.load();

      expect(vm.canEdit, isFalse);
    });
  });

  group('changing access', () {
    late MemberViewModel vm;

    setUp(() async {
      vm = vmFor(member('m1', 'Priya Nair', role: 'manager'));
      await vm.load();
    });

    tearDown(() => vm.dispose());

    test('notices a change of role or properties', () {
      vm.setRole('staff');
      expect(vm.isDirty, isTrue);

      vm.setRole('manager');
      expect(vm.isDirty, isFalse);

      vm.toggleProperty('P2');
      expect(vm.isDirty, isTrue);
      vm.toggleProperty('P2');
      expect(vm.isDirty, isFalse);
    });

    test('only offers manager and staff', () {
      vm.setRole('owner');

      expect(vm.role, 'manager');
    });

    test('saves the new role and properties, in the order the business lists them', () async {
      vm.setRole('staff');
      vm.toggleProperty('P2');

      expect(await vm.save(), isTrue);

      expect(source.updates.single.uid, 'm1');
      expect(source.updates.single.role, 'staff');
      expect(source.updates.single.propertyIds, ['P1', 'P2']);
      expect(vm.isDirty, isFalse, reason: 'what was saved is the new starting point');
    });

    test('saving with no change does nothing', () async {
      expect(await vm.save(), isTrue);

      expect(source.updates, isEmpty);
    });

    test('can take away every property', () async {
      vm.toggleProperty('P1');

      expect(vm.selected, isEmpty);
      expect(await vm.save(), isTrue);
      expect(source.updates.single.propertyIds, isEmpty);
    });

    test('shows the reason when the server refuses', () async {
      source.updateFailure = const TeamException('Member inactive');
      vm.toggleProperty('P2');

      expect(await vm.save(), isFalse);

      expect(vm.error, 'Member inactive');
      expect(vm.isDirty, isTrue, reason: 'nothing was saved');
    });

    test('says something plain for any other failure, and clears it on the next try', () async {
      source.updateFailure = Exception('boom');
      vm.toggleProperty('P2');
      await vm.save();
      expect(vm.error, "Couldn't save their access. Try again.");

      source.updateFailure = null;
      await vm.save();

      expect(vm.error, isNull);
    });

    test('is busy while saving', () async {
      vm.toggleProperty('P2');
      var sawSaving = false;
      vm.addListener(() => sawSaving = sawSaving || vm.saving);

      await vm.save();

      expect(sawSaving, isTrue);
      expect(vm.saving, isFalse);
    });
  });
}
