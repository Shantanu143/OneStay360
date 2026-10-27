import 'dart:async';

import 'package:business/app/business_shell.dart';
import 'package:business/app/refresh_signals.dart';
import 'package:business/data/providers/business_state_provider.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/reports/reports_models.dart';
import 'package:business/presentation/reports/reports_source.dart';
import 'package:business/presentation/reports/reports_tab.dart';
import 'package:business/presentation/reports/reports_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/session_fixtures.dart';

class FakeSource implements ReportsSource {
  FakeSource(this.data);

  ReportsData data;
  Object? failure;
  Completer<void>? gate;
  int loads = 0;

  @override
  Future<ReportsData> load(String businessId, List<String> periods) async {
    loads++;
    await gate?.future;
    if (failure != null) throw failure!;
    return data;
  }
}

ReportInvoice inv(
  String tenant,
  String property,
  String period,
  double amount, {
  String status = 'unpaid',
  DateTime? due,
  String? mode,
  String? name,
}) =>
    ReportInvoice(
      tenantId: tenant,
      tenantName: name ?? 'Tenant $tenant',
      propertyId: property,
      periodMonth: period,
      amount: amount,
      status: status,
      dueDate: due,
      mode: mode,
    );

ReportsData fixture() => ReportsData(
      properties: const [
        ReportProperty(id: 'P1', name: 'Sunrise Heights', totalBeds: 20, occupiedBeds: 12),
        ReportProperty(id: 'P2', name: 'Green Nest', totalBeds: 10, occupiedBeds: 5),
      ],
      invoices: [
        inv('t1', 'P1', '2026-10', 10000, status: 'paid', mode: 'upi'),
        inv('t2', 'P1', '2026-10', 8000, due: DateTime(2026, 10, 31)),
        inv('t3', 'P2', '2026-10', 9000, status: 'overdue', due: DateTime(2026, 10, 5), name: 'Asha Verma'),
        inv('t4', 'P2', '2026-10', 7000, due: DateTime(2026, 10, 10), name: 'Ravi Kulkarni'),
        inv('t1', 'P1', '2026-09', 10000, status: 'paid', mode: 'cash'),
        inv('t2', 'P1', '2026-09', 8000, status: 'paid', mode: 'razorpay'),
        inv('t3', 'P2', '2026-09', 9000, status: 'paid', mode: 'upi'),
        inv('t1', 'P1', '2026-08', 10000, status: 'paid', mode: 'cash'),
      ],
    );

void main() {
  late FakeSource source;
  late RefreshSignals signals;
  late ShellController shell;
  late List<String> calls;

  setUp(() {
    source = FakeSource(fixture());
    signals = RefreshSignals();
    shell = ShellController();
    calls = [];
  });

  tearDown(() {
    signals.dispose();
    shell.dispose();
  });

  Future<void> pumpTab(WidgetTester tester, {bool settle = true}) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final provider = await readyProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BusinessStateProvider>.value(value: provider),
          Provider<RefreshSignals>.value(value: signals),
          ChangeNotifierProvider<ShellController>.value(value: shell),
        ],
        child: MaterialApp(
          theme: BizTheme.light(),
          home: Scaffold(
            body: ReportsTab(
              source: source,
              clock: () => DateTime(2026, 10, 26, 10),
              onProfile: (_) => calls.add('profile'),
              onOpenProperty: (_, id) => calls.add('open:$id'),
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pump();
      await tester.pumpAndSettle();
    }
  }

  Future<void> chooseRange(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('this month', () {
    testWidgets('shows what was collected out of what was billed', (tester) async {
      await pumpTab(tester);

      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('17 of 30 beds filled'), findsOneWidget);
      expect(find.text('₹10,000'), findsWidgets);
      expect(find.text('of ₹34,000 billed'), findsOneWidget);
      expect(find.text('29.4% collected'), findsOneWidget);
      expect(find.text('Still to come in'), findsOneWidget);
      expect(find.text('₹8,000'), findsOneWidget);
      expect(find.text('Overdue · 2 invoices'), findsOneWidget);
      expect(find.text('₹16,000'), findsWidgets);
    });

    testWidgets('lists each property with beds and rent', (tester) async {
      await pumpTab(tester);

      expect(find.text('Sunrise Heights'), findsOneWidget);
      expect(find.text('12 of 20 beds filled · 60.0%'), findsOneWidget);
      expect(find.text('₹10,000 of ₹18,000 collected'), findsOneWidget);
      expect(find.text('Green Nest'), findsOneWidget);
      expect(find.text('2 overdue'), findsOneWidget);
    });

    testWidgets('names who owes the most, with how late', (tester) async {
      await pumpTab(tester);

      expect(find.text('Owing the most'.toUpperCase()), findsOneWidget);
      expect(find.text('Asha Verma'), findsOneWidget);
      expect(find.text('1 invoice · 21 days late'), findsOneWidget);
      expect(find.text('Ravi Kulkarni'), findsOneWidget);
    });

    testWidgets('the period pill in the hero is only as wide as its label', (tester) async {
      await pumpTab(tester);

      final label = find.descendant(of: find.byType(ReportsHero), matching: find.text('This month'));
      final pill = find.ancestor(of: label, matching: find.byType(Container)).first;

      expect(tester.getSize(pill).width, lessThan(200));
    });

    testWidgets('has no month chart for a single month', (tester) async {
      await pumpTab(tester);

      expect(find.text('Collections by month'), findsNothing);
    });
  });

  group('choosing a range', () {
    testWidgets('three months adds up the months and shows the chart', (tester) async {
      await pumpTab(tester);

      await chooseRange(tester, 'Last 3 months');

      expect(find.text('₹47,000'), findsWidgets);
      expect(find.text('of ₹71,000 billed'), findsOneWidget);
      expect(find.text('Collections by month'), findsOneWidget);
      for (final m in ['Aug', 'Sep', 'Oct']) {
        expect(find.text(m), findsOneWidget);
      }
      expect(source.loads, 1, reason: 'the range is worked out from what is already loaded');
    });

    testWidgets('the newest month is read out first', (tester) async {
      await pumpTab(tester);
      await chooseRange(tester, 'Last 3 months');

      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('₹10,000 collected of ₹34,000 · 29.4%'), findsOneWidget);
    });

    testWidgets('tapping a month reads out that month', (tester) async {
      await pumpTab(tester);
      await chooseRange(tester, 'Last 3 months');

      await tester.tap(find.text('Sep'));
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('₹27,000 collected of ₹27,000 · 100%'), findsOneWidget);
    });

    testWidgets('every month has a bar a screen reader can describe, even one with nothing billed', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTab(tester);
      await chooseRange(tester, 'Last 6 months');

      expect(find.bySemanticsLabel('October 2026: ₹10,000 collected of ₹34,000 billed'), findsOneWidget);
      expect(find.bySemanticsLabel('May 2026: ₹0 collected of ₹0 billed'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a month with no rent billed says so', (tester) async {
      await pumpTab(tester);
      await chooseRange(tester, 'Last 6 months');

      await tester.tap(find.text('May'));
      await tester.pumpAndSettle();

      expect(find.text('No rent was billed this month.'), findsOneWidget);
    });

    testWidgets('shows how tenants paid over the range, biggest first', (tester) async {
      await pumpTab(tester);
      await chooseRange(tester, 'Last 3 months');

      expect(find.text('How tenants paid'.toUpperCase()), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('₹20,000'), findsOneWidget);
      expect(find.text('UPI'), findsOneWidget);
      expect(find.text('Razorpay'), findsOneWidget);
    });
  });

  group('loading', () {
    testWidgets('shows the range chips and placeholders until the numbers arrive', (tester) async {
      source.gate = Completer<void>();
      await pumpTab(tester, settle: false);
      await tester.pump();

      expect(find.text('This month'), findsOneWidget);
      expect(find.text('Rent collected'), findsNothing);

      source.gate!.complete();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Rent collected'), findsOneWidget);
    });

    testWidgets('a failure says so and the retry works', (tester) async {
      source.failure = Exception('denied');
      await pumpTab(tester);

      expect(find.text("Couldn't load your reports."), findsOneWidget);

      source.failure = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load your reports."), findsNothing);
      expect(find.text('Rent collected'), findsOneWidget);
    });
  });

  group('when there is little to show', () {
    testWidgets('a business with nothing yet gets a plain message', (tester) async {
      source.data = const ReportsData(properties: [], invoices: []);
      await pumpTab(tester);

      expect(find.text('No reports yet'), findsOneWidget);
    });

    testWidgets('properties without invoices still show beds, and say no rent was billed', (tester) async {
      source.data = ReportsData(properties: fixture().properties, invoices: const []);
      await pumpTab(tester);

      expect(find.text('No rent invoices in this period yet.'), findsOneWidget);
      expect(find.text('Sunrise Heights'), findsOneWidget);
      expect(find.text('No rent billed'), findsNWidgets(2));
      expect(find.text('How tenants paid'.toUpperCase()), findsNothing);
      expect(find.text('Owing the most'.toUpperCase()), findsNothing);
    });

    testWidgets('invoices of a property that no longer exists still count, under "Other"', (tester) async {
      source.data = ReportsData(properties: const [], invoices: [inv('t9', 'gone', '2026-10', 500, status: 'paid', mode: 'cash')]);
      await pumpTab(tester);

      expect(find.text('Other'), findsWidgets);
      expect(find.text('₹500 of ₹500 collected'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('a property opens its page', (tester) async {
      await pumpTab(tester);

      await tester.tap(find.text('Sunrise Heights'));
      await tester.pumpAndSettle();

      expect(calls, ['open:P1']);
    });

    testWidgets('the "Other" row is not a link', (tester) async {
      source.data = ReportsData(properties: const [], invoices: [inv('t9', 'gone', '2026-10', 500, status: 'paid', mode: 'cash')]);
      await pumpTab(tester);

      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
    });

    testWidgets('the avatar opens the profile', (tester) async {
      await pumpTab(tester);

      await tester.tap(find.text('RS'));
      await tester.pumpAndSettle();

      expect(calls, ['profile']);
    });
  });

  group('staying up to date', () {
    testWidgets('reloads when a payment is recorded while the tab is showing', (tester) async {
      shell.goTo(ShellTab.reports);
      await pumpTab(tester);
      expect(source.loads, 1);

      source.data = ReportsData(properties: fixture().properties, invoices: const []);
      signals.paymentsChanged();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(source.loads, 2);
      expect(find.text('No rent invoices in this period yet.'), findsOneWidget);
    });

    testWidgets('waits until the tab is shown when the change happened elsewhere', (tester) async {
      await pumpTab(tester);
      expect(shell.current, ShellTab.home);

      signals.tenantsChanged();
      await tester.pump();
      expect(source.loads, 1);

      shell.goTo(ShellTab.reports);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(source.loads, 2);
    });

    testWidgets('does not reload just from switching back when nothing changed', (tester) async {
      await pumpTab(tester);

      shell.goTo(ShellTab.reports);
      await tester.pump();

      expect(source.loads, 1);
    });

    testWidgets('a failed refresh keeps the numbers and says they are old', (tester) async {
      shell.goTo(ShellTab.reports);
      await pumpTab(tester);

      source.failure = Exception('offline');
      signals.paymentsChanged();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text("Couldn't refresh. Showing the numbers from earlier."), findsOneWidget);
      expect(find.text('of ₹34,000 billed'), findsOneWidget);
    });
  });
}
