// Renders the main tenant screens to PNG for a visual check.
//
//   RENDER_DIR=/tmp/renders flutter test test/preview --update-goldens
//
// Skipped (and harmless) in a normal `flutter test` run.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenant/app/session_views.dart';
import 'package:tenant/data/models.dart';
import 'package:tenant/presentation/design/theme.dart';
import 'package:tenant/data/sources.dart';

import '../support/fakes.dart';
import '../support/harness.dart';
import '../support/render.dart';

void main() {
  final enabled = renderDir != null;

  setUpAll(() async {
    if (enabled) await loadDesignFonts();
  });

  FakeBackend livingTenant() {
    final now = DateTime.now();
    return FakeBackend()
      ..account.set(testAccount())
      ..stay.set(Stay(
        id: 'S1',
        businessId: 'B1',
        propertyId: 'P1',
        propertyName: 'Green Nest Co-living',
        roomId: 'R101',
        roomNumber: '101',
        bedId: '2',
        bedNumber: '2',
        monthlyRent: 9000,
        checkInDate: DateTime(now.year - 1, now.month, 5),
      ))
      ..unread.set(2)
      ..property.set(const PropertyContact(
        address: '12 Baner Road',
        city: 'Pune',
        phone: '9811100001',
        ownerName: 'Nest Stays',
        amenities: ['wifi', 'ac', 'laundry', 'foodIncluded', 'powerBackup'],
      ))
      ..room = const RoomInfo(sharing: 2, hasAC: true)
      ..invoices.set([
        RentInvoice(
          id: 'I1',
          status: InvoiceStatus.unpaid,
          amount: 9000,
          month: 'This month',
          periodMonth: '2099-01',
          dueDate: now.add(const Duration(days: 3)),
        ),
      ])
      ..payments.set([
        RentPayment(id: 'p1', state: PaymentState.paid, amount: 9000, month: 'Last month', method: 'UPI', date: now.subtract(const Duration(days: 28))),
        RentPayment(id: 'p2', state: PaymentState.paid, amount: 9000, month: 'Two months ago', method: 'Cash', date: now.subtract(const Duration(days: 58))),
      ])
      ..requests.set(const [])
      ..maintenance.set([
        MaintenanceRequest(
          id: 'm1',
          title: 'Geyser not heating',
          category: MaintenanceCategory.appliance,
          status: MaintenanceStatus.inProgress,
          ownerNote: 'Electrician coming at 5 pm',
          createdAt: now.subtract(const Duration(hours: 5)),
        ),
      ])
      ..pins.set([
        PinNote(id: 'n1', authorId: 'x', authorName: 'Rohan', category: PinCategory.sports, content: 'Badminton on the terrace at 7? Need two more!', createdAt: now.subtract(const Duration(hours: 2))),
        PinNote(id: 'n2', authorId: 'y', authorName: 'Meera', category: PinCategory.marketplace, content: 'Selling a study lamp, barely used.', createdAt: now.subtract(const Duration(hours: 9))),
      ])
      ..notifications.set([
        TenantNotification(id: 'a', type: 'bill_received', title: 'Rent due', body: 'Your rent of ₹9,000 is due in 3 days.', createdAt: now.subtract(const Duration(hours: 3))),
        TenantNotification(id: 'b', type: 'general', title: 'Water supply', body: 'No water from 10 to 12 tomorrow.', read: true, createdAt: now.subtract(const Duration(days: 1))),
      ]);
  }

  FakeBackend newcomer() {
    return FakeBackend()
      ..account.set(testAccount(tenantId: 'TEN9', complete: false))
      ..stay.set(null)
      ..unread.set(0)
      ..requests.set([
        EnrollmentRequest(
          id: 'E1',
          stage: EnrollmentStage.billSent,
          propertyName: 'Lotus Girls PG',
          propertyId: 'BUS0000001PNR001',
          createdAt: DateTime.now(),
          moveIn: DateTime.now().add(const Duration(days: 6)),
          roomNumber: '204',
          bedNumber: '1',
          monthlyRent: 8500,
          lines: const [BillLine('Rent (first period)', 6800), BillLine('Security deposit', 17000), BillLine('Maintenance', 500)],
          total: 24300,
          paymentMode: BillPaymentMode.upi,
          ownerUpiId: 'lotuspg@okhdfc',
        ),
      ])
      ..request.set(EnrollmentRequest(
        id: 'E1',
        stage: EnrollmentStage.billSent,
        propertyName: 'Lotus Girls PG',
        moveIn: DateTime.now().add(const Duration(days: 6)),
        roomNumber: '204',
        bedNumber: '1',
        monthlyRent: 8500,
        lines: const [BillLine('Rent (first period)', 6800), BillLine('Security deposit', 17000), BillLine('Maintenance', 500)],
        total: 24300,
        paymentMode: BillPaymentMode.upi,
        ownerUpiId: 'lotuspg@okhdfc',
      ))
      ..maintenance.set(const [])
      ..invitations = [
        const PendingInvitation(id: 'I1', businessId: 'B', propertyId: 'P', propertyName: 'Sunrise Residency', roomNumber: '12', bedNumber: '3', monthlyRent: 7500),
      ]
      ..pages['Bangalore'] = [
        PropertyPage([
          testProperty(id: 'BUS0000001PNR001', name: 'Lotus Girls PG', single: 11000, double: 8500, gender: 'female', featured: true),
          testProperty(id: 'P2', name: 'Raja Boys Hostel', single: 14000, double: 9500, gender: 'male', rating: 4.1),
        ]),
      ]
      ..properties['BUS0000001PNR001'] = testProperty(id: 'BUS0000001PNR001', name: 'Lotus Girls PG', single: 11000, double: 8500, gender: 'female', featured: true);
  }

  Future<Harness> start(WidgetTester tester, FakeBackend backend) async {
    useIphoneView(tester);
    final h = Harness(backend);
    await h.pump(tester);
    return h;
  }

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await Harness.settle(tester);
  }

  testWidgets('home', (tester) async {
    await start(tester, livingTenant());
    await snapshot(tester, 'home');
  }, skip: !enabled);

  testWidgets('home scrolled', (tester) async {
    await start(tester, livingTenant());
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -700));
    await Harness.settle(tester);
    await snapshot(tester, 'home_scrolled');
  }, skip: !enabled);

  testWidgets('home newcomer', (tester) async {
    await start(tester, newcomer());
    await snapshot(tester, 'home_newcomer');
  }, skip: !enabled);

  testWidgets('explore', (tester) async {
    await start(tester, newcomer());
    await tab(tester, 'Explore');
    await snapshot(tester, 'explore');
  }, skip: !enabled);

  testWidgets('property', (tester) async {
    await start(tester, newcomer());
    await tab(tester, 'Explore');
    await tester.tap(find.text('Lotus Girls PG'));
    await Harness.settle(tester);
    await snapshot(tester, 'property');
  }, skip: !enabled);

  testWidgets('my stay', (tester) async {
    await start(tester, livingTenant());
    await tab(tester, 'My stay');
    await snapshot(tester, 'my_stay');
  }, skip: !enabled);

  testWidgets('pay rent', (tester) async {
    final b = livingTenant()..settings = const PaymentSettings(onlineEnabled: true, upiId: 'nest@okicici');
    await start(tester, b);
    await tester.tap(find.text('Pay rent').first);
    await Harness.settle(tester);
    await tester.tap(find.text('UPI to owner'));
    await Harness.settle(tester);
    await snapshot(tester, 'pay_rent');
  }, skip: !enabled);

  testWidgets('first bill', (tester) async {
    await start(tester, newcomer());
    await tester.tap(find.textContaining('Review & pay'));
    await Harness.settle(tester);
    await snapshot(tester, 'first_bill');
  }, skip: !enabled);

  testWidgets('maintenance', (tester) async {
    await start(tester, livingTenant());
    await tester.tap(find.text('Get help'));
    await Harness.settle(tester);
    await snapshot(tester, 'maintenance_new');
  }, skip: !enabled);

  testWidgets('notifications', (tester) async {
    await start(tester, livingTenant());
    await tester.tap(find.byTooltip('Notifications'));
    await Harness.settle(tester);
    await snapshot(tester, 'notifications');
  }, skip: !enabled);

  testWidgets('profile', (tester) async {
    await start(tester, livingTenant());
    await tab(tester, 'Profile');
    await snapshot(tester, 'profile');
  }, skip: !enabled);

  Future<void> showLogo(WidgetTester tester) async {
    // Asset images decode off the fake clock.
    await tester.runAsync(() async {
      for (final e in tester.elementList(find.byType(Image))) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await tester.pump();
  }

  testWidgets('login', (tester) async {
    useIphoneView(tester);
    final h = Harness(FakeBackend());
    await h.pump(tester, signedIn: false);
    await showLogo(tester);
    await snapshot(tester, 'login');
  }, skip: !enabled);

  testWidgets('splash', (tester) async {
    useIphoneView(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: const MediaQuery(data: MediaQueryData(disableAnimations: true), child: BrandSplash()),
    ));
    await showLogo(tester);
    await snapshot(tester, 'splash');
  }, skip: !enabled);
}
