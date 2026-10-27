import 'package:provider/provider.dart';
import 'package:business/app/refresh_signals.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/requests/approval_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/approval_fakes.dart';
import '../../support/request_fakes.dart';

void main() {
  late RefreshSignals signals;
  setUp(() => signals = RefreshSignals());
  tearDown(() => signals.dispose());

  late FakeApprovalSource source;
  Object? popped = 'unset';

  setUp(() {
    source = FakeApprovalSource(approvalContext());
    popped = 'unset';
  });

  Future<void> open(WidgetTester tester, {bool settle = true}) async {
    tester.view.physicalSize = const Size(400, 4200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<RefreshSignals>.value(
        value: signals,
        child: MaterialApp(
        theme: BizTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => ApprovalScreen(
                        request: requestOf(),
                        source: source,
                        today: () => DateTime(2026, 10, 26),
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
      ),
    );
    await tester.tap(find.text('launch'));
    await tester.pump();
    if (settle) {
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }
  }

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

  Finder bed(String room, String label) => find.descendant(
        of: find.ancestor(of: find.text('Room $room'), matching: find.byType(Container)).first,
        matching: find.text(label),
      );

  testWidgets('shows what was asked for and the beds that are free', (tester) async {
    await open(tester);

    expect(find.text('Mohit Saxena asked for 2-sharing · from 2 Nov 2026.'), findsOneWidget);
    expect(find.text('Room 101'), findsOneWidget);
    expect(find.text('Room 201'), findsOneWidget);
    expect(find.text('Room 102'), findsNothing, reason: 'every bed in 102 is taken');
    expect(find.text('Requested'), findsNWidgets(2), reason: 'the two doubles');
  });

  testWidgets('starts with the property deposit and maintenance', (tester) async {
    await open(tester);

    expect(fieldText(tester, 'deposit'), '13000');
    expect(fieldText(tester, 'maintenance'), '500');
  });

  testWidgets('choosing a bed fills in the rent and the bill', (tester) async {
    await open(tester);

    await tester.tap(bed('101', 'B2'));
    await tester.pumpAndSettle();

    expect(fieldText(tester, 'rent'), '6500');
    expect(find.text('Send bill · ₹19,500'), findsOneWidget);
    expect(find.text('Total due now'), findsOneWidget);
  });

  testWidgets('the first bill follows what is typed', (tester) async {
    await open(tester);
    await tester.tap(bed('101', 'B2'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('rent')), '7000');
    await tester.pumpAndSettle();

    expect(find.text('Send bill · ₹20,000'), findsOneWidget);

    await tester.tap(find.text('Collect deposit now'));
    await tester.pumpAndSettle();
    expect(find.text('Send bill · ₹7,000'), findsOneWidget);
  });

  testWidgets('turning food off asks how much to take off', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('food-deduction')), findsNothing);

    await tester.tap(find.text('Food included'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food-deduction')), findsOneWidget);
  });

  testWidgets('sending without a bed says so', (tester) async {
    await open(tester);

    await tester.tap(find.textContaining('Send bill'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a room and bed first.'), findsOneWidget);
    expect(source.bills, isEmpty);
  });

  testWidgets('Send bill goes out with the chosen method and closes', (tester) async {
    await open(tester);
    await tester.tap(bed('101', 'B2'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Send bill'));
    await tester.pumpAndSettle();

    expect(source.bills.single.id, 'R1');
    expect(source.bills.single.s.roomNumber, '101');
    expect(source.bills.single.p.mode, 'upi_manual');
    expect(popped, true);
  });

  testWidgets('"I\'ll collect payment myself" approves without a bill', (tester) async {
    await open(tester);
    await tester.tap(bed('201', 'B1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Approve, I'll collect payment myself"));
    await tester.pumpAndSettle();

    expect(source.approvals.single.s.roomNumber, '201');
    expect(source.approvals.single.s.monthlyRent, 8000, reason: 'AC double');
    expect(source.bills, isEmpty);
    expect(popped, true);
  });

  testWidgets('sending a bill tells the app a bed is held and a request moved on', (tester) async {
    await open(tester);
    await tester.tap(bed('101', 'B2'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Send bill'));
    await tester.pumpAndSettle();

    expect(signals.tenants.value, 1);
    expect(signals.properties.value, 1);
    expect(signals.anyChanged.value, 1);
  });

  testWidgets('approving without a bill tells the app a tenant is on the way', (tester) async {
    await open(tester);
    await tester.tap(bed('201', 'B1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Approve, I'll collect payment myself"));
    await tester.pumpAndSettle();

    expect(signals.tenants.value, 1);
    expect(signals.properties.value, 1);
  });

  testWidgets('a failed send changes nothing', (tester) async {
    source.submitFailure = Exception('denied');
    await open(tester);
    await tester.tap(bed('101', 'B2'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Send bill'));
    await tester.pumpAndSettle();

    expect(signals.anyChanged.value, 0);
  });

  testWidgets('a failed send stays open with the reason', (tester) async {
    source.submitFailure = Exception('denied');
    await open(tester);
    await tester.tap(bed('101', 'B2'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Send bill'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't send the bill. Try again."), findsOneWidget);
    expect(popped, 'unset');
  });

  group('how the tenant pays', () {
    testWidgets('lists the owner\'s methods and uses the one picked', (tester) async {
      source.context = approvalContext(methods: [upiMethod(preferred: true), bankMethod()]);
      await open(tester);

      expect(find.text('UPI · owner@upi'), findsOneWidget);
      expect(find.text('HDFC · •••• 7890'), findsOneWidget);

      await tester.tap(find.text('HDFC · •••• 7890'));
      await tester.pumpAndSettle();
      await tester.tap(bed('101', 'B2'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Send bill'));
      await tester.pumpAndSettle();

      expect(source.bills.single.p.mode, 'bank_transfer');
    });

    testWidgets('asks for a UPI id when there are no methods', (tester) async {
      source.context = approvalContext(methods: []);
      await open(tester);
      await tester.tap(bed('101', 'B2'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Send bill'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your UPI ID, or add a payment method in Settings.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('upi')), 'me@upi');
      await tester.tap(find.textContaining('Send bill'));
      await tester.pumpAndSettle();

      expect(source.bills.single.p.info, {'ownerUpiId': 'me@upi'});
    });
  });

  testWidgets('a failed load can be retried', (tester) async {
    source.loadFailure = Exception('denied');
    await open(tester);

    expect(find.text("Couldn't load the rooms. Check your connection and try again."), findsOneWidget);

    source.loadFailure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Room 101'), findsOneWidget);
  });

  testWidgets('says so when no bed is free', (tester) async {
    source.context = approvalContext();
    // Everything taken.
    source.context = ApprovalContextAllFull.of(source.context);
    await open(tester);

    expect(find.text('No free beds'), findsOneWidget);
  });
}
