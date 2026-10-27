// lib/presentation/reports/reports_calculator.dart
//
// Pure arithmetic for the Reports tab: no Firebase, no widgets.
import 'package:intl/intl.dart';

import 'reports_models.dart';

/// `YYYY-MM` for the last [months] months up to and including [now]'s,
/// oldest first.
List<String> reportPeriods(DateTime now, int months) => [
      for (var i = months - 1; i >= 0; i--) _period(DateTime(now.year, now.month - i, 1)),
    ];

String _period(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// Groups the free-text `mode` the backend stores into a few readable names.
String payModeLabel(String? mode) {
  final m = (mode ?? '').trim().toLowerCase();
  if (m.contains('razorpay') || m == 'online' || m == 'card') return 'Razorpay';
  if (m.contains('upi')) return 'UPI';
  if (m.contains('cash')) return 'Cash';
  if (m.contains('bank') || m.contains('transfer') || m.contains('neft') || m.contains('imps')) {
    return 'Bank transfer';
  }
  return 'Other';
}

const _otherProperty = 'Other';
const _topOverdue = 5;

ReportResult buildReport(
  ReportsData data, {
  required ReportRange range,
  required DateTime now,
}) {
  final periods = reportPeriods(now, range.months);
  final inRange = {for (final p in periods) p};
  final invoices = [for (final i in data.invoices) if (inRange.contains(i.periodMonth)) i];

  bool isOverdue(ReportInvoice i) =>
      !i.isPaid && (i.status == 'overdue' || (i.dueDate != null && i.dueDate!.isBefore(now)));

  var billed = 0.0, collected = 0.0, pending = 0.0, overdueAmount = 0.0;
  var overdueCount = 0;
  for (final i in invoices) {
    billed += i.amount;
    if (i.isPaid) {
      collected += i.amount;
    } else if (isOverdue(i)) {
      overdueAmount += i.amount;
      overdueCount++;
    } else {
      pending += i.amount;
    }
  }

  // Month by month, including months nobody was billed.
  final months = <MonthPoint>[
    for (final p in periods)
      () {
        final inMonth = invoices.where((i) => i.periodMonth == p);
        final date = DateTime(int.parse(p.substring(0, 4)), int.parse(p.substring(5)), 1);
        return MonthPoint(
          period: p,
          label: DateFormat('MMM').format(date),
          longLabel: DateFormat('MMMM y').format(date),
          billed: inMonth.fold(0.0, (s, i) => s + i.amount),
          collected: inMonth.where((i) => i.isPaid).fold(0.0, (s, i) => s + i.amount),
        );
      }(),
  ];

  // Per property; invoices of a property we don't know land under "Other".
  final known = {for (final p in data.properties) p.id};
  String keyOf(ReportInvoice i) => known.contains(i.propertyId) ? i.propertyId : '';
  final properties = <PropertyReport>[
    for (final p in data.properties)
      _propertyReport(p.id, p.name, p.totalBeds, p.occupiedBeds, invoices.where((i) => keyOf(i) == p.id), isOverdue),
  ];
  final strays = invoices.where((i) => keyOf(i).isEmpty).toList();
  if (strays.isNotEmpty) {
    properties.add(_propertyReport('', _otherProperty, 0, 0, strays, isOverdue));
  }
  properties.sort((a, b) {
    final byMoney = b.collected.compareTo(a.collected);
    return byMoney != 0 ? byMoney : a.name.compareTo(b.name);
  });

  // How the collected money arrived.
  final byMode = <String, double>{};
  for (final i in invoices.where((i) => i.isPaid)) {
    byMode.update(payModeLabel(i.mode), (v) => v + i.amount, ifAbsent: () => i.amount);
  }
  final modes = [
    for (final e in byMode.entries)
      PayMode(label: e.key, amount: e.value, share: collected > 0 ? e.value / collected : 0),
  ]..sort((a, b) {
      final byAmount = b.amount.compareTo(a.amount);
      return byAmount != 0 ? byAmount : a.label.compareTo(b.label);
    });

  // Who owes the most.
  final today = DateTime(now.year, now.month, now.day);
  final owing = <String, List<ReportInvoice>>{};
  for (final i in invoices.where(isOverdue)) {
    owing.putIfAbsent(i.tenantId, () => []).add(i);
  }
  final overdue = <OverdueTenant>[
    for (final e in owing.entries)
      OverdueTenant(
        tenantId: e.key,
        name: e.value.first.tenantName,
        amount: e.value.fold(0.0, (s, i) => s + i.amount),
        invoices: e.value.length,
        daysLate: e.value
            .map((i) => i.dueDate == null ? 0 : today.difference(DateTime(i.dueDate!.year, i.dueDate!.month, i.dueDate!.day)).inDays)
            .fold(0, (a, b) => a > b ? a : b),
      ),
  ]..sort((a, b) => b.amount.compareTo(a.amount));

  return ReportResult(
    summary: ReportsSummary(
      billed: billed,
      collected: collected,
      pending: pending,
      overdueAmount: overdueAmount,
      overdueCount: overdueCount,
      invoiceCount: invoices.length,
    ),
    months: months,
    properties: properties,
    modes: modes,
    overdue: overdue.take(_topOverdue).toList(),
    totalBeds: data.properties.fold(0, (s, p) => s + p.totalBeds),
    occupiedBeds: data.properties.fold(0, (s, p) => s + p.occupiedBeds),
  );
}

PropertyReport _propertyReport(
  String id,
  String name,
  int totalBeds,
  int occupiedBeds,
  Iterable<ReportInvoice> invoices,
  bool Function(ReportInvoice) isOverdue,
) {
  var billed = 0.0, collected = 0.0;
  var late = 0;
  for (final i in invoices) {
    billed += i.amount;
    if (i.isPaid) {
      collected += i.amount;
    } else if (isOverdue(i)) {
      late++;
    }
  }
  return PropertyReport(
    id: id,
    name: name,
    totalBeds: totalBeds,
    occupiedBeds: occupiedBeds,
    billed: billed,
    collected: collected,
    overdueCount: late,
  );
}
