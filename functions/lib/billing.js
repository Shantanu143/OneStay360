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
exports.triggerBillingManual = exports.processMonthlyBilling = void 0;
// PLAN & PRICING INVARIANTS:
// - Plans and pricing are platform-owned.
// - Properties carry a plan snapshot (immutable per property).
// - Billing never reads live plan pricing for existing properties; it uses snapshots.
// - Any pricing change requires explicit migration logic.
// Billing engine invariants:
// - All billing state transitions are server-owned (scheduler + payment confirmation).
// - Clients must not write billing fields or infer state transitions.
// - property.billingStatus is set only from processMonthlyBilling and confirmActivationPayment.
// - invoice status lifecycle mirrors property billing status; paid is terminal.
// PRICING OWNERSHIP:
// - pricePerBed is platform-owned (OneStay360), not editable by business owners, never sent by clients.
// - Promos apply only to final payable amount; base pricing is constant and server-side.
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const plan_1 = require("./plan");
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();
const messaging = admin.messaging();
function addDays(ts, days) {
    const d = ts.toDate();
    d.setDate(d.getDate() + days);
    return admin.firestore.Timestamp.fromDate(d);
}
function computeStateFromDue(now, dueDate) {
    const graceEnd = addDays(dueDate, 5);
    const suspensionAt = addDays(dueDate, 12);
    if (now.toMillis() <= dueDate.toMillis())
        return 'due';
    if (now.toMillis() <= graceEnd.toMillis())
        return 'grace';
    if (now.toMillis() <= suspensionAt.toMillis())
        return 'past_due';
    return 'suspended';
}
function deterministicInvoiceId(propertyId, periodStart) {
    return `${propertyId}_${periodStart.toMillis()}`;
}
async function processProperty(propSnap, now, defaultPlan) {
    const prop = propSnap.data();
    const propertyRef = propSnap.ref;
    if (prop.status !== 'active' && prop.status !== 'suspended')
        return null;
    if (!prop.nextBillingDate)
        return null;
    return await db.runTransaction(async (tx) => {
        const freshPropSnap = await tx.get(propertyRef);
        if (!freshPropSnap.exists)
            return null;
        const freshProp = freshPropSnap.data();
        const nextBillingDate = freshProp.nextBillingDate;
        if (!nextBillingDate)
            return null;
        if (freshProp.status !== 'active' && freshProp.status !== 'suspended')
            return null;
        if (now.toMillis() < nextBillingDate.toMillis())
            return null;
        const periodStart = nextBillingDate;
        const periodEnd = addDays(periodStart, 30);
        const dueDate = addDays(periodStart, 5);
        const planFromProperty = freshProp.plan;
        const plan = planFromProperty && typeof planFromProperty.pricePerBedInr === 'number'
            ? {
                id: planFromProperty.id || 'property_plan_snapshot',
                name: planFromProperty.name || 'Plan',
                pricePerBedInr: planFromProperty.pricePerBedInr,
                isActive: true,
                isDefault: false,
            }
            : defaultPlan;
        const baseAmount = Number(plan.pricePerBedInr) * Number(freshProp.totalBeds || 0);
        if (!Number.isFinite(baseAmount) || baseAmount <= 0)
            return null;
        const invoiceId = deterministicInvoiceId(freshProp.propertyId || propSnap.id, periodStart);
        const invoiceRef = db.collection('billing_invoices').doc(invoiceId);
        const existingInvoiceQuery = db
            .collection('billing_invoices')
            .where('propertyId', '==', freshProp.propertyId || propSnap.id)
            .where('periodStart', '==', periodStart)
            .where('status', 'in', ['issued', 'due', 'grace', 'past_due']);
        let invoiceSnap = await tx.get(invoiceRef);
        const deterministicStatus = invoiceSnap.exists ? invoiceSnap.data()?.status : undefined;
        if (!invoiceSnap.exists || deterministicStatus === 'paid') {
            const existingUnpaid = await tx.get(existingInvoiceQuery);
            if (!existingUnpaid.empty) {
                invoiceSnap = existingUnpaid.docs[0];
            }
            else if (!invoiceSnap.exists) {
                tx.set(invoiceRef, {
                    invoiceId,
                    businessId: freshProp.businessId,
                    propertyId: freshProp.propertyId || propSnap.id,
                    purpose: 'monthly',
                    periodStart,
                    periodEnd,
                    baseAmount,
                    discountAmount: 0,
                    finalAmount: baseAmount,
                    status: 'issued',
                    dueDate,
                    paidAt: null,
                    paymentId: null,
                    promoCode: null,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                invoiceSnap = await tx.get(invoiceRef);
            }
        }
        const invoiceData = invoiceSnap.exists ? invoiceSnap.data() : undefined;
        const invoiceDueDate = invoiceData?.dueDate || dueDate;
        let billingStatus;
        if (invoiceData?.status === 'paid') {
            billingStatus = 'paid';
        }
        else {
            billingStatus = computeStateFromDue(now, invoiceDueDate);
        }
        // Keep invoice status aligned for ops visibility (never regress paid)
        if (invoiceSnap.exists) {
            const currentInvoiceStatus = invoiceData?.status || 'issued';
            const nextInvoiceStatus = currentInvoiceStatus === 'paid' ? 'paid' : billingStatus;
            if (nextInvoiceStatus !== currentInvoiceStatus) {
                tx.update(invoiceRef, { status: nextInvoiceStatus });
            }
        }
        const updates = { billingStatus };
        if (billingStatus === 'suspended') {
            updates.status = 'suspended';
        }
        else if (billingStatus === 'paid') {
            updates.status = 'active';
        }
        tx.update(propertyRef, updates);
        // Return status change info for notification
        return {
            propertyId: freshProp.propertyId || propSnap.id,
            propertyName: freshProp.name || 'Property',
            businessId: freshProp.businessId,
            billingStatus,
            previousStatus: freshProp.billingStatus,
            invoiceAmount: invoiceData?.finalAmount || baseAmount,
            dueDate: invoiceDueDate,
        };
    });
}
/**
 * Send billing notification to business owner
 */
async function sendBillingNotification(businessId, notification, data) {
    try {
        // Get business owner's user ID
        const businessSnap = await db.collection('businesses').doc(businessId).get();
        if (!businessSnap.exists) {
            console.warn(`Business ${businessId} not found for billing notification`);
            return;
        }
        const businessData = businessSnap.data();
        const ownerUserId = businessData?.ownerUserId || businessData?.ownerUid;
        if (!ownerUserId) {
            console.warn(`No owner found for business ${businessId}`);
            return;
        }
        // Get device tokens
        const deviceTokensSnap = await db
            .collection('users')
            .doc(ownerUserId)
            .collection('deviceTokens')
            .where('active', '==', true)
            .limit(100)
            .get();
        if (deviceTokensSnap.empty) {
            console.log(`No active device tokens for business owner ${ownerUserId}`);
            return;
        }
        const deviceTokens = deviceTokensSnap.docs.map((doc) => doc.id);
        // Send to all tokens
        const sendPromises = deviceTokens.map(async (token) => {
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
                            channelId: 'billing_notifications',
                        },
                    },
                    apns: {
                        payload: {
                            aps: {
                                alert: {
                                    title: notification.title,
                                    body: notification.body,
                                },
                                sound: 'default',
                                badge: 1,
                            },
                        },
                    },
                });
                console.log(`✅ Billing notification sent to token: ${token.substring(0, 20)}...`);
            }
            catch (error) {
                console.error(`❌ Failed to send billing notification to token:`, error?.message);
                // Mark invalid tokens as inactive
                if (error?.message?.includes('registration token is invalid') ||
                    error?.message?.includes('registration token is not registered')) {
                    await db
                        .collection('users')
                        .doc(ownerUserId)
                        .collection('deviceTokens')
                        .doc(token)
                        .update({ active: false, deactivatedAt: new Date() })
                        .catch(() => { });
                }
            }
        });
        await Promise.all(sendPromises);
        // Also persist notification to business notifications collection
        await db.collection('businesses').doc(businessId).collection('notifications').add({
            businessId,
            title: notification.title,
            message: notification.body,
            type: data.type || 'billing',
            propertyId: data.propertyId || null,
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            metadata: data,
        });
        console.log(`✅ Billing notification persisted for business ${businessId}`);
    }
    catch (error) {
        console.error('Error sending billing notification:', error);
    }
}
/**
 * Get notification message based on billing status
 */
function getBillingNotificationMessage(status, propertyName, amount, dueDate) {
    const dueDateStr = dueDate.toDate().toLocaleDateString('en-IN');
    const amountStr = `₹${amount.toLocaleString('en-IN')}`;
    switch (status) {
        case 'due':
            return {
                title: '💰 Payment Due',
                body: `Payment of ${amountStr} is due for ${propertyName}. Due date: ${dueDateStr}`,
            };
        case 'grace':
            return {
                title: '⚠️ Payment Overdue - Grace Period',
                body: `Payment of ${amountStr} for ${propertyName} is overdue. Please pay within 5 days to avoid suspension.`,
            };
        case 'past_due':
            return {
                title: '🚨 Urgent: Payment Past Due',
                body: `Payment for ${propertyName} is past due. Property will be suspended soon if not paid.`,
            };
        case 'suspended':
            return {
                title: '🔴 Property Suspended',
                body: `${propertyName} has been suspended due to non-payment. Pay ${amountStr} to reactivate.`,
            };
        default:
            return null;
    }
}
exports.processMonthlyBilling = functions
    .runWith({
    timeoutSeconds: 540,
    memory: '512MB',
    minInstances: 0,
    maxInstances: 1,
})
    .pubsub.schedule('0 3 * * *')
    .timeZone('Asia/Kolkata')
    .onRun(async () => {
    console.log('🔄 Starting processMonthlyBilling...');
    const now = admin.firestore.Timestamp.now();
    const defaultPlan = await (0, plan_1.getDefaultActivePlan)();
    const propsSnap = await db.collectionGroup('properties').get();
    console.log(`📊 Processing ${propsSnap.size} properties...`);
    const statusChanges = [];
    // Process properties sequentially to avoid overwhelming Firestore
    for (const doc of propsSnap.docs) {
        try {
            const result = await processProperty(doc, now, defaultPlan);
            if (result && result.billingStatus !== result.previousStatus) {
                statusChanges.push(result);
            }
        }
        catch (error) {
            console.error(`Error processing property ${doc.id}:`, error);
        }
    }
    console.log(`📬 Sending notifications for ${statusChanges.length} status changes...`);
    // Send notifications for status changes
    for (const change of statusChanges) {
        const message = getBillingNotificationMessage(change.billingStatus, change.propertyName, change.invoiceAmount, change.dueDate);
        if (message) {
            await sendBillingNotification(change.businessId, message, {
                type: 'billing_status_change',
                propertyId: change.propertyId,
                propertyName: change.propertyName,
                billingStatus: change.billingStatus,
                previousStatus: change.previousStatus,
                invoiceAmount: String(change.invoiceAmount),
            });
        }
    }
    console.log('✅ processMonthlyBilling completed');
    return null;
});
/**
 * Manual trigger for billing processing (for testing/ops)
 * Call this to manually run billing for a specific property or all properties
 */
exports.triggerBillingManual = functions.https.onCall(async (data, context) => {
    // Require authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }
    const { propertyId, businessId } = data || {};
    const now = admin.firestore.Timestamp.now();
    const defaultPlan = await (0, plan_1.getDefaultActivePlan)();
    console.log(`🔄 Manual billing trigger by ${context.auth.uid}`);
    if (propertyId && businessId) {
        // Process single property
        const propSnap = await db
            .doc(`businesses/${businessId}/properties/${propertyId}`)
            .get();
        if (!propSnap.exists) {
            throw new functions.https.HttpsError('not-found', 'Property not found');
        }
        const result = await processProperty(propSnap, now, defaultPlan);
        return { success: true, result };
    }
    else {
        // Process all properties
        const propsSnap = await db.collectionGroup('properties').get();
        let processed = 0;
        for (const doc of propsSnap.docs) {
            try {
                await processProperty(doc, now, defaultPlan);
                processed++;
            }
            catch (error) {
                console.error(`Error processing ${doc.id}:`, error);
            }
        }
        return { success: true, processed };
    }
});
//# sourceMappingURL=billing.js.map