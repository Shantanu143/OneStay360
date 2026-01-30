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
exports.assertBusinessPermission = assertBusinessPermission;
exports.assertPropertyPermission = assertPropertyPermission;
exports.getMembershipRole = getMembershipRole;
exports.getPropertyRole = getPropertyRole;
exports.businessPermissionsForRole = businessPermissionsForRole;
exports.propertyPermissionsForRole = propertyPermissionsForRole;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const businessPermissions = {
    owner: new Set(['INVITE_MEMBERS', 'ASSIGN_PROPERTIES', 'VIEW_BILLING', 'PAY_INVOICES', 'VIEW_REPORTS']),
    manager: new Set(['VIEW_REPORTS']),
    staff: new Set([]),
};
const propertyPermissions = {
    owner: new Set([
        'VIEW_PROPERTY',
        'MANAGE_PROPERTY_STATE',
        'CREATE_ROOMS_BEDS',
        'UPDATE_ROOMS_BEDS',
        'UPDATE_BED_OCCUPANCY',
        'CREATE_TENANTS',
        'UPDATE_TENANTS',
        'DELETE_TENANTS',
    ]),
    manager: new Set([
        'VIEW_PROPERTY',
        'UPDATE_BED_OCCUPANCY',
        'CREATE_TENANTS',
        'UPDATE_TENANTS',
    ]),
    staff: new Set([
        'VIEW_PROPERTY',
        'UPDATE_BED_OCCUPANCY',
        'CREATE_TENANTS',
        'UPDATE_TENANTS',
    ]),
};
function businessPermissionsForRole(role) {
    return Array.from(businessPermissions[role] ?? []);
}
function propertyPermissionsForRole(role) {
    return Array.from(propertyPermissions[role] ?? []);
}
const db = admin.firestore();
async function getMembershipRole(uid, businessId) {
    const snap = await db.doc(`businesses/${businessId}/members/${uid}`).get();
    if (!snap.exists) {
        throw new functions.https.HttpsError('permission-denied', 'Not a business member');
    }
    const data = snap.data();
    if (data.status !== 'active') {
        throw new functions.https.HttpsError('permission-denied', 'Inactive membership');
    }
    const role = data.role || 'staff';
    return role;
}
async function getPropertyRole(uid, businessId, propertyId) {
    const businessRole = await getMembershipRole(uid, businessId);
    if (businessRole === 'owner')
        return 'owner';
    const accessRef = db.doc(`businesses/${businessId}/properties/${propertyId}/access/${uid}`);
    const accessSnap = await accessRef.get();
    if (!accessSnap.exists) {
        throw new functions.https.HttpsError('permission-denied', 'No property access');
    }
    const role = accessSnap.data()?.role || 'staff';
    return role;
}
async function assertBusinessPermission(uid, businessId, permission) {
    const role = await getMembershipRole(uid, businessId);
    if (!businessPermissions[role].has(permission)) {
        throw new functions.https.HttpsError('permission-denied', 'Permission denied');
    }
}
async function assertPropertyPermission(uid, businessId, propertyId, permission) {
    const role = await getPropertyRole(uid, businessId, propertyId);
    if (!propertyPermissions[role].has(permission)) {
        throw new functions.https.HttpsError('permission-denied', 'Permission denied');
    }
}
//# sourceMappingURL=permissions.js.map