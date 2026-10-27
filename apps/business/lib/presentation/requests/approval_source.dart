// lib/presentation/requests/approval_source.dart
import 'package:models/business/property/property_model.dart';

import '../../models/payment_method_model.dart';
import '../view_models/tenant_wizard/assignment.dart';
import 'request_models.dart';

/// Everything the approval form needs to know about the property.
class ApprovalContext {
  const ApprovalContext({
    required this.property,
    required this.floors,
    required this.methods,
    this.businessUpiId,
  });

  final Property property;
  final List<FloorSlot> floors;

  /// The owner's active payment methods, preferred first.
  final List<PaymentMethod> methods;

  /// A UPI id saved on the business before payment methods existed.
  final String? businessUpiId;
}

/// How the tenant is asked to pay the first bill.
class PaymentChoice {
  const PaymentChoice(this.mode, this.info);

  /// 'upi_manual' | 'bank_transfer' | 'cash'
  final String mode;

  /// Extra fields stored on the request (UPI id, bank details...).
  final Map<String, dynamic> info;
}

/// What the owner decided: where the tenant sleeps and what they pay first.
class ApprovalSubmission {
  const ApprovalSubmission({
    required this.roomNumber,
    required this.bedNumber,
    required this.monthlyRent,
    required this.proratedRent,
    required this.deposit,
    required this.maintenance,
    required this.foodIncluded,
    required this.foodDeduction,
    required this.depositNow,
    required this.total,
    required this.billingDate,
    required this.moveIn,
  });

  final String roomNumber;
  final String bedNumber;
  final double monthlyRent;
  final double proratedRent;
  final double deposit;
  final double maintenance;
  final bool foodIncluded;
  final double foodDeduction;
  final bool depositNow;
  final double total;
  final int billingDate;
  final DateTime moveIn;
}

abstract class ApprovalSource {
  Future<ApprovalContext> load(EnrollmentRequest request);

  /// Approves and assigns the bed; the owner collects payment themselves.
  Future<void> approve(String requestId, ApprovalSubmission submission, {String? newUpiId});

  /// Sends the first bill; the tenant pays through [payment].
  Future<void> sendBill(
    String requestId,
    ApprovalSubmission submission,
    PaymentChoice payment, {
    String? newUpiId,
  });
}
