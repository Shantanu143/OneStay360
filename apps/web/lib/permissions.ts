// UI gating, mirroring apps/business/lib/utils/permissions.dart. The backend
// enforces the same rules (functions/permissions.ts, firestore.rules).
import type { BusinessRole } from "./types";

export function permissions(role: BusinessRole | undefined) {
  const owner = role === "owner";
  const manager = role === "manager";
  return {
    canInviteMembers: owner,
    canViewBilling: owner,
    canEditProperties: owner,
    canVacateTenants: owner,
    canEditPaymentMethods: owner,
    /** Managers act on requests, tenants and payments for their properties. */
    canManageTenants: owner || manager,
    canVerifyPayments: owner || manager,
    canApproveRequests: owner || manager,
    canUpdateMaintenance: true,
  };
}
