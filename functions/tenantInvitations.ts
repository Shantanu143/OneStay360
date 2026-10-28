/**
 * Tenant side of an owner's invitation (tenant_invitations/{id}, created by
 * createTenantInvitation in tenantOnboarding.ts).
 *
 * - listMyTenantInvitations: pending invitations sent to the caller's tenant
 *   id or phone number.
 * - approveInvitation: the tenant accepts; creates the business tenant
 *   record, the active stay, links the user and occupies the bed.
 * - rejectTenantInvitation: the tenant declines.
 *
 * The phone match uses the verified auth phone first, then the phone on the
 * caller's user document (the same trust onTenantUserCreated uses to link).
 */
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import {
  buildAcceptedTenantRecords,
  checkInvitationResponse,
  InvitationCaller,
  resolveTenantDocId,
} from './tenantInvitationLogic';
import { normalizePhone } from './invitationLogic';

if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

async function callerFor(context: functions.https.CallableContext): Promise<{ uid: string; caller: InvitationCaller }> {
  const uid = context.auth?.uid;
  if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  const user = (await db.doc(`users/${uid}`).get()).data() || {};
  return {
    uid,
    caller: {
      tenantId: user.tenantId || null,
      phones: [context.auth?.token?.phone_number, user.phone, user.mobileNumber],
    },
  };
}

function fail(check: { ok: false; code: any; message: string }): never {
  throw new functions.https.HttpsError(check.code, check.message);
}

function summary(id: string, inv: Record<string, any>) {
  const millis = (v: any) => (v && typeof v.toMillis === 'function' ? v.toMillis() : null);
  return {
    id,
    businessId: inv.businessId,
    propertyId: inv.propertyId,
    propertyName: inv.propertyName || '',
    roomNumber: inv.roomNumber || inv.roomId || '',
    bedNumber: inv.bedNumber || '',
    monthlyRent: inv.monthlyRent || 0,
    deposit: inv.deposit || 0,
    maintenance: inv.maintenance || 0,
    proratedRent: inv.proratedRent || 0,
    billingDay: inv.billingDay || null,
    noticePeriodDays: inv.noticePeriodDays || null,
    lockInPeriodMonths: inv.lockInPeriodMonths || null,
    moveInDate: millis(inv.moveInDate),
    createdAt: millis(inv.createdAt),
    status: inv.status,
  };
}

export const listMyTenantInvitations = functions.https.onCall(async (_data, context) => {
  const { caller } = await callerFor(context);

  const found = new Map<string, Record<string, any>>();
  if (caller.tenantId) {
    const byId = await db
      .collection('tenant_invitations')
      .where('tenantId', '==', caller.tenantId)
      .where('status', '==', 'pending')
      .get();
    byId.docs.forEach((d) => found.set(d.id, d.data()));
  }

  // Phones are stored as the owner typed them, so try the usual spellings.
  const tenDigits = Array.from(new Set(caller.phones.map((p) => normalizePhone(p)).filter((p) => p.length === 10)));
  for (const digits of tenDigits) {
    for (const spelling of [`+91${digits}`, digits, `+91 ${digits.slice(0, 5)} ${digits.slice(5)}`]) {
      const byPhone = await db
        .collection('tenant_invitations')
        .where('tenantPhone', '==', spelling)
        .where('status', '==', 'pending')
        .get();
      byPhone.docs.forEach((d) => found.set(d.id, d.data()));
    }
  }

  const invitations = Array.from(found.entries())
    .filter(([, inv]) => checkInvitationResponse(inv, caller).ok)
    .map(([id, inv]) => summary(id, inv))
    .sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));
  return { invitations };
});

export const getMyTenantInvitation = functions.https.onCall(async (data, context) => {
  const { caller } = await callerFor(context);
  const invitationId = data?.invitationId;
  if (!invitationId) throw new functions.https.HttpsError('invalid-argument', 'invitationId required');
  const snap = await db.doc(`tenant_invitations/${invitationId}`).get();
  const inv = snap.data();
  if (!inv) fail({ ok: false, code: 'not-found', message: 'This invitation no longer exists.' });
  // Answered invitations are still shown (as answered) to the invitee.
  const check = checkInvitationResponse({ ...inv, status: 'pending' }, caller);
  if (!check.ok) fail(check);
  return { invitation: summary(snap.id, inv) };
});

export const approveInvitation = functions.https.onCall(async (data, context) => {
  const { uid, caller } = await callerFor(context);
  const invitationId = data?.invitationId;
  if (!invitationId) throw new functions.https.HttpsError('invalid-argument', 'invitationId required');

  const invRef = db.doc(`tenant_invitations/${invitationId}`);
  const userRef = db.doc(`users/${uid}`);

  const tenantDocId = await db.runTransaction(async (tx) => {
    const invSnap = await tx.get(invRef);
    const inv = invSnap.data();
    const check = checkInvitationResponse(inv, caller);
    if (!check.ok) fail(check);
    const invitation = inv as Record<string, any>;

    const resolvedId = resolveTenantDocId(caller.tenantId, invitation.tenantId);
    const globalRef = db.doc(`tenants/${resolvedId}`);
    const globalSnap = await tx.get(globalRef);
    const global = globalSnap.data();
    if (global?.status === 'active' && global?.businessId && global.businessId !== invitation.businessId) {
      fail({
        ok: false,
        code: 'failed-precondition',
        message: 'You are already staying at another PG. Vacate it before joining a new one.',
      });
    }

    const now = admin.firestore.Timestamp.now();
    const records = buildAcceptedTenantRecords(invitation, {
      invitationId,
      tenantDocId: resolvedId,
      uid,
      now,
      moveIn: invitation.moveInDate || now,
    });

    const propertyPath = `businesses/${invitation.businessId}/properties/${invitation.propertyId}`;
    const bedRef = db.doc(`${propertyPath}/rooms/${invitation.roomId}/beds/${records.bedId}`);
    const bed = (await tx.get(bedRef)).data();
    if (bed?.tenantId && (bed.occupied || bed.isOccupied) && bed.tenantId !== resolvedId) {
      fail({
        ok: false,
        code: 'failed-precondition',
        message: 'That bed has just been taken. Ask the owner to send a new invitation.',
      });
    }

    tx.set(db.doc(`businesses/${invitation.businessId}/tenants/${resolvedId}`), records.bizTenant, { merge: true });
    tx.set(globalRef, { ...records.globalTenant, name: invitation.tenantName || '', phone: invitation.tenantPhone || '' }, { merge: true });
    const stayRef = globalRef.collection('stays').doc();
    tx.set(stayRef, { stayId: stayRef.id, ...records.stay });
    tx.set(bedRef, records.bed, { merge: true });
    tx.set(db.doc(propertyPath), { occupiedBeds: admin.firestore.FieldValue.increment(1), updatedAt: now }, { merge: true });
    tx.set(userRef, { tenantId: resolvedId, isTenant: true, updatedAt: now }, { merge: true });
    tx.update(invRef, { status: 'accepted', approvedAt: now, acceptedBy: uid, tenantDocId: resolvedId });
    return resolvedId;
  });

  // Let the owner know (best effort).
  try {
    const inv = (await invRef.get()).data() || {};
    await db.collection('businesses').doc(inv.businessId).collection('notifications').add({
      businessId: inv.businessId,
      type: 'tenant_joined',
      title: 'Invitation accepted',
      message: `${inv.tenantName || 'A tenant'} accepted the invitation to ${inv.propertyName || 'your property'}.`,
      propertyId: inv.propertyId || null,
      tenantId: tenantDocId,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    functions.logger.warn('tenant_invitation_accept_notify_failed', err);
  }

  return { success: true, tenantId: tenantDocId };
});

export const rejectTenantInvitation = functions.https.onCall(async (data, context) => {
  const { uid, caller } = await callerFor(context);
  const invitationId = data?.invitationId;
  if (!invitationId) throw new functions.https.HttpsError('invalid-argument', 'invitationId required');
  const reason = typeof data?.reason === 'string' && data.reason.trim() ? data.reason.trim().slice(0, 500) : null;

  const invRef = db.doc(`tenant_invitations/${invitationId}`);
  const inv = (await invRef.get()).data();
  const check = checkInvitationResponse(inv, caller);
  if (!check.ok) fail(check);

  await invRef.update({
    status: 'rejected',
    rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
    rejectedBy: uid,
    rejectionReason: reason,
  });

  try {
    await db.collection('businesses').doc(inv!.businessId).collection('notifications').add({
      businessId: inv!.businessId,
      type: 'tenant_invitation_declined',
      title: 'Invitation declined',
      message: `${inv!.tenantName || 'A tenant'} declined the invitation to ${inv!.propertyName || 'your property'}.${reason ? ` Reason: ${reason}` : ''}`,
      propertyId: inv!.propertyId || null,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    functions.logger.warn('tenant_invitation_reject_notify_failed', err);
  }

  return { success: true };
});
