import 'package:business/presentation/view_models/tenant_wizard/first_bill.dart';
import 'package:flutter_test/flutter_test.dart';

FirstBill bill({
  double rent = 6000,
  double deposit = 12000,
  double maintenance = 500,
  bool foodIncluded = true,
  double foodDeduction = 0,
  bool depositNow = true,
  bool maintenanceFromDeposit = false,
  DateTime? moveIn,
  double? override,
}) => FirstBill(
  monthlyRent: rent,
  deposit: deposit,
  maintenance: maintenance,
  foodIncluded: foodIncluded,
  foodDeduction: foodDeduction,
  depositNow: depositNow,
  maintenanceDeductedFromDeposit: maintenanceFromDeposit,
  moveIn: moveIn,
  proratedOverride: override,
);

void main() {
  group('proration', () {
    test('move-in on the 1st-15th pays the full month', () {
      expect(bill(moveIn: DateTime(2026, 10, 1)).autoProratedRent, 6000);
      expect(bill(moveIn: DateTime(2026, 10, 15)).autoProratedRent, 6000);
    });

    test('move-in on the 16th or later pays half', () {
      expect(bill(moveIn: DateTime(2026, 10, 16)).autoProratedRent, 3000);
      expect(bill(moveIn: DateTime(2026, 10, 31)).autoProratedRent, 3000);
    });

    test('no move-in date yet means a full month', () {
      expect(bill().autoProratedRent, 6000);
    });

    test('says which rule applied', () {
      expect(
        bill(moveIn: DateTime(2026, 10, 10)).prorationNote,
        contains('Full month'),
      );
      expect(
        bill(moveIn: DateTime(2026, 10, 20)).prorationNote,
        contains('Half month'),
      );
      expect(bill().prorationNote, isNull);
    });

    test('an owner override wins over the rule', () {
      final b = bill(moveIn: DateTime(2026, 10, 20), override: 4200);
      expect(b.proratedRent, 4200);
      expect(b.autoProratedRent, 3000);
    });

    test('a zero or missing rent gives a zero bill', () {
      expect(bill(rent: 0, depositNow: false).total, 0);
    });
  });

  group('food', () {
    test('food included means no deduction', () {
      final b = bill(foodIncluded: true, foodDeduction: 1500);
      expect(b.foodDeductionApplied, 0);
      expect(b.adjustedMonthlyRent, 6000);
    });

    test('food excluded takes the deduction off the monthly rent first', () {
      final b = bill(
        foodIncluded: false,
        foodDeduction: 1500,
        moveIn: DateTime(2026, 10, 20),
      );
      expect(b.foodDeductionApplied, 1500);
      expect(b.adjustedMonthlyRent, 4500);
      expect(b.autoProratedRent, 2250); // half of the adjusted rent
    });

    test('the deduction can never push rent below zero', () {
      final b = bill(rent: 1000, foodIncluded: false, foodDeduction: 5000);
      expect(b.adjustedMonthlyRent, 0);
    });
  });

  group('total', () {
    test('adds the full deposit when paid now', () {
      expect(
        bill(moveIn: DateTime(2026, 10, 5), depositNow: true).total,
        18000,
      );
    });

    test('leaves the deposit out when paid later', () {
      expect(
        bill(moveIn: DateTime(2026, 10, 5), depositNow: false).total,
        6000,
      );
    });

    test(
      'maintenance is never added up front (it is taken from the refund)',
      () {
        expect(bill(maintenance: 500, depositNow: false).total, 6000);
      },
    );
  });

  group('breakdown rows', () {
    test('lists each charge, then the total', () {
      final rows = bill(moveIn: DateTime(2026, 10, 5)).rows;
      expect(rows.map((r) => r.label).toList(), [
        'Monthly rent',
        'Prorated rent (full month)',
        'Security deposit',
        'Maintenance',
        'Total due now',
      ]);
      expect(rows.last.isTotal, isTrue);
      expect(rows.last.amount, 18000);
    });

    test('shows the food deduction rows only when food is excluded', () {
      final rows = bill(foodIncluded: false, foodDeduction: 1000).rows;
      final labels = rows.map((r) => r.label).toList();
      expect(labels, contains('Less: food not included'));
      expect(labels, contains('Adjusted monthly rent'));
    });

    test('marks a deferred deposit as pay later', () {
      final deposit = bill(
        depositNow: false,
      ).rows.firstWhere((r) => r.label == 'Security deposit');
      expect(deposit.amount, 0);
      expect(deposit.note, 'Pay later');
    });

    test('explains how maintenance is handled', () {
      final m = bill(
        maintenance: 500,
      ).rows.firstWhere((r) => r.label == 'Maintenance');
      expect(m.amount, 0);
      expect(m.note, contains('refund'));
    });

    test('shows a half-month label for late move-ins', () {
      final rows = bill(moveIn: DateTime(2026, 10, 20)).rows;
      expect(rows.map((r) => r.label), contains('Prorated rent (half month)'));
    });
  });
}
