import 'dart:async';

import 'package:business/data/providers/business_notifications_provider.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/notifications/notifications_screen.dart';
import 'package:firebase_services/services/business_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/business/business_notification_model.dart';
import 'package:provider/provider.dart';

class FakeNotificationService implements BusinessNotificationService {
  final controller = StreamController<List<BusinessNotification>>.broadcast();
  final read = <String>[];
  int markAllCalls = 0;
  int subscriptions = 0;

  @override
  Stream<List<BusinessNotification>> streamNotifications(String businessId, {int limit = 50}) {
    subscriptions++;
    return controller.stream;
  }

  @override
  Future<void> markAsRead({required String businessId, required String notificationId}) async {
    read.add(notificationId);
  }

  @override
  Future<void> markAllAsRead(String businessId) async => markAllCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BusinessNotification note(
  String id,
  String title, {
  bool read = false,
  BusinessNotificationType type = BusinessNotificationType.enrollmentRequest,
  String? property = 'Sunrise Boys PG',
  DateTime? at,
}) =>
    BusinessNotification(
      id: id,
      businessId: 'BUS1',
      title: title,
      message: 'Message for $title',
      type: type,
      read: read,
      createdAt: at ?? DateTime(2026, 10, 26, 9),
      propertyId: 'P1',
      propertyName: property,
    );

void main() {
  late FakeNotificationService service;
  late BusinessNotificationsProvider provider;
  late List<String> opened;
  final now = DateTime(2026, 10, 26, 12);

  setUp(() {
    service = FakeNotificationService();
    provider = BusinessNotificationsProvider(service: service);
    opened = [];
  });

  tearDown(() {
    provider.dispose();
    service.controller.close();
  });

  Future<void> open(WidgetTester tester, {bool withBusiness = true, bool settle = true}) async {
    if (withBusiness) provider.updateBusiness('BUS1');
    await tester.pumpWidget(
      ChangeNotifierProvider<BusinessNotificationsProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: BizTheme.light(),
          home: BusinessNotificationsScreen(
            clock: () => now,
            onOpen: (context, n) async => opened.add(n.id),
          ),
        ),
      ),
    );
    // The placeholders pulse until the first snapshot, so don't wait for quiet.
    if (settle) await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> emit(WidgetTester tester, List<BusinessNotification> list) async {
    service.controller.add(list);
    await tester.pumpAndSettle();
  }

  testWidgets('explains what is missing before a business is linked', (tester) async {
    await open(tester, withBusiness: false);

    expect(find.textContaining('once your business account is fully linked'), findsOneWidget);
  });

  testWidgets('shows placeholders until the first snapshot arrives', (tester) async {
    await open(tester, settle: false);
    await tester.pump();

    expect(find.text('No notifications yet'), findsNothing);
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('says so when there is nothing yet', (tester) async {
    await open(tester);
    await emit(tester, const []);

    expect(find.text('No notifications yet'), findsOneWidget);
    expect(find.text('All caught up'), findsOneWidget);
  });

  testWidgets('puts unread first, with the count in the header', (tester) async {
    await open(tester);
    await emit(tester, [
      note('a', 'Old news', read: true, at: DateTime(2026, 10, 20, 9)),
      note('b', 'New request'),
      note('c', 'Fresh payment', type: BusinessNotificationType.payment),
    ]);

    expect(find.text('2 unread'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('EARLIER'), findsOneWidget);
    final newY = tester.getTopLeft(find.text('New request')).dy;
    final oldY = tester.getTopLeft(find.text('Old news')).dy;
    expect(newY, lessThan(oldY));
  });

  testWidgets('each row shows its message, property and how long ago', (tester) async {
    await open(tester);
    await emit(tester, [note('b', 'New request')]);

    expect(find.text('Message for New request'), findsOneWidget);
    expect(find.text('Sunrise Boys PG · 3h ago'), findsOneWidget);
  });

  testWidgets('tapping a row marks it read and opens its target', (tester) async {
    await open(tester);
    await emit(tester, [note('b', 'New request')]);

    await tester.tap(find.text('New request'));
    await tester.pumpAndSettle();

    expect(service.read, ['b']);
    expect(opened, ['b']);
  });

  testWidgets('"Mark all as read" appears only while something is unread', (tester) async {
    await open(tester);
    await emit(tester, [note('b', 'New request')]);

    await tester.tap(find.byTooltip('Mark all as read'));
    await tester.pumpAndSettle();
    expect(service.markAllCalls, 1);

    await emit(tester, [note('b', 'New request', read: true)]);
    expect(find.byTooltip('Mark all as read'), findsNothing);
    expect(find.text('NEW'), findsNothing);
  });

  testWidgets('a failed stream shows a retry that subscribes again', (tester) async {
    await open(tester);
    service.controller.addError(Exception('denied'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load notifications'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(service.subscriptions, 2);

    await emit(tester, [note('b', 'New request')]);
    expect(find.text('New request'), findsOneWidget);
  });
}
