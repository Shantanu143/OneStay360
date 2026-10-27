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
exports.onMaintenanceRequestUpdated = exports.onMaintenanceRequestCreated = void 0;
/**
 * Maintenance requests (maintenanceRequests/{id}).
 *
 * Tenants create them from the tenant app and may cancel an open one; owners
 * and their team move them open -> in_progress -> resolved. Both sides write
 * directly (see firestore.rules); these triggers only notify.
 */
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const maintenanceLogic_1 = require("./maintenanceLogic");
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();
exports.onMaintenanceRequestCreated = functions.firestore
    .document('maintenanceRequests/{requestId}')
    .onCreate(async (snap, context) => {
    const r = snap.data();
    if (!r?.businessId)
        return null;
    await db
        .collection('businesses')
        .doc(r.businessId)
        .collection('notifications')
        .add({
        ...(0, maintenanceLogic_1.ownerMaintenanceNotification)(context.params.requestId, r),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return null;
});
exports.onMaintenanceRequestUpdated = functions.firestore
    .document('maintenanceRequests/{requestId}')
    .onUpdate(async (change, context) => {
    const after = change.after.data();
    const message = (0, maintenanceLogic_1.maintenanceStatusMessage)(change.before.data(), after);
    if (!message || !after.tenantUid)
        return null;
    const tokens = await db
        .collection('users')
        .doc(after.tenantUid)
        .collection('deviceTokens')
        .where('active', '==', true)
        .limit(20)
        .get();
    await Promise.all(tokens.docs.map((t) => admin
        .messaging()
        .send({
        token: t.id,
        notification: message,
        data: { type: 'maintenance_update', maintenanceRequestId: context.params.requestId },
    })
        .catch((err) => functions.logger.warn('maintenance_push_failed', err?.code || err))));
    return null;
});
//# sourceMappingURL=maintenance.js.map