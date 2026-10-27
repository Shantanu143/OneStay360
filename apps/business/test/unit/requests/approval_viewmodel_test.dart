import 'package:business/presentation/requests/approval_viewmodel.dart';
import 'package:business/presentation/requests/request_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/approval_fakes.dart';
import '../../support/request_fakes.dart';

void main() {
  late FakeApprovalSource source;
  late ApprovalViewModel vm;
  final request = requestOf(); // wants 2-sharing, moving in 2 Nov 2026

  Future<void> start({EnrollmentRequest? r, FakeApprovalSource? src}) async {
    source = src ?? FakeApprovalSource(approvalContext());
    vm = ApprovalViewModel(request: r ?? request, source: source, today: () => DateTime(2026, 10, 26));
    await vm.load();
  }

  tearDown(() => vm.dispose());

  group('loading', () {
    test('fills in the property defaults', () async {
      await start();

      expect(vm.loading, isFalse);
      expect(vm.error, isNull);
      expect(vm.deposit, 13000);
      expect(vm.maintenance, 500);
      expect(vm.maintenanceFromDeposit, isTrue);
      expect(vm.moveIn, DateTime(2026, 11, 2));
      expect(vm.foodIncluded, isTrue);
      expect(vm.depositNow, isTrue);
      expect(vm.billingDate, 1);
    });

    test('moves in today when the request names no date', () async {
      await start(r: EnrollmentRequest.fromMap('R1', {...requestDoc()..remove('moveInDate')}));

      expect(vm.moveIn, DateTime(2026, 10, 26));
    });

    test('reports a failed load and can retry', () async {
      final src = FakeApprovalSource(approvalContext())..loadFailure = Exception('denied');
      await start(src: src);

      expect(vm.error, "Couldn't load the rooms. Check your connection and try again.");

      src.loadFailure = null;
      await vm.load();
      expect(vm.error, isNull);
      expect(vm.floors, isNotEmpty);
    });

    test('preselects the preferred payment method', () async {
      await start();

      expect(vm.selectedMethodId, 'm1');
    });
  });

  group('choosing a bed', () {
    setUp(() async => start());

    test('only free beds can be taken', () async {
      vm.selectBed('102', '1'); // 102 is full
      expect(vm.selectedBed, isNull);

      vm.selectBed('101', '1'); // taken
      expect(vm.selectedBed, isNull);

      vm.selectBed('101', '2');
      expect(vm.selectedRoom?.number, '101');
      expect(vm.selectedBed, '2');
    });

    test('sets the rent from the room price', () async {
      vm.selectBed('101', '2');
      expect(vm.rent, 6500);

      vm.selectBed('201', '1'); // AC double
      expect(vm.rent, 8000);
    });

    test('keeps a rent the owner typed', () async {
      vm.selectBed('101', '2');
      vm.setRent(7000);

      vm.selectBed('201', '1');

      expect(vm.rent, 7000);
    });

    test('flags the rooms that match what the tenant asked for', () async {
      final matching = vm.floors.expand((f) => f.rooms).where(vm.matchesRequest).map((r) => r.number);

      expect(matching, ['101', '201'], reason: 'both doubles; the triple does not match');
    });

    test('lists rooms with a free bed first', () async {
      expect(vm.floors.expand((f) => f.rooms).where((r) => r.freeBeds > 0).map((r) => r.number),
          containsAll(['101', '201']));
    });
  });

  group('the first bill', () {
    setUp(() async {
      await start();
      vm.selectBed('101', '2'); // rent 6500
    });

    test('is a full month for a move-in on the 1st-15th', () {
      vm.setMoveIn(DateTime(2026, 11, 10));

      expect(vm.bill.proratedRent, 6500);
      expect(vm.bill.total, 6500 + 13000);
    });

    test('is half a month from the 16th', () {
      vm.setMoveIn(DateTime(2026, 11, 20));

      expect(vm.bill.proratedRent, 3250);
    });

    test('takes the food deduction off when food is not included', () {
      vm.setFoodIncluded(false);
      vm.setFoodDeduction(1500);
      vm.setMoveIn(DateTime(2026, 11, 1));

      expect(vm.bill.proratedRent, 5000);
    });

    test('leaves the deposit out when it is paid later', () {
      vm.setMoveIn(DateTime(2026, 11, 1));
      vm.setDepositNow(false);

      expect(vm.bill.total, 6500);
    });

    test('lets the owner override the prorated rent', () {
      vm.setProratedOverride(4000);

      expect(vm.bill.proratedRent, 4000);
      vm.setProratedOverride(null);
      expect(vm.bill.proratedRent, isNot(4000));
    });
  });

  group('approving', () {
    setUp(() async => start());

    test('needs a bed', () async {
      expect(await vm.approve(), isFalse);
      expect(vm.error, 'Choose a room and bed first.');
      expect(source.approvals, isEmpty);
    });

    test('assigns the bed and records the bill', () async {
      vm.selectBed('101', '2');
      vm.setMoveIn(DateTime(2026, 11, 2));

      expect(await vm.approve(), isTrue);

      final a = source.approvals.single;
      expect(a.id, 'R1');
      expect(a.s.roomNumber, '101');
      expect(a.s.bedNumber, '2');
      expect(a.s.monthlyRent, 6500);
      expect(a.s.proratedRent, 6500);
      expect(a.s.deposit, 13000);
      expect(a.s.maintenance, 500);
      expect(a.s.total, 19500);
      expect(a.s.billingDate, 1);
      expect(a.s.moveIn, DateTime(2026, 11, 2));
      expect(vm.submitting, isFalse);
    });

    test('says what went wrong and stays open', () async {
      vm.selectBed('101', '2');
      source.submitFailure = Exception('denied');

      expect(await vm.approve(), isFalse);
      expect(vm.error, "Couldn't approve this request. Try again.");
      expect(vm.submitting, isFalse);
    });
  });

  group('sending the bill', () {
    setUp(() async {
      await start();
      vm.selectBed('101', '2');
    });

    test('goes out with the chosen UPI method', () async {
      expect(await vm.sendBill(), isTrue);

      final b = source.bills.single;
      expect(b.p.mode, 'upi_manual');
      expect(b.p.info, {'ownerUpiId': 'owner@upi', 'paymentMethodId': 'm1'});
      expect(b.s.total, 19500);
    });

    test('carries bank details for a bank method', () async {
      source.context = approvalContext(methods: [bankMethod()]);
      await vm.load();
      vm.selectBed('101', '2');
      vm.selectMethod('m2');

      await vm.sendBill();

      final p = source.bills.single.p;
      expect(p.mode, 'bank_transfer');
      expect(p.info['bankName'], 'HDFC');
      expect(p.info['accountNumber'], '1234567890');
      expect(p.info['ifscCode'], 'HDFC0001234');
      expect(p.info['accountHolderName'], 'Rajesh Sharma');
    });

    test('is cash when the method is cash', () async {
      source.context = approvalContext(methods: [cashMethod()]);
      await vm.load();
      vm.selectBed('101', '2');

      await vm.sendBill();

      expect(source.bills.single.p.mode, 'cash');
    });

    test('asks for a UPI id when no payment method is set up', () async {
      source.context = approvalContext(methods: []);
      await vm.load();
      vm.selectBed('101', '2');

      expect(await vm.sendBill(), isFalse);
      expect(vm.error, 'Enter your UPI ID, or add a payment method in Settings.');

      vm.setUpiId('me@upi');
      expect(await vm.sendBill(), isTrue);
      expect(source.bills.single.p.info, {'ownerUpiId': 'me@upi'});
      expect(source.bills.single.upi, 'me@upi', reason: 'saved on the business for next time');
    });

    test('uses the UPI id saved on the business when there are no methods', () async {
      source.context = approvalContext(methods: [], businessUpiId: 'saved@upi');
      await vm.load();
      vm.selectBed('101', '2');

      expect(vm.upiId, 'saved@upi');
      expect(await vm.sendBill(), isTrue);
    });

    test('refuses a bill with nothing to pay', () async {
      vm.setRent(0);
      vm.setDepositNow(false);

      expect(await vm.sendBill(), isFalse);
      expect(vm.error, 'The first bill must be more than ₹0.');
      expect(source.bills, isEmpty);
    });

    test('needs a bed too', () async {
      vm.selectBed('101', '2');
      vm.clearBed();

      expect(await vm.sendBill(), isFalse);
      expect(vm.error, 'Choose a room and bed first.');
    });

    test('says what went wrong and stays open', () async {
      source.submitFailure = Exception('denied');

      expect(await vm.sendBill(), isFalse);
      expect(vm.error, "Couldn't send the bill. Try again.");
    });

    test('ignores a second tap while sending', () async {
      final first = vm.sendBill();
      final second = vm.sendBill();

      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(source.bills, hasLength(1));
    });
  });
}
