import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { assertBusinessPermission } from './permissions';
import { logAudit } from './audit';
import { diffAccess, uniqueIds } from './memberAccessLogic';

if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

export const updateMemberPropertyAccess = functions.https.onCall(async (data, context) => {
  const actorUid = context.auth?.uid;
  const { businessId, memberUid, role, propertyIds } = data || {};

  if (!actorUid) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  if (!businessId || !memberUid || !role || !Array.isArray(propertyIds)) {
    throw new functions.https.HttpsError('invalid-argument', 'businessId, memberUid, role, propertyIds required');
  }
  if (role !== 'manager' && role !== 'staff') {
    throw new functions.https.HttpsError('invalid-argument', 'role must be manager or staff');
  }

  await assertBusinessPermission(actorUid, businessId, 'ASSIGN_PROPERTIES');

  const uniqueProperties = uniqueIds(propertyIds);
  const membershipRef = db.doc(`businesses/${businessId}/members/${memberUid}`);

  const now = admin.firestore.Timestamp.now();

  const { roleChanged, addedProps, removedProps } = await db.runTransaction(async (tx) => {
    const memberSnap = await tx.get(membershipRef);
    if (!memberSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Member not found');
    }
    const member = memberSnap.data() as any;
    if (member.status !== 'active') {
      throw new functions.https.HttpsError('failed-precondition', 'Member inactive');
    }
    if (member.role === 'owner') {
      throw new functions.https.HttpsError('failed-precondition', 'Owner role cannot be changed');
    }

    // Every property of the business: the requested ones must exist, and each
    // one's `access/{memberUid}` doc shows what the member has now. (A
    // collection-group query by document id cannot be used here: Firestore
    // only accepts a full document path for that.)
    const propertiesSnap = await tx.get(db.collection(`businesses/${businessId}/properties`));
    const propertyIdsInBusiness = new Set(propertiesSnap.docs.map((d) => d.id));
    for (const pid of uniqueProperties) {
      if (!propertyIdsInBusiness.has(pid)) {
        throw new functions.https.HttpsError('failed-precondition', `Property ${pid} not found`);
      }
    }

    const accessSnaps = await Promise.all(
      propertiesSnap.docs.map((d) => tx.get(d.ref.collection('access').doc(memberUid)))
    );
    const existingPids = propertiesSnap.docs.filter((_, i) => accessSnaps[i].exists).map((d) => d.id);

    const { toAdd, toKeep, toRemove } = diffAccess(existingPids, uniqueProperties);

    // Add new access docs
    for (const pid of toAdd) {
      const accessRef = db.doc(`businesses/${businessId}/properties/${pid}/access/${memberUid}`);
      tx.set(accessRef, {
        role,
        businessId,
        grantedAt: now,
        grantedBy: actorUid,
        createdBy: actorUid,
        updatedBy: actorUid,
        actorRole: role,
      });
    }

    // Update kept docs to reflect role (downgrade) and actor
    for (const pid of toKeep) {
      const accessRef = db.doc(`businesses/${businessId}/properties/${pid}/access/${memberUid}`);
      tx.set(accessRef, {
        role,
        businessId,
        updatedBy: actorUid,
        actorRole: role,
        updatedAt: now,
      }, { merge: true });
    }

    // Remove revoked access
    for (const pid of toRemove) {
      const accessRef = db.doc(`businesses/${businessId}/properties/${pid}/access/${memberUid}`);
      tx.delete(accessRef);
    }

    // Update member role if changed
    const roleChanged = member.role !== role;
    tx.set(membershipRef, {
      role,
      updatedAt: now,
      updatedBy: actorUid,
    }, { merge: true });

    return { roleChanged, addedProps: toAdd, removedProps: toRemove };
  });

  // Audit logs
  for (const pid of addedProps) {
    await logAudit({
      businessId,
      actorUid,
      propertyId: pid,
      action: 'property_access_granted',
      entityType: 'property_access',
      entityId: memberUid,
    });
  }

  for (const pid of removedProps) {
    await logAudit({
      businessId,
      actorUid,
      propertyId: pid,
      action: 'property_access_revoked',
      entityType: 'property_access',
      entityId: memberUid,
    });
  }

  if (roleChanged) {
    await logAudit({
      businessId,
      actorUid,
      action: 'member_role_changed',
      entityType: 'member',
      entityId: memberUid,
    });
  }

  return { ok: true, role, propertyIds: uniqueProperties };
});
