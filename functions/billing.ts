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
    minInstances: 0,
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