import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/profile/billing_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:models/business/property/property_model.dart';

import '../../support/property_fixtures.dart';
import '../../unit/view_models/business_dashboard_viewmodel_test.mocks.dart';

Property prop(String id, String name, String billing, {String status = 'active'}) =>
    makeProperty(id: id, name: name, status: status).copyWith(
      billingStatus: billing,
      billedBedCount: 19,
      pricePerBed: 30,
      nextBillingDate: DateTime(2026, 11, 14),
    );

void main() {
  late MockPropertyRepository repo;
  late List<String> opened;

  setUp(() {
    repo = MockPropertyRepository();
    opened = [];
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: BizTheme.light(),
        home: BillingOverviewScreen(
          businessId: 'BUS1',
          repository: repo,
          onOpen: (context, p) => opened.add(p.id!),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('shows the monthly total and what needs attention', (tester) async {
    when(repo.getPropertiesByBusiness('BUS1')).thenAnswer((_) async => [
          prop('a', 'Sunrise', 'paid'),
          prop('b', 'Lotus', 'due'),
        ]);
    await open(tester);

    expect(find.text('₹1,140'), findsOneWidget);
    expect(find.text('1 property needs your attention'), findsOneWidget);
    expect(find.text('Payment due'), findsOneWidget);
    expect(find.text('Billing active'), findsOneWidget);
    expect(find.text('₹570 / month · next 14 Nov 2026'), findsNWidgets(2));
  });

  testWidgets('says everything is paid when it is', (tester) async {
    when(repo.getPropertiesByBusiness('BUS1')).thenAnswer((_) async => [prop('a', 'Sunrise', 'paid')]);
    await open(tester);

    expect(find.text('Everything is paid up'), findsOneWidget);
  });

  testWidgets('a draft shows as not activated and is left out of the total', (tester) async {
    when(repo.getPropertiesByBusiness('BUS1')).thenAnswer((_) async => [
          prop('g', 'Green Valley', 'payment_due', status: 'draft'),
        ]);
    await open(tester);

    expect(find.text('Not activated yet'), findsOneWidget);
    expect(find.text('₹0'), findsOneWidget);
  });

  testWidgets('tapping a property opens it', (tester) async {
    when(repo.getPropertiesByBusiness('BUS1')).thenAnswer((_) async => [prop('b', 'Lotus', 'due')]);
    await open(tester);

    await tester.tap(find.text('Lotus'));
    await tester.pumpAndSettle();

    expect(opened, ['b']);
  });

  testWidgets('says so when there are no properties', (tester) async {
    when(repo.getPropertiesByBusiness('BUS1')).thenAnswer((_) async => []);
    await open(tester);

    expect(find.text('No properties yet'), findsOneWidget);
  });

  testWidgets('a failed load can be retried', (tester) async {
    when(repo.getPropertiesByBusiness('BUS1')).thenThrow(Exception('denied'));
    await open(tester);
    expect(find.text("Couldn't load your properties."), findsOneWidget);

    when(repo.getPropertiesByBusiness('BUS1')).thenAnswer((_) async => [prop('a', 'Sunrise', 'paid')]);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Sunrise'), findsOneWidget);
  });
}
