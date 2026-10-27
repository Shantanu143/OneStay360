// lib/presentation/requests/firestore_approval_source.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:models/business/property/property_model.dart';

import '../../models/payment_method_model.dart';
import '../view_models/tenant_wizard/assignment.dart';
import '../view_models/tenant_wizard/assignment_data_source.dart';
import 'approval_source.dart';
import 'request_models.dart';

class FirestoreApprovalSource implements ApprovalSource {
  FirestoreApprovalSource({FirebaseFirestore? firestore, AssignmentDataSource? assignments})
      : _fs = firestore ?? FirebaseFirestore.instance,
        _assignments = assignments ?? FirestoreAssignmentSource();

  final FirebaseFirestore _fs;
  final AssignmentDataSource _assignments;

  /// Requests in these stages already hold a bed for their tenant.
  static const _holdingBeds = {'approved', 'bill_sent', 'payment_submitted'};

  DocumentReference<Map<String, dynamic>> _request(String id) =>
      _fs.collection('enrollmentRequests').doc(id);

  @override
  Future<ApprovalContext> load(EnrollmentRequest request) async {
    final businessId = request.businessId;
    final propertyId = request.propertyId;
    final business = _fs.collection('businesses').doc(businessId);

    final propertyDoc = await business.collection('properties').doc(propertyId).get();
    final propertyData = propertyDoc.data();
    if (!propertyDoc.exists || propertyData == null) throw StateError('Property not found');
    final property = Property.fromMap({...propertyData}, propertyDoc.id);

    final results = await Future.wait([
      _assignments.roomsFor(businessId, property),
      _assignments.occupiedBeds(businessId, propertyId),
      _reservedBeds(businessId, propertyId, request.id),
      _methods(businessId),
      business.get(),
    ]);

    final occupied = <String, Set<String>>{};
    for (final taken in [results[1], results[2]]) {
      (taken as Map<String, Set<String>>).forEach((room, beds) {
        occupied.putIfAbsent(room, () => <String>{}).addAll(beds);
      });
    }
    final businessData = (results[4] as DocumentSnapshot<Map<String, dynamic>>).data();
    final upi = businessData?['upiId']?.toString();

    return ApprovalContext(
      property: property,
      floors: buildFloors(List.of(results[0] as List<dynamic>).cast(), occupied),
      methods: results[3] as List<PaymentMethod>,
      businessUpiId: upi == null || upi.trim().isEmpty ? null : upi.trim(),
    );
  }

  /// Beds promised to other requests that haven't become tenants yet.
  Future<Map<String, Set<String>>> _reservedBeds(
    String businessId,
    String propertyId,
    String exceptRequestId,
  ) async {
    final snap = await _fs
        .collection('enrollmentRequests')
        .where('businessId', isEqualTo: businessId)
        .where('propertyId', isEqualTo: propertyId)
        .get();
    final reserved = <String, Set<String>>{};
    for (final doc in snap.docs) {
      if (doc.id == exceptRequestId) continue;
      final d = doc.data();
      if (!_holdingBeds.contains(d['status'])) continue;
      final room = (d['roomId'] ?? d['roomNumber'])?.toString() ?? '';
      final bed = (d['bedId'] ?? d['bedNumber'])?.toString() ?? '';
      if (room.isNotEmpty && bed.isNotEmpty) {
        reserved.putIfAbsent(room, () => <String>{}).add(bed);
      }
    }
    return reserved;
  }

  Future<List<PaymentMethod>> _methods(String businessId) async {
    final snap = await _fs
        .collection('businesses')
        .doc(businessId)
        .collection('paymentMethods')
        .where('isActive', isEqualTo: true)
        .get();
    final list = [
      for (final d in snap.docs)
        PaymentMethod.fromFirestore({...d.data(), 'id': d.data()['id'] ?? d.id}),
    ];
    list.sort((a, b) {
      if (a.isPreferred != b.isPreferred) return a.isPreferred ? -1 : 1;
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  Map<String, dynamic> _fields(ApprovalSubmission s) => {
        'roomId': s.roomNumber,
        'roomNumber': s.roomNumber,
        'bedId': s.bedNumber,
        'bedNumber': s.bedNumber,
        'monthlyRent': s.monthlyRent,
        'proratedRent': s.proratedRent,
        'depositAmount': s.deposit,
        'maintenanceAmount': s.maintenance,
        'foodAddon': s.foodIncluded,
        'foodDeduction': s.foodDeduction,
        'paySecurityDepositNow': s.depositNow,
        'totalFirstMonth': s.total,
        'billingDate': s.billingDate,
        'moveInDate': Timestamp.fromDate(s.moveIn),
      };

  /// Keeps a UPI id typed into the form on the business for next time.
  Future<void> _saveUpi(String requestId, String? upi) async {
    if (upi == null) return;
    final doc = await _request(requestId).get();
    final businessId = doc.data()?['businessId']?.toString();
    if (businessId == null || businessId.isEmpty) return;
    await _fs.collection('businesses').doc(businessId).update({'upiId': upi});
  }

  @override
  Future<void> approve(String requestId, ApprovalSubmission submission, {String? newUpiId}) async {
    await _saveUpi(requestId, newUpiId);
    await _request(requestId).update({
      'status': 'approved',
      ..._fields(submission),
      'paymentMode': 'immediate',
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> sendBill(
    String requestId,
    ApprovalSubmission submission,
    PaymentChoice payment, {
    String? newUpiId,
  }) async {
    await _saveUpi(requestId, newUpiId);
    await _request(requestId).update({
      'status': 'bill_sent',
      ..._fields(submission),
      'totalBillAmount': submission.total,
      'paymentMode': payment.mode,
      ...payment.info,
      'billSentAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
