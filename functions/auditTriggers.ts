import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { logAudit } from './audit';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export const auditPropertyAccess = functions.firestore
  .document('businesses/{businessId}/properties/{propertyId}/access/{uid}')
  .onWrite(async (change, context) => {
    const { businessId, propertyId, uid } = context.params as { businessId: string; propertyId: string; uid: string };

    if (!change.before.exists && change.after.exists) {
      const data = change.after.data() as any;
      const actorUid = (data?.updatedBy as string) || (data?.createdBy as string) || (data?.grantedBy as string);
      if (!actorUid) throw new Error('Missing actorUid on access grant');
      await logAudit({
        businessId,
        actorUid,
        action: 'property_access_granted',
        entityType: 'property_access',
        entityId: uid,
        propertyId,
      });
      return;
    }

    if (change.before.exists && !change.after.exists) {
      const data = change.before.data() as any;
      const actorUid = (data?.updatedBy as string) || (data?.revokedBy as string) || (data?.createdBy as string);
      if (!actorUid) throw new Error('Missing actorUid on access revoke');
      await logAudit({
        businessId,
        actorUid,
        action: 'property_access_revoked',
        entityType: 'property_access',
        entityId: uid,
        propertyId,
      });
    }
  });

export const auditTenantCreate = functions.firestore
  .document('businesses/{businessId}/tenants/{tenantId}')
  .onCreate(async (snap, context) => {
    const { businessId, tenantId } = context.params as { businessId: string; tenantId: string };
    const data = snap.data() as any;
    const actorUid = (data?.createdBy as string) || (data?.updatedBy as string);
    if (!actorUid) throw new Error('Missing actorUid on tenant create');
    const propertyId = (data?.propertyId as string) || null;

    await logAudit({
      businessId,
      actorUid,
      action: 'tenant_created',
      entityType: 'tenant',
      entityId: tenantId,
      propertyId,
    });
  });

export const auditTenantDelete = functions.firestore
  .document('businesses/{businessId}/tenants/{tenantId}')
  .onDelete(async (snap, context) => {
    const { businessId, tenantId } = context.params as { businessId: string; tenantId: string };
    const data = snap.data() as any;
    const actorUid = (data?.updatedBy as string) || (data?.deletedBy as string) || (data?.createdBy as string);
    if (!actorUid) throw new Error('Missing actorUid on tenant delete');
    const propertyId = (data?.propertyId as string) || null;

    await logAudit({
      businessId,
      actorUid,
      action: 'tenant_deleted',
      entityType: 'tenant',
      entityId: tenantId,
      propertyId,
    });
  });

export const auditBedOccupancy = functions.firestore
  .document('businesses/{businessId}/properties/{propertyId}/rooms/{roomId}/beds/{bedId}')
  .onUpdate(async (change, context) => {
    const { businessId, propertyId, bedId } = context.params as {
      businessId: string;
      propertyId: string;
      bedId: string;
    };

    const before = change.before.data() as any;
    const after = change.after.data() as any;

    const beforeOccupied = Boolean(before?.isOccupied);
    const afterOccupied = Boolean(after?.isOccupied);
    const beforeTenant = before?.tenantId || null;
    const afterTenant = after?.tenantId || null;

    let action: 'bed_occupied' | 'bed_vacated' | null = null;
    if (!beforeOccupied && afterOccupied) {
      action = 'bed_occupied';
    } else if (beforeOccupied && !afterOccupied) {
      action = 'bed_vacated';
    } else if (beforeOccupied && afterOccupied && beforeTenant !== afterTenant) {
      action = 'bed_occupied';
    }

    if (!action) return null;

    const actorUid = (after?.updatedBy as string) || (after?.occupiedBy as string);
    if (!actorUid) throw new Error('Missing actorUid on bed occupancy change');

    await logAudit({
      businessId,
      actorUid,
      action,
      entityType: 'bed',
      entityId: bedId,
      propertyId,
    });
    return null;
  });
