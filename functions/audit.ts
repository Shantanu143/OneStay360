import * as admin from 'firebase-admin';
import {
  getMembershipRole,
  getPropertyRole,
  businessPermissionsForRole,
  propertyPermissionsForRole,
  Role,
} from './permissions';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

export type AuditPermissionsSnapshot = {
  business: string[];
  property?: string[];
};

export type AuditLogPayload = {
  businessId: string;
  actorUid: string;
  propertyId?: string | null;
  action: string;
  entityType: string;
  entityId: string;
};

async function resolveActorContext(
  businessId: string,
  actorUid: string,
  propertyId?: string | null
): Promise<{ actorRole: Role; actorPermissions: AuditPermissionsSnapshot }> {
  const businessRole = await getMembershipRole(actorUid, businessId);
  const propertyScoped = propertyId && typeof propertyId === 'string';

  if (propertyScoped) {
    const propertyRole = await getPropertyRole(actorUid, businessId, propertyId!);
    return {
      actorRole: propertyRole,
      actorPermissions: {
        business: businessPermissionsForRole(businessRole),
        property: propertyPermissionsForRole(propertyRole),
      },
    };
  }

  return {
    actorRole: businessRole,
    actorPermissions: {
      business: businessPermissionsForRole(businessRole),
    },
  };
}

export async function logAudit(payload: AuditLogPayload) {
  const { businessId, actorUid, action, entityType, entityId, propertyId = null } = payload;

  if (!actorUid) {
    throw new Error('actorUid required for audit log');
  }

  const { actorRole, actorPermissions } = await resolveActorContext(businessId, actorUid, propertyId);

  const ref = db.collection(`businesses/${businessId}/audit_logs`).doc();
  await ref.set({
    actorUid,
    actorRole,
    actorPermissions,
    action,
    entityType,
    entityId,
    propertyId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}
