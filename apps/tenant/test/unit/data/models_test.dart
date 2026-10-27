import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenant/data/models.dart';

void main() {
  group('TenantAccount', () {
    test('reads names, phones and favourites, whichever key was used', () {
      final a = TenantAccount.fromMap('uid1', {
        'tenantId': 'TEN0000001',
        'name': 'Asha Rao',
        'mobileNumber': '9811100001',
        'email': 'asha@example.test',
        'profileComplete': true,
        'favoritePropertyIds': ['P1', 'P2'],
      });
      expect(a.uid, 'uid1');
      expect(a.tenantId, 'TEN0000001');
      expect(a.name, 'Asha Rao');
      expect(a.phone, '9811100001');
      expect(a.profileComplete, isTrue);
      expect(a.favorites, {'P1', 'P2'});
    });

    test('ignores a tenant id that is blank', () {
      final a = TenantAccount.fromMap('uid1', {'tenantId': '', 'fullName': 'A'});
      expect(a.tenantId, isNull);
      expect(a.name, 'A');
      expect(a.profileComplete, isFalse);
    });
  });

  group('Stay', () {
    test('reads the stay the backend writes', () {
      final s = Stay.fromMap('S1', {
        'businessId': 'BUS1',
        'propertyId': 'P1',
        'propertyName': 'Green Nest',
        'roomId': 'R101',
        'roomNumber': '101',
        'bedId': '2',
        'bedNumber': '2',
        'monthlyRent': 9000,
        'checkInDate': Timestamp.fromDate(DateTime(2026, 2, 5)),
      });
      expect(s.businessId, 'BUS1');
      expect(s.roomLabel, 'Room 101 · Bed 2');
      expect(s.monthlyRent, 9000);
      expect(s.billingDay, 5);
    });

    test('falls back to ids when numbers are missing', () {
      final s = Stay.fromMap('S1', {'businessId': 'B', 'propertyId': 'P', 'roomId': 'R9', 'bedId': '1'});
      expect(s.roomLabel, 'Room R9 · Bed 1');
      expect(s.billingDay, isNull);
    });
  });

  group('EnrollmentRequest', () {
    test('reads a bill sent over UPI', () {
      final r = EnrollmentRequest.fromMap('E1', {
        'status': 'bill_sent',
        'propertyId': 'P1',
        'businessId': 'BUS1',
        'propertyName': 'Green Nest',
        'roomNumber': '101',
        'bedNumber': '2',
        'monthlyRent': 9000,
        'proratedRent': 4500,
        'depositAmount': 18000,
        'maintenanceAmount': 500,
        'totalBillAmount': 23000,
        'paymentMode': 'upi_manual',
        'ownerUpiId': 'owner@upi',
        'paymentRejectionReason': 'Not received',
      });
      expect(r.stage, EnrollmentStage.billSent);
      expect(r.total, 23000);
      expect(r.paymentMode, BillPaymentMode.upi);
      expect(r.ownerUpiId, 'owner@upi');
      expect(r.paymentRejectionReason, 'Not received');
      expect(r.lines.map((l) => l.label), ['Rent (first period)', 'Security deposit', 'Maintenance']);
    });

    test('totals deposit and advance when no total was stored', () {
      final r = EnrollmentRequest.fromMap('E1', {'status': 'bill_sent', 'depositAmount': 1000, 'advanceAmount': 500});
      expect(r.total, 1500);
      expect(r.lines.map((l) => l.label), ['Advance rent', 'Security deposit']);
    });

    test('reads bank details for a bank transfer bill', () {
      final r = EnrollmentRequest.fromMap('E1', {
        'status': 'bill_sent',
        'paymentMode': 'bank_transfer',
        'bankName': 'HDFC',
        'accountNumber': '0001',
        'ifscCode': 'HDFC0001',
        'accountHolderName': 'Owner',
      });
      expect(r.paymentMode, BillPaymentMode.bank);
      expect(r.bank!.ifscCode, 'HDFC0001');
    });

    test('maps every status to a stage and step', () {
      expect(EnrollmentStage.of('pending').step, 0);
      expect(EnrollmentStage.of('approved').step, 1);
      expect(EnrollmentStage.of('bill_sent').step, 1);
      expect(EnrollmentStage.of('payment_submitted').step, 2);
      expect(EnrollmentStage.of('confirmed').step, 3);
      expect(EnrollmentStage.of('accepted'), EnrollmentStage.confirmed);
      expect(EnrollmentStage.of('approval_failed'), EnrollmentStage.failed);
      expect(EnrollmentStage.of('weird'), EnrollmentStage.other);
      expect(EnrollmentStage.pending.isOpen, isTrue);
      expect(EnrollmentStage.confirmed.isOpen, isFalse);
      expect(EnrollmentStage.rejected.isOpen, isFalse);
    });
  });

  group('RentInvoice', () {
    test('knows when it is open and overdue', () {
      final due = DateTime(2026, 3, 10);
      final inv = RentInvoice.fromMap('I1', {
        'amount': 9000,
        'month': 'March 2026',
        'periodMonth': '2026-03',
        'dueDate': Timestamp.fromDate(due),
        'status': 'unpaid',
      });
      expect(inv.isOpen, isTrue);
      expect(inv.isOverdueAt(DateTime(2026, 3, 9)), isFalse);
      expect(inv.isOverdueAt(DateTime(2026, 3, 11)), isTrue);
      expect(RentInvoice.fromMap('I2', {'status': 'overdue'}).isOverdueAt(DateTime(2000)), isTrue);
      expect(RentInvoice.fromMap('I3', {'status': 'paid'}).isOpen, isFalse);
    });
  });

  group('RentPayment', () {
    test('reads the states owners and the server write', () {
      expect(RentPayment.fromMap('a', {'status': 'Paid'}).state, PaymentState.paid);
      expect(RentPayment.fromMap('a', {'status': 'verified'}).state, PaymentState.paid);
      expect(RentPayment.fromMap('a', {'status': 'pending_verification'}).state, PaymentState.pending);
      expect(RentPayment.fromMap('a', {'status': 'Pending'}).state, PaymentState.pending);
      expect(RentPayment.fromMap('a', {'status': 'rejected', 'rejectionReason': 'No'}).rejectionReason, 'No');
    });
  });

  group('MaintenanceRequest', () {
    test('round-trips the wire values', () {
      final m = MaintenanceRequest.fromMap('M1', {
        'title': 'Fan',
        'category': 'electrical',
        'priority': 'urgent',
        'status': 'in_progress',
        'ownerNote': 'Tomorrow',
      });
      expect(m.category, MaintenanceCategory.electrical);
      expect(m.urgent, isTrue);
      expect(m.status, MaintenanceStatus.inProgress);
      expect(m.status.wire, 'in_progress');
      expect(m.canCancel, isFalse);
      expect(MaintenanceRequest.fromMap('M2', {'status': 'open'}).canCancel, isTrue);
      expect(MaintenanceRequest.fromMap('M3', {'category': '??'}).category, MaintenanceCategory.other);
    });
  });

  group('PendingInvitation', () {
    test('reads the callable payload (millis)', () {
      final i = PendingInvitation.fromMap({
        'id': 'I1',
        'businessId': 'B',
        'propertyId': 'P',
        'propertyName': 'Green Nest',
        'roomNumber': '101',
        'bedNumber': '2',
        'monthlyRent': 9000,
        'deposit': 18000,
        'moveInDate': DateTime(2026, 4, 1).millisecondsSinceEpoch,
        'status': 'pending',
      });
      expect(i.id, 'I1');
      expect(i.moveIn, DateTime(2026, 4, 1));
      expect(i.deposit, 18000);
      expect(i.placement, 'Room 101 · Bed 2');
    });
  });
}
