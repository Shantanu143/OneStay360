import 'package:business/presentation/tenant_detail/tenant_detail_models.dart';
import 'package:business/presentation/tenant_detail/tenant_detail_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/tenant_fakes.dart';

void main() {
  late FakeTenantSource source;
  late TenantDetailViewModel vm;

  TenantProfile profile([Map<String, dynamic>? map]) => TenantProfile.fromMap(
        map ?? tenantMap(),
        propertyName: 'Sunrise Boys PG',
        businessId: 'BUS1',
      );

  setUp(() {
    source = FakeTenantSource();
    vm = TenantDetailViewModel(profile: profile(), source: source);
  });

  tearDown(() => vm.dispose());

  group('payments', () {
    test('start loading, then show the newest first', () async {
      vm.listenPayments();
      expect(vm.paymentsLoading, isTrue);

      source.controller.add([
        TenantPayment.fromMap('a', {'month': 'August', 'amount': 1, 'date': DateTime(2026, 8, 3)}),
        TenantPayment.fromMap('b', {'month': 'October', 'amount': 2, 'date': DateTime(2026, 10, 3)}),
        TenantPayment.fromMap('c', {'month': 'September', 'amount': 3}),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(vm.paymentsLoading, isFalse);
      expect(vm.payments.map((p) => p.id), ['b', 'a', 'c'], reason: 'undated last');
    });

    test('listen once however often it is asked', () {
      vm.listenPayments();
      vm.listenPayments();

      expect(source.listens, 1);
    });

    test('report a stream failure without losing what was shown', () async {
      vm.listenPayments();
      source.controller.add([TenantPayment.fromMap('a', {'amount': 1})]);
      await Future<void>.delayed(Duration.zero);

      source.controller.addError(Exception('denied'));
      await Future<void>.delayed(Duration.zero);

      expect(vm.paymentsError, "Couldn't load payments.");
      expect(vm.payments, hasLength(1));
    });

    test('can be retried', () async {
      vm.listenPayments();
      source.controller.addError(Exception('denied'));
      await Future<void>.delayed(Duration.zero);

      vm.retryPayments();
      expect(source.listens, 2);
      expect(vm.paymentsError, isNull);
      expect(vm.paymentsLoading, isTrue);
    });

    test('nothing to listen to without a business or tenant', () {
      final empty = TenantDetailViewModel(
        profile: TenantProfile.fromMap({'name': 'X'}, propertyName: '', businessId: ''),
        source: source,
      )..listenPayments();

      expect(source.listens, 0);
      expect(empty.paymentsLoading, isFalse);
      expect(empty.payments, isEmpty);
      empty.dispose();
    });

    test('stop listening on dispose', () {
      vm.listenPayments();
      expect(source.controller.hasListener, isTrue);

      vm.dispose();

      expect(source.controller.hasListener, isFalse);
      vm = TenantDetailViewModel(profile: profile(), source: source);
    });
  });

  group('saveContact', () {
    test('saves trimmed values and shows them straight away', () async {
      final error = await vm.saveContact(
        name: '  Rohan M  ',
        phone: ' +91 98765 43210 ',
        email: ' rohan@new.test ',
      );

      expect(error, isNull);
      expect(source.updates.single, {
        'businessId': 'BUS1',
        'tenantId': 'TEN0000001',
        'name': 'Rohan M',
        'phone': '+91 98765 43210',
        'email': 'rohan@new.test',
      });
      expect(vm.profile.name, 'Rohan M');
      expect(vm.profile.phone, '+91 98765 43210');
      expect(vm.saving, isFalse);
    });

    test('lets the email be cleared', () async {
      expect(await vm.saveContact(name: 'Rohan', phone: '9000000101', email: ''), isNull);
      expect(vm.profile.email, isNull);
    });

    test('refuses bad input without calling the backend', () async {
      expect(await vm.saveContact(name: ' ', phone: '9000000101', email: ''), "Enter the tenant's name.");
      expect(await vm.saveContact(name: 'Rohan', phone: '123', email: ''), 'Enter a valid phone number.');
      expect(
        await vm.saveContact(name: 'Rohan', phone: '9000000101', email: 'nope'),
        'Enter a valid email address.',
      );
      expect(source.updates, isEmpty);
      expect(vm.profile.name, 'Rohan Mehta');
    });

    test('keeps the old details when the save fails', () async {
      source.updateFailure = Exception('permission-denied');

      final error = await vm.saveContact(name: 'Changed', phone: '9000000101', email: '');

      expect(error, "Couldn't save the changes. Try again.");
      expect(vm.profile.name, 'Rohan Mehta');
      expect(vm.saving, isFalse);
    });
  });

  group('remove', () {
    test('vacates the bed through the backend', () async {
      final ok = await vm.remove();

      expect(ok, isTrue);
      expect(source.vacated.single, {
        'businessId': 'BUS1',
        'tenantId': 'TEN0000001',
        'propertyId': 'P1',
        'roomId': '101',
        'bedId': '1',
      });
      expect(vm.removing, isFalse);
      expect(vm.actionError, isNull);
    });

    test('says why when it fails', () async {
      source.vacateFailure = Exception('boom');

      expect(await vm.remove(), isFalse);
      expect(vm.actionError, "Couldn't remove this tenant. Try again.");
      expect(vm.removing, isFalse);
    });

    test('refuses when the record lacks its room or bed', () async {
      final bare = TenantDetailViewModel(
        profile: TenantProfile.fromMap(
          {'tenantId': 'T1', 'name': 'A', 'propertyId': 'P1'},
          propertyName: '',
          businessId: 'BUS1',
        ),
        source: source,
      );

      expect(await bare.remove(), isFalse);
      expect(bare.actionError, 'Missing information to remove this tenant.');
      expect(source.vacated, isEmpty);
      bare.dispose();
    });
  });
}
