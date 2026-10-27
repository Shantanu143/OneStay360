import 'package:provider/provider.dart';
import 'package:business/app/refresh_signals.dart';
import 'package:business/presentation/design/components/biz_chips.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/payments/pending_payments_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/payment_fakes.dart';
import '../../support/request_fakes.dart';

class FakePendingActions implements PendingPaymentsActions {
  final calls = <String>[];

  @override
  Future<void> copy(BuildContext context, String text, {String? message}) async => calls.add('copy:$text');

  @override
  Future<void> openUrl(BuildContext context, Uri uri) async => calls.add('url:$uri');
}

void main() {
  late RefreshSignals signals;
  setUp(() => signals = RefreshSignals());
  tearDown(() => signals.dispose());

  late FakePendingSource source;
  late FakeRequestSource requests;
  late FakePendingActions actions;
  final now = DateTime(2026, 10, 26, 12);

  setUp(() {
    source = FakePendingSource()
      ..rent = [
        rentPayment('p1', at: DateTime(2026, 10, 26, 9)),
        rentPayment('p2', tenantId: 'T2', name: 'Arjun Reddy', method: 'Cash', txn: null, at: DateTime(2026, 10, 25)),
      ];
    requests = FakeRequestSource();
    actions = FakePendingActions();
  });

  tearDown(() {
    source.deposits$.close();
    requests.controller.close();
  });

  Future<void> open(WidgetTester tester, {String? propertyId, bool deposits = true}) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<RefreshSignals>.value(
        value: signals,
        child: MaterialApp(
        theme: BizTheme.light(),
        home: PendingPaymentsScreen(
          businessId: 'BUS1',
          propertyId: propertyId,
          source: source,
          requestSource: requests,
          actions: actions,
          clock: () => now,
        ),
      ),
      ),
    );
    await tester.pump();
    if (deposits) source.deposits$.add([depositRequest('d1')]);
    await tester.pumpAndSettle();
  }

  Future<void> goTo(WidgetTester tester, String tab) async {
    await tester.tap(find.descendant(of: find.byType(BizFilterChips), matching: find.text(tab)));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the rent payments to check, newest first', (tester) async {
    await open(tester);

    expect(find.text('Rohan Mehta'), findsOneWidget);
    expect(find.text('Arjun Reddy'), findsOneWidget);
    expect(find.text('Room 101 · Bed 1 · October 2026'), findsNWidgets(2));
    expect(find.text('₹9,500'), findsNWidgets(2));
    expect(find.text('UTR123456789'), findsOneWidget);
    expect(find.text('3 to confirm'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Rohan Mehta')).dy,
      lessThan(tester.getTopLeft(find.text('Arjun Reddy')).dy),
    );
  });

  testWidgets('counts each tab', (tester) async {
    await open(tester);

    final chips = tester.widget<BizFilterChips>(find.byType(BizFilterChips)).chips;
    expect(chips.map((c) => '${c.label} ${c.count}'), ['Rent 2', 'Deposits 1']);
  });

  testWidgets('Confirm checks first, then verifies and removes the payment', (tester) async {
    await open(tester);

    await tester.tap(find.text('Confirm').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Have you received ₹9,500'), findsOneWidget);

    await tester.tap(find.text('Yes, confirm'));
    await tester.pumpAndSettle();

    expect(source.verified.single.paymentId, 'p1');
    expect(source.verified.single.confirm, isTrue);
    expect(find.text('Rohan Mehta'), findsNothing);
    expect(find.text('2 to confirm'), findsOneWidget);
  });

  testWidgets('confirming rent tells the rest of the app that money came in', (tester) async {
    await open(tester);

    await tester.tap(find.text('Confirm').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, confirm'));
    await tester.pumpAndSettle();

    expect(signals.payments.value, 1);
    expect(signals.tenants.value, 0, reason: 'rent does not add a tenant');
    expect(signals.anyChanged.value, 1);
  });

  testWidgets('confirming a deposit also adds a tenant and fills a bed', (tester) async {
    await open(tester);
    await goTo(tester, 'Deposits');

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, confirm'));
    await tester.pumpAndSettle();

    expect(signals.payments.value, 1);
    expect(signals.tenants.value, 1);
    expect(signals.properties.value, 1);
    expect(signals.anyChanged.value, 1);
  });

  testWidgets('rejecting a payment changes what is waiting', (tester) async {
    await open(tester);

    await tester.tap(find.text('Reject').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Short by ₹500');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject').last);
    await tester.pumpAndSettle();

    expect(signals.payments.value, 1);
    expect(signals.tenants.value, 0);
  });

  testWidgets('a failed confirm says nothing changed', (tester) async {
    source.verifyFailure = Exception('denied');
    await open(tester);

    await tester.tap(find.text('Confirm').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, confirm'));
    await tester.pumpAndSettle();

    expect(signals.anyChanged.value, 0);
  });

  testWidgets('Reject needs a reason', (tester) async {
    await open(tester);

    await tester.tap(find.text('Reject').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Amount short by ₹500');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject').last); // the dialog's button, over the card's
    await tester.pumpAndSettle();

    expect(source.verified.single.confirm, isFalse);
    expect(source.verified.single.reason, 'Amount short by ₹500');
  });

  testWidgets('a failure keeps the payment and says so', (tester) async {
    source.verifyFailure = Exception('denied');
    await open(tester);

    await tester.tap(find.text('Confirm').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, confirm'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't update that payment. Try again."), findsOneWidget);
    expect(find.text('Rohan Mehta'), findsOneWidget);
  });

  testWidgets('the transaction id can be copied', (tester) async {
    await open(tester);

    await tester.tap(find.byTooltip('Copy transaction ID'));
    await tester.pumpAndSettle();

    expect(actions.calls, ['copy:UTR123456789']);
  });

  testWidgets('deposits are confirmed through their request', (tester) async {
    await open(tester);
    await goTo(tester, 'Deposits');

    expect(find.text('Devansh Trivedi'), findsOneWidget);
    expect(find.text('Room B2 · Bed 2 · First bill'), findsOneWidget);
    expect(find.text('₹17,500'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, confirm'));
    await tester.pumpAndSettle();

    expect(requests.calls, ['confirm:d1']);
  });

  testWidgets('says so when nothing is waiting', (tester) async {
    source.rent = const [];
    await open(tester, deposits: false);
    source.deposits$.add(const []);
    await tester.pumpAndSettle();

    expect(find.text('Nothing to confirm'), findsOneWidget);
    expect(find.text('All confirmed'), findsOneWidget);
  });

  testWidgets('a failed rent load can be retried', (tester) async {
    source.rentFailure = Exception('denied');
    await open(tester);

    expect(find.text("Couldn't load rent payments."), findsOneWidget);

    source.rentFailure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Rohan Mehta'), findsOneWidget);
    expect(source.rentLoads, 2);
  });

  testWidgets('limits itself to one property', (tester) async {
    await open(tester, propertyId: 'P7');

    expect(source.lastPropertyId, 'P7');
  });
}
