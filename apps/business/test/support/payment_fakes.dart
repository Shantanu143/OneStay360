import 'dart:async';

import 'package:business/presentation/payments/pending_models.dart';
import 'package:business/presentation/payments/pending_source.dart';
import 'package:business/presentation/requests/request_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

PendingRent rentPayment(
  String id, {
  String tenantId = 'T1',
  String name = 'Rohan Mehta',
  double amount = 9500,
  String method = 'UPI',
  String? txn = 'UTR123456789',
  DateTime? at,
}) =>
    PendingRent(
      paymentId: id,
      tenantId: tenantId,
      tenantName: name,
      roomNumber: '101',
      bedNumber: '1',
      month: 'October 2026',
      amount: amount,
      method: method,
      transactionId: txn,
      submittedAt: at ?? DateTime(2026, 10, 26, 9),
    );

EnrollmentRequest depositRequest(String id, {String name = 'Devansh Trivedi', double total = 17500}) =>
    EnrollmentRequest.fromMap(id, {
      'tenantName': name,
      'tenantPhone': '+919000000504',
      'propertyId': 'P1',
      'propertyName': 'Sunrise Boys PG',
      'businessId': 'BUS1',
      'status': 'payment_submitted',
      'roomNumber': 'B2',
      'bedNumber': '2',
      'totalBillAmount': total,
      'transactionId': 'UTR982736451209',
      'paymentSubmittedAt': Timestamp.fromDate(DateTime(2026, 10, 26, 10)),
      'createdAt': Timestamp.fromDate(DateTime(2026, 10, 20)),
    });

class FakePendingSource implements PendingPaymentsSource {
  final deposits$ = StreamController<List<EnrollmentRequest>>.broadcast();
  List<PendingRent> rent = const [];
  Object? rentFailure;
  Object? verifyFailure;
  int rentLoads = 0;
  int depositWatches = 0;
  String? lastPropertyId;
  final verified = <({String tenantId, String paymentId, bool confirm, String? reason})>[];

  @override
  Future<List<PendingRent>> rentPayments(String businessId, {String? propertyId}) async {
    rentLoads++;
    lastPropertyId = propertyId;
    if (rentFailure != null) throw rentFailure!;
    return rent;
  }

  @override
  Stream<List<EnrollmentRequest>> deposits(String businessId, {String? propertyId}) {
    depositWatches++;
    return deposits$.stream;
  }

  @override
  Future<void> verifyRent({
    required String businessId,
    required String tenantId,
    required String paymentId,
    required bool confirm,
    String? reason,
  }) async {
    if (verifyFailure != null) throw verifyFailure!;
    verified.add((tenantId: tenantId, paymentId: paymentId, confirm: confirm, reason: reason));
  }
}
