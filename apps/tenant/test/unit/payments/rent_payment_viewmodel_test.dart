import 'package:flutter_test/flutter_test.dart';
import 'package:tenant/data/models.dart';
import 'package:tenant/data/sources.dart';
import 'package:tenant/presentation/payments/rent_payment_viewmodel.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBackend backend;
  const invoice = RentInvoice(
    id: 'I1',
    status: InvoiceStatus.unpaid,
    amount: 9000,
    month: 'March 2026',
    periodMonth: '2026-03',
  );

  setUp(() => backend = FakeBackend());

  RentPaymentViewModel make({RentInvoice? inv = invoice}) => RentPaymentViewModel(
        source: backend,
        stay: testStay,
        tenantId: 'TEN1',
        invoice: inv,
        clock: () => DateTime(2026, 3, 12),
      );

  group('choosing how to pay', () {
    test('offers online first when the owner has it on and there is an invoice', () async {
      backend.settings = const PaymentSettings(onlineEnabled: true, upiId: 'owner@upi');
      final vm = make();
      expect(vm.loading, isTrue);
      await vm.load();
      expect(vm.loading, isFalse);
      expect(vm.methods, [RentMethod.online, RentMethod.upi, RentMethod.cash]);
      expect(vm.method, RentMethod.online);
      expect(vm.ownerUpiId, 'owner@upi');
    });

    test('no online payment without an invoice to link it to', () async {
      backend.settings = const PaymentSettings(onlineEnabled: true);
      final vm = make(inv: null);
      await vm.load();
      expect(vm.methods, [RentMethod.upi, RentMethod.cash]);
      expect(vm.method, RentMethod.upi);
    });

    test('no online payment when the owner has not set it up', () async {
      final vm = make();
      await vm.load();
      expect(vm.methods, isNot(contains(RentMethod.online)));
    });
  });

  group('amount and month', () {
    test('an invoice fixes both', () async {
      final vm = make();
      await vm.load();
      expect(vm.amountLocked, isTrue);
      expect(vm.amount, 9000);
      expect(vm.month, 'March 2026');
      vm.setAmount('1');
      expect(vm.amount, 9000);
    });

    test('without an invoice the rent and this month are suggested', () async {
      final vm = make(inv: null);
      await vm.load();
      expect(vm.amountLocked, isFalse);
      expect(vm.amount, 9000);
      expect(vm.month, 'March 2026');
      expect(vm.monthOptions, ['January 2026', 'February 2026', 'March 2026', 'April 2026']);
      vm.setMonth('February 2026');
      vm.setAmount('8,500');
      expect(vm.amount, 8500);
      expect(vm.month, 'February 2026');
    });
  });

  group('paying online', () {
    test('creates the link for the invoice', () async {
      backend.settings = const PaymentSettings(onlineEnabled: true);
      final vm = make();
      await vm.load();
      final url = await vm.startOnlinePayment();
      expect(url, 'https://rzp.io/test');
      expect(backend.calls, contains('createPaymentLink:I1'));
      expect(vm.stage, RentStage.awaitingOnline);
    });

    test('explains a failure and stays put', () async {
      backend.settings = const PaymentSettings(onlineEnabled: true);
      final vm = make();
      await vm.load();
      backend.failure = const TenantFailure('Owner payments are paused.');
      expect(await vm.startOnlinePayment(), isNull);
      expect(vm.error, 'Owner payments are paused.');
      expect(vm.stage, RentStage.choosing);
      expect(vm.busy, isFalse);
    });
  });

  group('paying by UPI', () {
    test('needs a transaction reference, shown only after trying', () async {
      final vm = make();
      await vm.load();
      vm.select(RentMethod.upi);
      expect(vm.referenceError, isNull);
      expect(await vm.submitManual(), isFalse);
      expect(vm.referenceError, 'Enter the UPI reference (UTR) from your payment app.');
      vm.setReference('12ab');
      expect(await vm.submitManual(), isFalse);
      expect(vm.referenceError, 'That reference looks too short.');
      expect(backend.lastRent, isNull);
    });

    test('submits for the owner to confirm', () async {
      final vm = make();
      await vm.load();
      vm.select(RentMethod.upi);
      vm.setReference(' 412345678901 ');
      expect(await vm.submitManual(), isTrue);
      final s = backend.lastRent!;
      expect(s.businessId, 'B1');
      expect(s.amount, 9000);
      expect(s.month, 'March 2026');
      expect(s.mode, 'UPI');
      expect(s.reference, '412345678901');
      expect(s.invoiceId, 'I1');
      expect(vm.stage, RentStage.submitted);
    });

    test('builds a UPI link with the amount when the owner has a UPI id', () async {
      backend.settings = const PaymentSettings(upiId: 'owner@upi');
      final vm = make();
      await vm.load();
      final uri = vm.upiIntent!;
      expect(uri.scheme, 'upi');
      expect(uri.queryParameters['pa'], 'owner@upi');
      expect(uri.queryParameters['am'], '9000.00');
      expect(uri.queryParameters['pn'], 'Green Nest');
    });

    test('no UPI link without a UPI id', () async {
      final vm = make();
      await vm.load();
      expect(vm.upiIntent, isNull);
    });
  });

  group('paying cash', () {
    test('needs no reference', () async {
      final vm = make(inv: null);
      await vm.load();
      vm.select(RentMethod.cash);
      expect(await vm.submitManual(), isTrue);
      expect(backend.lastRent!.mode, 'Cash');
      expect(backend.lastRent!.invoiceId, isNull);
    });

    test('a wrong amount is caught before sending', () async {
      final vm = make(inv: null);
      await vm.load();
      vm.select(RentMethod.cash);
      vm.setAmount('0');
      expect(await vm.submitManual(), isFalse);
      expect(vm.amountError, 'Enter the amount you paid.');
      expect(backend.calls, isNot(contains('submitRentPayment')));
    });

    test('a backend refusal is shown', () async {
      final vm = make();
      await vm.load();
      vm.select(RentMethod.cash);
      backend.failure = const TenantFailure('This invoice has already been paid.');
      expect(await vm.submitManual(), isFalse);
      expect(vm.error, 'This invoice has already been paid.');
      expect(vm.stage, RentStage.choosing);
    });
  });

  test('the call to action follows the method', () async {
    backend.settings = const PaymentSettings(onlineEnabled: true);
    final vm = make();
    await vm.load();
    expect(vm.actionLabel, 'Pay ₹9,000 online');
    vm.select(RentMethod.upi);
    expect(vm.actionLabel, "I've paid ₹9,000");
    vm.select(RentMethod.cash);
    expect(vm.actionLabel, 'I paid ₹9,000 in cash');
  });
}
