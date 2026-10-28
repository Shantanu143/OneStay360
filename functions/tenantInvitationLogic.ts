// Pure rules for a tenant answering an owner's invitation (tenant_invitations).
// Kept free of firebase-admin so it can be unit tested; tenantInvitations.ts
// does the reads and writes.
import { phonesMatch } from './invitationLogic';

export interface InvitationCaller {
  /** The caller's `users/{uid}.tenantId`, when they have one. */
  tenantId: string | null | undefined;
  /** Phone numbers known for the caller (verified auth phone first). */
  phones: Array<string | null | undefined>;
}

export type ResponseCheck =
  | { ok: true }
  | { ok: false; code: 'not-found' | 'failed-precondition' | 'permission-denied'; message: string };

const isTenantDocId = (id: string | null | undefined): id is string =>
  typeof id === 'string' && /^TEN\d+$/.test(id);

/** Whether the caller may accept or decline [invitation]. */
export function checkInvitationResponse(
  invitation: Record<string, any> | undefined,
  caller: InvitationCaller,
): ResponseCheck {
  if (!invitation) {
    return { ok: false, code: 'not-found', message: 'This invitation no longer exists.' };
  }
  if (invitation.status !== 'pending') {
    return {
      ok: false,
      code: 'failed-precondition',
      message: `This invitation was already ${invitation.status === 'rejected' ? 'declined' : 'accepted'}.`,
    };
  }
  const byId = !!invitation.tenantId && caller.tenantId === invitation.tenantId;
  const byPhone = caller.phones.some((p) => phonesMatch(p, invitation.tenantPhone));
  if (!byId && !byPhone) {
    return { ok: false, code: 'permission-denied', message: 'This invitation was sent to someone else.' };
  }
  return { ok: true };
}

/**
 * The tenant document the stay is recorded under: the caller's own tenant id
 * when they already have one (so their history stays together), otherwise
 * the placeholder the owner's invitation created.
 */
export function resolveTenantDocId(callerTenantId: string | null | undefined, invitationTenantId: string): string {
  return isTenantDocId(callerTenantId) ? callerTenantId : invitationTenantId;
}

export interface AcceptContext {
  invitationId: string;
  tenantDocId: string;
  uid: string;
  /** Server timestamp to stamp records with. */
  now: unknown;
  /** The move-in date as stored on the invitation. */
  moveIn: unknown;
}

/** Everything written when the tenant accepts, as plain objects. */
export function buildAcceptedTenantRecords(inv: Record<string, any>, ctx: AcceptContext) {
  const bedId = String(typeof inv.bedIndex === 'number' ? inv.bedIndex + 1 : inv.bedNumber || '1');
  const roomNumber = inv.roomNumber || inv.roomId;
  const bedNumber = inv.bedNumber || bedId;
  const monthlyRent = typeof inv.monthlyRent === 'number' ? inv.monthlyRent : 0;
  const placement = {
    businessId: inv.businessId,
    propertyId: inv.propertyId,
    propertyName: inv.propertyName || '',
    roomId: inv.roomId,
    bedId,
    roomNumber,
    bedNumber,
    monthlyRent,
    checkInDate: ctx.moveIn,
  };

  const bizTenant = {
    id: ctx.tenantDocId,
    tenantId: ctx.tenantDocId,
    userId: ctx.uid,
    name: inv.tenantName || '',
    phone: inv.tenantPhone || '',
    email: inv.tenantEmail || null,
    gender: inv.gender || null,
    ...placement,
    status: 'active',
    invitationId: ctx.invitationId,
    createdAt: ctx.now,
    updatedAt: ctx.now,
    linkedAt: ctx.now,
    additionalInfo: {
      depositAmount: inv.deposit || 0,
      maintenanceAmount: inv.maintenance || 0,
      maintenanceDeductedFromDeposit: inv.maintenanceDeductedFromDeposit || false,
      proratedRent: inv.proratedRent || 0,
      billingDate: inv.billingDay || 1,
      lockInPeriodMonths: inv.lockInPeriodMonths || null,
      noticePeriodDays: inv.noticePeriodDays || null,
      paymentCycle: inv.paymentCycle || 'Monthly',
    },
  };

  const globalTenant = {
    tenantId: ctx.tenantDocId,
    userId: ctx.uid,
    ...placement,
    status: 'active',
    linkedAt: ctx.now,
    updatedAt: ctx.now,
  };

  const stay = {
    invitationId: ctx.invitationId,
    ...placement,
    status: 'active',
    createdAt: ctx.now,
    updatedAt: ctx.now,
  };

  const bed = {
    occupied: true,
    isOccupied: true,
    tenantId: ctx.tenantDocId,
    tenantName: inv.tenantName || '',
    occupiedAt: ctx.now,
  };

  return { bizTenant, globalTenant, stay, bed, bedId };
}
