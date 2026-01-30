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
exports.auditBedOccupancy = exports.auditTenantDelete = exports.auditTenantCreate = exports.auditPropertyAccess = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const audit_1 = require("./audit");
if (admin.apps.length === 0) {
    admin.initializeApp();
}
exports.auditPropertyAccess = functions.firestore
    .document('businesses/{businessId}/properties/{propertyId}/access/{uid}')
    .onWrite(async (change, context) => {
    const { businessId, propertyId, uid } = context.params;
    if (!change.before.exists && change.after.exists) {
        const data = change.after.data();
        const actorUid = data?.updatedBy || data?.createdBy || data?.grantedBy;
        if (!actorUid)
            throw new Error('Missing actorUid on access grant');
        await (0, audit_1.logAudit)({
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
        const data = change.before.data();
        const actorUid = data?.updatedBy || data?.revokedBy || data?.createdBy;
        if (!actorUid)
            throw new Error('Missing actorUid on access revoke');
        await (0, audit_1.logAudit)({
            businessId,
            actorUid,
            action: 'property_access_revoked',
            entityType: 'property_access',
            entityId: uid,
            propertyId,
        });
    }
});
exports.auditTenantCreate = functions.firestore
    .document('businesses/{businessId}/tenants/{tenantId}')
    .onCreate(async (snap, context) => {
    const { businessId, tenantId } = context.params;
    const data = snap.data();
    const actorUid = data?.createdBy || data?.updatedBy;
    if (!actorUid)
        throw new Error('Missing actorUid on tenant create');
    const propertyId = data?.propertyId || null;
    await (0, audit_1.logAudit)({
        businessId,
        actorUid,
        action: 'tenant_created',
        entityType: 'tenant',
        entityId: tenantId,
        propertyId,
    });
});
exports.auditTenantDelete = functions.firestore
    .document('businesses/{businessId}/tenants/{tenantId}')
    .onDelete(async (snap, context) => {
    const { businessId, tenantId } = context.params;
    const data = snap.data();
    const actorUid = data?.updatedBy || data?.deletedBy || data?.createdBy;
    if (!actorUid)
        throw new Error('Missing actorUid on tenant delete');
    const propertyId = data?.propertyId || null;
    await (0, audit_1.logAudit)({
        businessId,
        actorUid,
        action: 'tenant_deleted',
        entityType: 'tenant',
        entityId: tenantId,
        propertyId,
    });
});
exports.auditBedOccupancy = functions.firestore
    .document('businesses/{businessId}/properties/{propertyId}/rooms/{roomId}/beds/{bedId}')
    .onUpdate(async (change, context) => {
    const { businessId, propertyId, bedId } = context.params;
    const before = change.before.data();
    const after = change.after.data();
    const beforeOccupied = Boolean(before?.isOccupied);
    const afterOccupied = Boolean(after?.isOccupied);
    const beforeTenant = before?.tenantId || null;
    const afterTenant = after?.tenantId || null;
    let action = null;
    if (!beforeOccupied && afterOccupied) {
        action = 'bed_occupied';
    }
    else if (beforeOccupied && !afterOccupied) {
        action = 'bed_vacated';
    }
    else if (beforeOccupied && afterOccupied && beforeTenant !== afterTenant) {
        action = 'bed_occupied';
    }
    if (!action)
        return null;
    const actorUid = after?.updatedBy || after?.occupiedBy;
    if (!actorUid)
        throw new Error('Missing actorUid on bed occupancy change');
    await (0, audit_1.logAudit)({
        businessId,
        actorUid,
        action,
        entityType: 'bed',
        entityId: bedId,
        propertyId,
    });
    return null;
});
//# sourceMappingURL=auditTriggers.js.map