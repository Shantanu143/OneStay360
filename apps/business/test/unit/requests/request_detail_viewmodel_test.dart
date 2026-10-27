import 'package:business/presentation/requests/request_detail_viewmodel.dart';
import 'package:business/presentation/requests/request_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/request_fakes.dart';

void main() {
  late FakeRequestSource source;
  late RequestDetailViewModel vm;

  setUp(() {
    source = FakeRequestSource();
    vm = RequestDetailViewModel(requestId: 'R1', source: source, initial: requestOf());
  });

  tearDown(() => vm.dispose());

  Future<void> push(EnrollmentRequest? r) async {
    source.controller.add(r);
    await Future<void>.delayed(Duration.zero);
  }

  group('watching', () {
    test('shows the request it was given while the live one loads', () {
      vm.start();

      expect(vm.request?.tenantName, 'Mohit Saxena');
      expect(vm.loading, isFalse, reason: 'something to show already');
    });

    test('follows the live document', () async {
      vm.start();
      await push(requestOf(status: 'bill_sent', extra: billExtra));

      expect(vm.request!.stage, RequestStage.billSent);
      expect(vm.request!.bill!.total, 21500);
    });

    test('is loading without anything to show until the first snapshot', () async {
      final bare = RequestDetailViewModel(requestId: 'R1', source: source)..start();
      expect(bare.loading, isTrue);

      await push(requestOf());
      expect(bare.loading, isFalse);
      bare.dispose();
    });

    test('knows when the request has been deleted', () async {
      vm.start();
      await push(null);

      expect(vm.missing, isTrue);
    });

    test('reports a failure and can retry', () async {
      vm.start();
      source.controller.addError(Exception('denied'));
      await Future<void>.delayed(Duration.zero);

      expect(vm.error, "Couldn't load this request.");

      vm.retry();
      expect(source.watches, 2);
      expect(vm.error, isNull);
    });

    test('starts once however often it is asked', () {
      vm.start();
      vm.start();

      expect(source.watches, 1);
    });

    test('stops listening on dispose', () {
      vm.start();
      vm.dispose();

      expect(source.controller.hasListener, isFalse);
      vm = RequestDetailViewModel(requestId: 'R1', source: source);
    });
  });

  group('actions', () {
    test('reject turns a pending request down', () async {
      vm.start();

      expect(await vm.reject(), isTrue);
      expect(source.calls, ['reject:R1']);
      expect(vm.busy, isFalse);
    });

    test('confirm and reject-payment need a submitted payment', () async {
      vm.start();
      expect(await vm.confirmPayment(), isFalse);
      expect(await vm.rejectPayment('why'), isFalse);
      expect(vm.actionError, 'This request has changed. Review it again.');
      expect(source.calls, isEmpty);

      await push(requestOf(status: 'payment_submitted', extra: billExtra));
      expect(await vm.confirmPayment(), isTrue);
      expect(await vm.rejectPayment('Wrong amount'), isTrue);
      expect(source.calls, ['confirm:R1', 'rejectPayment:R1:Wrong amount']);
    });

    test('a request that could not be completed can be tried again', () async {
      vm.start();
      await push(requestOf(status: 'approval_failed', extra: {...billExtra, 'approvalError': 'Bed taken'}));

      expect(await vm.retryApproval(), isTrue);
      expect(source.calls, ['confirm:R1'], reason: 'confirming again re-runs adding the tenant');
    });

    test('trying again only applies to a failed approval', () async {
      vm.start();

      expect(await vm.retryApproval(), isFalse);
      expect(source.calls, isEmpty);
    });

    test('reject only applies while the request is pending', () async {
      vm.start();
      await push(requestOf(status: 'confirmed'));

      expect(await vm.reject(), isFalse);
      expect(source.calls, isEmpty);
    });

    test('a failed action says so and can be tried again', () async {
      vm.start();
      source.failure = Exception('denied');

      expect(await vm.reject(), isFalse);
      expect(vm.actionError, "Couldn't update the request. Try again.");
      expect(vm.busy, isFalse);

      source.failure = null;
      expect(await vm.reject(), isTrue);
      expect(vm.actionError, isNull);
    });
  });
}
