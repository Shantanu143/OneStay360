// End-to-end journeys through the real app on the in-memory backend: every
// tap a tenant makes, down to what reaches the backend.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenant/data/models.dart';
import 'package:tenant/data/sources.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

void main() {
  FakeBackend tenantWithStay() {
    final now = DateTime.now();
    return FakeBackend()
      ..account.set(testAccount())
      ..stay.set(testStay)
      ..unread.set(1)
      ..property.set(const PropertyContact(address: 'MG Road', city: 'Pune', phone: '9811100001'))
      ..invoices.set([
        RentInvoice(
          id: 'I1',
          status: InvoiceStatus.unpaid,
          amount: 9000,
          month: 'March 2026',
          periodMonth: '2026-03',
          dueDate: now.add(const Duration(days: 2)),
        ),
      ])
      ..payments.set(const [])
      ..requests.set(const [])
      ..maintenance.set(const [])
      ..pins.set(const [])
      ..notifications.set([
        TenantNotification(id: 'n1', type: 'tenant_invitation', title: 'New PG Invitation', invitationId: 'INV1', createdAt: now),
      ])
      ..invitation = const PendingInvitation(
        id: 'INV1',
        businessId: 'B9',
        propertyId: 'P9',
        propertyName: 'Sunrise Residency',
        roomNumber: '12',
        bedNumber: '3',
        monthlyRent: 7500,
      );
  }

  FakeBackend newcomer() {
    return FakeBackend()
      ..account.set(testAccount(tenantId: null))
      ..requests.set(const [])
      ..maintenance.set(const [])
      ..pages['Bangalore'] = [
        PropertyPage([testProperty(id: 'BUS0000001PNR001', name: 'Lotus Girls PG')]),
      ]
      ..properties['BUS0000001PNR001'] = testProperty(id: 'BUS0000001PNR001', name: 'Lotus Girls PG');
  }

  Future<Harness> start(WidgetTester tester, FakeBackend backend) async {
    useTallPhone(tester);
    final h = Harness(backend);
    await h.pump(tester);
    return h;
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await Harness.settle(tester);
  }

  testWidgets('a newcomer finds a PG and asks to join', (tester) async {
    final b = newcomer();
    await start(tester, b);
    expect(find.text('Find your next home'), findsOneWidget);

    await tap(tester, find.text('Explore PGs'));
    expect(find.text('Lotus Girls PG'), findsOneWidget);

    await tap(tester, find.text('Lotus Girls PG'));
    await tap(tester, find.text('Request to join'));
    expect(find.text('Send request'), findsOneWidget);

    // Sending without a date asks for one.
    await tap(tester, find.text('Send request'));
    expect(find.text('Pick a move-in date.'), findsOneWidget);
    expect(b.lastEnrollment, isNull);

    await tap(tester, find.text('Choose a date'));
    await tap(tester, find.text('OK'));
    await tap(tester, find.text('Double'));
    await tap(tester, find.text('Send request'));

    final d = b.lastEnrollment!;
    expect(d.propertyId, 'BUS0000001PNR001');
    expect(d.name, 'Asha Rao');
    expect(d.phone, '+919811100001');
    expect(d.sharing, 'Double');
    expect(find.text('The owner has your request'), findsOneWidget);

    // The request shows up on Home once the backend has it.
    b.requests.set([
      EnrollmentRequest(id: 'E-new', stage: EnrollmentStage.pending, propertyName: 'Lotus Girls PG', propertyId: 'BUS0000001PNR001', createdAt: DateTime.now()),
    ]);
    await tap(tester, find.text('Track on Home'));
    expect(find.text('Your request'), findsOneWidget);
    expect(find.text('Waiting for owner'), findsOneWidget);
  });

  testWidgets('paying the first bill by UPI', (tester) async {
    final bill = EnrollmentRequest(
      id: 'E1',
      stage: EnrollmentStage.billSent,
      propertyName: 'Lotus Girls PG',
      createdAt: DateTime.now(),
      lines: const [BillLine('Security deposit', 17000)],
      total: 17000,
      paymentMode: BillPaymentMode.upi,
      ownerUpiId: 'lotus@upi',
    );
    final b = newcomer()
      ..requests.set([bill])
      ..request.set(bill);
    final h = await start(tester, b);

    await tap(tester, find.text('Review & pay ₹17,000'));
    expect(find.text('lotus@upi'), findsOneWidget);

    await tap(tester, find.text('Open UPI app'));
    expect(h.device.opened.single.scheme, 'upi');
    expect(h.device.opened.single.queryParameters['am'], '17000.00');

    await tap(tester, find.text("I've paid ₹17,000"));
    expect(find.text('Enter the UPI reference (UTR) from your payment app.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('bill-reference')), '412345678901');
    await tap(tester, find.text("I've paid ₹17,000"));
    expect(b.calls, contains('submitBillPayment:E1'));
    expect(b.lastBillReference, '412345678901');
  });

  testWidgets('paying rent by UPI from Home', (tester) async {
    final b = tenantWithStay()..settings = const PaymentSettings(upiId: 'owner@upi');
    await start(tester, b);

    expect(find.text('₹9,000'), findsWidgets);
    await tap(tester, find.text('Pay rent'));
    expect(find.text('UPI to owner'), findsOneWidget);
    expect(find.text('Pay online'), findsNothing, reason: 'owner has no online payments');

    await tester.enterText(find.byKey(const Key('rent-reference')), 'UTR998877');
    await tap(tester, find.text("I've paid ₹9,000"));

    expect(b.lastRent!.mode, 'UPI');
    expect(b.lastRent!.invoiceId, 'I1');
    expect(b.lastRent!.reference, 'UTR998877');
    expect(find.text('Sent to your owner'), findsOneWidget);
  });

  testWidgets('paying rent online opens the payment link', (tester) async {
    final b = tenantWithStay()..settings = const PaymentSettings(onlineEnabled: true);
    final h = await start(tester, b);

    await tap(tester, find.text('Pay rent'));
    await tap(tester, find.text('Pay ₹9,000 online'));

    expect(b.calls, contains('createPaymentLink:I1'));
    expect(h.device.opened.single.toString(), 'https://rzp.io/test');

    // The webhook marks it paid; the screen notices.
    b.invoices.set(const [
      RentInvoice(id: 'I1', status: InvoiceStatus.paid, amount: 9000, month: 'March 2026', periodMonth: '2026-03'),
    ]);
    await Harness.settle(tester);
    expect(find.text('Rent paid'), findsOneWidget);
  });

  testWidgets('raising a maintenance request', (tester) async {
    final b = tenantWithStay();
    await start(tester, b);

    await tap(tester, find.text('Get help'));
    expect(find.text('New request'), findsWidgets);

    await tap(tester, find.text('Plumbing'));
    await tap(tester, find.text('Tap leaking'));
    await tap(tester, find.text('Send to owner'));

    final d = b.lastMaintenance!;
    expect(d.category, MaintenanceCategory.plumbing);
    expect(d.title, 'Tap leaking');
    expect(d.stay.propertyId, 'P1');
  });

  testWidgets('accepting an invitation from a notification', (tester) async {
    final b = tenantWithStay();
    await start(tester, b);

    await tap(tester, find.byTooltip('Notifications'));
    await tap(tester, find.text('New PG Invitation'));
    expect(b.markedRead, ['n1']);
    expect(find.text('Sunrise Residency'), findsWidgets);

    await tap(tester, find.text('Accept'));
    expect(find.text('Join Sunrise Residency?'), findsOneWidget);
    await tap(tester, find.text('Accept').last);

    expect(b.calls, contains('accept:INV1'));
    expect(find.text('Welcome home!'), findsOneWidget);
  });

  testWidgets('pinning a note on the house pinboard', (tester) async {
    final b = tenantWithStay();
    await start(tester, b);

    await tap(tester, find.text('Pin a note').first);
    await tester.enterText(find.byKey(const Key('pin-text')), 'Anyone for chess?');
    await tap(tester, find.text('Pin it'));

    expect(b.lastPin!.content, 'Anyone for chess?');
    expect(b.lastPin!.propertyId, 'P1');
  });

  testWidgets('contacting the owner on WhatsApp', (tester) async {
    final b = tenantWithStay();
    final h = await start(tester, b);

    await tap(tester, find.text('Owner'));
    await tap(tester, find.text('WhatsApp'));

    final uri = h.device.opened.single;
    expect(uri.host, 'wa.me');
    expect(uri.path, '/919811100001');
  });

  testWidgets('signing out asks first', (tester) async {
    final b = tenantWithStay();
    final h = await start(tester, b);

    await tap(tester, find.text('Profile'));
    await tap(tester, find.text('Sign out'));
    expect(find.text('Sign out?'), findsOneWidget);
    await tap(tester, find.text('Sign out').last);

    expect(h.account.signOuts, 1);
  });

  testWidgets('signed out tenants see the login and can sign in', (tester) async {
    useTallPhone(tester);
    final h = Harness(FakeBackend());
    await h.pump(tester, signedIn: false);

    expect(find.text('Welcome home'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('login-email')), 'asha@example.test');
    await tester.enterText(find.byKey(const Key('login-password')), 'secret1');
    await tap(tester, find.text('Sign in'));

    expect(h.signIn.calls, ['signIn:asha@example.test']);
  });
}
