import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:business/presentation/view_models/business_dashboard_viewmodel.dart';
import 'package:business/presentation/views/home/collections_card.dart';
import 'package:business/presentation/views/home/home_format.dart';
import 'package:business/presentation/views/home/home_sheets.dart';
import 'package:business/presentation/views/home/needs_attention_card.dart';
import 'package:business/presentation/views/widgets/floating_nav_bar.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('formatting', () {
    test('formatInr uses Indian digit grouping', () {
      expect(formatInr(482500), '₹4,82,500');
      expect(formatInr(37500), '₹37,500');
      expect(formatInr(1234567), '₹12,34,567');
      expect(formatInr(0), '₹0');
    });

    test('formatPercent keeps one decimal with clean ends', () {
      expect(formatPercent(0.928), '92.8%');
      expect(formatPercent(0.942), '94.2%');
      expect(formatPercent(1), '100%');
      expect(formatPercent(0), '0%');
      expect(formatPercent(1.7), '100%');
    });

    test('names and initials', () {
      expect(firstNameOf('Rajesh Sharma'), 'Rajesh');
      expect(firstNameOf('  '), '');
      expect(initialsOf('Rajesh Sharma'), 'RS');
      expect(initialsOf('rajesh'), 'R');
      expect(initialsOf('Anil Kumar Verma'), 'AV');
      expect(initialsOf(''), '');
    });

    test('daysLeftLabel counts to the end of the month', () {
      expect(daysLeftLabel(DateTime(2026, 10, 15)), '16 days left');
      expect(daysLeftLabel(DateTime(2026, 10, 30)), '1 day left');
      expect(daysLeftLabel(DateTime(2026, 10, 31)), 'Last day');
      expect(daysLeftLabel(DateTime(2028, 2, 28)), '1 day left'); // leap year
    });
  });

  group('reminders', () {
    test('whatsappNumber normalises Indian numbers', () {
      expect(whatsappNumber('98765 43210'), '919876543210');
      expect(whatsappNumber('+91 98765-43210'), '919876543210');
      expect(whatsappNumber('09876543210'), '919876543210');
      expect(whatsappNumber('12345'), isNull);
      expect(whatsappNumber(''), isNull);
    });

    test('reminderMessage mentions the amount, month and sender', () {
      final due = RentDue(
        tenantId: 'T1',
        tenantName: 'Amit Patel',
        phone: '9876543210',
        amount: 8500,
        month: 'October 2026',
        dueDate: DateTime(2026, 10, 6),
        overdue: true,
      );
      final message = reminderMessage(due, 'Apex Living & Stays');

      expect(message, contains('Hi Amit'));
      expect(message, contains('₹8,500'));
      expect(message, contains('October 2026'));
      expect(message, contains('6 Oct'));
      expect(message, contains('Apex Living & Stays'));
    });

    test('whatsappUri url-encodes the message', () {
      final uri = whatsappUri('919876543210', 'Pay ₹500 & thanks');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/919876543210');
      expect(uri.queryParameters['text'], 'Pay ₹500 & thanks');
    });
  });

  group('CollectionsCard', () {
    Widget card({
      bool loading = false,
      int overdue = 4,
      VoidCallback? onSend,
    }) => _host(
      CollectionsCard(
        loading: loading,
        title: 'October collections',
        daysLeft: '16 days left',
        target: 520000,
        collected: 482500,
        pending: 37500,
        overdueCount: overdue,
        progress: 482500 / 520000,
        onSendReminders: onSend ?? () {},
      ),
    );

    testWidgets('settles on the final figures after counting up', (
      tester,
    ) async {
      await tester.pumpWidget(card());
      await tester.pumpAndSettle();

      expect(find.text('October collections'), findsOneWidget);
      expect(find.text('16 days left'), findsOneWidget);
      expect(find.text('₹4,82,500'), findsOneWidget);
      expect(find.text('collected of ₹5,20,000'), findsOneWidget);
      expect(find.text('92.8%'), findsOneWidget);
      expect(find.text('₹37,500'), findsOneWidget);
      expect(find.text('4 invoices'), findsOneWidget);
    });

    testWidgets('counts up instead of jumping to the value', (tester) async {
      await tester.pumpWidget(card());
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('₹4,82,500'), findsNothing);
      expect(find.text('92.8%'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('₹4,82,500'), findsOneWidget);
    });

    testWidgets('shows placeholders while loading', (tester) async {
      await tester.pumpWidget(card(loading: true));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('₹4,82,500'), findsNothing);
      expect(find.text('92.8%'), findsNothing);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('overdue tile reads "All clear" with nothing overdue', (
      tester,
    ) async {
      await tester.pumpWidget(card(overdue: 0));
      await tester.pumpAndSettle();

      expect(find.text('All clear'), findsOneWidget);
      expect(find.textContaining('invoice'), findsNothing);
    });

    testWidgets('send reminders button fires the callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(card(onSend: () => taps++));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send reminders'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });
  });

  group('NeedsAttentionCard', () {
    AttentionItem item(String title, VoidCallback onTap) => AttentionItem(
      icon: Icons.event_outlined,
      color: Colors.blue,
      title: title,
      subtitle: 'subtitle for $title',
      onTap: onTap,
    );

    testWidgets('lists items and routes taps', (tester) async {
      String? tapped;
      await tester.pumpWidget(
        _host(
          NeedsAttentionCard(
            loading: false,
            items: [
              item('3 leases end this week', () => tapped = 'leases'),
              item('6 beds vacant', () => tapped = 'beds'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 leases end this week'), findsOneWidget);
      expect(find.text('6 beds vacant'), findsOneWidget);

      await tester.tap(find.text('6 beds vacant'));
      await tester.pumpAndSettle();
      expect(tapped, 'beds');
    });

    testWidgets('says so when nothing needs attention', (tester) async {
      await tester.pumpWidget(
        _host(const NeedsAttentionCard(loading: false, items: [])),
      );
      await tester.pumpAndSettle();

      expect(find.text("You're all caught up"), findsOneWidget);
    });

    testWidgets('swaps placeholders for rows once loaded', (tester) async {
      Widget build(bool loading) => _host(
        NeedsAttentionCard(
          loading: loading,
          items: [item('6 beds vacant', () {})],
        ),
      );

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('6 beds vacant'), findsNothing);

      await tester.pumpWidget(build(false));
      // Placeholders pulse forever, so settle by time, not by pumpAndSettle.
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('6 beds vacant'), findsOneWidget);
    });
  });

  group('FloatingNavBar', () {
    const items = [
      FloatingNavItem(icon: Icons.home_outlined, label: 'Home'),
      FloatingNavItem(icon: Icons.apartment_outlined, label: 'Properties'),
      FloatingNavItem(icon: Icons.people_outline_rounded, label: 'Tenants'),
      FloatingNavItem(icon: Icons.show_chart_rounded, label: 'Finances'),
    ];

    Widget bar({
      int selected = 0,
      ValueChanged<int>? onSelected,
      Future<void> Function()? onQuickAdd,
    }) => MaterialApp(
      home: Scaffold(
        bottomNavigationBar: FloatingNavBar(
          items: items,
          selectedIndex: selected,
          onSelected: onSelected ?? (_) {},
          onQuickAdd: onQuickAdd,
        ),
      ),
    );

    testWidgets('shows every tab label and reports taps by index', (
      tester,
    ) async {
      int? picked;
      await tester.pumpWidget(bar(onSelected: (i) => picked = i));
      await tester.pumpAndSettle();

      for (final item in items) {
        expect(find.text(item.label), findsOneWidget);
      }

      await tester.tap(find.text('Tenants'));
      await tester.pumpAndSettle();
      expect(picked, 2);
    });

    testWidgets('has no "+" button unless quick add is provided', (
      tester,
    ) async {
      await tester.pumpWidget(bar());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.add_rounded), findsNothing);

      await tester.pumpWidget(bar(onQuickAdd: () async {}));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('the "+" rotates while its sheet is open, then returns', (
      tester,
    ) async {
      final dismissed = Completer<void>();
      await tester.pumpWidget(bar(onQuickAdd: () => dismissed.future));
      await tester.pumpAndSettle();

      double turns() =>
          tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns;
      expect(turns(), 0);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(turns(), 0.125);

      dismissed.complete();
      await tester.pumpAndSettle();
      expect(turns(), 0);
    });

    testWidgets('no tab is highlighted when the screen is not a tab', (
      tester,
    ) async {
      await tester.pumpWidget(bar(selected: -1));
      await tester.pumpAndSettle();

      final selected = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.selected == true);
      expect(selected, isEmpty);
    });
  });
}
