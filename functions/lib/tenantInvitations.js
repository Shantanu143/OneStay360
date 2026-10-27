"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.rejectTenantInvitation = exports.approveInvitation = exports.getMyTenantInvitation = exports.listMyTenantInvitations = void 0;
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
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const tenantInvitationLogic_1 = require("./tenantInvitationLogic");
const invitationLogic_1 = require("./invitationLogic");
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();
async function callerFor(context) {
    const uid = context.auth?.uid;
    if (!uid)
        throw new functions.https.HttpsError('unauthenticated', 'Login required');
    const user = (await db.doc(`users/${uid}`).get()).data() || {};
    return {
        uid,
        caller: {
            tenantId: user.tenantId || null,
            phones: [context.auth?.token?.phone_number, user.phone, user.mobileNumber],
        },
    };
}
function fail(check) {
    throw new functions.https.HttpsError(check.code, check.message);
}
function summary(id, inv) {
    const millis = (v) => (v && typeof v.toMillis === 'function' ? v.toMillis() : null);
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
exports.listMyTenantInvitations = functions.https.onCall(async (_data, context) => {
    const { caller } = await callerFor(context);
    const found = new Map();
    if (caller.tenantId) {
        const byId = await db
            .collection('tenant_invitations')
            .where('tenantId', '==', caller.tenantId)
            .where('status', '==', 'pending')
            .get();
        byId.docs.forEach((d) => found.set(d.id, d.data()));
    }
    // Phones are stored as the owner typed them, so try the usual spellings.
    const tenDigits = Array.from(new Set(caller.phones.map((p) => (0, invitationLogic_1.normalizePhone)(p)).filter((p) => p.length === 10)));
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
        .filter(([, inv]) => (0, tenantInvitationLogic_1.checkInvitationResponse)(inv, caller).ok)
        .map(([id, inv]) => summary(id, inv))
        .sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));
    return { invitations };
});
exports.getMyTenantInvitation = functions.https.onCall(async (data, context) => {
    const { caller } = await callerFor(context);
    const invitationId = data?.invitationId;
    if (!invitationId)
        throw new functions.https.HttpsError('invalid-argument', 'invitationId required');
    const snap = await db.doc(`tenant_invitations/${invitationId}`).get();
    const inv = snap.data();
    if (!inv)
        fail({ ok: false, code: 'not-found', message: 'This invitation no longer exists.' });
    // Answered invitations are still shown (as answered) to the invitee.
    const check = (0, tenantInvitationLogic_1.checkInvitationResponse)({ ...inv, status: 'pending' }, caller);
    if (!check.ok)
        fail(check);
    return { invitation: summary(snap.id, inv) };
});
exports.approveInvitation = functions.https.onCall(async (data, context) => {
    const { uid, caller } = await callerFor(context);
    const invitationId = data?.invitationId;
    if (!invitationId)
        throw new functions.https.HttpsError('invalid-argument', 'invitationId required');
    const invRef = db.doc(`tenant_invitations/${invitationId}`);
    const userRef = db.doc(`users/${uid}`);
    const tenantDocId = await db.runTransaction(async (tx) => {
        const invSnap = await tx.get(invRef);
        const inv = invSnap.data();
        const check = (0, tenantInvitationLogic_1.checkInvitationResponse)(inv, caller);
        if (!check.ok)
            fail(check);
        const invitation = inv;
        const resolvedId = (0, tenantInvitationLogic_1.resolveTenantDocId)(caller.tenantId, invitation.tenantId);
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
        const records = (0, tenantInvitationLogic_1.buildAcceptedTenantRecords)(invitation, {
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
    }
    catch (err) {
        functions.logger.warn('tenant_invitation_accept_notify_failed', err);
    }
    return { success: true, tenantId: tenantDocId };
});
exports.rejectTenantInvitation = functions.https.onCall(async (data, context) => {
    const { uid, caller } = await callerFor(context);
    const invitationId = data?.invitationId;
    if (!invitationId)
        throw new functions.https.HttpsError('invalid-argument', 'invitationId required');
    const reason = typeof data?.reason === 'string' && data.reason.trim() ? data.reason.trim().slice(0, 500) : null;
    const invRef = db.doc(`tenant_invitations/${invitationId}`);
    const inv = (await invRef.get()).data();
    const check = (0, tenantInvitationLogic_1.checkInvitationResponse)(inv, caller);
    if (!check.ok)
        fail(check);
    await invRef.update({
        status: 'rejected',
        rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
        rejectedBy: uid,
        rejectionReason: reason,
    });
    try {
        await db.collection('businesses').doc(inv.businessId).collection('notifications').add({
            businessId: inv.businessId,
            type: 'tenant_invitation_declined',
            title: 'Invitation declined',
            message: `${inv.tenantName || 'A tenant'} declined the invitation to ${inv.propertyName || 'your property'}.${reason ? ` Reason: ${reason}` : ''}`,
            propertyId: inv.propertyId || null,
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    catch (err) {
        functions.logger.warn('tenant_invitation_reject_notify_failed', err);
    }
    return { success: true };
});
//# sourceMappingURL=tenantInvitations.js.map