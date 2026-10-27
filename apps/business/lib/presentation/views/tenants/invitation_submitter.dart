// lib/presentation/views/tenants/invitation_submitter.dart
import '../../view_models/add_tenant_invitation_viewmodel.dart';
import '../../view_models/tenant_wizard/wizard_viewmodel.dart';

/// Sends the wizard's result as a tenant invitation. Reuses the existing
/// invitation logic (business lookup, room gender check, creating the
/// invitation). Returns the error message, or null on success.
Future<String?> submitInvitation(WizardSubmission s) async {
  final vm = AddTenantInvitationViewModel();
  try {
    vm.setMode(s.mode == TenantEntryMode.search ? 'search' : 'manual');
    if (s.mode == TenantEntryMode.search) {
      vm.setSelectedTenant(s.tenant);
    } else {
      vm.setManualTenantData(Map<String, dynamic>.of(s.tenantData));
    }

    vm.setAssignment(
      propertyId: s.propertyId,
      propertyName: s.propertyName,
      floor: s.floor,
      roomId: s.roomId,
      roomNumber: s.roomNumber,
      bedIndex: s.bedIndex,
      bedNumber: s.bedNumber,
    );
    vm.setMoveInDate(s.moveIn);
    vm.setMoveOutDate(s.moveOut);
    vm.setMonthlyRent(s.monthlyRent);
    vm.setDeposit(s.deposit);
    vm.setMaintenance(s.maintenance);
    vm.setMaintenanceDeductedFromDeposit(s.maintenanceDeductedFromDeposit);
    vm.setProratedRent(s.proratedRent);
    vm.setBillingDay(s.billingDay);
    vm.setLockInPeriodMonths(s.lockInMonths);
    vm.setNoticePeriodDays(s.noticeDays);
    vm.setPaymentCycle(s.paymentCycle);
    vm.setFoodPreference(s.foodPreference);

    await vm.submit();
    return vm.errorMessage;
  } finally {
    vm.dispose();
  }
}
