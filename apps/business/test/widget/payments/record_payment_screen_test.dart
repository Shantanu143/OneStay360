import 'package:provider/provider.dart';
import 'package:business/app/refresh_signals.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/payments/record_payment_screen.dart';
import 'package:business/presentation/payments/record_payment_viewmodel.dart';
import 'package:flutter/material.dart';
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
    recorded.add({'tenantId': tenantId, 'amount': amount, 'month': month, 'mode': mode, 'txn': transactionId});
  }
}

void main() {
  late RefreshSignals signals;
  setUp(() => signals = RefreshSignals());
  tearDown(() => signals.dispose());

  late FakeRecorder recorder;
  Object? popped = 'unset';

  setUp(() {
    recorder = FakeRecorder();
    popped = 'unset';
  });

  Future<void> open(WidgetTester tester, {Map<String, dynamic>? tenant}) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<RefreshSignals>.value(
        value: signals,
        child: MaterialApp(
        theme: BizTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => RecordPaymentScreen(
                      tenant: tenant ??
                          {
                            'tenantId': 'TEN1',
                            'name': 'Rohan Mehta',
                            'room': '101',
                            'bed': '1',
                            'rent': 9500,
                          },
                      businessId: 'BUS1',
                      recorder: recorder,
                      now: () => DateTime(2026, 10, 26),
                    ),
                  ),
                );
              },
              child: const Text('launch'),
            ),
          ),
        ),
      ),
      ),
    );
    await tester.tap(find.text('launch'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts with the tenant, the rent and this month', (tester) async {
    await open(tester);

    expect(find.text('Rohan Mehta'), findsOneWidget);
    expect(find.text('Room 101 · Bed 1 · rent ₹9,500'), findsOneWidget);
    expect(tester.widget<TextFormField>(find.byKey(const Key('amount'))).controller!.text, '9500');
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Record ₹9,500'), findsOneWidget);
  });

  testWidgets('records what was typed and goes back', (tester) async {
    await open(tester);

    await tester.enterText(find.byKey(const Key('amount')), '7000');
    await tester.tap(find.text('UPI'));
    await tester.enterText(find.byKey(const Key('txn')), 'UTR55');
    await tester.pumpAndSettle();
    expect(find.text('Record ₹7,000'), findsOneWidget);

    await tester.tap(find.text('Record ₹7,000'));
    await tester.pumpAndSettle();

    expect(recorder.recorded.single, {
      'tenantId': 'TEN1',
      'amount': 7000.0,
      'month': 'October 2026',
      'mode': 'UPI',
      'txn': 'UTR55',
    });
    expect(popped, true);
  });

  testWidgets('tells the rest of the app that money came in', (tester) async {
    await open(tester);

    await tester.tap(find.text('Record ₹9,500'));
    await tester.pumpAndSettle();

    expect(signals.payments.value, 1);
    expect(signals.anyChanged.value, 1);
  });

  testWidgets('says nothing when the save fails', (tester) async {
    recorder.failure = Exception('denied');
    await open(tester);

    await tester.tap(find.text('Record ₹9,500'));
    await tester.pumpAndSettle();

    expect(signals.anyChanged.value, 0);
  });

  testWidgets('the month can be changed', (tester) async {
    await open(tester);

    await tester.tap(find.text('October 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('September 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Record ₹'));
    await tester.pumpAndSettle();

    expect(recorder.recorded.single['month'], 'September 2026');
  });

  testWidgets('an empty amount is refused with a reason', (tester) async {
    await open(tester, tenant: {'tenantId': 'TEN1', 'name': 'Rohan Mehta'});

    await tester.tap(find.text('Record payment').last); // the button, under the header's label
    await tester.pumpAndSettle();

    expect(find.text('Enter the amount received.'), findsOneWidget);
    expect(recorder.recorded, isEmpty);
    expect(popped, 'unset');
  });

  testWidgets('a failed save stays open and says so', (tester) async {
    recorder.failure = Exception('boom');
    await open(tester);

    await tester.tap(find.textContaining('Record ₹'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't record the payment. Try again."), findsOneWidget);
    expect(popped, 'unset');
  });
}
