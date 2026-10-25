/**
 * ======================================================
 * RAZORPAY INTEGRATION MODULE
 * ======================================================
 *
 * Architecture:
 * - PG Owner uses their own Razorpay merchant account.
 * - OneStay360 creates payment links using PG's API keys.
 * - Tenant pays via payment link.
 *
 * Money Flow: Tenant → Razorpay → PG Owner's Bank (directly)
 * OneStay360 NEVER touches tenant rent money.
 *
 * SECURITY:
 * ✅ Razorpay API keys are stored in a private Firestore doc.
 * ✅ Every payment webhook is HMAC verified.
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import * as https from 'https';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

// ─── Config ──────────────────────────────────────────────

type RazorpayCredentials = {
  keyId: string;
  keySecret: string;
  webhookSecret?: string;
};

function getWebhookSecret(): string {
  const config = functions.config();
  return (config.razorpay?.webhook_secret || process.env.RAZORPAY_WEBHOOK_SECRET || '').toString().trim();
}

async function getBusinessWebhookSecret(businessId: string): Promise<string> {
  try {
    const secretSnap = await db.doc(`businesses/${businessId}/settings/razorpay_private`).get();
    if (!secretSnap.exists) return '';
    const data = secretSnap.data() as any;
    return (data?.webhookSecret || data?.webhook_secret || '').toString().trim();
  } catch (err) {
    functions.logger.warn('razorpay_webhook_secret_lookup_failed', {
      businessId,
      error: (err as Error).message,
    });
    return '';
  }
}

async function getBusinessRazorpayCredentials(businessId: string): Promise<RazorpayCredentials> {
  const secretSnap = await db.doc(`businesses/${businessId}/settings/razorpay_private`).get();
  if (!secretSnap.exists) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Razorpay API keys not configured for this business.'
    );
  }

  const data = secretSnap.data() as any;
  const keyId = (data?.keyId || data?.key_id || '').toString();
  const keySecret = (data?.keySecret || data?.key_secret || '').toString();
  const webhookSecret = (data?.webhookSecret || data?.webhook_secret || '').toString().trim();

  if (!keyId || !keySecret) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Razorpay API keys not configured for this business.'
    );
  }

  return { keyId, keySecret, webhookSecret };
}

function razorpayHeaders(credentials: RazorpayCredentials): Record<string, string> {
  const auth = Buffer.from(`${credentials.keyId}:${credentials.keySecret}`).toString('base64');
  const headers: Record<string, string> = {
    'Authorization': `Basic ${auth}`,
    'Content-Type': 'application/json',
  };
  return headers;
}

function razorpayRequest(
  method: string,
  path: string,
  body?: any,
  credentials?: RazorpayCredentials
): Promise<any> {
  return new Promise((resolve, reject) => {
    if (!credentials) {
      reject(new functions.https.HttpsError('failed-precondition', 'Missing Razorpay credentials'));
      return;
    }

    const headers = razorpayHeaders(credentials);
    const postData = body ? JSON.stringify(body) : undefined;

    if (postData) {
      headers['Content-Length'] = String(Buffer.byteLength(postData));
    }

    const options: https.RequestOptions = {
      hostname: 'api.razorpay.com',
      path,
      method,
      headers,
    };

    const req = https.request(options, (res) => {
      let rawData = '';
      res.on('data', (chunk: Buffer) => { rawData += chunk.toString(); });
      res.on('end', () => {
        try {
          const data = JSON.parse(rawData);
          if (res.statusCode && res.statusCode >= 400) {
            functions.logger.error('razorpay_api_error', {
              status: res.statusCode,
              path,
              error: data,
            });
            reject(
              new functions.https.HttpsError(
                'internal',
                `Razorpay API error: ${data?.error?.description || JSON.stringify(data)}`
              )
            );
            return;
          }
          resolve(data);
        } catch (parseErr) {
          reject(new functions.https.HttpsError('internal', `Failed to parse Razorpay response: ${rawData}`));
        }
      });
    });

    req.on('error', (err) => {
      functions.logger.error('razorpay_request_error', { path, error: err.message });
      reject(new functions.https.HttpsError('internal', `Razorpay request failed: ${err.message}`));
    });

    if (postData) {
      req.write(postData);
    }
    req.end();
  });
}

// ─── Webhook Signature Verification ─────────────────────

function verifyWebhookSignature(
  rawBody: string,
  signature: string,
  secret: string
): boolean {
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(rawBody)
    .digest('hex');
  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expectedSignature)
  );
}

// ─── Push Notification Helpers ──────────────────────────

async function sendPushToUser(
  userId: string,
  notification: { title: string; body: string },
  data?: Record<string, string>
): Promise<void> {
  try {
    const tokensSnap = await db
      .collection('users')
      .doc(userId)
      .collection('deviceTokens')
      .where('active', '==', true)
      .limit(50)
      .get();

    if (tokensSnap.empty) return;

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
      } catch (err: any) {
        if (
          err?.message?.includes('registration token is invalid') ||
          err?.message?.includes('not registered')
        ) {
          await tokenDoc.ref.update({ active: false }).catch(() => {});
        }
      }
    }
  } catch (err) {
    functions.logger.warn('push_notification_failed', err);
  }
}

async function sendPushToBusinessOwner(
  businessId: string,
  notification: { title: string; body: string },
  data?: Record<string, string>
): Promise<void> {
  const bizSnap = await db.collection('businesses').doc(businessId).get();
  if (!bizSnap.exists) return;
  const ownerUid = (bizSnap.data() as any)?.ownerUserId || (bizSnap.data() as any)?.ownerUid;
  if (!ownerUid) return;
  await sendPushToUser(ownerUid, notification, data);
}

// ======================================================
// 1. PAYMENT SETUP (PG's OWN RAZORPAY ACCOUNT)
// ======================================================

/**
 * Legacy Route onboarding is disabled.
 * PG owners must add their own Razorpay API keys in settings.
 */
export const onboardPGOwner = functions
  .runWith({ timeoutSeconds: 30, memory: '256MB' })
  .https.onCall(async (data, context) => {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Route onboarding is disabled. Add your Razorpay API keys in business settings.'
    );
  });

/**
 * Check the KYC / activation status of the PG owner's Razorpay account.
 */
export const checkRazorpayStatus = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }

  const { businessId } = data || {};
  if (!businessId) {
    throw new functions.https.HttpsError('invalid-argument', 'businessId required');
  }

  const publicSnap = await db.doc(`businesses/${businessId}/settings/razorpay`).get();
  const publicData = publicSnap.exists ? (publicSnap.data() as any) : {};

  const secretSnap = await db.doc(`businesses/${businessId}/settings/razorpay_private`).get();
  const secretData = secretSnap.exists ? (secretSnap.data() as any) : {};

  const hasKeys = !!(secretData?.keyId || secretData?.key_id) && !!(secretData?.keySecret || secretData?.key_secret);
  const paymentsEnabled = publicData?.paymentsEnabled === true && hasKeys;

  return {
    onboarded: hasKeys,
    paymentsEnabled,
    kycStatus: paymentsEnabled ? 'activated' : (hasKeys ? 'configured' : null),
  };
});

/**
 * Verify Razorpay keys by calling a lightweight API using PG's credentials.
 */
export const verifyRazorpaySetup = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }

  const { businessId } = data || {};
  if (!businessId) {
    throw new functions.https.HttpsError('invalid-argument', 'businessId required');
  }

  const bizSnap = await db.collection('businesses').doc(businessId).get();
  if (!bizSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Business not found');
  }

  const bizData = bizSnap.data() as any;
  const ownerUid = bizData?.ownerUserId || bizData?.ownerUid;
  if (ownerUid && ownerUid !== uid) {
    throw new functions.https.HttpsError('permission-denied', 'Only the business owner can verify setup');
  }

  const credentials = await getBusinessRazorpayCredentials(businessId);

  let merchantId = '';
  let merchantName = '';

  try {
    // Lightweight API call to validate credentials
    await razorpayRequest('GET', '/v1/payment_links?count=1', undefined, credentials);
  } catch (err: any) {
    const message = err?.message || 'Razorpay verification failed';
    throw new functions.https.HttpsError('failed-precondition', message);
  }

  try {
    // Best-effort merchant identity fetch; some accounts may not allow this endpoint
    const account = await razorpayRequest('GET', '/v1/account', undefined, credentials);
    merchantId = (account?.id || account?.merchant_id || '').toString();
    merchantName = (account?.name || account?.business_name || '').toString();
  } catch (err) {
    // Ignore merchant identity errors and still mark verification true
    functions.logger.warn('razorpay_verify_identity_skipped', {
      businessId,
      error: (err as Error).message,
    });
  }

  await db.doc(`businesses/${businessId}/settings/razorpay`).set({
    verified: true,
    verifiedAt: admin.firestore.Timestamp.now(),
    merchantId: merchantId || null,
    merchantName: merchantName || null,
    updatedAt: admin.firestore.Timestamp.now(),
  }, { merge: true });

  return { ok: true };
});

function mapRazorpayStatus(status: string): string {
  switch (status) {
    case 'activated': return 'activated';
    case 'under_review': return 'under_review';
    case 'needs_clarification': return 'needs_clarification';
    case 'suspended': return 'suspended';
    default: return 'pending';
  }
}

// ======================================================
// 2. PAYMENT LINK GENERATION
// ======================================================

/**
 * Creates a Razorpay Payment Link for a specific rent invoice.
 * The payment is processed using the PG owner's own Razorpay account.
 */
export const createPaymentLink = functions
  .runWith({ timeoutSeconds: 30, memory: '256MB' })
  .https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }

    const { businessId, tenantId, rentInvoiceId } = data || {};
    if (!businessId || !tenantId || !rentInvoiceId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'businessId, tenantId, rentInvoiceId required'
      );
    }

    // Get Razorpay config for this business
    const configSnap = await db.doc(`businesses/${businessId}/settings/razorpay`).get();
    if (!configSnap.exists) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Online payments not enabled. Ask PG owner to enable payments.'
      );
    }

    const config = configSnap.data() as any;
    if (!config.paymentsEnabled) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Online payments are disabled.'
      );
    }

    const credentials = await getBusinessRazorpayCredentials(businessId);
    const keyIdHint = credentials.keyId ? `${credentials.keyId.slice(0, 6)}...${credentials.keyId.slice(-4)}` : 'unknown';

    // Get the rent invoice
    const invoiceRef = db.doc(
      `businesses/${businessId}/tenants/${tenantId}/rent_invoices/${rentInvoiceId}`
    );
    const invoiceSnap = await invoiceRef.get();
    if (!invoiceSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Rent invoice not found');
    }

    const invoice = invoiceSnap.data() as any;
    if (invoice.status === 'paid') {
      throw new functions.https.HttpsError('failed-precondition', 'Invoice already paid');
    }

    // If a payment link already exists and is still active, return it
    if (invoice.razorpayPaymentLinkId && invoice.razorpayPaymentLinkUrl) {
      return {
        paymentLinkUrl: invoice.razorpayPaymentLinkUrl,
        paymentLinkId: invoice.razorpayPaymentLinkId,
        alreadyCreated: true,
      };
    }

    // Get tenant details
    const tenantSnap = await db.doc(`businesses/${businessId}/tenants/${tenantId}`).get();
    const tenantData = tenantSnap.exists ? (tenantSnap.data() as any) : {};

    const amountInPaise = Math.round(invoice.amount * 100);

    // Create Razorpay Payment Link on the merchant account
    const linkPayload = {
      amount: amountInPaise,
      currency: 'INR',
      description: `Rent - ${invoice.month || 'Monthly Rent'}`,
      customer: {
        name: tenantData.name || 'Tenant',
        contact: tenantData.phone || undefined,
        email: tenantData.email || undefined,
      },
      notify: {
        sms: false,
        email: false,
      },
      reminder_enable: false,
      notes: {
        businessId,
        tenantId,
        rentInvoiceId,
        periodMonth: invoice.periodMonth || '',
      },
      callback_url: '', // Deep link back to app (set if needed)
      callback_method: 'get',
    };

    const cleanPayload = JSON.parse(JSON.stringify(linkPayload));

    const link = await razorpayRequest('POST', '/v1/payment_links', cleanPayload, credentials);

    // Store the payment link reference on the invoice
    await invoiceRef.update({
      razorpayPaymentLinkId: link.id,
      razorpayPaymentLinkUrl: link.short_url,
      mode: 'razorpay',
      razorpayKeyIdHint: keyIdHint,
      updatedAt: admin.firestore.Timestamp.now(),
    });

    functions.logger.info('payment_link_created', {
      businessId,
      tenantId,
      rentInvoiceId,
      paymentLinkId: link.id,
      keyIdHint,
    });

    return {
      paymentLinkUrl: link.short_url,
      paymentLinkId: link.id,
      alreadyCreated: false,
    };
  });

// ======================================================
// 3. WEBHOOK HANDLERS (CRITICAL)
// ======================================================

/**
 * Razorpay Payment Webhook — auto-verifies and reconciles payments.
 *
 * SECURITY: HMAC SHA256 signature verification is MANDATORY.
 * IDEMPOTENCY: Duplicate webhook calls are safely ignored.
 *
 * If this webhook fails, the product fails.
 */
export const razorpayPaymentWebhook = functions
  .runWith({ timeoutSeconds: 60, memory: '256MB' })
  .https.onRequest(async (req, res) => {
    // Only accept POST
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    const defaultWebhookSecret = getWebhookSecret();
    if (!defaultWebhookSecret) {
      functions.logger.warn('razorpay_webhook_secret_missing_default');
    }

    // ── Signature Verification (MANDATORY) ──
    const signature = req.headers['x-razorpay-signature'] as string;
    if (!signature) {
      functions.logger.warn('razorpay_webhook_no_signature');
      res.status(400).send('Missing signature');
      return;
    }

    const rawBody = (req as any).rawBody?.toString('utf8') || JSON.stringify(req.body);
    const signatureLength = signature ? signature.length : 0;

    let isValidSignature = false;
    try {
      if (defaultWebhookSecret) {
        isValidSignature = verifyWebhookSignature(rawBody, signature, defaultWebhookSecret);
      }
    } catch (err) {
      functions.logger.error('razorpay_webhook_signature_error', err);
      res.status(400).send('Signature verification failed');
      return;
    }

    if (!isValidSignature) {
      // Try business-specific webhook secret if available in notes
      let businessIdFromPayload = '';
      let eventAccountId = '';
      let eventType = '';
      try {
        const parsed = typeof req.body === 'object' ? req.body : JSON.parse(rawBody);
        const paymentLinkNotes = parsed?.payload?.payment_link?.entity?.notes || {};
        const paymentNotes = parsed?.payload?.payment?.entity?.notes || {};
        businessIdFromPayload = paymentLinkNotes.businessId || paymentNotes.businessId || '';
        eventAccountId = parsed?.account_id || parsed?.payload?.account?.entity?.id || '';
        eventType = parsed?.event || '';
      } catch (err) {
        functions.logger.warn('razorpay_webhook_payload_parse_failed', {
          error: (err as Error).message,
        });
      }

      functions.logger.warn('razorpay_webhook_signature_failed', {
        event: eventType,
        accountId: eventAccountId,
        businessId: businessIdFromPayload,
        signatureLength,
      });

      if (businessIdFromPayload) {
        const businessSecret = await getBusinessWebhookSecret(businessIdFromPayload);
        if (businessSecret) {
          isValidSignature = verifyWebhookSignature(rawBody, signature, businessSecret);
          functions.logger.info('razorpay_webhook_secret_try', {
            businessId: businessIdFromPayload,
            matched: isValidSignature,
            secretSource: 'business',
          });
        } else if (!defaultWebhookSecret) {
          functions.logger.error('razorpay_webhook_secret_missing', { businessId: businessIdFromPayload });
          res.status(500).send('Webhook secret not configured');
          return;
        }
      } else if (!defaultWebhookSecret) {
        functions.logger.error('razorpay_webhook_secret_missing');
        res.status(500).send('Webhook secret not configured');
        return;
      }
    }

    if (!isValidSignature) {
      functions.logger.error('razorpay_webhook_invalid_signature');
      res.status(400).send('Invalid signature');
      return;
    }

    // ── Process the event ──
    const event = req.body;
    const eventType = event?.event;
    const eventAccountId = event?.account_id || event?.payload?.account?.entity?.id || '';

    functions.logger.info('razorpay_webhook_received', {
      event: eventType,
      payloadAccountId: eventAccountId,
    });

    try {
      switch (eventType) {
        case 'payment_link.paid':
          await handlePaymentLinkPaid(event);
          break;
        case 'payment.captured':
          await handlePaymentCaptured(event);
          break;
        case 'account.activated':
        case 'account.under_review':
        case 'account.needs_clarification':
        case 'account.suspended':
          await handleAccountStatusChange(event);
          break;
        default:
          functions.logger.info('razorpay_webhook_unhandled_event', { event: eventType });
      }

      res.status(200).json({ status: 'ok' });
    } catch (err) {
      functions.logger.error('razorpay_webhook_processing_error', err);
      // Return 200 to prevent Razorpay retry storms on application errors.
      // The error is logged for investigation.
      res.status(200).json({ status: 'error_logged' });
    }
  });

/**
 * Handle payment_link.paid event.
 * This is the primary reconciliation path.
 */
async function handlePaymentLinkPaid(event: any): Promise<void> {
  const payload = event?.payload;
  const paymentLink = payload?.payment_link?.entity;
  const payment = payload?.payment?.entity;

  if (!paymentLink || !payment) {
    functions.logger.warn('payment_link_paid_missing_payload');
    return;
  }

  const paymentLinkId = paymentLink.id;
  const razorpayPaymentId = payment.id;
  const amountPaise = payment.amount;
  const amountInr = amountPaise / 100;

  const notes = paymentLink.notes || {};
  const { businessId, tenantId, rentInvoiceId } = notes;

  if (!businessId || !tenantId || !rentInvoiceId) {
    functions.logger.warn('payment_link_paid_missing_notes', { paymentLinkId, notes });
    return;
  }

  const invoiceRef = db.doc(
    `businesses/${businessId}/tenants/${tenantId}/rent_invoices/${rentInvoiceId}`
  );

  // ── Idempotency: Skip if already processed ──
  const invoiceSnap = await invoiceRef.get();
  if (!invoiceSnap.exists) {
    functions.logger.warn('payment_link_paid_invoice_not_found', { rentInvoiceId });
    return;
  }

  const invoice = invoiceSnap.data() as any;
  if (invoice.status === 'paid' && invoice.razorpayPaymentId === razorpayPaymentId) {
    functions.logger.info('payment_link_paid_already_processed', { razorpayPaymentId });
    return;
  }

  const now = admin.firestore.Timestamp.now();

  // ── Update invoice ──
  await invoiceRef.update({
    status: 'paid',
    verification: 'verified',
    mode: 'razorpay',
    razorpayPaymentId,
    razorpayPaymentLinkId: paymentLinkId,
    paidAt: now,
    updatedAt: now,
  });

  // ── Create payment history record ──
  const tenantSnap = await db.doc(`businesses/${businessId}/tenants/${tenantId}`).get();
  const tenantData = tenantSnap.exists ? (tenantSnap.data() as any) : {};

  const paymentRef = db
    .collection(`businesses/${businessId}/tenants/${tenantId}/payments`)
    .doc();

  await paymentRef.set({
    id: paymentRef.id,
    tenantId,
    businessId,
    tenantName: tenantData.name || '',
    roomNumber: tenantData.roomNumber || tenantData.roomId || '',
    bedNumber: tenantData.bedNumber || tenantData.bedId || '',
    amount: amountInr,
    month: invoice.month || '',
    date: now,
    status: 'Paid',
    verification: 'verified',
    method: 'Razorpay',
    mode: 'razorpay',
    razorpayPaymentId,
    razorpayPaymentLinkId: paymentLinkId,
    rentInvoiceId,
    submittedBy: 'system',
    recordedBy: 'razorpay_webhook',
    createdAt: now,
  });

  // ── Update tenant docs ──
  const bizTenantRef = db.doc(`businesses/${businessId}/tenants/${tenantId}`);
  await bizTenantRef.update({
    lastPaymentDate: now,
    lastPaymentAmount: amountInr,
    lastPaymentMonth: invoice.month || '',
    updatedAt: now,
  }).catch(() => {});

  const globalTenantRef = db.doc(`tenants/${tenantId}`);
  await globalTenantRef.update({
    lastPaymentDate: now,
    lastPaymentAmount: amountInr,
    updatedAt: now,
  }).catch(() => {});

  // ── Notify PG Owner ──
  await sendPushToBusinessOwner(businessId, {
    title: '💰 Rent Received',
    body: `₹${amountInr.toLocaleString('en-IN')} received from ${tenantData.name || 'Tenant'} for ${invoice.month || 'rent'}.`,
  }, {
    type: 'rent_received',
    tenantId,
    businessId,
    amount: String(amountInr),
  });

  // ── Notify Tenant ──
  const tenantUserId = tenantData.userId || tenantData.uid;
  if (tenantUserId) {
    await sendPushToUser(tenantUserId, {
      title: '✅ Payment Confirmed',
      body: `Your rent payment of ₹${amountInr.toLocaleString('en-IN')} for ${invoice.month || ''} has been verified.`,
    }, {
      type: 'rent_payment_verified',
      businessId,
    });
  }

  // ── Persist notification for business ──
  await db.collection('businesses').doc(businessId).collection('notifications').add({
    businessId,
    title: '💰 Rent Received',
    message: `₹${amountInr.toLocaleString('en-IN')} received from ${tenantData.name || 'Tenant'} for ${invoice.month || 'rent'} via Razorpay.`,
    type: 'rent_received',
    tenantId,
    read: false,
    createdAt: now,
  }).catch(() => {});

  functions.logger.info('payment_reconciled', {
    businessId,
    tenantId,
    rentInvoiceId,
    razorpayPaymentId,
    amount: amountInr,
  });
}

/**
 * Handle payment.captured event (fallback reconciliation).
 */
async function handlePaymentCaptured(event: any): Promise<void> {
  const payment = event?.payload?.payment?.entity;
  if (!payment) return;

  const notes = payment.notes || {};
  const { businessId, tenantId, rentInvoiceId } = notes;

  // If notes contain our invoice reference, reconcile
  if (businessId && tenantId && rentInvoiceId) {
    // Reuse the same logic by constructing a mock payment_link event
    await handlePaymentLinkPaid({
      payload: {
        payment_link: { entity: { id: payment.id, notes } },
        payment: { entity: payment },
      },
    });
  }
}

/**
 * Handle account status change events (KYC updates for PG owners).
 */
async function handleAccountStatusChange(event: any): Promise<void> {
  const account = event?.payload?.account?.entity;
  if (!account?.id) return;

  const accountId = account.id;
  const newStatus = mapRazorpayStatus(account.status || '');
  const activated = account.status === 'activated';

  // Find the business with this Razorpay account ID
  // We query across all businesses' settings
  const businessesSnap = await db.collectionGroup('settings')
    .where('razorpayAccountId', '==', accountId)
    .limit(1)
    .get();

  if (businessesSnap.empty) {
    functions.logger.warn('razorpay_account_webhook_no_business', { accountId });
    return;
  }

  const settingsDoc = businessesSnap.docs[0];
  const configData = settingsDoc.data() as any;
  const businessId = configData.businessId;

  await settingsDoc.ref.update({
    kycStatus: newStatus,
    paymentsEnabled: activated,
    updatedAt: admin.firestore.Timestamp.now(),
  });

  // Notify the PG owner
  let title = '';
  let body = '';

  switch (newStatus) {
    case 'activated':
      title = '🎉 Payments Activated!';
      body = 'Your online payment setup is complete. Tenants can now pay rent directly to your bank account.';
      break;
    case 'under_review':
      title = '📝 KYC Under Review';
      body = 'Your payment setup is being reviewed by Razorpay. This usually takes 1-2 business days.';
      break;
    case 'needs_clarification':
      title = '⚠️ Action Required';
      body = 'Razorpay needs additional information for your payment setup. Please check your Razorpay dashboard.';
      break;
    case 'suspended':
      title = '🔴 Payments Suspended';
      body = 'Your payment account has been suspended. Contact support for assistance.';
      break;
  }

  if (title && businessId) {
    await sendPushToBusinessOwner(businessId, { title, body }, {
      type: 'razorpay_kyc_update',
      kycStatus: newStatus,
      businessId,
    });
  }

  functions.logger.info('razorpay_account_status_updated', {
    businessId,
    accountId,
    status: newStatus,
    activated,
  });
}

// ======================================================
// 4. PAYMENT DASHBOARD AGGREGATION
// ======================================================

/**
 * Get payment aggregation stats for the business dashboard.
 */
export const getPaymentDashboard = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }

  const { businessId } = data || {};
  if (!businessId) {
    throw new functions.https.HttpsError('invalid-argument', 'businessId required');
  }

  // Get all tenants for this business
  const tenantsSnap = await db
    .collection(`businesses/${businessId}/tenants`)
    .where('status', '==', 'active')
    .get();

  let totalCollected = 0;
  let verifiedAmount = 0;
  let pendingAmount = 0;
  let manualAmount = 0;
  let unpaidInvoices = 0;

  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const monthStartTs = admin.firestore.Timestamp.fromDate(monthStart);

  // Process tenants in concurrent chunks of 20 to eliminate sequential N+1 query lag
  const BATCH_SIZE = 20;
  for (let i = 0; i < tenantsSnap.docs.length; i += BATCH_SIZE) {
    const chunk = tenantsSnap.docs.slice(i, i + BATCH_SIZE);
    const results = await Promise.all(
      chunk.map(async (tenantDoc) => {
        const tenantId = tenantDoc.id;

        // Fetch unpaid invoices and payments concurrently for this tenant
        const [unpaidSnap, paymentsSnap] = await Promise.all([
          db
            .collection(`businesses/${businessId}/tenants/${tenantId}/rent_invoices`)
            .where('status', 'in', ['unpaid', 'overdue'])
            .get(),
          db
            .collection(`businesses/${businessId}/tenants/${tenantId}/payments`)
            .where('date', '>=', monthStartTs)
            .get(),
        ]);

        let localTotal = 0;
        let localVerified = 0;
        let localPending = 0;
        let localManual = 0;

        for (const payDoc of paymentsSnap.docs) {
          const pay = payDoc.data() as any;
          const amount = pay.amount || 0;

          if (pay.status === 'Paid' || pay.status === 'paid') {
            localTotal += amount;

            if (pay.verification === 'verified' || pay.mode === 'razorpay') {
              localVerified += amount;
            } else if (pay.status === 'pending_verification') {
              localPending += amount;
            } else {
              localManual += amount;
            }
          }
        }

        return {
          unpaidCount: unpaidSnap.size,
          totalCollected: localTotal,
          verifiedAmount: localVerified,
          pendingAmount: localPending,
          manualAmount: localManual,
        };
      })
    );

    for (const res of results) {
      unpaidInvoices += res.unpaidCount;
      totalCollected += res.totalCollected;
      verifiedAmount += res.verifiedAmount;
      pendingAmount += res.pendingAmount;
      manualAmount += res.manualAmount;
    }
  }

  return {
    totalCollected,
    verifiedAmount,
    pendingAmount,
    manualAmount,
    unpaidInvoices,
    activeTenants: tenantsSnap.size,
  };
});
