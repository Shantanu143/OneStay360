import 'package:business/presentation/payments/record_payment_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRecorder implements PaymentRecorder {
  final recorded = <Map<String, Object?>>[];
  Object? failure;

  @override
  Future<void> record({
    required String businessId,
    required String tenantId,
    required double amount,
    required String month,
    required String mode,
    String? transactionId,
    String? note,
  }) async {
    if (failure != null) throw failure!;
    recorded.add({
      'businessId': businessId,
      'tenantId': tenantId,
      'amount': amount,
      'month': month,
      'mode': mode,
      'transactionId': transactionId,
      'note': note,
    });
  }
}

void main() {
  late FakeRecorder recorder;
  late RecordPaymentViewModel vm;

  setUp(() {
    recorder = FakeRecorder();
    vm = RecordPaymentViewModel(
      businessId: 'BUS1',
      tenantId: 'TEN1',
      suggestedAmount: 9500,
      recorder: recorder,
      now: () => DateTime(2026, 10, 26),
    );
  });

  tearDown(() => vm.dispose());

  test('offers this month and the five before, newest first', () {
    expect(vm.months, [
      'October 2026',
      'September 2026',
      'August 2026',
      'July 2026',
      'June 2026',
      'May 2026',
    ]);
    expect(vm.month, 'October 2026');
  });

  test('wraps the months over a new year', () {
    final jan = RecordPaymentViewModel(
      businessId: 'B',
      tenantId: 'T',
      recorder: recorder,
      now: () => DateTime(2027, 1, 5),
    );
    expect(jan.months.take(3), ['January 2027', 'December 2026', 'November 2026']);
    jan.dispose();
  });

  test('starts with the rent as the amount and cash as the mode', () {
    expect(vm.amount, 9500);
    expect(vm.mode, 'Cash');
  });

  group('recording', () {
    test('sends what was entered', () async {
      vm
        ..setAmount(7000)
        ..selectMonth('September 2026')
        ..selectMode('UPI')
        ..setTransactionId('  UTR123  ')
        ..setNote('  part payment ');

      expect(await vm.submit(), isTrue);

      expect(recorder.recorded.single, {
        'businessId': 'BUS1',
        'tenantId': 'TEN1',
        'amount': 7000.0,
        'month': 'September 2026',
        'mode': 'UPI',
        'transactionId': 'UTR123',
        'note': 'part payment',
      });
      expect(vm.submitting, isFalse);
    });

    test('leaves out a blank transaction id and note', () async {
      await vm.submit();

      expect(recorder.recorded.single['transactionId'], isNull);
      expect(recorder.recorded.single['note'], isNull);
    });

    test('needs an amount above zero', () async {
      vm.setAmount(0);

      expect(await vm.submit(), isFalse);
      expect(vm.error, 'Enter the amount received.');
      expect(recorder.recorded, isEmpty);
    });

    test('ignores a month or mode it was not offered', () {
      vm.selectMonth('Smarch 1999');
      vm.selectMode('Barter');

      expect(vm.month, 'October 2026');
      expect(vm.mode, 'Cash');
    });

    test('says why a failure happened and can try again', () async {
      recorder.failure = Exception('boom');

      expect(await vm.submit(), isFalse);
      expect(vm.error, "Couldn't record the payment. Try again.");
      expect(vm.submitting, isFalse);

      recorder.failure = null;
      expect(await vm.submit(), isTrue);
      expect(vm.error, isNull);
    });

    test('a second tap while sending is ignored', () async {
      final first = vm.submit();
      final second = vm.submit();

      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(recorder.recorded, hasLength(1));
    });
  });
}
