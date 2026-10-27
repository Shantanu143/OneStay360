import 'package:business/presentation/requests/request_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/tenant/tenant_request_model.dart';

import '../../support/request_fakes.dart';

void main() {
  group('EnrollmentRequest.fromMap', () {
    test('reads what the tenant submitted', () {
      final r = requestOf();

      expect(r.id, 'R1');
      expect(r.tenantName, 'Mohit Saxena');
      expect(r.phone, '+919000000501');
      expect(r.email, 'mohit@example.test');
      expect(r.propertyId, 'P1');
      expect(r.propertyName, 'Sunrise Boys PG');
      expect(r.businessId, 'BUS1');
      expect(r.moveIn, DateTime(2026, 11, 2));
      expect(r.notes, 'Joining Flipkart, need a quiet room.');
      expect(r.sharingLabel, '2-sharing');
      expect(r.createdAt, DateTime(2026, 10, 26, 9));
      expect(r.bill, isNull);
      expect(r.payment, isNull);
    });

    test('names the tenant when the request has no name', () {
      final r = EnrollmentRequest.fromMap('R9', {'status': 'pending'});

      expect(r.displayName, 'Unnamed request');
      expect(r.initials, '?');
    });

    test('reads the bill once the owner has sent one', () {
      final r = requestOf(status: 'bill_sent', extra: billExtra);

      expect(r.bill, isNotNull);
      expect(r.bill!.roomNumber, '302');
      expect(r.bill!.bedNumber, '2');
      expect(r.bill!.total, 21500);
      expect(r.bill!.monthlyRent, 11500);
      expect(r.bill!.deposit, 10000);
      expect(r.bill!.maintenance, 1000);
      expect(r.bill!.paymentLabel, 'UPI');
      expect(r.bill!.ownerUpiId, 'owner@upi');
    });

    test('reads the payment the tenant says they made', () {
      final r = requestOf(status: 'payment_submitted', extra: {
        ...billExtra,
        'transactionId': 'UTR982736451209',
        'paymentSubmittedAt': Timestamp.fromDate(DateTime(2026, 10, 26, 14)),
      });

      expect(r.payment!.transactionId, 'UTR982736451209');
      expect(r.payment!.submittedAt, DateTime(2026, 10, 26, 14));
    });

    test('keeps the reason when the owner turned a payment down', () {
      final r = requestOf(status: 'bill_sent', extra: {
        ...billExtra,
        'paymentRejectionReason': 'Amount short by ₹500',
      });

      expect(r.payment!.rejectionReason, 'Amount short by ₹500');
    });

    test('tolerates a server timestamp that has not arrived', () {
      final r = EnrollmentRequest.fromMap('R9', {'status': 'pending', 'createdAt': null});

      expect(r.createdAt, isNotNull);
    });

    test('copes with ISO dates and blank text', () {
      final r = EnrollmentRequest.fromMap('R9', {
        'status': 'pending',
        'moveInDate': '2026-12-01',
        'notes': '   ',
        'tenantEmail': '',
      });

      expect(r.moveIn, DateTime(2026, 12, 1));
      expect(r.notes, isNull);
      expect(r.email, isNull);
    });
  });

  group('stages', () {
    RequestStage stage(String s) => requestOf(status: s).stage;

    test('map every status the backend uses', () {
      expect(stage('pending'), RequestStage.pending);
      expect(stage('approved'), RequestStage.approved);
      expect(stage('bill_sent'), RequestStage.billSent);
      expect(stage('payment_submitted'), RequestStage.paymentSubmitted);
      expect(stage('confirmed'), RequestStage.confirmed);
      expect(stage('accepted'), RequestStage.confirmed);
      expect(stage('rejected'), RequestStage.rejected);
      expect(stage('approval_failed'), RequestStage.approvalFailed);
      expect(stage('whatever'), RequestStage.other);
    });

    test('say what happens next in plain words', () {
      expect(RequestStage.pending.nextStep, contains('approve'));
      expect(RequestStage.billSent.nextStep, contains('Waiting'));
      expect(RequestStage.paymentSubmitted.nextStep, contains('confirm'));
      expect(RequestStage.confirmed.nextStep, contains('joined'));
    });

    test('only pending, payment_submitted and approval_failed need the owner', () {
      expect(RequestStage.pending.needsOwner, isTrue);
      expect(RequestStage.paymentSubmitted.needsOwner, isTrue);
      expect(RequestStage.approvalFailed.needsOwner, isTrue);
      expect(RequestStage.billSent.needsOwner, isFalse);
      expect(RequestStage.confirmed.needsOwner, isFalse);
      expect(RequestStage.rejected.needsOwner, isFalse);
    });
  });

  test('keeps why adding the tenant failed', () {
    final r = requestOf(
      status: 'approval_failed',
      extra: {...billExtra, 'approvalError': 'Bed 2 is already occupied'},
    );

    expect(r.stage, RequestStage.approvalFailed);
    expect(r.stage.label, "Couldn't add tenant");
    expect(r.approvalError, 'Bed 2 is already occupied');
  });

  group('what to tell the owner when adding the tenant failed', () {
    String? problem(String? error) =>
        requestOf(status: 'approval_failed', extra: {'approvalError': error}).approvalProblem;

    test('passes on a message that makes sense to them', () {
      expect(problem('Bed 2 is already occupied'), 'Bed 2 is already occupied');
      expect(
        problem('Room 101 is reserved for Female tenants only. This tenant is Male.'),
        'Room 101 is reserved for Female tenants only. This tenant is Male.',
      );
    });

    test('hides backend noise behind a plain sentence', () {
      expect(
        problem('5 NOT_FOUND: no entity to update: app: "dev~x"\npath <\n  Element {}\n>\n'),
        'Something went wrong on our side. Try again; if it keeps failing, contact support.',
      );
    });

    test('has nothing to say when there is no error', () {
      expect(problem(null), isNull);
    });
  });

  test('a request from the list can be shown while the live copy loads', () {
    final r = EnrollmentRequest.fromTenantRequest(TenantRequest.fromFirestore('R1', requestDoc()));

    expect(r.id, 'R1');
    expect(r.displayName, 'Mohit Saxena');
    expect(r.phone, '+919000000501');
    expect(r.moveIn, DateTime(2026, 11, 2));
    expect(r.notes, 'Joining Flipkart, need a quiet room.');
    expect(r.sharingLabel, '2-sharing');
    expect(r.stage, RequestStage.pending);
  });
}
