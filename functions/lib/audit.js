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
exports.logAudit = logAudit;
const admin = __importStar(require("firebase-admin"));
const permissions_1 = require("./permissions");
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();
async function resolveActorContext(businessId, actorUid, propertyId) {
    const businessRole = await (0, permissions_1.getMembershipRole)(actorUid, businessId);
    const propertyScoped = propertyId && typeof propertyId === 'string';
    if (propertyScoped) {
        const propertyRole = await (0, permissions_1.getPropertyRole)(actorUid, businessId, propertyId);
        return {
            actorRole: propertyRole,
            actorPermissions: {
                business: (0, permissions_1.businessPermissionsForRole)(businessRole),
                property: (0, permissions_1.propertyPermissionsForRole)(propertyRole),
            },
        };
    }
    return {
        actorRole: businessRole,
        actorPermissions: {
            business: (0, permissions_1.businessPermissionsForRole)(businessRole),
        },
    };
}
async function logAudit(payload) {
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
//# sourceMappingURL=audit.js.map