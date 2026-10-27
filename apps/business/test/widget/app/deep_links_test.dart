import 'package:business/app/deep_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLink.fromUri', () {
    test('parses an invite link on the app host', () {
      final link = AppLink.fromUri(
        Uri.parse(
          'https://app.onestay360.brandedpatil.in/invite?inviteId=INV123',
        ),
      );

      expect(link, isA<InviteLink>());
      expect((link as InviteLink).inviteId, 'INV123');
      expect(link.requiresSession, isFalse);
    });

    test('ignores other hosts, other paths and missing ids', () {
      expect(
        AppLink.fromUri(Uri.parse('https://evil.example/invite?inviteId=1')),
        isNull,
      );
      expect(
        AppLink.fromUri(
          Uri.parse('https://app.onestay360.brandedpatil.in/other?inviteId=1'),
        ),
        isNull,
      );
      expect(
        AppLink.fromUri(
          Uri.parse('https://app.onestay360.brandedpatil.in/invite'),
        ),
        isNull,
      );
      expect(
        AppLink.fromUri(
          Uri.parse('https://app.onestay360.brandedpatil.in/invite?inviteId='),
        ),
        isNull,
      );
    });
  });

  group('AppLink.fromPushData', () {
    test(
      'enrollment request with a property opens that property\'s requests',
      () {
        final link = AppLink.fromPushData({
          'type': 'enrollment_request',
          'propertyId': 'P1',
          'requestId': 'R1',
        });

        expect(link, isA<PropertyTabLink>());
        expect((link as PropertyTabLink).propertyId, 'P1');
        expect(link.tab, PropertyTab.requests);
        expect(link.requiresSession, isTrue);
      },
    );

    test('enrollment request without a property falls back to the request', () {
      final link = AppLink.fromPushData({
        'type': 'enrollment_request',
        'requestId': 'R1',
      });

      expect(link, isA<EnrollmentRequestLink>());
      expect((link as EnrollmentRequestLink).requestId, 'R1');
    });

    test('billing changes open the property billing tab', () {
      final link = AppLink.fromPushData({
        'type': 'billing_status_change',
        'propertyId': 'P9',
      });

      expect((link as PropertyTabLink).tab, PropertyTab.billing);
    });

    test('payment submitted opens pending payments', () {
      final link = AppLink.fromPushData({
        'type': 'payment_submitted',
        'businessId': 'B1',
        'requestId': 'R1',
      });

      expect(link, isA<PendingPaymentsLink>());
      expect((link as PendingPaymentsLink).businessId, 'B1');
    });

    test('rent received opens the notifications list', () {
      expect(
        AppLink.fromPushData({'type': 'rent_received'}),
        isA<NotificationsLink>(),
      );
    });

    test('unknown or incomplete payloads are ignored', () {
      expect(AppLink.fromPushData({'type': 'mystery'}), isNull);
      expect(AppLink.fromPushData({}), isNull);
      expect(AppLink.fromPushData({'type': 'enrollment_request'}), isNull);
      expect(AppLink.fromPushData({'type': 'billing_status_change'}), isNull);
    });
  });

  group('DeepLinkCoordinator', () {
    late GlobalKey<NavigatorState> navKey;
    late DeepLinkCoordinator coordinator;
    late List<AppLink> opened;

    setUp(() {
      navKey = GlobalKey<NavigatorState>();
      opened = [];
      coordinator = DeepLinkCoordinator(
        navigatorKey: navKey,
        routeFor: (link) {
          opened.add(link);
          return MaterialPageRoute<void>(
            builder: (_) => Scaffold(body: Text('page:${link.runtimeType}')),
          );
        },
      );
    });

    Future<void> mount(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: const Scaffold(body: Text('root')),
        ),
      );
    }

    testWidgets('invite links open immediately, even when signed out', (
      tester,
    ) async {
      await mount(tester);

      coordinator.handle(const InviteLink('INV1'));
      await tester.pumpAndSettle();

      expect(opened, hasLength(1));
      expect(find.text('page:InviteLink'), findsOneWidget);
    });

    testWidgets('session links wait until the session is ready', (
      tester,
    ) async {
      await mount(tester);

      coordinator.handle(const PropertyTabLink('P1', PropertyTab.requests));
      await tester.pumpAndSettle();
      expect(opened, isEmpty, reason: 'not ready yet');

      coordinator.sessionReady();
      await tester.pumpAndSettle();

      expect(opened, hasLength(1));
      expect(find.text('page:PropertyTabLink'), findsOneWidget);
    });

    testWidgets('links arriving after ready open immediately', (tester) async {
      await mount(tester);
      coordinator.sessionReady();

      coordinator.handle(const NotificationsLink());
      await tester.pumpAndSettle();

      expect(opened, hasLength(1));
    });

    testWidgets('only the latest waiting session link is kept', (tester) async {
      await mount(tester);

      coordinator.handle(const PropertyTabLink('P1', PropertyTab.requests));
      coordinator.handle(const PropertyTabLink('P2', PropertyTab.billing));
      coordinator.sessionReady();
      await tester.pumpAndSettle();

      expect(opened, hasLength(1));
      expect((opened.single as PropertyTabLink).propertyId, 'P2');
    });

    testWidgets('a repeated invite link is not opened twice', (tester) async {
      await mount(tester);

      coordinator.handle(const InviteLink('INV1'));
      coordinator.handle(const InviteLink('INV1'));
      await tester.pumpAndSettle();

      expect(opened, hasLength(1));
    });

    testWidgets('signing out drops links that needed the session', (
      tester,
    ) async {
      await mount(tester);
      coordinator.handle(const NotificationsLink());

      coordinator.sessionEnded();
      coordinator.sessionReady();
      await tester.pumpAndSettle();

      expect(opened, isEmpty);
    });

    testWidgets('keeps a link until the navigator exists', (tester) async {
      coordinator.handle(const InviteLink('INV1')); // no navigator mounted yet
      expect(opened, isEmpty);

      await mount(tester);
      coordinator.navigatorReady();
      await tester.pumpAndSettle();

      expect(opened, hasLength(1));
    });

    testWidgets('an unroutable link is dropped without crashing', (
      tester,
    ) async {
      final quiet = DeepLinkCoordinator(
        navigatorKey: navKey,
        routeFor: (_) => null,
      );
      await mount(tester);

      quiet.handle(const InviteLink('INV1'));
      await tester.pumpAndSettle();

      expect(find.text('root'), findsOneWidget);
    });
  });
}
