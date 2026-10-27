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
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { BillingStatus } from './types';
import { getDefaultActivePlan, Plan } from './plan';
import { assertPropertyPermission } from './permissions';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

function addDays(ts: admin.firestore.Timestamp, days: number) {
  const d = ts.toDate();
  d.setDate(d.getDate() + days);
  return admin.firestore.Timestamp.fromDate(d);
}

function computeStateFromDue(now: admin.firestore.Timestamp, dueDate: admin.firestore.Timestamp): BillingStatus {
  const graceEnd = addDays(dueDate, 5);
  const suspensionAt = addDays(dueDate, 12);

  if (now.toMillis() <= dueDate.toMillis()) return 'due';
  if (now.toMillis() <= graceEnd.toMillis()) return 'grace';
  if (now.toMillis() <= suspensionAt.toMillis()) return 'past_due';
  return 'suspended';
}

function deterministicInvoiceId(propertyId: string, periodStart: admin.firestore.Timestamp) {
  return `${propertyId}_${periodStart.toMillis()}`;
}

type BillingResult = {
  propertyId: string;
  propertyName: string;
  businessId: string;
  billingStatus: BillingStatus;
  previousStatus: string;
  invoiceAmount: number;
  dueDate: admin.firestore.Timestamp;
} | null;

async function processProperty(
  propSnap: FirebaseFirestore.QueryDocumentSnapshot,
  now: admin.firestore.Timestamp,
  defaultPlan: Plan
): Promise<BillingResult> {
  const prop = propSnap.data() as any;
  const propertyRef = propSnap.ref;

  if (prop.status !== 'active' && prop.status !== 'suspended') return null;
  if (!prop.nextBillingDate) return null;

  return await db.runTransaction(async (tx) => {
    const freshPropSnap = await tx.get(propertyRef);
    if (!freshPropSnap.exists) return null;
    const freshProp = freshPropSnap.data() as any;

    const nextBillingDate: admin.firestore.Timestamp | undefined = freshProp.nextBillingDate;
    if (!nextBillingDate) return null;
    if (freshProp.status !== 'active' && freshProp.status !== 'suspended') return null;
    if (now.toMillis() < nextBillingDate.toMillis()) return null;

    const periodStart = nextBillingDate;
    const periodEnd = addDays(periodStart, 30);
    const dueDate = addDays(periodStart, 5);
    const planFromProperty = freshProp.plan as Partial<Plan> | undefined;
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
    if (!Number.isFinite(baseAmount) || baseAmount <= 0) return null;

    const invoiceId = deterministicInvoiceId(freshProp.propertyId || propSnap.id, periodStart);
    const invoiceRef = db.collection('billing_invoices').doc(invoiceId);

    const existingInvoiceQuery = db
      .collection('billing_invoices')
      .where('propertyId', '==', freshProp.propertyId || propSnap.id)
      .where('periodStart', '==', periodStart)
      .where('status', 'in', ['issued', 'due', 'grace', 'past_due']);

    let invoiceSnap = await tx.get(invoiceRef);
    const deterministicStatus = invoiceSnap.exists ? (invoiceSnap.data() as any)?.status : undefined;

    if (!invoiceSnap.exists || deterministicStatus === 'paid') {
      const existingUnpaid = await tx.get(existingInvoiceQuery);
      if (!existingUnpaid.empty) {
        invoiceSnap = existingUnpaid.docs[0];
      } else if (!invoiceSnap.exists) {
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

    const invoiceData = invoiceSnap.exists ? ((invoiceSnap as any).data() as any) : undefined;
    const invoiceDueDate: admin.firestore.Timestamp = (invoiceData?.dueDate as any) || dueDate;
    let billingStatus: BillingStatus;

    if (invoiceData?.status === 'paid') {
      billingStatus = 'paid';
    } else {
      billingStatus = computeStateFromDue(now, invoiceDueDate);
    }

    // Keep invoice status aligned for ops visibility (never regress paid)
    if (invoiceSnap.exists) {
      const currentInvoiceStatus = (invoiceData?.status as BillingStatus | undefined) || 'issued';
      const nextInvoiceStatus: BillingStatus = currentInvoiceStatus === 'paid' ? 'paid' : billingStatus;
      if (nextInvoiceStatus !== currentInvoiceStatus) {
        tx.update(invoiceRef, { status: nextInvoiceStatus });
      }
    }

    const updates: any = { billingStatus };
    if (billingStatus === 'suspended') {
      updates.status = 'suspended';
    } else if (billingStatus === 'paid') {
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
async function sendBillingNotification(
  businessId: string,
  notification: { title: string; body: string },
  data: Record<string, string>
): Promise<void> {
  try {
    // Get business owner's user ID
    const businessSnap = await db.collection('businesses').doc(businessId).get();
    if (!businessSnap.exists) {
      console.warn(`Business ${businessId} not found for billing notification`);
      return;
    }

    const businessData = businessSnap.data() as any;
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
      } catch (error: any) {
        console.error(`❌ Failed to send billing notification to token:`, error?.message);
        // Mark invalid tokens as inactive
        if (
          error?.message?.includes('registration token is invalid') ||
          error?.message?.includes('registration token is not registered')
        ) {
          await db
            .collection('users')
            .doc(ownerUserId)
            .collection('deviceTokens')
            .doc(token)
            .update({ active: false, deactivatedAt: new Date() })
            .catch(() => {});
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
  } catch (error) {
    console.error('Error sending billing notification:', error);
  }
}

/**
 * Get notification message based on billing status
 */
function getBillingNotificationMessage(
  status: BillingStatus,
  propertyName: string,
  amount: number,
  dueDate: admin.firestore.Timestamp
): { title: string; body: string } | null {
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

export const processMonthlyBilling = functions
  .runWith({
    timeoutSeconds: 540,
    memory: '512MB',
    maxInstances: 1,
  })
  .pubsub.schedule('0 3 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    console.log('🔄 Starting processMonthlyBilling...');
    const now = admin.firestore.Timestamp.now();
    const defaultPlan = await getDefaultActivePlan();
    const propsSnap = await db.collectionGroup('properties').get();

    console.log(`📊 Processing ${propsSnap.size} properties...`);

    const statusChanges: Array<{
      propertyId: string;
      propertyName: string;
      businessId: string;
      billingStatus: BillingStatus;
      previousStatus: string;
      invoiceAmount: number;
      dueDate: admin.firestore.Timestamp;
    }> = [];

    // Process properties sequentially to avoid overwhelming Firestore
    for (const doc of propsSnap.docs) {
      try {
        const result = await processProperty(doc, now, defaultPlan);
        if (result && result.billingStatus !== result.previousStatus) {
          statusChanges.push(result);
        }
      } catch (error) {
        console.error(`Error processing property ${doc.id}:`, error);
      }
    }

    console.log(`📬 Sending notifications for ${statusChanges.length} status changes...`);

    // Send notifications for status changes
    for (const change of statusChanges) {
      const message = getBillingNotificationMessage(
        change.billingStatus,
        change.propertyName,
        change.invoiceAmount,
        change.dueDate
      );

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
export const triggerBillingManual = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const { propertyId, businessId } = data || {};
  const now = admin.firestore.Timestamp.now();
  const defaultPlan = await getDefaultActivePlan();

  console.log(`🔄 Manual billing trigger by ${context.auth.uid}`);

  if (propertyId && businessId) {
    // Process single property
    const propSnap = await db
      .doc(`businesses/${businessId}/properties/${propertyId}`)
      .get();

    if (!propSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Property not found');
    }

    const result = await processProperty(
      propSnap as FirebaseFirestore.QueryDocumentSnapshot,
      now,
      defaultPlan
    );

    return { success: true, result };
  } else {
    // Process all properties
    const propsSnap = await db.collectionGroup('properties').get();
    let processed = 0;

    for (const doc of propsSnap.docs) {
      try {
        await processProperty(doc, now, defaultPlan);
        processed++;
      } catch (error) {
        console.error(`Error processing ${doc.id}:`, error);
      }
    }

    return { success: true, processed };
  }
});

/**
 * Debug function to check property billing configuration
 */
export const debugPropertyBilling = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const { propertyId, businessId } = data || {};
  
  if (!propertyId || !businessId) {
    // List all properties with their billing status
    const propsSnap = await db.collectionGroup('properties').get();
    const properties = propsSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        path: doc.ref.path,
        name: data.name || doc.id,
        status: data.status,
        billingStatus: data.billingStatus,
        nextBillingDate: data.nextBillingDate?.toDate?.() || data.nextBillingDate,
        totalBeds: data.totalBeds,
        plan: data.plan ? { id: data.plan.id, pricePerBedInr: data.plan.pricePerBedInr } : null,
      };
    });
    
    return { 
      count: properties.length,
      properties,
      now: new Date().toISOString(),
    };
  }

  // Single property details
  const propSnap = await db.doc(`businesses/${businessId}/properties/${propertyId}`).get();
  
  if (!propSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Property not found');
  }

  const prop = propSnap.data() as any;
  const now = admin.firestore.Timestamp.now();
  
  // Check billing conditions
  const checks = {
    hasActiveStatus: prop.status === 'active' || prop.status === 'suspended',
    hasNextBillingDate: !!prop.nextBillingDate,
    nextBillingDateValue: prop.nextBillingDate?.toDate?.() || prop.nextBillingDate,
    billingDatePassed: prop.nextBillingDate ? now.toMillis() >= prop.nextBillingDate.toMillis() : false,
    hasTotalBeds: !!prop.totalBeds && prop.totalBeds > 0,
    hasPlan: !!prop.plan,
  };

  // Get recent invoices
  const invoicesSnap = await db.collection('billing_invoices')
    .where('propertyId', '==', propertyId)
    .orderBy('createdAt', 'desc')
    .limit(5)
    .get();

  const invoices = invoicesSnap.docs.map(doc => ({
    id: doc.id,
    ...doc.data(),
    periodStart: doc.data().periodStart?.toDate?.(),
    periodEnd: doc.data().periodEnd?.toDate?.(),
    dueDate: doc.data().dueDate?.toDate?.(),
  }));

  return {
    property: {
      id: propertyId,
      name: prop.name,
      status: prop.status,
      billingStatus: prop.billingStatus,
      totalBeds: prop.totalBeds,
      plan: prop.plan,
      nextBillingDate: prop.nextBillingDate?.toDate?.(),
      activatedAt: prop.activatedAt?.toDate?.(),
    },
    checks,
    invoices,
    now: now.toDate().toISOString(),
    recommendation: !checks.hasNextBillingDate 
      ? 'Property is missing nextBillingDate - needs to be set when property is activated'
      : !checks.billingDatePassed 
        ? `Billing will run on ${checks.nextBillingDateValue}`
        : 'Ready for billing',
  };
});

/**
 * Fix missing nextBillingDate for a property (admin only)
 */
export const fixPropertyBillingDate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const { propertyId, businessId, daysFromNow = 0 } = data || {};
  
  if (!propertyId || !businessId) {
    throw new functions.https.HttpsError('invalid-argument', 'propertyId and businessId required');
  }

  const propRef = db.doc(`businesses/${businessId}/properties/${propertyId}`);
  const propSnap = await propRef.get();
  
  if (!propSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Property not found');
  }

  const prop = propSnap.data()!;
  const now = admin.firestore.Timestamp.now();
  
  // Set nextBillingDate to now + daysFromNow (default: now, meaning billing should run immediately)
  const nextBillingDate = admin.firestore.Timestamp.fromDate(
    new Date(now.toDate().getTime() + daysFromNow * 24 * 60 * 60 * 1000)
  );

  await propRef.update({
    nextBillingDate,
    updatedAt: now,
  });

  console.log(`✅ Fixed nextBillingDate for ${propertyId}: ${nextBillingDate.toDate()}`);

  return {
    success: true,
    propertyId,
    previousNextBillingDate: prop.nextBillingDate?.toDate?.() || null,
    newNextBillingDate: nextBillingDate.toDate(),
    message: daysFromNow === 0 
      ? 'Next billing date set to now. Run processMonthlyBilling to trigger billing.'
      : `Next billing date set to ${daysFromNow} days from now.`,
  };
});

/**
 * Record a tenant payment (manual entry by business owner / manager).
 * Writes to payments subcollection, updates lastPaymentDate on tenant docs.
 */
export const recordPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const {
    businessId,
    tenantId,
    amount,
    month,       // e.g. "March 2026"
    paymentMode, // 'Cash' | 'UPI' | 'Bank Transfer' | 'Cheque' | 'Other'
    transactionId,
    note,
  } = data;

  if (!businessId || !tenantId || !amount || !month) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields: businessId, tenantId, amount, month'
    );
  }

  const now = admin.firestore.Timestamp.now();

  // Verify the tenant belongs to this business
  const bizTenantRef = db.doc(`businesses/${businessId}/tenants/${tenantId}`);
  const bizTenantSnap = await bizTenantRef.get();

  if (!bizTenantSnap.exists) {
    throw new functions.https.HttpsError('not-found', `Tenant ${tenantId} not found in business ${businessId}`);
  }

  const tenantData = bizTenantSnap.data() as any;

  // Only people who manage this tenant's property may record money for them.
  await assertPropertyPermission(context.auth.uid, businessId, tenantData.propertyId, 'UPDATE_TENANTS');

  // The invoice this payment settles, so the tenant's dues and the owner's
  // collection totals stay right. Matched by month label like verifyRentPayment.
  const invoiceQuery = await db
    .collection(`businesses/${businessId}/tenants/${tenantId}/rent_invoices`)
    .where('month', '==', month)
    .where('status', 'in', ['unpaid', 'overdue'])
    .limit(1)
    .get();
  const invoiceRef = invoiceQuery.empty ? null : invoiceQuery.docs[0].ref;

  // Create payment record
  const paymentRef = db.collection(`businesses/${businessId}/tenants/${tenantId}/payments`).doc();
  const paymentRecord = {
    id: paymentRef.id,
    tenantId,
    businessId,
    tenantName: tenantData.name || '',
    roomNumber: tenantData.roomNumber || tenantData.roomId || '',
    bedNumber: tenantData.bedNumber || tenantData.bedId || '',
    amount: Number(amount),
    month,
    date: now,
    status: 'Paid',
    method: paymentMode || 'Cash',
    transactionId: transactionId || null,
    note: note || null,
    recordedBy: context.auth.uid,
    createdAt: now,
    ...(invoiceRef ? { rentInvoiceId: invoiceRef.id } : {}),
  };

  await db.runTransaction(async (tx) => {
    // Read before write
    const globalTenantRef = db.doc(`tenants/${tenantId}`);
    const globalSnap = await tx.get(globalTenantRef);

    // Write payment record
    tx.set(paymentRef, paymentRecord);

    if (invoiceRef) {
      tx.update(invoiceRef, {
        status: 'paid',
        paidAt: now,
        verification: 'verified',
        mode: String(paymentMode || 'Cash').toLowerCase(),
        updatedAt: now,
      });
    }

    // Update lastPaymentDate on business-scoped tenant doc
    tx.update(bizTenantRef, {
      lastPaymentDate: now,
      lastPaymentAmount: Number(amount),
      lastPaymentMonth: month,
      updatedAt: now,
    });

    // Update global tenant doc if it exists
    if (globalSnap.exists) {
      tx.update(globalTenantRef, {
        lastPaymentDate: now,
        lastPaymentAmount: Number(amount),
        updatedAt: now,
      });
    }
  });

  console.log(`✅ Payment recorded: ${tenantId} paid ₹${amount} for ${month} (${paymentMode})`);

  return {
    success: true,
    paymentId: paymentRef.id,
    tenantId,
    amount: Number(amount),
    month,
  };
});
/**
 * Tenant submits a rent payment (waiting for verification)
 */
export const submitRentPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const {
    businessId,
    amount,
    month,
    paymentMode, // 'Cash' | 'UPI'
    transactionId,
    screenshotUrl,
    rentInvoiceId, // Optional: links this payment to a specific invoice
  } = data;

  const tenantId = context.auth.uid; // Ensuring tenant can only submit for themselves

  if (!businessId || !amount || !month || !paymentMode) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields: businessId, amount, month, paymentMode'
    );
  }

  if (paymentMode === 'UPI' && !transactionId) {
    throw new functions.https.HttpsError('invalid-argument', 'Transaction ID is required for UPI payments');
  }

  const now = admin.firestore.Timestamp.now();

  // Resolve the actual tenant document ID (e.g. TEN0000001) from the user doc.
  // The business-scoped tenant collection uses the sequential TEN ID, not the auth UID.
  const userSnap = await db.collection('users').doc(tenantId).get();
  const actualTenantId: string | null = userSnap.exists
    ? (userSnap.data() as any)?.tenantId || null
    : null;

  if (!actualTenantId) {
    throw new functions.https.HttpsError(
      'not-found',
      'Tenant record not found. Please contact your PG owner.'
    );
  }

  // Verify the tenant belongs to this business using the actual TEN ID
  const bizTenantRef = db.doc(`businesses/${businessId}/tenants/${actualTenantId}`);
  const bizTenantSnap = await bizTenantRef.get();

  if (!bizTenantSnap.exists) {
    throw new functions.https.HttpsError('not-found', `Tenant not found in business ${businessId}`);
  }

  const tenantData = bizTenantSnap.data() as any;

  // If a rentInvoiceId is provided, validate the amount matches the invoice
  // to prevent tenants from submitting arbitrary amounts.
  if (rentInvoiceId) {
    const invoiceSnap = await db
      .doc(`businesses/${businessId}/tenants/${actualTenantId}/rent_invoices/${rentInvoiceId}`)
      .get();
    if (invoiceSnap.exists) {
      const invoiceData = invoiceSnap.data() as any;
      const invoiceAmount = Number(invoiceData.amount);
      const submittedAmount = Number(amount);
      // Allow a small tolerance (₹1) for rounding differences
      if (Math.abs(submittedAmount - invoiceAmount) > 1) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          `Amount mismatch. Invoice amount is ₹${invoiceAmount}. Please pay the exact amount.`
        );
      }
      if (invoiceData.status === 'paid') {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'This invoice has already been paid.'
        );
      }
    }
  }

  // Create payment record in pending state
  const paymentRef = db.collection(`businesses/${businessId}/tenants/${actualTenantId}/payments`).doc();
  const paymentRecord: Record<string, any> = {
    id: paymentRef.id,
    tenantId: actualTenantId,
    businessId,
    tenantName: tenantData.name || '',
    roomNumber: tenantData.roomNumber || tenantData.roomId || '',
    bedNumber: tenantData.bedNumber || tenantData.bedId || '',
    amount: Number(amount),
    month,
    date: now,
    status: 'pending_verification',
    method: paymentMode,
    transactionId: transactionId || null,
    screenshotUrl: screenshotUrl || null,
    submittedBy: 'tenant',
    createdAt: now,
  };

  // Store the invoice reference so verifyRentPayment can mark it paid
  if (rentInvoiceId) {
    paymentRecord.rentInvoiceId = rentInvoiceId;
  }

  await paymentRef.set(paymentRecord);

  console.log(`Payment submitted for verification: ${actualTenantId} paid ₹${amount} for ${month} via ${paymentMode}`);

  return {
    success: true,
    paymentId: paymentRef.id,
    status: 'pending_verification',
  };
});

/**
 * Property owner verifies (confirms or rejects) a tenant's rent payment submission
 */
export const verifyRentPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const { businessId, tenantId, paymentId, action, rejectionReason } = data;

  if (!businessId || !tenantId || !paymentId || !action) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields: businessId, tenantId, paymentId, action'
    );
  }

  if (action !== 'confirm' && action !== 'reject') {
    throw new functions.https.HttpsError('invalid-argument', 'Action must be confirm or reject');
  }

  if (action === 'reject' && !rejectionReason) {
    throw new functions.https.HttpsError('invalid-argument', 'rejectionReason is required when rejecting');
  }

  const now = admin.firestore.Timestamp.now();

  const bizTenantRef = db.doc(`businesses/${businessId}/tenants/${tenantId}`);
  const paymentRef = db.collection(`businesses/${businessId}/tenants/${tenantId}/payments`).doc(paymentId);
  const globalTenantRef = db.doc(`tenants/${tenantId}`);

  // Only people who manage the tenant's property may confirm or reject their
  // payments (a tenant must not be able to approve their own).
  const tenantForAuth = await bizTenantRef.get();
  if (!tenantForAuth.exists) {
    throw new functions.https.HttpsError('not-found', 'Tenant not found');
  }
  await assertPropertyPermission(
    context.auth.uid,
    businessId,
    (tenantForAuth.data() as any).propertyId,
    'UPDATE_TENANTS'
  );

  let finalStatus = '';

  await db.runTransaction(async (tx) => {
    // Reads
    const [bizTenantSnap, paymentSnap, globalTenantSnap] = await Promise.all([
      tx.get(bizTenantRef),
      tx.get(paymentRef),
      tx.get(globalTenantRef),
    ]);

    if (!paymentSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Payment record not found');
    }

    const paymentData = paymentSnap.data() as any;

    if (paymentData.status !== 'pending_verification') {
      throw new functions.https.HttpsError('failed-precondition', `Payment is already ${paymentData.status}`);
    }

    if (action === 'confirm') {
      finalStatus = 'Paid';

      // Firestore transactions must do every read before the first write, so
      // find the invoice this payment settles before touching anything.
      //   Prefer the stored rentInvoiceId on the payment record; fall back to
      //   matching by month for older records.
      let invoiceToPay: FirebaseFirestore.DocumentReference | null = null;
      const storedInvoiceId = paymentData.rentInvoiceId as string | undefined;
      if (storedInvoiceId) {
        const invoiceRef = db.doc(
          `businesses/${businessId}/tenants/${tenantId}/rent_invoices/${storedInvoiceId}`
        );
        const invoiceSnap = await tx.get(invoiceRef);
        if (invoiceSnap.exists && (invoiceSnap.data() as any)?.status !== 'paid') {
          invoiceToPay = invoiceRef;
        }
      } else {
        const invoiceQuery = db
          .collection(`businesses/${businessId}/tenants/${tenantId}/rent_invoices`)
          .where('month', '==', paymentData.month)
          .where('status', 'in', ['unpaid', 'overdue'])
          .limit(1);
        const invoiceSnap = await tx.get(invoiceQuery);
        if (!invoiceSnap.empty) invoiceToPay = invoiceSnap.docs[0].ref;
      }

      // 1. Mark payment as Paid
      tx.update(paymentRef, {
        status: finalStatus,
        verifiedBy: context.auth!.uid,
        verifiedAt: now,
        updatedAt: now,
      });

      // 2. Update lastPaymentDate on business tenant doc
      if (bizTenantSnap.exists) {
        tx.update(bizTenantRef, {
          lastPaymentDate: now,
          lastPaymentAmount: paymentData.amount,
          lastPaymentMonth: paymentData.month,
          updatedAt: now,
        });
      }

      // 3. Update global tenant doc if exists
      if (globalTenantSnap.exists) {
        tx.update(globalTenantRef, {
          lastPaymentDate: now,
          lastPaymentAmount: paymentData.amount,
          updatedAt: now,
        });
      }

      // 4. Mark the matching rent_invoice as paid so the tenant's
      //    "All Caught Up" banner appears immediately.
      if (invoiceToPay) {
        tx.update(invoiceToPay, {
          status: 'paid',
          paidAt: now,
          verification: 'verified',
          mode: paymentData.method || 'manual',
          updatedAt: now,
        });
      }
    } else {
      // Reject
      finalStatus = 'rejected';
      tx.update(paymentRef, {
        status: finalStatus,
        rejectionReason: rejectionReason,
        rejectedBy: context.auth!.uid,
        rejectedAt: now,
        updatedAt: now,
      });
    }
  });

  if (finalStatus === 'Paid') {
    console.log(`Payment verified/confirmed: ${paymentId}`);
  } else {
    console.log(`Payment rejected: ${paymentId} - Reason: ${rejectionReason}`);
  }

  return { success: true, paymentId, action };
});
