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
exports.processMonthlyBilling = void 0;
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
const db = admin.firestore();
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
        return;
    if (!prop.nextBillingDate)
        return;
    await db.runTransaction(async (tx) => {
        const freshPropSnap = await tx.get(propertyRef);
        if (!freshPropSnap.exists)
            return;
        const freshProp = freshPropSnap.data();
        const nextBillingDate = freshProp.nextBillingDate;
        if (!nextBillingDate)
            return;
        if (freshProp.status !== 'active' && freshProp.status !== 'suspended')
            return;
        if (now.toMillis() < nextBillingDate.toMillis())
            return;
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
            return;
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
    });
}
exports.processMonthlyBilling = functions.pubsub
    .schedule('0 3 * * *')
    .timeZone('Etc/UTC')
    .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const defaultPlan = await (0, plan_1.getDefaultActivePlan)();
    const propsSnap = await db.collectionGroup('properties').get();
    const tasks = [];
    propsSnap.forEach((doc) => {
        tasks.push(processProperty(doc, now, defaultPlan));
    });
    await Promise.all(tasks);
});
//# sourceMappingURL=billing.js.map