import 'package:flutter_test/flutter_test.dart';
import 'package:tenant/data/models.dart';
import 'package:tenant/presentation/payments/request_viewmodel.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBackend backend;
  late RequestViewModel vm;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  EnrollmentRequest bill({BillPaymentMode mode = BillPaymentMode.upi, String? rejection}) => EnrollmentRequest(
        id: 'E1',
        stage: EnrollmentStage.billSent,
        propertyName: 'Green Nest',
        total: 23000,
        paymentMode: mode,
        ownerUpiId: mode == BillPaymentMode.upi ? 'owner@upi' : null,
        paymentRejectionReason: rejection,
      );

  setUp(() {
    backend = FakeBackend();
    vm = RequestViewModel(source: backend, requestId: 'E1', uid: 'u1');
  });

  tearDown(() => vm.dispose());

  test('loads, then follows the request', () async {
    expect(vm.loading, isTrue);
    backend.request.set(bill());
    await settle();
    expect(vm.loading, isFalse);
    expect(vm.request!.stage, EnrollmentStage.billSent);
    backend.request.set(const EnrollmentRequest(id: 'E1', stage: EnrollmentStage.confirmed));
    await settle();
    expect(vm.request!.stage, EnrollmentStage.confirmed);
  });

  test('a deleted request is gone', () async {
    backend.request.set(null);
    await settle();
    expect(vm.loading, isFalse);
    expect(vm.missing, isTrue);
  });

  group('paying the first bill', () {
    test('UPI needs a reference', () async {
      backend.request.set(bill());
      await settle();
      expect(vm.referenceRequired, isTrue);
      expect(await vm.confirmPaid(), isFalse);
      expect(vm.referenceError, 'Enter the UPI reference (UTR) from your payment app.');
      vm.setReference('123');
      expect(await vm.confirmPaid(), isFalse);
      expect(vm.referenceError, 'That reference looks too short.');
    });

    test('sends the reference and waits for the owner', () async {
      backend.request.set(bill());
      await settle();
      vm.setReference(' UTR4567890 ');
      expect(await vm.confirmPaid(), isTrue);
      expect(backend.calls, contains('submitBillPayment:E1'));
      expect(backend.lastBillReference, 'UTR4567890');
    });

    test('bank transfers need a reference too', () async {
      backend.request.set(bill(mode: BillPaymentMode.bank));
      await settle();
      expect(vm.referenceRequired, isTrue);
      expect(vm.referenceLabel, 'Transfer reference (UTR)');
    });

    test('cash needs none and is recorded as cash', () async {
      backend.request.set(bill(mode: BillPaymentMode.cash));
      await settle();
      expect(vm.referenceRequired, isFalse);
      expect(await vm.confirmPaid(), isTrue);
      expect(backend.lastBillReference, 'CASH');
    });

    test('a failure is explained', () async {
      backend.request.set(bill());
      await settle();
      vm.setReference('UTR4567890');
      backend.failure = Exception('denied');
      expect(await vm.confirmPaid(), isFalse);
      expect(vm.error, "Couldn't send it. Check your connection and try again.");
      expect(vm.busy, isFalse);
    });

    test('shows why the owner sent the last payment back', () async {
      backend.request.set(bill(rejection: 'Amount not received'));
      await settle();
      expect(vm.request!.paymentRejectionReason, 'Amount not received');
    });

    test('builds the UPI link with the bill total', () async {
      backend.request.set(bill());
      await settle();
      expect(vm.upiIntent!.queryParameters['am'], '23000.00');
      expect(vm.upiIntent!.queryParameters['pa'], 'owner@upi');
    });
  });

  test('a pending request can be withdrawn', () async {
    backend.request.set(const EnrollmentRequest(id: 'E1', stage: EnrollmentStage.pending));
    await settle();
    expect(vm.canWithdraw, isTrue);
    expect(await vm.withdraw(), isTrue);
    expect(backend.calls, contains('withdraw:E1'));
  });

  test('only pending requests can be withdrawn', () async {
    backend.request.set(bill());
    await settle();
    expect(vm.canWithdraw, isFalse);
    expect(await vm.withdraw(), isFalse);
  });
}
