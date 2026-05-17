"use strict";
/**
 * ======================================================
 * TENANT BILLING — Automated Rent Invoice Generation
 * ======================================================
 *
 * Daily CRON job that:
 * 1. Checks all active tenants
 * 2. Generates rent invoices on their billing date
 * 3. Marks overdue invoices
 * 4. Sends push notifications
 */
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
exports.triggerRentInvoiceGeneration = exports.markOverdueInvoices = exports.generateTenantRentInvoices = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();
const messaging = admin.messaging();
// ─── Helpers ────────────────────────────────────────────
function getMonthLabel(date) {
    const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return `${months[date.getMonth()]} ${date.getFullYear()}`;
}
function getPeriodMonth(date) {
    const y = date.getFullYear();
    const m = (date.getMonth() + 1).toString().padStart(2, '0');
    return `${y}-${m}`;
}
async function sendPushToTenant(tenantId, notification, data) {
    try {
        // Get the tenant's user ID from the global tenant doc
        const tenantSnap = await db.collection('tenants').doc(tenantId).get();
        if (!tenantSnap.exists)
            return;
        const tenantData = tenantSnap.data();
        const userId = tenantData.userId || tenantData.uid;
        if (!userId)
            return;
        const tokensSnap = await db
            .collection('users')
            .doc(userId)
            .collection('deviceTokens')
            .where('active', '==', true)
            .limit(50)
            .get();
        if (tokensSnap.empty)
            return;
        for (const tokenDoc of tokensSnap.docs) {
            try {
                await messaging.send({
                    token: tokenDoc.id,
                    notification,
                    data: data || {},
                    android: {
                        priority: 'high',
                        notification: {
                            ...notification,
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
            }
            catch (err) {
                if (err?.message?.includes('registration token is invalid') ||
                    err?.message?.includes('not registered')) {
                    await tokenDoc.ref.update({ active: false }).catch(() => { });
                }
            }
        }
    }
    catch (err) {
        functions.logger.warn('tenant_push_failed', { tenantId, error: err });
    }
}
// ======================================================
// GENERATE TENANT RENT INVOICES (Daily CRON)
// ======================================================
/**
 * Runs daily at 1:00 AM IST.
 * For each active tenant, checks if a rent invoice should be generated
 * for the current month based on their billing date.
 *
 * Billing date is derived from:
 * 1. tenant.additionalInfo.billingDate (explicit, set during onboarding)
 * 2. Fallback: day-of-month from tenant.checkInDate
 * 3. Fallback: 1st of the month
 */
exports.generateTenantRentInvoices = functions
    .runWith({
    timeoutSeconds: 540,
    memory: '512MB',
    maxInstances: 1,
})
    .pubsub.schedule('0 1 * * *')
    .timeZone('Asia/Kolkata')
    .onRun(async () => {
    functions.logger.info('🔄 Starting generateTenantRentInvoices...');
    const now = new Date();
    const today = now.getDate();
    const currentPeriod = getPeriodMonth(now);
    const currentMonthLabel = getMonthLabel(now);
    // Query all active tenants across all businesses
    const tenantsSnap = await db
        .collectionGroup('tenants')
        .where('status', '==', 'active')
        .get();
    functions.logger.info(`📊 Found ${tenantsSnap.size} active tenants`);
    let invoicesCreated = 0;
    let skipped = 0;
    for (const tenantDoc of tenantsSnap.docs) {
        try {
            const tenant = tenantDoc.data();
            const tenantId = tenantDoc.id;
            const businessId = tenant.businessId;
            // Skip if missing essential data
            if (!businessId || !tenant.monthlyRent || tenant.monthlyRent <= 0) {
                skipped++;
                continue;
            }
            // Determine billing date for this tenant
            let billingDate = 1; // default: 1st of month
            if (tenant.additionalInfo?.billingDate) {
                billingDate = Number(tenant.additionalInfo.billingDate);
            }
            else if (tenant.checkInDate) {
                const checkIn = tenant.checkInDate.toDate
                    ? tenant.checkInDate.toDate()
                    : new Date(tenant.checkInDate);
                billingDate = checkIn.getDate();
            }
            // Only generate invoice on the billing date (or after, if missed)
            if (today < billingDate) {
                skipped++;
                continue;
            }
            // Check if invoice already exists for this period (idempotent)
            const existingSnap = await db
                .collection(`businesses/${businessId}/tenants/${tenantId}/rent_invoices`)
                .where('periodMonth', '==', currentPeriod)
                .limit(1)
                .get();
            if (!existingSnap.empty) {
                skipped++;
                continue;
            }
            // Calculate due date (billing date + 5 days grace)
            const dueDate = new Date(now.getFullYear(), now.getMonth(), billingDate + 5);
            const dueDateTs = admin.firestore.Timestamp.fromDate(dueDate);
            const nowTs = admin.firestore.Timestamp.now();
            // Create the rent invoice
            const invoiceRef = db
                .collection(`businesses/${businessId}/tenants/${tenantId}/rent_invoices`)
                .doc();
            await invoiceRef.set({
                invoiceId: invoiceRef.id,
                tenantId,
                businessId,
                propertyId: tenant.propertyId || '',
                amount: Number(tenant.monthlyRent),
                month: currentMonthLabel,
                periodMonth: currentPeriod,
                dueDate: dueDateTs,
                status: 'unpaid',
                verification: 'unverified',
                mode: null,
                razorpayPaymentLinkId: null,
                razorpayPaymentLinkUrl: null,
                razorpayPaymentId: null,
                paidAt: null,
                createdAt: nowTs,
                updatedAt: nowTs,
            });
            invoicesCreated++;
            // Send push notification to tenant
            await sendPushToTenant(tenantId, {
                title: '🏠 Rent Due',
                body: `Your rent of ₹${Number(tenant.monthlyRent).toLocaleString('en-IN')} for ${currentMonthLabel} is due. Pay now to avoid late fees.`,
            }, {
                type: 'rent_due',
                businessId,
                amount: String(tenant.monthlyRent),
                month: currentMonthLabel,
            });
        }
        catch (err) {
            functions.logger.error(`Error generating invoice for tenant ${tenantDoc.id}:`, err);
        }
    }
    functions.logger.info(`✅ generateTenantRentInvoices completed. Created: ${invoicesCreated}, Skipped: ${skipped}`);
    return null;
});
// ======================================================
// MARK OVERDUE INVOICES (Daily CRON)
// ======================================================
/**
 * Runs daily at 9:00 AM IST.
 * Marks unpaid invoices as 'overdue' if past due date.
 * Sends reminder notifications.
 */
exports.markOverdueInvoices = functions
    .runWith({
    timeoutSeconds: 300,
    memory: '256MB',
    maxInstances: 1,
})
    .pubsub.schedule('0 9 * * *')
    .timeZone('Asia/Kolkata')
    .onRun(async () => {
    functions.logger.info('🔄 Starting markOverdueInvoices...');
    const now = admin.firestore.Timestamp.now();
    let markedOverdue = 0;
    // Query all unpaid invoices where dueDate has passed
    const overdueSnap = await db
        .collectionGroup('rent_invoices')
        .where('status', '==', 'unpaid')
        .where('dueDate', '<', now)
        .limit(500)
        .get();
    if (overdueSnap.empty) {
        functions.logger.info('✅ No overdue invoices found');
        return null;
    }
    const batch = db.batch();
    for (const doc of overdueSnap.docs) {
        batch.update(doc.ref, {
            status: 'overdue',
            updatedAt: now,
        });
        // Send reminder notification
        const invoice = doc.data();
        if (invoice.tenantId) {
            // Fire-and-forget notification
            sendPushToTenant(invoice.tenantId, {
                title: '⚠️ Rent Overdue!',
                body: `Your rent of ₹${Number(invoice.amount).toLocaleString('en-IN')} for ${invoice.month || ''} is overdue. Please pay immediately.`,
            }, {
                type: 'rent_overdue',
                businessId: invoice.businessId || '',
                amount: String(invoice.amount),
            }).catch(() => { });
        }
        markedOverdue++;
    }
    await batch.commit();
    functions.logger.info(`✅ Marked ${markedOverdue} invoices as overdue`);
    return null;
});
// ======================================================
// MANUAL TRIGGER (for testing / ops)
// ======================================================
/**
 * Manually trigger rent invoice generation for a specific business or all.
 * Useful for testing and backfill.
 */
exports.triggerRentInvoiceGeneration = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }
    const { businessId, tenantId } = data || {};
    const now = new Date();
    const currentPeriod = getPeriodMonth(now);
    const currentMonthLabel = getMonthLabel(now);
    const nowTs = admin.firestore.Timestamp.now();
    let created = 0;
    let tenantsQuery = db
        .collectionGroup('tenants')
        .where('status', '==', 'active');
    if (businessId && tenantId) {
        // Single tenant
        const tenantSnap = await db
            .doc(`businesses/${businessId}/tenants/${tenantId}`)
            .get();
        if (!tenantSnap.exists) {
            throw new functions.https.HttpsError('not-found', 'Tenant not found');
        }
        const tenant = tenantSnap.data();
        if (!tenant.monthlyRent || tenant.monthlyRent <= 0) {
            return { success: true, created: 0, message: 'Tenant has no rent configured' };
        }
        // Check existing
        const existingSnap = await db
            .collection(`businesses/${businessId}/tenants/${tenantId}/rent_invoices`)
            .where('periodMonth', '==', currentPeriod)
            .limit(1)
            .get();
        if (!existingSnap.empty) {
            return { success: true, created: 0, message: 'Invoice already exists for this period' };
        }
        let billingDate = 1;
        if (tenant.additionalInfo?.billingDate) {
            billingDate = Number(tenant.additionalInfo.billingDate);
        }
        const dueDate = new Date(now.getFullYear(), now.getMonth(), billingDate + 5);
        const invoiceRef = db
            .collection(`businesses/${businessId}/tenants/${tenantId}/rent_invoices`)
            .doc();
        await invoiceRef.set({
            invoiceId: invoiceRef.id,
            tenantId,
            businessId,
            propertyId: tenant.propertyId || '',
            amount: Number(tenant.monthlyRent),
            month: currentMonthLabel,
            periodMonth: currentPeriod,
            dueDate: admin.firestore.Timestamp.fromDate(dueDate),
            status: 'unpaid',
            verification: 'unverified',
            mode: null,
            razorpayPaymentLinkId: null,
            razorpayPaymentLinkUrl: null,
            razorpayPaymentId: null,
            paidAt: null,
            createdAt: nowTs,
            updatedAt: nowTs,
        });
        created = 1;
    }
    else {
        return {
            success: false,
            message: 'Provide businessId and tenantId for targeted generation',
        };
    }
    return { success: true, created };
});
//# sourceMappingURL=tenantBilling.js.map