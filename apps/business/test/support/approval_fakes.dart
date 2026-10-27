import 'package:business/models/payment_method_model.dart';
import 'package:business/presentation/requests/approval_source.dart';
import 'package:business/presentation/requests/request_models.dart';
import 'package:business/presentation/view_models/tenant_wizard/assignment.dart';
import 'package:models/business/property/property_pricing_model.dart';
import 'package:models/business/property/property_room_model.dart';

import 'property_fixtures.dart';

PropertyRoom roomFor(String number, String floor, int sharing, {bool ac = false}) => PropertyRoom(
      roomNumber: number,
      floor: floor,
      occupancyType: '$sharing',
      sharingType: sharing,
      hasAC: ac,
    );

PaymentMethod upiMethod({String id = 'm1', String upi = 'owner@upi', bool preferred = false}) =>
    PaymentMethod(
      id: id,
      businessId: 'BUS1',
      type: 'upi',
      upiId: upi,
      isActive: true,
      isPreferred: preferred,
      createdAt: DateTime(2026, 1, 1),
    );

PaymentMethod bankMethod() => PaymentMethod(
      id: 'm2',
      businessId: 'BUS1',
      type: 'bank',
      bankName: 'HDFC',
      accountNumber: '1234567890',
      ifscCode: 'HDFC0001234',
      accountHolderName: 'Rajesh Sharma',
      isActive: true,
      isPreferred: false,
      createdAt: DateTime(2026, 1, 2),
    );

PaymentMethod cashMethod() => PaymentMethod(
      id: 'm3',
      businessId: 'BUS1',
      type: 'cash',
      isActive: true,
      isPreferred: false,
      createdAt: DateTime(2026, 1, 3),
    );

/// Two floors; 101 holds 1 of 2 beds taken, 102 is a full triple, 201 is a free AC double.
ApprovalContext approvalContext({List<PaymentMethod>? methods, String? businessUpiId}) {
  final property = makeProperty(
    id: 'P1',
    name: 'Sunrise Boys PG',
    single: 9000,
    double: 6500,
    triple: 5000,
    deposit: 13000,
    maintenance: 500,
    maintenanceDeducted: true,
    sharingPrices: [SharingPricingEntry(sharing: 2, nonAc: 6500, ac: 8000)],
  );
  final rooms = [
    roomFor('101', '1', 2),
    roomFor('102', '1', 3),
    roomFor('201', '2', 2, ac: true),
  ];
  final floors = buildFloors(rooms, {
    '101': {'1'},
    '102': {'1', '2', '3'},
  });
  return ApprovalContext(
    property: property,
    floors: floors,
    methods: methods ?? [upiMethod(preferred: true)],
    businessUpiId: businessUpiId,
  );
}

class FakeApprovalSource implements ApprovalSource {
  FakeApprovalSource(this.context);

  ApprovalContext context;
  Object? loadFailure;
  Object? submitFailure;
  int loads = 0;

  final approvals = <({String id, ApprovalSubmission s, String? upi})>[];
  final bills = <({String id, ApprovalSubmission s, PaymentChoice p, String? upi})>[];

  @override
  Future<ApprovalContext> load(EnrollmentRequest request) async {
    loads++;
    if (loadFailure != null) throw loadFailure!;
    return context;
  }

  @override
  Future<void> approve(String requestId, ApprovalSubmission submission, {String? newUpiId}) async {
    if (submitFailure != null) throw submitFailure!;
    approvals.add((id: requestId, s: submission, upi: newUpiId));
  }

  @override
  Future<void> sendBill(
    String requestId,
    ApprovalSubmission submission,
    PaymentChoice payment, {
    String? newUpiId,
  }) async {
    if (submitFailure != null) throw submitFailure!;
    bills.add((id: requestId, s: submission, p: payment, upi: newUpiId));
  }
}

/// The same property with every bed taken.
class ApprovalContextAllFull {
  static ApprovalContext of(ApprovalContext base) {
    final rooms = [
      roomFor('101', '1', 2),
      roomFor('102', '1', 3),
      roomFor('201', '2', 2, ac: true),
    ];
    return ApprovalContext(
      property: base.property,
      floors: buildFloors(rooms, {
        '101': {'1', '2'},
        '102': {'1', '2', '3'},
        '201': {'1', '2'},
      }),
      methods: base.methods,
    );
  }
}
