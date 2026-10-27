import 'dart:async';

import 'package:business/presentation/requests/request_models.dart';
import 'package:business/presentation/requests/request_source.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A request document as `submitEnrollmentRequest` writes it, plus whatever
/// later stages add.
Map<String, dynamic> requestDoc({
  String status = 'pending',
  Map<String, dynamic> extra = const {},
}) =>
    {
      'tenantName': 'Mohit Saxena',
      'tenantPhone': '+919000000501',
      'tenantEmail': 'mohit@example.test',
      'propertyId': 'P1',
      'propertyName': 'Sunrise Boys PG',
      'businessId': 'BUS1',
      'status': status,
      'moveInDate': Timestamp.fromDate(DateTime(2026, 11, 2)),
      'sharingType': '2',
      'roomType': 'Double Sharing',
      'notes': 'Joining Flipkart, need a quiet room.',
      'createdAt': Timestamp.fromDate(DateTime(2026, 10, 26, 9)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 10, 26, 11, 30)),
      ...extra,
    };

EnrollmentRequest requestOf({
  String status = 'pending',
  Map<String, dynamic> extra = const {},
}) =>
    EnrollmentRequest.fromMap('R1', requestDoc(status: status, extra: extra));

final billExtra = <String, dynamic>{
  'roomNumber': '302',
  'bedNumber': '2',
  'roomId': '302',
  'bedId': '2',
  'monthlyRent': 11500,
  'proratedRent': 11500,
  'depositAmount': 10000,
  'maintenanceAmount': 1000,
  'foodAddon': true,
  'foodDeduction': 0,
  'totalBillAmount': 21500,
  'paymentMode': 'upi_manual',
  'ownerUpiId': 'owner@upi',
  'billSentAt': Timestamp.fromDate(DateTime(2026, 10, 26, 12)),
};

class FakeRequestSource implements RequestSource {
  final controller = StreamController<EnrollmentRequest?>.broadcast();
  int watches = 0;
  Object? failure;
  final calls = <String>[];

  @override
  Stream<EnrollmentRequest?> watch(String requestId) {
    watches++;
    return controller.stream;
  }

  Future<void> _do(String call) async {
    if (failure != null) throw failure!;
    calls.add(call);
  }

  @override
  Future<void> reject(String requestId) => _do('reject:$requestId');

  @override
  Future<void> confirmPayment(String requestId) => _do('confirm:$requestId');

  @override
  Future<void> rejectPayment(String requestId, String reason) => _do('rejectPayment:$requestId:$reason');
}
