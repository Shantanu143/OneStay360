import 'package:business/presentation/reports/reports_calculator.dart';
import 'package:business/presentation/reports/reports_models.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 10, 26, 10);

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

const sunrise = ReportProperty(id: 'P1', name: 'Sunrise Heights', totalBeds: 20, occupiedBeds: 12);
const nest = ReportProperty(id: 'P2', name: 'Green Nest', totalBeds: 10, occupiedBeds: 5);

ReportsData fixture() => ReportsData(
      properties: const [sunrise, nest],
      invoices: [
        // October
        inv('t1', 'P1', '2026-10', 10000, status: 'paid', mode: 'upi'),
        inv('t2', 'P1', '2026-10', 8000, due: DateTime(2026, 10, 31)),
        inv('t3', 'P2', '2026-10', 9000, status: 'overdue', due: DateTime(2026, 10, 5)),
        inv('t4', 'P2', '2026-10', 7000, due: DateTime(2026, 10, 10)),
        // September
        inv('t1', 'P1', '2026-09', 10000, status: 'paid', mode: 'cash'),
        inv('t2', 'P1', '2026-09', 8000, status: 'paid', mode: 'razorpay'),
        inv('t3', 'P2', '2026-09', 9000, status: 'paid', mode: 'upi'),
        // August
        inv('t1', 'P1', '2026-08', 10000, status: 'paid', mode: 'cash'),
        // Too old for any range
        inv('t1', 'P1', '2026-04', 99999, status: 'paid', mode: 'cash'),
      ],
    );

ReportResult report(ReportRange range, [ReportsData? data]) =>
    buildReport(data ?? fixture(), range: range, now: now);

void main() {
  group('periods', () {
    test('count back from the current month, oldest first', () {
      expect(reportPeriods(now, 3), ['2026-08', '2026-09', '2026-10']);
    });

    test('cross a year boundary', () {
      expect(reportPeriods(DateTime(2027, 1, 15), 3), ['2026-11', '2026-12', '2027-01']);
    });
  });

  group('this month', () {
    final r = report(ReportRange.thisMonth);

    test('totals what was billed, collected and is still due', () {
      expect(r.summary.billed, 34000);
      expect(r.summary.collected, 10000);
      expect(r.summary.pending, 8000, reason: 'due on the 31st, so not late yet');
      expect(r.summary.overdueAmount, 16000);
      expect(r.summary.overdueCount, 2);
      expect(r.summary.invoiceCount, 4);
      expect(r.summary.rate, closeTo(10000 / 34000, 1e-9));
    });

    test('counts an unpaid invoice past its due date as overdue even if never marked', () {
      expect(r.overdue.map((o) => o.tenantId), contains('t4'));
    });

    test('ignores invoices outside the range', () {
      expect(r.summary.billed, isNot(greaterThan(34000)));
    });
  });

  group('last 3 months', () {
    final r = report(ReportRange.last3);

    test('adds up the three months', () {
      expect(r.summary.billed, 71000);
      expect(r.summary.collected, 47000);
    });

    test('has one point per month, oldest first, including months with no invoices', () {
      expect(r.months.map((m) => m.period), ['2026-08', '2026-09', '2026-10']);
      expect(r.months.map((m) => m.label), ['Aug', 'Sep', 'Oct']);
      expect(r.months.map((m) => m.billed), [10000, 27000, 34000]);
      expect(r.months.map((m) => m.collected), [10000, 27000, 10000]);
    });

    test('a month nobody was billed has a zero rate rather than dividing by zero', () {
      final r6 = report(ReportRange.last6);
      final may = r6.months.firstWhere((m) => m.period == '2026-05');
      expect(may.billed, 0);
      expect(may.rate, 0);
    });

    test('splits what was collected by how it was paid, biggest first', () {
      expect(r.modes.map((m) => m.label), ['Cash', 'UPI', 'Razorpay']);
      expect(r.modes.map((m) => m.amount), [20000, 19000, 8000]);
      expect(r.modes.first.share, closeTo(20000 / 47000, 1e-9));
    });
  });

  group('by property', () {
    final r = report(ReportRange.thisMonth);

    test('shows each property with its own money and beds', () {
      final p1 = r.properties.firstWhere((p) => p.id == 'P1');
      expect(p1.name, 'Sunrise Heights');
      expect(p1.billed, 18000);
      expect(p1.collected, 10000);
      expect(p1.overdueCount, 0);
      expect(p1.occupiedBeds, 12);
      expect(p1.totalBeds, 20);
      expect(p1.occupancy, closeTo(0.6, 1e-9));
    });

    test('puts the one that collected most first', () {
      expect(r.properties.map((p) => p.id), ['P1', 'P2']);
    });

    test('keeps a property that has no invoices', () {
      final data = ReportsData(properties: const [sunrise, nest], invoices: [inv('t1', 'P1', '2026-10', 100)]);
      final res = report(ReportRange.thisMonth, data);
      final p2 = res.properties.firstWhere((p) => p.id == 'P2');
      expect(p2.billed, 0);
      expect(p2.rate, 0);
    });

    test('groups invoices of an unknown property under "Other" without losing the money', () {
      final data = ReportsData(properties: const [sunrise], invoices: [
        inv('t1', 'P1', '2026-10', 100, status: 'paid', mode: 'cash'),
        inv('t9', 'gone', '2026-10', 50, status: 'paid', mode: 'cash'),
        inv('t8', '', '2026-10', 25, status: 'paid', mode: 'cash'),
      ]);
      final res = report(ReportRange.thisMonth, data);
      expect(res.summary.collected, 175);
      final other = res.properties.firstWhere((p) => p.name == 'Other');
      expect(other.collected, 75);
    });

    test('totals the beds across properties', () {
      expect(r.totalBeds, 30);
      expect(r.occupiedBeds, 17);
      expect(r.occupancy, closeTo(17 / 30, 1e-9));
    });

    test('no beds means zero occupancy', () {
      final res = report(ReportRange.thisMonth, const ReportsData(properties: [], invoices: []));
      expect(res.occupancy, 0);
    });
  });

  group('who owes', () {
    test('lists the biggest dues first with how late they are', () {
      final r = report(ReportRange.thisMonth);
      expect(r.overdue.map((o) => o.tenantId), ['t3', 't4']);
      expect(r.overdue.first.amount, 9000);
      expect(r.overdue.first.daysLate, 21);
      expect(r.overdue.last.daysLate, 16);
    });

    test('adds up one tenant owing for several months', () {
      final data = ReportsData(properties: const [sunrise], invoices: [
        inv('t3', 'P1', '2026-10', 9000, status: 'overdue', due: DateTime(2026, 10, 5), name: 'Asha'),
        inv('t3', 'P1', '2026-09', 9000, status: 'overdue', due: DateTime(2026, 9, 5), name: 'Asha'),
      ]);
      final r = report(ReportRange.last3, data);
      expect(r.overdue, hasLength(1));
      expect(r.overdue.single.name, 'Asha');
      expect(r.overdue.single.amount, 18000);
      expect(r.overdue.single.invoices, 2);
      expect(r.overdue.single.daysLate, 51, reason: 'counted from the oldest unpaid invoice');
    });

    test('shows at most five', () {
      final data = ReportsData(properties: const [sunrise], invoices: [
        for (var i = 0; i < 8; i++)
          inv('t$i', 'P1', '2026-10', 1000.0 + i, status: 'overdue', due: DateTime(2026, 10, 1)),
      ]);
      expect(report(ReportRange.thisMonth, data).overdue, hasLength(5));
    });

    test('nobody owing means an empty list', () {
      final data = ReportsData(properties: const [sunrise], invoices: [
        inv('t1', 'P1', '2026-10', 100, status: 'paid', mode: 'cash'),
      ]);
      expect(report(ReportRange.thisMonth, data).overdue, isEmpty);
    });
  });

  group('payment mode names', () {
    test('are tidied into a few readable groups', () {
      expect(payModeLabel('razorpay'), 'Razorpay');
      expect(payModeLabel('Razorpay'), 'Razorpay');
      expect(payModeLabel('online'), 'Razorpay');
      expect(payModeLabel('upi'), 'UPI');
      expect(payModeLabel('UPI'), 'UPI');
      expect(payModeLabel('cash'), 'Cash');
      expect(payModeLabel('Cash'), 'Cash');
      expect(payModeLabel('bank'), 'Bank transfer');
      expect(payModeLabel('bank transfer'), 'Bank transfer');
      expect(payModeLabel('manual'), 'Other');
      expect(payModeLabel(null), 'Other');
      expect(payModeLabel(''), 'Other');
    });
  });

  group('empty', () {
    test('has no invoices and zero totals', () {
      final r = report(ReportRange.thisMonth, const ReportsData(properties: [sunrise], invoices: []));
      expect(r.hasInvoices, isFalse);
      expect(r.summary.billed, 0);
      expect(r.summary.rate, 0);
      expect(r.modes, isEmpty);
    });
  });
}
