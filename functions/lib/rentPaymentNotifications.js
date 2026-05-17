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
exports.onPaymentUpdated = exports.onPaymentCreated = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();
const messaging = admin.messaging();
/**
 * Triggered when a new payment is created in businesses/{businessId}/tenants/{tenantId}/payments
 * Scenarios:
 * 1. Tenant submits rent (status = 'pending_verification') -> Notify Owner
 * 2. Owner manually records payment (status = 'Paid', submittedBy = owner) -> Notify Tenant
 */
exports.onPaymentCreated = functions.firestore
    .document('businesses/{businessId}/tenants/{tenantId}/payments/{paymentId}')
    .onCreate(async (snap, context) => {
    const paymentData = snap.data();
    const { businessId, tenantId, paymentId } = context.params;
    try {
        if (paymentData.status === 'pending_verification' && paymentData.submittedBy === 'tenant') {
            // Tenant submitted rent -> Notify Business Owner
            await notifyOwnerAboutPendingRent(businessId, paymentData);
        }
        else if ((paymentData.status === 'Paid' || paymentData.status === 'paid') && paymentData.recordedBy) {
            // Owner manually recorded payment -> Notify Tenant
            await notifyTenantAboutPayment(tenantId, paymentData, 'Payment Recorded', `Your rent payment for ${paymentData.month} (₹${paymentData.amount}) has been recorded by the owner.`);
        }
    }
    catch (error) {
        console.error(`Error processing payment creation for ${paymentId}:`, error);
    }
});
/**
 * Triggered when a payment document is updated
 * Scenario:
 * Owner verifies rent (status changes from pending_verification to Paid or rejected) -> Notify Tenant
 */
exports.onPaymentUpdated = functions.firestore
    .document('businesses/{businessId}/tenants/{tenantId}/payments/{paymentId}')
    .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const { tenantId, paymentId } = context.params;
    try {
        // Check if status changed FROM pending_verification
        if (beforeData.status === 'pending_verification' && afterData.status !== 'pending_verification') {
            if (afterData.status === 'Paid' || afterData.status === 'paid') {
                // Owner confirmed
                await notifyTenantAboutPayment(tenantId, afterData, 'Rent Payment Confirmed ✅', `Your rent payment of ₹${afterData.amount} for ${afterData.month} has been verified and confirmed by the owner.`);
            }
            else if (afterData.status === 'rejected') {
                // Owner rejected
                await notifyTenantAboutPayment(tenantId, afterData, 'Rent Payment Rejected ❌', `Your rent payment for ${afterData.month} was rejected. Reason: ${afterData.rejectionReason || 'Not provided'}. Please check your app.`);
            }
        }
    }
    catch (error) {
        console.error(`Error processing payment update for ${paymentId}:`, error);
    }
});
// --- Helper Functions ---
async function notifyOwnerAboutPendingRent(businessId, paymentData) {
    const businessSnap = await db.collection('businesses').doc(businessId).get();
    if (!businessSnap.exists)
        return;
    const businessInfo = businessSnap.data();
    const ownerUserId = businessInfo?.ownerUserId || businessInfo?.ownerUid;
    if (!ownerUserId)
        return;
    const deviceTokensSnap = await db.collection('users').doc(ownerUserId).collection('deviceTokens').where('active', '==', true).get();
    if (deviceTokensSnap.empty)
        return;
    const tenantName = paymentData.tenantName || 'A tenant';
    const month = paymentData.month || '';
    const amount = paymentData.amount || 0;
    const notification = {
        title: 'New Rent Payment Submission 💰',
        body: `${tenantName} has submitted ₹${amount} for ${month}. Please verify.`,
    };
    await sendPushNotifications(deviceTokensSnap.docs.map(d => d.id), notification, {
        type: 'rent_payment_submission',
        businessId,
    });
}
async function notifyTenantAboutPayment(tenantId, paymentData, title, body) {
    // Global tenant doc contains the tenant's auth UID
    const tenantSnap = await db.collection('tenants').doc(tenantId).get();
    if (!tenantSnap.exists)
        return;
    const tenantInfo = tenantSnap.data();
    const tenantUserId = tenantInfo.userId || tenantInfo.uid; // Depending on how you link tenant docs to auth users
    // Fallback: If tenant ID is their auth UID (which is often the case in this app)
    const targetUid = tenantUserId || tenantId;
    const deviceTokensSnap = await db.collection('users').doc(targetUid).collection('deviceTokens').where('active', '==', true).get();
    if (deviceTokensSnap.empty)
        return;
    const notification = { title, body };
    await sendPushNotifications(deviceTokensSnap.docs.map(d => d.id), notification, {
        type: 'rent_payment_update',
    });
}
async function sendPushNotifications(tokens, notification, data) {
    if (tokens.length === 0)
        return;
    const sendPromises = tokens.map(async (token) => {
        try {
            await messaging.send({
                token: token,
                notification: notification,
                data: data,
                android: {
                    priority: 'high',
                    notification: {
                        title: notification.title,
                        body: notification.body,
                        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
                        sound: 'default',
                        channelId: 'rent_payments',
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            alert: { title: notification.title, body: notification.body },
                            sound: 'default',
                            badge: 1,
                        },
                    },
                },
            });
            console.log(`✅ Notification sent to token: ${token}`);
        }
        catch (error) {
            console.error(`❌ Failed to send to token ${token}:`, error);
        }
    });
    await Promise.all(sendPromises);
}
//# sourceMappingURL=rentPaymentNotifications.js.map