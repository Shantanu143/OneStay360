import 'package:provider/provider.dart';
import 'package:business/app/refresh_signals.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/requests/request_detail_actions.dart';
import 'package:business/presentation/requests/request_detail_screen.dart';
import 'package:business/presentation/requests/request_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/tenant/tenant_request_model.dart';

import '../../support/request_fakes.dart';

class FakeRequestActions implements RequestDetailActions {
  final calls = <String>[];
  Uri? opened;
  bool approvalResult = false;

  @override
  Future<void> call(BuildContext context, String phone) async => calls.add('call:$phone');

  @override
  Future<void> openUrl(BuildContext context, Uri uri) async {
    opened = uri;
    calls.add('url');
  }

  @override
  Future<void> copy(BuildContext context, String text, {String? message}) async =>
      calls.add('copy:$text');

  @override
  Future<bool> openApproval(BuildContext context, EnrollmentRequest request) async {
    calls.add('approve:${request.id}');
    return approvalResult;
  }
}

void main() {
  late RefreshSignals signals;
  setUp(() => signals = RefreshSignals());
  tearDown(() => signals.dispose());

  late FakeRequestSource source;
  late FakeRequestActions actions;
  Object? popped = 'unset';
  final now = DateTime(2026, 10, 26, 12);

  setUp(() {
    source = FakeRequestSource();
    actions = FakeRequestActions();
    popped = 'unset';
  });

  tearDown(() => source.controller.close());

  Future<void> push(WidgetTester tester, EnrollmentRequest? r) async {
    source.controller.add(r);
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester, {
    EnrollmentRequest? live,
    bool emit = true,
  }) async {
    tester.view.physicalSize = const Size(400, 2800);
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
                      builder: (_) => RequestDetailScreen(
                        propertyId: 'P1',
                        request: TenantRequest.fromFirestore('R1', requestDoc()),
                        source: source,
                        actions: actions,
                        clock: () => now,
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
    await tester.pump(const Duration(milliseconds: 400));
    if (emit) await push(tester, live ?? requestOf());
  }

  group('a pending request', () {
    testWidgets('shows who, what they want and what to do next', (tester) async {
      await open(tester);

      expect(find.text('Mohit Saxena'), findsOneWidget);
      expect(find.text('Sunrise Boys PG'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.textContaining('then approve it'), findsOneWidget);
      expect(find.text('+919000000501'), findsOneWidget);
      expect(find.text('mohit@example.test'), findsOneWidget);
      expect(find.text('2-sharing'), findsOneWidget);
      expect(find.text('2 Nov 2026'), findsOneWidget);
      expect(find.text('Joining Flipkart, need a quiet room.'), findsOneWidget);
      expect(find.text('First bill'), findsNothing);
    });

    testWidgets('shows what the list knew while the live copy is on its way', (tester) async {
      await open(tester, emit: false);

      expect(find.text('Mohit Saxena'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
    });

    testWidgets('can be called, messaged and copied', (tester) async {
      await open(tester);

      await tester.tap(find.text('Call'));
      await tester.tap(find.text('WhatsApp'));
      await tester.tap(find.byTooltip('Copy phone number'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['call:+919000000501', 'url', 'copy:+919000000501']);
      expect(actions.opened?.host, 'wa.me');
      expect(actions.opened?.path, '/919000000501');
    });

    testWidgets('Approve opens the approval form', (tester) async {
      await open(tester);

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['approve:R1']);
    });

    testWidgets('Reject asks first, then turns it down and goes back', (tester) async {
      await open(tester);

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      expect(find.text('Reject this request?'), findsOneWidget);

      await tester.tap(find.text('Reject').last);
      await tester.pumpAndSettle();

      expect(source.calls, ['reject:R1']);
      expect(popped, true);
    });

    testWidgets('rejecting a request tells the app the pipeline changed', (tester) async {
      await open(tester);

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reject').last);
      await tester.pumpAndSettle();

      expect(signals.tenants.value, 1);
      expect(signals.anyChanged.value, 1);
    });

    testWidgets('cancelling Reject changes nothing', (tester) async {
      await open(tester);

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(source.calls, isEmpty);
      expect(popped, 'unset');
    });

    testWidgets('a failed Reject says so and stays', (tester) async {
      source.failure = Exception('denied');
      await open(tester);

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reject').last);
      await tester.pumpAndSettle();

      expect(find.text("Couldn't update the request. Try again."), findsOneWidget);
      expect(popped, 'unset');
    });
  });

  group('after the bill is sent', () {
    testWidgets('shows the bill and waits for the tenant', (tester) async {
      await open(tester, live: requestOf(status: 'bill_sent', extra: billExtra));

      expect(find.text('Bill sent'), findsOneWidget);
      expect(find.textContaining('Waiting for the tenant'), findsOneWidget);
      expect(find.text('First bill'), findsOneWidget);
      expect(find.text('Room 302 · Bed 2'), findsOneWidget);
      expect(find.text('₹21,500'), findsOneWidget);
      expect(find.text('UPI · owner@upi'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Confirm payment'), findsNothing);
    });

    testWidgets('mentions why the last payment was turned down', (tester) async {
      await open(
        tester,
        live: requestOf(
          status: 'bill_sent',
          extra: {...billExtra, 'paymentRejectionReason': 'Amount short by ₹500'},
        ),
      );

      expect(find.textContaining('Amount short by ₹500'), findsOneWidget);
    });

    testWidgets('follows the request as it changes', (tester) async {
      await open(tester);
      expect(find.text('Approve'), findsOneWidget);

      await push(tester, requestOf(status: 'bill_sent', extra: billExtra));

      expect(find.text('Approve'), findsNothing);
      expect(find.text('First bill'), findsOneWidget);
    });
  });

  group('a payment to confirm', () {
    final submitted = requestOf(status: 'payment_submitted', extra: {
      ...billExtra,
      'transactionId': 'UTR982736451209',
      'paymentSubmittedAt': Timestamp.fromDate(DateTime(2026, 10, 26, 11)),
    });

    testWidgets('shows what the tenant says they paid', (tester) async {
      await open(tester, live: submitted);

      expect(find.text('Payment to confirm'), findsOneWidget);
      expect(find.text('UTR982736451209'), findsOneWidget);
      expect(find.text('Confirm payment'), findsOneWidget);
      expect(find.text('Reject payment'), findsOneWidget);
    });

    testWidgets('Confirm payment checks the amount first', (tester) async {
      await open(tester, live: submitted);

      await tester.tap(find.text('Confirm payment'));
      await tester.pumpAndSettle();
      expect(find.textContaining('₹21,500'), findsWidgets);
      expect(find.textContaining('UTR982736451209'), findsWidgets);

      await tester.tap(find.text('Yes, confirm'));
      await tester.pumpAndSettle();

      expect(source.calls, ['confirm:R1']);
    });

    testWidgets('confirming the payment tells the app money came in and a tenant is on the way', (tester) async {
      await open(tester, live: submitted);

      await tester.tap(find.text('Confirm payment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes, confirm'));
      await tester.pumpAndSettle();

      expect(signals.payments.value, 1);
      expect(signals.tenants.value, 1);
      expect(signals.properties.value, 1);
      expect(signals.anyChanged.value, 1);
    });

    testWidgets('rejecting the payment tells the app what is waiting changed', (tester) async {
      await open(tester, live: submitted);

      await tester.tap(find.text('Reject payment'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Short by ₹500');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      expect(signals.payments.value, 1);
      expect(signals.tenants.value, 0);
    });

    testWidgets('Reject payment needs a reason and sends it', (tester) async {
      await open(tester, live: submitted);

      await tester.tap(find.text('Reject payment'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Amount short by ₹500');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reject')); // the dialog's button (the bar's says "Reject payment")
      await tester.pumpAndSettle();

      expect(source.calls, ['rejectPayment:R1:Amount short by ₹500']);
    });
  });

  group('a request that could not be completed', () {
    final failed = requestOf(
      status: 'approval_failed',
      extra: {...billExtra, 'approvalError': 'Bed 2 is already occupied'},
    );

    testWidgets('says why and offers to try again', (tester) async {
      await open(tester, live: failed);

      expect(find.text("Couldn't add tenant"), findsOneWidget);
      expect(find.textContaining('Bed 2 is already occupied'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(source.calls, ['confirm:R1']);
    });
  });

  group('signals after a retry', () {
    testWidgets('trying again tells the app a tenant is on the way', (tester) async {
      final failed = requestOf(
        status: 'approval_failed',
        extra: {...billExtra, 'approvalError': 'Bed 2 is already occupied'},
      );
      await open(tester, live: failed);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(signals.tenants.value, 1);
      expect(signals.properties.value, 1);
    });
  });

  group('other states', () {
    testWidgets('a confirmed request is read-only', (tester) async {
      await open(tester, live: requestOf(status: 'confirmed', extra: billExtra));

      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.textContaining('has joined'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
    });

    testWidgets('says so when the request was deleted', (tester) async {
      await open(tester, emit: false);
      await push(tester, null);

      expect(find.text('This request no longer exists'), findsOneWidget);
    });

    testWidgets('a failed load can be retried', (tester) async {
      await open(tester, emit: false);
      source.controller.addError(Exception('denied'));
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't load this request."), findsOneWidget);
      expect(find.text('Mohit Saxena'), findsOneWidget, reason: 'the last known details stay');

      await tester.tap(find.textContaining("Couldn't load this request."));
      await tester.pump();
      expect(source.watches, 2);
    });
  });
}
