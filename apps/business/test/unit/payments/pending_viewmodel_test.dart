import 'package:business/presentation/payments/pending_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/payment_fakes.dart';
import '../../support/request_fakes.dart';

void main() {
  late FakePendingSource pending;
  late FakeRequestSource requests;
  late PendingPaymentsViewModel vm;

  setUp(() {
    pending = FakePendingSource()
      ..rent = [
        rentPayment('p1', at: DateTime(2026, 10, 24)),
        rentPayment('p2', tenantId: 'T2', name: 'Arjun Reddy', at: DateTime(2026, 10, 26)),
      ];
    requests = FakeRequestSource();
    vm = PendingPaymentsViewModel(
      businessId: 'BUS1',
      source: pending,
      requests: requests,
    );
  });

  tearDown(() => vm.dispose());

  Future<void> start() async {
    await vm.start();
    pending.deposits$.add([depositRequest('d1')]);
    await Future<void>.delayed(Duration.zero);
  }

  group('loading', () {
    test('shows rent and deposits, newest first', () async {
      await start();

      expect(vm.loading, isFalse);
      expect(vm.rent.map((r) => r.paymentId), ['p2', 'p1']);
      expect(vm.deposits.map((d) => d.id), ['d1']);
      expect(vm.total, 3);
    });

    test('passes the property filter along', () async {
      vm = PendingPaymentsViewModel(
        businessId: 'BUS1',
        propertyId: 'P9',
        source: pending,
        requests: requests,
      );
      await vm.start();

      expect(pending.lastPropertyId, 'P9');
    });

    test('a failed rent load does not hide the deposits', () async {
      pending.rentFailure = Exception('denied');
      await start();

      expect(vm.rentError, "Couldn't load rent payments.");
      expect(vm.deposits, hasLength(1));
      expect(vm.depositsError, isNull);
    });

    test('a failed deposits stream is reported on its own', () async {
      await vm.start();
      pending.deposits$.addError(Exception('denied'));
      await Future<void>.delayed(Duration.zero);

      expect(vm.depositsError, "Couldn't load deposits.");
      expect(vm.rent, hasLength(2));
    });

    test('rent can be reloaded', () async {
      await start();
      pending.rent = [rentPayment('p3')];

      await vm.reloadRent();

      expect(vm.rent.map((r) => r.paymentId), ['p3']);
      expect(pending.rentLoads, 2);
    });

    test('starting twice listens once', () async {
      await vm.start();
      await vm.start();

      expect(pending.depositWatches, 1);
    });
  });

  group('rent payments', () {
    setUp(() async => start());

    test('confirming one verifies it and takes it off the list', () async {
      final ok = await vm.confirmRent(vm.rent.first);

      expect(ok, isTrue);
      expect(pending.verified.single, (tenantId: 'T2', paymentId: 'p2', confirm: true, reason: null));
      expect(vm.rent.map((r) => r.paymentId), ['p1']);
    });

    test('rejecting one sends the reason', () async {
      final ok = await vm.rejectRent(vm.rent.first, 'Amount short');

      expect(ok, isTrue);
      expect(pending.verified.single.confirm, isFalse);
      expect(pending.verified.single.reason, 'Amount short');
      expect(vm.rent, hasLength(1));
    });

    test('a failure keeps it on the list and says why', () async {
      pending.verifyFailure = Exception('boom');

      final ok = await vm.confirmRent(vm.rent.first);

      expect(ok, isFalse);
      expect(vm.rent, hasLength(2));
      expect(vm.actionError, "Couldn't update that payment. Try again.");
      expect(vm.isBusy('p2'), isFalse);
    });

    test('is busy while one is being processed, and ignores a second tap', () async {
      final target = vm.rent.first;
      final first = vm.confirmRent(target);
      expect(vm.isBusy('p2'), isTrue);

      expect(await vm.confirmRent(target), isFalse);
      expect(await first, isTrue);
      expect(pending.verified, hasLength(1));
    });
  });

  group('deposits', () {
    setUp(() async => start());

    test('confirm goes through the request', () async {
      expect(await vm.confirmDeposit(vm.deposits.first), isTrue);
      expect(requests.calls, ['confirm:d1']);
    });

    test('reject sends the reason and the deposit leaves the list when the request moves on', () async {
      expect(await vm.rejectDeposit(vm.deposits.first, 'Wrong amount'), isTrue);
      expect(requests.calls, ['rejectPayment:d1:Wrong amount']);

      pending.deposits$.add(const []);
      await Future<void>.delayed(Duration.zero);
      expect(vm.deposits, isEmpty);
    });

    test('a failure says why', () async {
      requests.failure = Exception('denied');

      expect(await vm.confirmDeposit(vm.deposits.first), isFalse);
      expect(vm.actionError, "Couldn't update that payment. Try again.");
    });
  });

  test('tab choice sticks and counts are per tab', () async {
    await start();

    expect(vm.tab, PendingTab.rent);
    vm.selectTab(PendingTab.deposits);
    expect(vm.tab, PendingTab.deposits);
    expect(vm.count(PendingTab.rent), 2);
    expect(vm.count(PendingTab.deposits), 1);
  });

  test('stops listening on dispose', () async {
    await vm.start();
    vm.dispose();

    expect(pending.deposits$.hasListener, isFalse);
    vm = PendingPaymentsViewModel(businessId: 'BUS1', source: pending, requests: requests);
  });
}
