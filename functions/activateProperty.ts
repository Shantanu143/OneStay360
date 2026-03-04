// PLAN & PRICING INVARIANTS:
// - Plans and pricing are platform-owned.
// - Properties carry a plan snapshot (immutable per property).
// - Billing and activation never read live plan pricing for existing properties; they use snapshots.
// - Any pricing change requires explicit migration logic.
// Billing engine invariants:
// - Billing state is server-owned; clients cannot write billing fields.
// - property.billingStatus is set only via processMonthlyBilling and confirmActivationPayment.
// - UI must not attempt to transition billing states; it only reads them.
// - Invoice lifecycle is enforced on the server; paid is terminal and immutable.
// PRICING OWNERSHIP:
// - pricePerBed is platform-owned (OneStay360), not editable by business owners, never sent by clients.
// - Promos apply only to final payable amount; base pricing is constant and server-side.
// Welcome email is:
// - Sent once per property
// - Triggered only after successful activation
// - Server-owned and idempotent
// - Non-blocking (never affects billing or activation)
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import Razorpay from 'razorpay';
import { BillingStatus } from './types';
import { getDefaultActivePlan, Plan } from './plan';
import { assertBusinessPermission, assertPropertyPermission } from './permissions';

if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

type CheckoutPurpose = 'activation' | 'monthly';

type QuoteResult = {
  baseAmount: number;
  discountAmount: number;
  finalAmount: number;
  promo: null | {
    code: string;
    type: string;
    value: number;
    maxDiscount?: number;
    minAmount?: number;
  };
  promoRefs?: {
    promoRef: FirebaseFirestore.DocumentReference;
    redemptionRef: FirebaseFirestore.DocumentReference;
  };
  invoiceRef?: FirebaseFirestore.DocumentReference;
  plan: {
    id: string;
    name: string;
    pricePerBedInr: number;
  };
};

/* -------------------- Razorpay Client -------------------- */

/**
 * Get Razorpay credentials from Firebase config or environment variables
 * Set via: firebase functions:config:set razorpay.key_id="..." razorpay.key_secret="..."
 */
function getRazorpayConfig() {
  const config = functions.config();
  return {
    keyId: config.razorpay?.key_id || process.env.RAZORPAY_KEY_ID || '',
    keySecret: config.razorpay?.key_secret || process.env.RAZORPAY_KEY_SECRET || '',
  };
}

function getRazorpayClient() {
  const { keyId, keySecret } = getRazorpayConfig();

  if (!keyId || !keySecret) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET not configured. Set via: firebase functions:config:set razorpay.key_id="..." razorpay.key_secret="..."'
    );
  }

  return new Razorpay({
    key_id: keyId,
    key_secret: keySecret,
  });
}

/* -------------------- Business Activation Bootstrap -------------------- */

export const ensureBusinessActivation = functions.firestore
  .document('businesses/{businessId}')
  .onCreate(async (_, context) => {
    const businessId = context.params.businessId;
    const ref = db.doc(`business_activation/${businessId}`);

    const snap = await ref.get();
    if (snap.exists) return;

    await ref.set({
      used: false,
      usedAt: null,
      propertyId: null,
      paymentId: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

/* -------------------- Helpers -------------------- */

function addDays(ts: admin.firestore.Timestamp, days: number) {
  const d = ts.toDate();
  d.setDate(d.getDate() + days);
  return admin.firestore.Timestamp.fromDate(d);
}

function verifySignature(orderId: string, paymentId: string, signature: string) {
  const { keySecret } = getRazorpayConfig();
  if (!keySecret) {
    throw new functions.https.HttpsError('failed-precondition', 'RAZORPAY_KEY_SECRET not configured');
  }
  const hmac = crypto.createHmac('sha256', keySecret);
  hmac.update(`${orderId}|${paymentId}`);
  if (hmac.digest('hex') !== signature) {
    throw new functions.https.HttpsError('failed-precondition', 'Invalid Razorpay signature');
  }
}

async function getPropertyPricing(
  businessId: string,
  propertyId: string,
  tx?: FirebaseFirestore.Transaction
) {
  const propertyRef = db.doc(`businesses/${businessId}/properties/${propertyId}`);
  const businessRef = db.doc(`businesses/${businessId}`);
  const propSnap = tx ? await tx.get(propertyRef) : await propertyRef.get();
  if (!propSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Property not found');
  }
  const businessSnap = tx ? await tx.get(businessRef) : await businessRef.get();
  if (!businessSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Business not found');
  }

  const prop = propSnap.data()!;
  const totalBeds = Number(prop.totalBeds || 0);
  if (totalBeds <= 0) {
    throw new functions.https.HttpsError('failed-precondition', 'Invalid property pricing');
  }

  const planFromBusiness = (businessSnap.data() as any)?.plan as Partial<Plan> | undefined;
  const plan = planFromBusiness && typeof planFromBusiness.pricePerBedInr === 'number'
    ? {
        id: planFromBusiness.id || 'business_plan_snapshot',
        name: planFromBusiness.name || 'Plan',
        pricePerBedInr: planFromBusiness.pricePerBedInr,
        isActive: true,
        isDefault: false,
      }
    : await getDefaultActivePlan(tx);

  const baseAmount = totalBeds * Number(plan.pricePerBedInr);
  return { baseAmount, propertyRef, propSnap, prop, plan };
}

function assertPromoWindow(promo: any, now: admin.firestore.Timestamp) {
  const validFrom: admin.firestore.Timestamp | undefined = promo.validFrom;
  const validTo: admin.firestore.Timestamp | undefined = promo.validTo;
  if (validFrom && now.toMillis() < validFrom.toMillis()) {
    throw new functions.https.HttpsError('failed-precondition', 'Promo not started');
  }
  if (validTo && now.toMillis() > validTo.toMillis()) {
    throw new functions.https.HttpsError('failed-precondition', 'Promo expired');
  }
}

async function computeQuote(options: {
  businessId: string;
  propertyId: string;
  purpose: CheckoutPurpose;
  invoiceId?: string;
  promoCode?: string;
  tx?: FirebaseFirestore.Transaction;
  now?: admin.firestore.Timestamp;
}): Promise<QuoteResult> {
  const { businessId, propertyId, purpose, promoCode, tx, invoiceId } = options;
  const now = options.now || admin.firestore.Timestamp.now();
  const { baseAmount: propBaseAmount, propertyRef, propSnap, prop, plan } = await getPropertyPricing(
    businessId,
    propertyId,
    tx
  );
  let baseAmount = propBaseAmount;

  if (purpose === 'activation' && prop.status === 'active') {
    throw new functions.https.HttpsError('failed-precondition', 'Property already active');
  }

  if (purpose === 'monthly' && prop.status === 'suspended' && !invoiceId) {
    throw new functions.https.HttpsError('failed-precondition', 'Suspended properties require an unpaid invoice to pay');
  }

  let invoiceRef: FirebaseFirestore.DocumentReference | undefined;
  if (purpose === 'monthly') {
    if (!invoiceId) {
      throw new functions.https.HttpsError('invalid-argument', 'invoiceId required for monthly');
    }
    invoiceRef = db.doc(`billing_invoices/${invoiceId}`);
    const invoiceSnap = tx ? await tx.get(invoiceRef) : await invoiceRef.get();
    if (!invoiceSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Invoice not found');
    }
    const inv = invoiceSnap.data()! as any;
    if (inv.businessId !== businessId || inv.propertyId !== propertyId) {
      throw new functions.https.HttpsError('failed-precondition', 'Invoice property mismatch');
    }
    if (inv.status === 'paid') {
      throw new functions.https.HttpsError('failed-precondition', 'Invoice already paid');
    }
    if (inv.status === 'void') {
      throw new functions.https.HttpsError('failed-precondition', 'Invoice void');
    }
    const invoiceBase = typeof inv.baseAmount === 'number' ? inv.baseAmount : baseAmount;
    baseAmount = invoiceBase;
  }

  let discountAmount = 0;
  let promoResult: QuoteResult['promo'] = null;
  let promoRefs: QuoteResult['promoRefs'] = undefined;

  if (promoCode) {
    const promoRef = db.doc(`promos/${promoCode}`);
    const promoSnap = tx ? await tx.get(promoRef) : await promoRef.get();
    if (!promoSnap.exists) {
      throw new functions.https.HttpsError('failed-precondition', 'Promo not found');
    }

    const promo = promoSnap.data()! as any;
    if (promo.status !== 'active') {
      throw new functions.https.HttpsError('failed-precondition', 'Promo inactive');
    }
    assertPromoWindow(promo, now);

    const applicableTo: string[] = promo.applicableTo || [];
    if (!applicableTo.includes(purpose)) {
      throw new functions.https.HttpsError('failed-precondition', 'Promo not applicable to purpose');
    }

    // Pricing-agnostic eligibility threshold: must be >= 1 and compared to dynamic baseAmount (beds x plan price)
    const minAmount = Number(promo.minAmount ?? promo.constraints?.minAmount ?? 0);
    if (!Number.isFinite(minAmount) || minAmount < 1) {
      throw new functions.https.HttpsError('failed-precondition', 'Promo minAmount must be >= 1');
    }
    if (baseAmount < minAmount) {
      throw new functions.https.HttpsError('failed-precondition', 'Minimum amount not satisfied');
    }

    const redemptionRef = db.doc(`promo_redemptions/${promoCode}_${businessId}`);
    const redemptionSnap = tx ? await tx.get(redemptionRef) : await redemptionRef.get();
    if (redemptionSnap.exists) {
      throw new functions.https.HttpsError('failed-precondition', 'Promo already used by business');
    }

    const usage = promo.usage || {};
    const perBusiness = Number(usage.perBusiness || 1);
    if (perBusiness <= 0) {
      throw new functions.https.HttpsError('failed-precondition', 'Promo not usable');
    }

    const globalLimit = Number(usage.globalLimit || 0);
    const redemptionCount = Number(promo.redemptionCount || 0);
    if (globalLimit > 0 && redemptionCount >= globalLimit) {
      throw new functions.https.HttpsError('failed-precondition', 'Promo global limit reached');
    }

    const type = promo.type || promo.discount?.type;
    const value = Number(promo.value ?? promo.discount?.value ?? 0);
    if (type !== 'percentage' && type !== 'flat') {
      throw new functions.https.HttpsError('failed-precondition', 'Invalid promo type');
    }
    if (value <= 0) {
      throw new functions.https.HttpsError('failed-precondition', 'Invalid promo value');
    }

    if (type === 'percentage') {
      const maxCap = Number(promo.maxDiscount ?? promo.discount?.maxAmount ?? promo.discount?.maxDiscount ?? 0);
      if (!Number.isFinite(maxCap) || maxCap <= 0) {
        throw new functions.https.HttpsError('failed-precondition', 'Percentage promos require discount.maxAmount');
      }
      discountAmount = Math.min(Math.floor((baseAmount * value) / 100), maxCap);
    } else {
      const maxCap = Number(promo.maxDiscount ?? promo.discount?.maxAmount ?? promo.discount?.maxDiscount ?? 0);
      discountAmount = value;
      if (maxCap > 0 && discountAmount > maxCap) {
        discountAmount = maxCap;
      }
    }
    if (discountAmount > baseAmount) {
      discountAmount = baseAmount;
    }

    const stackable = promo.stackable === true;
    promoResult = {
      code: promo.code || promoCode,
      type,
      value,
      maxDiscount: promo.maxDiscount ?? promo.discount?.maxAmount ?? promo.discount?.maxDiscount,
      minAmount: minAmount,
      name: promo.name,
      description: promo.description,
      stackable,
    } as any;
    try {
      functions.logger.info('Promo applied', {
        code: promoResult?.code,
        name: promo.name,
        description: promo.description,
        stackable,
      });
    } catch (_) {
      // best-effort logging only
    }
    promoRefs = { promoRef, redemptionRef };
  }

  const finalAmount = Math.max(1, baseAmount - discountAmount);

  const planResult = {
    id: plan.id,
    name: plan.name,
    pricePerBedInr: Number(plan.pricePerBedInr),
  };

  return { baseAmount, discountAmount, finalAmount, promo: promoResult, promoRefs, invoiceRef, plan: planResult };
}

/* -------------------- CREATE ACTIVATION ORDER -------------------- */

export const createCheckoutQuote = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  const { businessId, propertyId, purpose, promoCode, invoiceId } = data || {};

  if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  if (!businessId || !propertyId || !purpose) {
    throw new functions.https.HttpsError('invalid-argument', 'businessId, propertyId, purpose required');
  }

  if (purpose !== 'activation' && purpose !== 'monthly') {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid purpose');
  }

  await assertBusinessPermission(uid, businessId, 'PAY_INVOICES');

   // Defensive: ensure there is only a single unpaid invoice for this property
  if (purpose === 'monthly') {
    const unpaidSnap = await db
      .collection('billing_invoices')
      .where('propertyId', '==', propertyId)
      .where('status', 'in', ['issued', 'due', 'grace', 'past_due'])
      .limit(2)
      .get();
    if (unpaidSnap.size > 1) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Multiple unpaid invoices detected — contact support'
      );
    }
  }

  const quote = await computeQuote({
    businessId,
    propertyId,
    purpose,
    promoCode,
    invoiceId,
  });

  return {
    baseAmount: quote.baseAmount,
    discountAmount: quote.discountAmount,
    finalAmount: quote.finalAmount,
    promo: quote.promo,
    plan: quote.plan,
  };
});

export const createActivationOrder = functions
  .runWith({ timeoutSeconds: 60, memory: '256MB' })
  .https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    const { businessId, propertyId, purpose, promoCode, clientFinalAmount, invoiceId } = data || {};

    if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Login required');
    if (!businessId || !propertyId || !purpose) {
      throw new functions.https.HttpsError('invalid-argument', 'businessId, propertyId, purpose required');
    }

    if (purpose !== 'activation' && purpose !== 'monthly') {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid purpose');
    }

    await assertBusinessPermission(uid, businessId, 'PAY_INVOICES');

    const quote = await computeQuote({
      businessId,
      propertyId,
      purpose,
      promoCode,
      invoiceId,
    });

    const invoiceIdNote = quote.invoiceRef ? quote.invoiceRef.id : null;

    if (clientFinalAmount !== undefined) {
      const clientAmountNum = Number(clientFinalAmount);
      if (Number.isFinite(clientAmountNum) && clientAmountNum !== quote.finalAmount) {
        throw new functions.https.HttpsError('failed-precondition', 'Amount mismatch');
      }
    }

    if (quote.finalAmount <= 0) {
      throw new functions.https.HttpsError('failed-precondition', 'Final amount must be positive');
    }

    try {
      const razorpay = getRazorpayClient();

      const order = await razorpay.orders.create({
        amount: quote.finalAmount * 100,
        currency: 'INR',
        receipt: `act_${businessId}_${propertyId}`,
        notes: {
          businessId,
          propertyId,
          purpose,
          promoCode: promoCode || null,
          invoiceId: invoiceIdNote,
          baseAmount: quote.baseAmount,
          discountAmount: quote.discountAmount,
          finalAmount: quote.finalAmount,
        },
      });

      const { keyId } = getRazorpayConfig();
      return {
        orderId: order.id,
        amount: order.amount,
        currency: order.currency,
        baseAmount: quote.baseAmount,
        discountAmount: quote.discountAmount,
        finalAmount: quote.finalAmount,
        promo: quote.promo,
        razorpayKeyId: keyId,
      };
    } catch (err: any) {
      const rpCode = err?.error?.code || err?.code || 'UNKNOWN';
      const rpDesc =
        err?.error?.description || err?.description || err?.message || String(err);

      functions.logger.error('Razorpay order creation failed', {
        businessId,
        propertyId,
        rpCode,
        rpDesc,
        raw: err,
      });

      if (rpCode === 'BAD_REQUEST_ERROR') {
        throw new functions.https.HttpsError(
          'failed-precondition',
          `Razorpay: ${rpDesc}`
        );
      }

      throw new functions.https.HttpsError('internal', 'Failed to create payment order');
    }
  });

/* -------------------- CONFIRM PAYMENT & ACTIVATE -------------------- */

export const confirmActivationPayment = functions
  .runWith({ timeoutSeconds: 120, memory: '256MB' })
  .https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    const { orderId, paymentId, razorpaySignature } = data || {};

    if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Login required');
    if (!orderId || !paymentId || !razorpaySignature) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing payment fields');
    }

    verifySignature(orderId, paymentId, razorpaySignature);

    const razorpay = getRazorpayClient();
    const [order, payment] = await Promise.all([
      razorpay.orders.fetch(orderId),
      razorpay.payments.fetch(paymentId),
    ]);

    if (payment.status !== 'captured') {
      throw new functions.https.HttpsError('failed-precondition', 'Payment not captured');
    }

    const { businessId, propertyId, purpose, promoCode, baseAmount, discountAmount, finalAmount, invoiceId } =
      order.notes as any;
    await assertPropertyPermission(uid, businessId, propertyId, 'MANAGE_PROPERTY_STATE');
    await assertBusinessPermission(uid, businessId, 'PAY_INVOICES');

    const propertyRef = db.doc(`businesses/${businessId}/properties/${propertyId}`);
    const businessRef = propertyRef.parent.parent!;
    const activationRef = db.doc(`business_activation/${businessId}`);
    const paymentRef = db.collection('platform_payments').doc(paymentId);
    const businessPaymentRef = propertyRef.parent.parent!
      .collection('payments_to_onestay360')
      .doc(paymentId);
    const roomsQuery = propertyRef.collection('rooms');
    const invoiceRef = invoiceId ? db.doc(`billing_invoices/${invoiceId}`) : null;

    const attemptRef = db.collection('payment_attempts').doc(paymentId);
    try {
      await attemptRef.set(
        {
          businessId,
          propertyId,
          invoiceId: invoiceId || null,
          amount: Number(payment.amount) / 100,
          gateway: 'razorpay',
          status: 'initiated',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    } catch (e) {
      functions.logger.warn('payment_attempts log failed (initiated)', { paymentId, error: e });
    }

    let txError: any;

    await db
      .runTransaction(async (tx) => {
      const now = admin.firestore.Timestamp.now();
      const quote = await computeQuote({
        businessId,
        propertyId,
        purpose,
        promoCode: promoCode || undefined,
        invoiceId: invoiceId || undefined,
        tx,
        now,
      });

      const expectedAmountPaise = quote.finalAmount * 100;
      if (payment.amount !== expectedAmountPaise) {
        throw new functions.https.HttpsError('failed-precondition', 'Payment amount mismatch');
      }

      const propSnap = await tx.get(propertyRef);
      if (!propSnap.exists) throw new Error('Property missing');

      const businessSnap = await tx.get(businessRef);
      if (!businessSnap.exists) throw new Error('Business missing');

      const prop = propSnap.data()!;
      const billingStart = now;
      const nextBilling = addDays(prop.nextBillingDate || now, 30); // anchor-based
      const totalBeds = Number(prop.totalBeds);

      // Load all rooms and beds inside the same transaction
      const roomsSnap = await tx.get(roomsQuery);
      const roomRefs = roomsSnap.docs.map((doc) => doc.ref);

      const bedRefs: FirebaseFirestore.DocumentReference[] = [];
      for (const roomDoc of roomsSnap.docs) {
        const bedsSnap = await tx.get(roomDoc.ref.collection('beds'));
        bedsSnap.docs.forEach((b) => bedRefs.push(b.ref));
      }

      // Promo redemption lock
      if (quote.promo && quote.promoRefs) {
        const { promoRef, redemptionRef } = quote.promoRefs;
        const redemptionSnap = await tx.get(redemptionRef);
        if (redemptionSnap.exists) {
          throw new functions.https.HttpsError('failed-precondition', 'Promo already used by business');
        }
        tx.set(redemptionRef, {
          promoCode: quote.promo.code,
          businessId,
          paymentId,
          usedAt: billingStart,
        });
        tx.update(promoRef, {
          redemptionCount: admin.firestore.FieldValue.increment(1),
        });
      }

      const paymentDoc = {
        paymentId,
        orderId,
        businessId,
        propertyId,
        amount: Number(payment.amount) / 100,
        baseAmount: quote.baseAmount,
        discountAmount: quote.discountAmount,
        finalAmount: quote.finalAmount,
        promoCode: quote.promo?.code || null,
        gateway: 'razorpay',
        status: 'success',
        purpose,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (purpose === 'activation') {
        tx.set(paymentRef, paymentDoc);
        tx.set(businessPaymentRef, paymentDoc);

        const businessData = businessSnap.data() as any;
        if (!businessData.plan) {
          tx.set(
            businessRef,
            {
              plan: {
                id: quote.plan.id,
                name: quote.plan.name,
                pricePerBedInr: quote.plan.pricePerBedInr,
                activatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
            },
            { merge: true }
          );
        }

        tx.update(propertyRef, {
          status: 'active',
          billingStatus: 'paid',
          activeBedCount: totalBeds,
          billedBedCount: totalBeds,
          billingStartDate: billingStart,
          nextBillingDate: nextBilling,
          lastPaymentId: paymentId,
          plan: quote.plan,
        });

        // Keep city index in sync for reads that hit properties_by_city
        const city = prop.city || prop.cityCode || prop.cityName;
        if (city) {
          const cityPropRef = db.collection('properties_by_city').doc(String(city)).collection('properties').doc(propertyId);
          tx.set(cityPropRef, {
            status: 'active',
            billingStatus: 'paid',
            activeBedCount: totalBeds,
            billedBedCount: totalBeds,
            billingStartDate: billingStart,
            nextBillingDate: nextBilling,
            lastPaymentId: paymentId,
            plan: quote.plan,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        }

        // Activate every room
        roomRefs.forEach((roomRef) => {
          tx.update(roomRef, {
            isActive: true,
            status: 'active',
            updatedBy: uid,
          });
        });

        // Activate every bed
        bedRefs.forEach((bedRef) => {
          tx.update(bedRef, {
            isActive: true,
            updatedBy: uid,
          });
        });

        // Mark business activation record if present (without promo semantics)
        tx.set(
          activationRef,
          {
            used: true,
            usedAt: billingStart,
            propertyId,
            paymentId,
          },
          { merge: true }
        );
      } else if (purpose === 'monthly') {
        if (!invoiceRef) {
          throw new functions.https.HttpsError('invalid-argument', 'invoiceId required for monthly');
        }
        const invoiceSnap = await tx.get(invoiceRef);
        if (!invoiceSnap.exists) {
          throw new functions.https.HttpsError('not-found', 'Invoice not found');
        }
        const invoice = invoiceSnap.data()! as any;
        if (!invoice.status || invoice.status === 'void') {
          throw new functions.https.HttpsError('failed-precondition', 'Invoice not payable');
        }

        const periodStart = invoice.periodStart as admin.firestore.Timestamp | undefined;
        const periodEnd = invoice.periodEnd as admin.firestore.Timestamp | undefined;
        if (!periodStart || !periodEnd) {
          throw new functions.https.HttpsError('failed-precondition', 'Invoice missing billing period');
        }

        const existingPaymentSnap = await tx.get(paymentRef);
        if (existingPaymentSnap.exists) {
          const existingPayment = existingPaymentSnap.data() as any;
          if (existingPayment.invoiceId && existingPayment.invoiceId !== invoiceRef.id) {
            throw new functions.https.HttpsError('failed-precondition', 'Payment already linked to another invoice');
          }
        }

        const existingBusinessPaymentSnap = await tx.get(businessPaymentRef);
        if (existingBusinessPaymentSnap.exists) {
          const existingPayment = existingBusinessPaymentSnap.data() as any;
          if (existingPayment.invoiceId && existingPayment.invoiceId !== invoiceRef.id) {
            throw new functions.https.HttpsError('failed-precondition', 'Business payment already linked to another invoice');
          }
        }

        const paymentDocWithInvoice = {
          ...paymentDoc,
          invoiceId: invoiceRef.id,
          periodStart,
          periodEnd,
        };

        if (invoice.status === 'paid') {
          if (invoice.paymentId && invoice.paymentId !== paymentId) {
            throw new functions.https.HttpsError('failed-precondition', 'Invoice already paid by another payment');
          }

          // Idempotent replay: ensure payment records and property state are consistent
          tx.set(paymentRef, paymentDocWithInvoice, { merge: true });
          tx.set(businessPaymentRef, paymentDocWithInvoice, { merge: true });
          tx.update(propertyRef, {
            billingStatus: 'paid',
            status: 'active',
            lastPaymentId: invoice.paymentId || paymentId,
            nextBillingDate: nextBilling,
          });
          return;
        }

        if (invoice.paymentId && invoice.paymentId !== paymentId) {
          throw new functions.https.HttpsError('failed-precondition', 'Invoice already paid by another payment');
        }

        tx.set(paymentRef, paymentDocWithInvoice);
        tx.set(businessPaymentRef, paymentDocWithInvoice);

        tx.update(invoiceRef, {
          status: 'paid',
          paidAt: admin.firestore.FieldValue.serverTimestamp(),
          paymentId,
        });

        tx.update(propertyRef, {
          billingStatus: 'paid',
          status: 'active',
          lastPaymentId: paymentId,
          nextBillingDate: nextBilling,
        });

        // Reactivate rooms/beds if suspended
        roomRefs.forEach((roomRef) => {
          tx.update(roomRef, {
            isActive: true,
            status: 'active',
            updatedBy: uid,
          });
        });
        bedRefs.forEach((bedRef) => {
          tx.update(bedRef, {
            isActive: true,
            updatedBy: uid,
          });
        });
      }
      })
      .catch((err) => {
        txError = err;
      });

    if (txError) {
      try {
        await attemptRef.set({ status: 'failed', failedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      } catch (e) {
        functions.logger.warn('payment_attempts log failed (failed)', { paymentId, error: e });
      }
      throw txError;
    }

    // Send one-time welcome email after activation commit (non-blocking, idempotent)
    try {
      if (purpose === 'activation') {
        const propSnap = await propertyRef.get();
        const propData = propSnap.data() as any;
        const welcomeSent = propData?.welcomeEmailSentAt;
        const eligible = !welcomeSent && propData?.status === 'active' && propData?.billingStatus === 'paid';
        const businessSnap = await businessRef.get();
        const businessData = businessSnap.data() as any;
        const ownerEmail = businessData?.email || businessData?.ownerEmail || businessData?.contactEmail;
        functions.logger.info('welcome_email_check', {
          propertyId,
          businessId,
          status: propData?.status,
          billingStatus: propData?.billingStatus,
          welcomeEmailSentAt: Boolean(welcomeSent),
          ownerEmailPresent: Boolean(ownerEmail),
        });

        if (eligible && ownerEmail) {
          const businessName = businessData?.name || 'there';
          const propertyName = propData?.name || propertyId;
          const planName = propData?.plan?.name || 'Plan';
          const activationDate = new Date().toISOString().slice(0, 10);

          const { buildWelcomeEmail, sendEmail } = await import('./sendEmail');
          const email = buildWelcomeEmail({
            businessName,
            propertyName,
            planName,
            activationDate,
            to: ownerEmail,
          });
          try {
            await sendEmail(email);
            await propertyRef.set({ welcomeEmailSentAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
            functions.logger.info('welcome_email_sent', { propertyId, businessId, to: ownerEmail });
          } catch (err) {
            functions.logger.error('welcome_email_failed', { error: err, propertyId, businessId, to: ownerEmail });
          }
        } else if (eligible && !ownerEmail) {
          functions.logger.info('welcome_email_skipped_no_recipient', { propertyId, businessId });
        }
      }
    } catch (err) {
      functions.logger.error('welcome_email_failed', { error: err, propertyId, businessId });
    }

    try {
      await attemptRef.set({ status: 'confirmed', confirmedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    } catch (e) {
      functions.logger.warn('payment_attempts log failed (confirmed)', { paymentId, error: e });
    }

    return { ok: true };
  });
