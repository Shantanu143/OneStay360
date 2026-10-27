import 'package:business/presentation/design/components/biz_chips.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/property_detail/property_detail_actions.dart';
import 'package:business/presentation/property_detail/property_detail_models.dart';
import 'package:business/presentation/property_detail/property_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/business/property/property_model.dart';
import 'package:models/business/property/property_room_model.dart';
import 'package:models/tenant/tenant_request_model.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../support/detail_fakes.dart';
import '../../support/property_fixtures.dart';

PropertyRoom roomOf(String number, String floor, int sharing, {bool ac = false}) =>
    PropertyRoom(
      roomNumber: number,
      floor: floor,
      occupancyType: '$sharing',
      sharingType: sharing,
      hasAC: ac,
    );

class FakeActions implements PropertyDetailActions {
  final calls = <String>[];
  Uri? openedUrl;
  bool checkoutResult = false;
  bool tenantRemoved = false;

  @override
  Future<bool> openTenant(BuildContext context,
      {required Property property, required PropertyTenant tenant}) async {
    calls.add('tenant:${tenant.id}');
    return tenantRemoved;
  }

  @override
  Future<void> openRequest(BuildContext context,
      {required String propertyId, required TenantRequest request}) async {
    calls.add('request:${request.id}');
  }

  @override
  Future<bool> openCheckout(BuildContext context,
      {required String propertyId, required String purpose, String? invoiceId}) async {
    calls.add('checkout:$purpose:${invoiceId ?? '-'}');
    return checkoutResult;
  }

  @override
  Future<void> call(BuildContext context, String phone) async => calls.add('call:$phone');

  @override
  Future<void> openUrl(BuildContext context, Uri uri) async {
    openedUrl = uri;
    calls.add('url');
  }

  @override
  Future<void> copy(BuildContext context, String text, {String? message}) async =>
      calls.add('copy:$text');
}

void main() {
  late FakeDetailSource source;
  late FakeActions actions;
  final now = DateTime(2026, 10, 26, 12);

  final skyline = makeProperty(id: 'P1', name: 'Skyline Residency', city: 'Pune')
      .copyWith(billingStatus: 'paid');

  setUp(() {
    actions = FakeActions();
    source = FakeDetailSource()
      ..prop = skyline
      ..roomList = [roomOf('101', '1', 2), roomOf('102', '1', 3), roomOf('201', '2', 2, ac: true)]
      ..tenantList = [
        tenant('T1', name: 'Amit Patel', phone: '+91 98765 43210', room: '101', bed: '1', rent: 6500),
        tenant('T2', name: 'Neha Verma', phone: '9811122233', room: '102', bed: '2', rent: 5000),
      ];
  });

  Future<void> open(WidgetTester tester, {int? tab, bool settle = true}) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: BizTheme.light(),
        home: PropertyDetailScreen(
          propertyId: 'P1',
          initialTabIndex: tab,
          source: source,
          actions: actions,
          clock: () => now,
        ),
      ),
    );
    if (settle) {
      await tester.pump();
      await tester.pumpAndSettle();
    }
  }

  /// The chip row scrolls sideways, so bring the chip into view first.
  Future<void> goTo(WidgetTester tester, String tab) async {
    final chip = find.descendant(
      of: find.byType(BizFilterChips),
      matching: find.text(tab),
    );
    final row = tester.widget<BizFilterChips>(find.byType(BizFilterChips));
    final target = row.chips.indexWhere((c) => c.label == tab);
    final dx = target < row.selectedIndex ? 160.0 : -160.0;
    for (var i = 0; i < 20 && chip.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(BizFilterChips), Offset(dx, 0));
      await tester.pump();
    }
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  List<BizChipData> chipsOf(WidgetTester tester) =>
      tester.widget<BizFilterChips>(find.byType(BizFilterChips)).chips;

  group('header and overview', () {
    testWidgets('shows the property, where it is and real occupancy figures', (tester) async {
      await open(tester);

      expect(find.text('Skyline Residency'), findsOneWidget);
      expect(find.text('Pune · Active'), findsOneWidget);
      expect(find.text('28.6%'), findsOneWidget);
      expect(find.text('2 of 7 beds filled'), findsOneWidget);
      expect(find.text('₹11,500'), findsOneWidget);
    });

    testWidgets('lists the seven tabs', (tester) async {
      await open(tester);

      expect(chipsOf(tester).map((c) => c.label), [
        'Overview',
        'Layout',
        'Tenants',
        'Analytics',
        'Payments',
        'Requests',
        'QR',
      ]);
    });

    testWidgets('never invents an owner email', (tester) async {
      await open(tester);

      expect(find.textContaining('@'), findsNothing);
      expect(find.text('Apex'), findsOneWidget);
      expect(find.text('9000000000'), findsOneWidget);
    });

    testWidgets('a draft property offers activation', (tester) async {
      source.prop = skyline.copyWith(status: 'draft', billingStatus: 'payment_due');
      await open(tester);

      expect(find.text('Activate this property to start adding tenants.'), findsOneWidget);
      await tester.tap(find.text('Activate this property to start adding tenants.'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['checkout:activation:-']);
    });

    testWidgets('reloads the property after a payment goes through', (tester) async {
      source.prop = skyline.copyWith(status: 'draft', billingStatus: 'payment_due');
      actions.checkoutResult = true;
      await open(tester);
      expect(source.propertyCalls, 1);

      await tester.tap(find.text('Activate this property to start adding tenants.'));
      await tester.pumpAndSettle();

      expect(source.propertyCalls, 2);
    });

    testWidgets('an overdue subscription points to Payments', (tester) async {
      source.prop = skyline.copyWith(billingStatus: 'past_due');
      await open(tester);

      expect(find.text('Overdue — pay now to keep this property running.'), findsOneWidget);
      await tester.tap(find.text('Overdue — pay now to keep this property running.'));
      await tester.pumpAndSettle();

      expect(find.text('PAYMENT HISTORY'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('groups rooms by floor with free-bed counts', (tester) async {
      await open(tester);
      await goTo(tester, 'Layout');

      expect(find.text('FLOOR 1'), findsOneWidget);
      expect(find.text('FLOOR 2'), findsOneWidget);
      expect(find.text('3 of 5 beds free'), findsOneWidget);
      expect(find.text('Room 101'), findsOneWidget);
      expect(find.text('Room 201'), findsOneWidget);
      expect(find.text('2-sharing · AC'), findsOneWidget);
    });

    testWidgets('a room opens its beds and who sleeps in them', (tester) async {
      await open(tester);
      await goTo(tester, 'Layout');

      await tester.tap(find.text('Room 101'));
      await tester.pumpAndSettle();

      expect(find.text('Amit Patel'), findsOneWidget);
      expect(find.text('Vacant'), findsOneWidget);

      await tester.tap(find.text('Amit Patel'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['tenant:T1']);
    });

    testWidgets('says so when no rooms are set up', (tester) async {
      source
        ..roomList = const []
        ..tenantList = const [];
      await open(tester);
      await goTo(tester, 'Layout');

      expect(find.text('No rooms yet'), findsOneWidget);
    });
  });

  group('tenants', () {
    testWidgets('lists everyone with room, bed and rent', (tester) async {
      await open(tester);
      await goTo(tester, 'Tenants');

      expect(find.text('Amit Patel'), findsOneWidget);
      expect(find.text('Room 101 · Bed 1'), findsOneWidget);
      expect(find.text('₹6,500'), findsOneWidget);
      expect(find.text('Neha Verma'), findsOneWidget);
    });

    testWidgets('searching narrows the list', (tester) async {
      await open(tester);
      await goTo(tester, 'Tenants');

      await tester.enterText(find.byType(TextField), 'neha');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Neha Verma'), findsOneWidget);
      expect(find.text('Amit Patel'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('No tenants match'), findsOneWidget);
    });

    testWidgets('a tenant opens their detail and can be called', (tester) async {
      await open(tester);
      await goTo(tester, 'Tenants');

      await tester.tap(find.text('Amit Patel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Call Amit Patel'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['tenant:T1', 'call:+91 98765 43210']);
    });

    testWidgets('reloads after a tenant was removed, not after a look', (tester) async {
      await open(tester);
      await goTo(tester, 'Tenants');

      await tester.tap(find.text('Amit Patel'));
      await tester.pumpAndSettle();
      expect(source.propertyCalls, 1, reason: 'just looked');

      actions.tenantRemoved = true;
      await tester.tap(find.text('Amit Patel'));
      await tester.pumpAndSettle();
      expect(source.propertyCalls, 2);
    });

    testWidgets('an empty property invites its first tenant', (tester) async {
      source.tenantList = const [];
      await open(tester);
      await goTo(tester, 'Tenants');

      expect(find.text('No tenants yet'), findsOneWidget);
    });
  });

  group('analytics', () {
    testWidgets("totals this month's rent from the invoices", (tester) async {
      source.invoices = [
        InvoiceSummary(tenantId: 'T1', amount: 6500, status: 'paid'),
        InvoiceSummary(tenantId: 'T2', amount: 5000, status: 'overdue'),
      ];
      await open(tester);
      await goTo(tester, 'Analytics');

      expect(source.lastPeriod, '2026-10');
      expect(find.text('October collections'), findsOneWidget);
      expect(find.text('₹11,500'), findsOneWidget);
      expect(find.text('₹6,500'), findsOneWidget);
      expect(find.text('₹5,000'), findsOneWidget);
      expect(find.text('56.5%'), findsOneWidget);
      expect(find.text('1 paid'), findsOneWidget);
      expect(find.text('1 unpaid'), findsOneWidget);
      expect(find.text('1 overdue'), findsOneWidget);
    });

    testWidgets('explains an empty month instead of showing zeros', (tester) async {
      await open(tester);
      await goTo(tester, 'Analytics');

      expect(find.text('No rent invoices for October yet'), findsOneWidget);
    });

    testWidgets('recovers from a failed load with Try again', (tester) async {
      source.invoicesFailure = Exception('offline');
      await open(tester);
      await goTo(tester, 'Analytics');

      expect(find.text("Couldn't load this month's collections."), findsOneWidget);

      source
        ..invoicesFailure = null
        ..invoices = [InvoiceSummary(tenantId: 'T1', amount: 6500, status: 'paid')];
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('₹6,500'), findsWidgets);
      expect(source.invoiceCalls, 2);
    });

    testWidgets('loads once however often the tab is revisited', (tester) async {
      await open(tester);
      await goTo(tester, 'Analytics');
      await goTo(tester, 'Overview');
      await goTo(tester, 'Analytics');

      expect(source.invoiceCalls, 1);
      expect(source.propertyCalls, 1);
    });
  });

  group('payments', () {
    testWidgets('an active subscription shows history and no pay button', (tester) async {
      source.payments = [
        {
          'id': 'pay1',
          'amount': 1500,
          'finalAmount': 1200,
          'status': 'paid',
          'purpose': 'activation',
          'promoCode': 'WELCOME',
          'discountAmount': 300,
          'orderId': 'order_9',
        },
      ];
      await open(tester);
      await goTo(tester, 'Payments');

      expect(find.text('Billing active'), findsOneWidget);
      expect(find.text('Pay now'), findsNothing);
      expect(find.text('Activation payment'), findsOneWidget);
      expect(find.text('₹1,200'), findsOneWidget);

      await tester.tap(find.text('Activation payment'));
      await tester.pumpAndSettle();
      expect(find.textContaining('WELCOME'), findsOneWidget);
      expect(find.textContaining('You saved ₹300'), findsOneWidget);
    });

    testWidgets('a due invoice can be paid, then the property refreshes', (tester) async {
      source
        ..prop = skyline.copyWith(billingStatus: 'due')
        ..unpaid = 'INV-7';
      actions.checkoutResult = true;
      await open(tester);
      await goTo(tester, 'Payments');

      expect(find.text('Payment due'), findsOneWidget);
      await tester.tap(find.text('Pay now'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['checkout:monthly:INV-7']);
      expect(source.propertyCalls, 2);
    });

    testWidgets("won't open checkout before the invoice is known", (tester) async {
      source
        ..prop = skyline.copyWith(billingStatus: 'due')
        ..unpaid = null;
      await open(tester);
      await goTo(tester, 'Payments');

      await tester.tap(find.text('Pay now'));
      await tester.pumpAndSettle();

      expect(actions.calls, isEmpty);
      expect(find.textContaining("couldn't find an open invoice"), findsOneWidget);
    });

    testWidgets('an unactivated property is activated from here', (tester) async {
      source.prop = skyline.copyWith(status: 'draft', billingStatus: 'payment_due');
      await open(tester);
      await goTo(tester, 'Payments');

      await tester.tap(find.text('Activate property'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['checkout:activation:-']);
    });

    testWidgets('shows an empty history and a failed load', (tester) async {
      await open(tester);
      await goTo(tester, 'Payments');
      expect(find.text('No payments yet'), findsOneWidget);
    });

    testWidgets('a failed history load can be retried', (tester) async {
      source.billingFailure = Exception('offline');
      await open(tester);
      await goTo(tester, 'Payments');
      expect(find.text("Couldn't load payments."), findsOneWidget);

      source.billingFailure = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No payments yet'), findsOneWidget);
    });
  });

  group('requests', () {
    testWidgets('shows live requests, the pending count, and opens one', (tester) async {
      await open(tester);
      source.requestsController.add([
        request('R1', 'pending', name: 'Mohit Rao'),
        request('R2', 'pending', name: 'Isha Jain', at: DateTime(2026, 10, 21)),
        request('R3', 'confirmed', name: 'Karan Shah', at: DateTime(2026, 10, 19)),
      ]);
      await tester.pumpAndSettle();

      expect(chipsOf(tester).firstWhere((c) => c.label == 'Requests').count, 2);

      await goTo(tester, 'Requests');
      expect(find.text('Mohit Rao'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);

      await tester.tap(find.text('Mohit Rao'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['request:R1']);
    });

    testWidgets('says so when nobody has asked yet', (tester) async {
      await open(tester);
      source.requestsController.add(const []);
      await tester.pumpAndSettle();
      await goTo(tester, 'Requests');

      expect(find.text('No requests yet'), findsOneWidget);
    });

    testWidgets('reports a request stream failure', (tester) async {
      await open(tester);
      source.requestsController.addError(Exception('denied'));
      await tester.pumpAndSettle();
      await goTo(tester, 'Requests');

      expect(find.text("Couldn't load requests."), findsOneWidget);
    });
  });

  group('qr', () {
    testWidgets('shows a scannable code with copy and WhatsApp share', (tester) async {
      await open(tester);
      await goTo(tester, 'QR');

      expect(find.byType(QrImageView), findsOneWidget);
      const link = 'https://onestay.app/request?propertyId=P1';
      expect(find.text(link), findsOneWidget);

      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['copy:$link']);

      await tester.tap(find.text('Share on WhatsApp'));
      await tester.pumpAndSettle();
      expect(actions.openedUrl?.host, 'wa.me');
      expect(actions.openedUrl?.queryParameters['text'], contains(link));
      expect(actions.openedUrl?.queryParameters['text'], contains('Skyline Residency'));
    });
  });

  group('opening and loading', () {
    testWidgets('deep-link tab indexes open Payments and Requests', (tester) async {
      await open(tester, tab: 4);
      expect(find.text('PAYMENT HISTORY'), findsOneWidget);
      expect(source.billingCalls, 1);
    });

    testWidgets('the requests index opens Requests', (tester) async {
      // The placeholders pulse until the first snapshot arrives.
      await open(tester, tab: 5, settle: false);
      await tester.pump();
      source.requestsController.add(const []);
      await tester.pumpAndSettle();
      expect(find.text('No requests yet'), findsOneWidget);
    });

    testWidgets('an unknown index falls back to Overview', (tester) async {
      await open(tester, tab: 42);
      expect(find.text('28.6%'), findsOneWidget);
    });

    testWidgets('shows placeholders while loading', (tester) async {
      await open(tester, settle: false);
      expect(find.text('28.6%'), findsNothing);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('28.6%'), findsOneWidget);
    });

    testWidgets('a failed load can be retried', (tester) async {
      source.coreFailure = Exception('offline');
      await open(tester);
      expect(
        find.text("Couldn't load this property. Check your connection and try again."),
        findsOneWidget,
      );

      source.coreFailure = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Skyline Residency'), findsOneWidget);
    });

    testWidgets('a deleted property says it is gone', (tester) async {
      source.prop = null;
      await open(tester);
      expect(find.text('Property not found'), findsOneWidget);
    });

    testWidgets('pulling down refreshes', (tester) async {
      await open(tester);
      // The indicator arms after a quarter of the (tall, 3000px) test viewport.
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 2400), 1000);
      await tester.pumpAndSettle();

      expect(source.propertyCalls, 2);
    });

    testWidgets('closing the screen stops listening for requests', (tester) async {
      await open(tester);
      expect(source.requestsController.hasListener, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(source.requestsController.hasListener, isFalse);
    });
  });
}
