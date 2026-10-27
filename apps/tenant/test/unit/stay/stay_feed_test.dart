import 'package:flutter_test/flutter_test.dart';
import 'package:tenant/data/models.dart';
import 'package:tenant/data/tenant_session.dart';
import 'package:tenant/presentation/stay/stay_feed.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBackend backend;
  late TenantSession session;
  late StayFeed feed;
  final now = DateTime(2026, 3, 12, 10);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    backend = FakeBackend();
    session = TenantSession(source: backend);
    feed = StayFeed(session: session, source: backend, clock: () => now);
    session.start('u1');
    backend.account.set(testAccount());
    await settle();
  });

  tearDown(() {
    feed.dispose();
    session.dispose();
  });

  test('has nothing without a stay', () async {
    backend.stay.set(null);
    await settle();
    expect(feed.stay, isNull);
    expect(feed.dueInvoice, isNull);
    expect(backend.invoices.listens, 0);
  });

  test('follows the stay: property, room, invoices and payments', () async {
    backend.room = const RoomInfo(sharing: 2, hasAC: true);
    backend.stay.set(testStay);
    await settle();
    backend.property.set(const PropertyContact(address: 'MG Road', city: 'Pune', phone: '98'));
    backend.invoices.set([]);
    backend.payments.set([]);
    await settle();

    expect(feed.stay!.propertyName, 'Green Nest');
    expect(feed.property!.location, 'MG Road, Pune');
    expect(feed.room!.sharingLabel, 'Double sharing');
    expect(feed.loadingMoney, isFalse);
  });

  test('the due invoice is the oldest open one', () async {
    backend.stay.set(testStay);
    await settle();
    backend.invoices.set([
      const RentInvoice(id: 'mar', status: InvoiceStatus.unpaid, periodMonth: '2026-03', amount: 9000),
      const RentInvoice(id: 'feb', status: InvoiceStatus.overdue, periodMonth: '2026-02', amount: 9000),
      const RentInvoice(id: 'jan', status: InvoiceStatus.paid, periodMonth: '2026-01', amount: 9000),
    ]);
    await settle();

    expect(feed.dueInvoice!.id, 'feb');
    expect(feed.openInvoices.map((i) => i.id), ['feb', 'mar']);
    expect(feed.totalDue, 18000);
  });

  test('knows a payment waiting for the owner on an invoice', () async {
    backend.stay.set(testStay);
    await settle();
    backend.payments.set([
      const RentPayment(id: 'p1', state: PaymentState.pending, invoiceId: 'feb', amount: 9000),
      const RentPayment(id: 'p0', state: PaymentState.rejected, invoiceId: 'jan', amount: 9000),
    ]);
    await settle();
    expect(feed.pendingPaymentFor('feb')!.id, 'p1');
    expect(feed.pendingPaymentFor('jan'), isNull);
  });

  test('next due date follows the billing day', () async {
    backend.stay.set(Stay(
      id: 'S',
      businessId: 'B1',
      propertyId: 'P1',
      checkInDate: DateTime(2025, 11, 5),
    ));
    await settle();
    expect(feed.nextBillingDate, DateTime(2026, 4, 5), reason: '5th already passed in March');

    backend.stay.set(Stay(id: 'S', businessId: 'B1', propertyId: 'P1', checkInDate: DateTime(2025, 11, 20)));
    await settle();
    expect(feed.nextBillingDate, DateTime(2026, 3, 20));
  });

  test('a billing day past the end of a short month lands on its last day', () async {
    final feb = StayFeed(session: session, source: backend, clock: () => DateTime(2026, 2, 2));
    backend.stay.set(Stay(id: 'S', businessId: 'B1', propertyId: 'P1', checkInDate: DateTime(2025, 1, 31)));
    await settle();
    expect(feb.nextBillingDate, DateTime(2026, 2, 28));
    feb.dispose();
  });

  test('moving out stops listening to the old stay', () async {
    backend.stay.set(testStay);
    await settle();
    backend.invoices.set([const RentInvoice(id: 'x', status: InvoiceStatus.unpaid)]);
    await settle();
    backend.stay.set(null);
    await settle();
    expect(feed.invoices, isEmpty);
    expect(feed.dueInvoice, isNull);
  });
}
