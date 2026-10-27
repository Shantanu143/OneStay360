// lib/presentation/view_models/tenant_wizard/first_bill.dart
import 'dart:math' as math;

class BillRow {
  const BillRow(this.label, this.amount, {this.note, this.isTotal = false});

  final String label;
  final double amount;
  final String? note;
  final bool isTotal;
}

/// What a new tenant owes up front.
///
/// Rules (carried over from the original Add Tenant screen):
///  * If food is not included, the monthly food deduction comes off the rent.
///  * Move-in on the 1st-15th pays the full (adjusted) month; the 16th or later
///    pays half. The owner can override the figure.
///  * The full security deposit is due now unless deferred.
///  * One-time maintenance is not charged up front; it is taken from the
///    deposit refund when the tenant leaves.
class FirstBill {
  const FirstBill({
    required this.monthlyRent,
    required this.deposit,
    required this.maintenance,
    required this.foodIncluded,
    required this.foodDeduction,
    required this.depositNow,
    required this.maintenanceDeductedFromDeposit,
    this.moveIn,
    this.proratedOverride,
  });

  final double monthlyRent;
  final double deposit;
  final double maintenance;
  final bool foodIncluded;
  final double foodDeduction;
  final bool depositNow;
  final bool maintenanceDeductedFromDeposit;
  final DateTime? moveIn;

  /// Owner-entered prorated rent; null uses the rule.
  final double? proratedOverride;

  double get foodDeductionApplied =>
      foodIncluded ? 0 : math.max(0, foodDeduction);

  double get adjustedMonthlyRent =>
      math.max(0, monthlyRent - foodDeductionApplied);

  bool get isHalfMonth => moveIn != null && moveIn!.day >= 16;

  double get autoProratedRent =>
      isHalfMonth ? adjustedMonthlyRent / 2 : adjustedMonthlyRent;

  double get proratedRent => proratedOverride ?? autoProratedRent;

  String? get prorationNote {
    final d = moveIn;
    if (d == null) return null;
    final when = '${d.day}/${d.month}/${d.year}';
    return d.day <= 15
        ? 'Full month rent (move-in on $when, between the 1st and 15th)'
        : 'Half month rent (move-in on $when, from the 16th)';
  }

  double get total => proratedRent + (depositNow ? deposit : 0);

  List<BillRow> get rows => [
    BillRow('Monthly rent', monthlyRent),
    if (!foodIncluded) ...[
      BillRow(
        'Less: food not included',
        foodDeductionApplied,
        note: 'Deducted from monthly rent',
      ),
      BillRow('Adjusted monthly rent', adjustedMonthlyRent),
    ],
    BillRow(
      isHalfMonth ? 'Prorated rent (half month)' : 'Prorated rent (full month)',
      proratedRent,
      note: proratedOverride != null ? 'Edited by you' : null,
    ),
    depositNow
        ? BillRow('Security deposit', deposit)
        : const BillRow('Security deposit', 0, note: 'Pay later'),
    if (maintenance > 0)
      BillRow(
        'Maintenance',
        0,
        note: maintenanceDeductedFromDeposit
            ? '₹${maintenance.toStringAsFixed(0)} is taken from the deposit refund when they leave'
            : '₹${maintenance.toStringAsFixed(0)} is taken from the refund when they leave',
      )
    else
      const BillRow('Maintenance', 0, note: 'None'),
    BillRow('Total due now', total, isTotal: true),
  ];
}
