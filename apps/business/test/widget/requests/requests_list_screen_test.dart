import 'dart:async';

import 'package:business/presentation/design/components/biz_chips.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/requests/request_models.dart';
import 'package:business/presentation/requests/request_source.dart';
import 'package:business/presentation/requests/requests_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/request_fakes.dart';

class FakeListSource implements RequestListSource {
  final controller = StreamController<List<EnrollmentRequest>>.broadcast();
  int watches = 0;

  @override
  Stream<List<EnrollmentRequest>> watchAll(String businessId) {
    watches++;
    return controller.stream;
  }
}

EnrollmentRequest req(String id, String status, String name, {String property = 'P1', int day = 20}) =>
    EnrollmentRequest.fromMap(id, {
      ...requestDoc(status: status),
      'tenantName': name,
      'propertyId': property,
      'propertyName': property == 'P1' ? 'Sunrise Boys PG' : 'Lotus Ladies Hostel',
      'createdAt': DateTime(2026, 10, day),
    });

void main() {
  late FakeListSource source;
  late List<String> opened;
  final now = DateTime(2026, 10, 26, 12);

  setUp(() {
    source = FakeListSource();
    opened = [];
  });

  tearDown(() => source.controller.close());

  Future<void> open(
    WidgetTester tester, {
    String? businessId = 'BUS1',
    String? initialRequestId,
    String? propertyId,
  }) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: BizTheme.light(),
        home: EnrollmentRequestsScreen(
          businessId: businessId,
          initialRequestId: initialRequestId,
          initialPropertyId: propertyId,
          source: source,
          clock: () => now,
          onOpen: (context, r) async => opened.add(r.id),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> push(WidgetTester tester, List<EnrollmentRequest> list) async {
    source.controller.add(list);
    await tester.pumpAndSettle();
  }

  List<BizChipData> chips(WidgetTester tester) =>
      tester.widget<BizFilterChips>(find.byType(BizFilterChips)).chips;

  Future<void> tapChip(WidgetTester tester, String label) async {
    final chip = find.descendant(of: find.byType(BizFilterChips), matching: find.text(label));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  testWidgets('opens on what needs the owner', (tester) async {
    await open(tester);
    await push(tester, [
      req('a', 'pending', 'Mohit Saxena'),
      req('b', 'bill_sent', 'Karan Singh'),
      req('c', 'confirmed', 'Rohan Mehta'),
    ]);

    expect(find.text('Mohit Saxena'), findsOneWidget);
    expect(find.text('Karan Singh'), findsNothing);
    expect(chips(tester).map((c) => '${c.label} ${c.count}'), [
      'Needs you 1',
      'Waiting 1',
      'Done 1',
      'All 3',
    ]);
  });

  testWidgets('each row shows who, where and what stage', (tester) async {
    await open(tester);
    await push(tester, [req('a', 'pending', 'Mohit Saxena')]);

    expect(find.text('+919000000501'), findsOneWidget);
    expect(find.text('Sunrise Boys PG · 2-sharing'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('6d ago'), findsOneWidget);
  });

  testWidgets('another filter shows its requests', (tester) async {
    await open(tester);
    await push(tester, [req('a', 'pending', 'Mohit Saxena'), req('b', 'bill_sent', 'Karan Singh')]);

    await tapChip(tester, 'All');

    expect(find.text('Mohit Saxena'), findsOneWidget);
    expect(find.text('Karan Singh'), findsOneWidget);
  });

  testWidgets('tapping a row opens it', (tester) async {
    await open(tester);
    await push(tester, [req('a', 'pending', 'Mohit Saxena')]);

    await tester.tap(find.text('Mohit Saxena'));
    await tester.pumpAndSettle();

    expect(opened, ['a']);
  });

  testWidgets('limits itself to one property', (tester) async {
    await open(tester, propertyId: 'P2');
    await push(tester, [
      req('a', 'pending', 'Mohit Saxena', property: 'P1'),
      req('b', 'pending', 'Aditi Rao', property: 'P2'),
    ]);

    expect(find.text('Aditi Rao'), findsOneWidget);
    expect(find.text('Mohit Saxena'), findsNothing);
  });

  testWidgets('a request named by a notification is marked', (tester) async {
    await open(tester, initialRequestId: 'b');
    await push(tester, [
      req('a', 'pending', 'Mohit Saxena'),
      req('b', 'pending', 'Aditi Rao'),
    ]);

    expect(find.byKey(const Key('highlighted-request')), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('highlighted-request')), matching: find.text('Aditi Rao')),
      findsOneWidget,
    );
  });

  testWidgets('a notification can name a request that is already done', (tester) async {
    await open(tester, initialRequestId: 'c');
    await push(tester, [req('a', 'pending', 'Mohit Saxena'), req('c', 'confirmed', 'Rohan Mehta')]);

    expect(find.text('Rohan Mehta'), findsOneWidget, reason: 'switched to All so it can be found');
  });

  testWidgets('says so when there are none', (tester) async {
    await open(tester);
    await push(tester, const []);

    expect(find.text('No enrollment requests yet'), findsOneWidget);
  });

  testWidgets('says so when the filter is empty', (tester) async {
    await open(tester);
    await push(tester, [req('b', 'bill_sent', 'Karan Singh')]);

    await tapChip(tester, 'Done');

    expect(find.text('Nothing here'), findsOneWidget);
  });

  testWidgets('a failed load can be retried', (tester) async {
    await open(tester);
    source.controller.addError(Exception('denied'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load requests."), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(source.watches, 2);
  });

  testWidgets('explains when no business is linked yet', (tester) async {
    await open(tester, businessId: null);

    expect(find.text('No business found'), findsOneWidget);
  });
}
