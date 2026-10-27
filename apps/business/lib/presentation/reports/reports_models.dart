// lib/presentation/reports/reports_models.dart
import 'package:models/business/property/property_model.dart';

/// How far back the Reports tab looks.
enum ReportRange {
  thisMonth(1, 'This month'),
  last3(3, 'Last 3 months'),
  last6(6, 'Last 6 months');

  const ReportRange(this.months, this.label);

  final int months;
  final String label;
}

/// One rent invoice, reduced to what reports need.
class ReportInvoice {
  const ReportInvoice({
    required this.tenantId,
    required this.tenantName,
    required this.propertyId,
    required this.periodMonth,
    required this.amount,
    required this.status,
    this.dueDate,
    this.mode,
  });

  final String tenantId;
  final String tenantName;
  final String propertyId;

  /// `YYYY-MM`.
  final String periodMonth;
  final double amount;

  /// `paid`, `unpaid` or `overdue`.
  final String status;
  final DateTime? dueDate;

  /// How a paid invoice was settled (free text written by the backend).
  final String? mode;

  bool get isPaid => status == 'paid';
}

class ReportProperty {
  const ReportProperty({
    required this.id,
    required this.name,
    required this.totalBeds,
    required this.occupiedBeds,
  });

  /// [occupiedBeds] here comes from the property's stored counter, which can
  /// be out of date; the source replaces it with a count of active tenants.
  factory ReportProperty.fromProperty(Property p) => ReportProperty(
        id: p.id ?? '',
        name: p.name,
        totalBeds: p.totals.beds,
        occupiedBeds: (p.totals.beds - p.totals.availableBeds).clamp(0, p.totals.beds),
      );

  final String id;
  final String name;
  final int totalBeds;
  final int occupiedBeds;

  ReportProperty withOccupiedBeds(int beds) => ReportProperty(
        id: id,
        name: name,
        totalBeds: totalBeds,
        occupiedBeds: beds.clamp(0, totalBeds),
      );
}

/// Everything the source hands over; the calculator does the arithmetic.
class ReportsData {
  const ReportsData({required this.properties, required this.invoices});

  final List<ReportProperty> properties;
  final List<ReportInvoice> invoices;
}

class ReportsSummary {
  const ReportsSummary({
    required this.billed,
    required this.collected,
    required this.pending,
    required this.overdueAmount,
    required this.overdueCount,
    required this.invoiceCount,
  });

  final double billed;
  final double collected;

  /// Unpaid but not yet late.
  final double pending;
  final double overdueAmount;
  final int overdueCount;
  final int invoiceCount;

  /// 0..1 share of what was billed that has been collected.
  double get rate => billed > 0 ? (collected / billed).clamp(0.0, 1.0) : 0;
}

class MonthPoint {
  const MonthPoint({
    required this.period,
    required this.label,
    required this.longLabel,
    required this.billed,
    required this.collected,
  });

  final String period;

  /// `Oct`.
  final String label;

  /// `October 2026`.
  final String longLabel;
  final double billed;
  final double collected;

  double get rate => billed > 0 ? (collected / billed).clamp(0.0, 1.0) : 0;
}

class PropertyReport {
  const PropertyReport({
    required this.id,
    required this.name,
    required this.totalBeds,
    required this.occupiedBeds,
    required this.billed,
    required this.collected,
    required this.overdueCount,
  });

  final String id;
  final String name;
  final int totalBeds;
  final int occupiedBeds;
  final double billed;
  final double collected;
  final int overdueCount;

  double get occupancy => totalBeds > 0 ? occupiedBeds / totalBeds : 0;
  double get rate => billed > 0 ? (collected / billed).clamp(0.0, 1.0) : 0;
}

class PayMode {
  const PayMode({required this.label, required this.amount, required this.share});

  final String label;
  final double amount;

  /// 0..1 of everything collected.
  final double share;
}

class OverdueTenant {
  const OverdueTenant({
    required this.tenantId,
    required this.name,
    required this.amount,
    required this.invoices,
    required this.daysLate,
  });

  final String tenantId;
  final String name;
  final double amount;
  final int invoices;

  /// Days since the oldest unpaid invoice was due.
  final int daysLate;
}

class ReportResult {
  const ReportResult({
    required this.summary,
    required this.months,
    required this.properties,
    required this.modes,
    required this.overdue,
    required this.totalBeds,
    required this.occupiedBeds,
  });

  final ReportsSummary summary;
  final List<MonthPoint> months;
  final List<PropertyReport> properties;
  final List<PayMode> modes;
  final List<OverdueTenant> overdue;
  final int totalBeds;
  final int occupiedBeds;

  bool get hasInvoices => summary.invoiceCount > 0;
  double get occupancy => totalBeds > 0 ? occupiedBeds / totalBeds : 0;
}
