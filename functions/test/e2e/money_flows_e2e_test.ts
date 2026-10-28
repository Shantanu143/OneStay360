/**
 * End-to-end money flows against the Firestore emulator, through the real
 * callables, the real Razorpay webhook (signed requests) and the real
 * triggers. Needs the emulator:
 *
 *   npx firebase emulators:exec --only firestore --project demo-onestay \
 *     "npx jest -c jest.e2e.config.js"
 */
import * as crypto from 'crypto';

const PROJECT = 'demo-onestay';
const WEBHOOK_SECRET = 'whsec_e2e';
process.env.GCLOUD_PROJECT = PROJECT;
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.RAZORPAY_WEBHOOK_SECRET = WEBHOOK_SECRET;

// eslint-disable-next-line @typescript-eslint/no-var-requires
const fft = require('firebase-functions-test')({ projectId: PROJECT });
fft.mockConfig({ razorpay: { webhook_secret: WEBHOOK_SECRET } });

import * as admin from 'firebase-admin';
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });

// eslint-disable-next-line import/first
import { submitRentPayment, verifyRentPayment } from '../../billing';
import { razorpayPaymentWebhook } from '../../razorpay';
import { onPaymentCreated } from '../../rentPaymentNotifications';
import { updatePropertyDetails } from '../../propertyEdit';
import { createTenantInvitation } from '../../tenantOnboarding';
import { approveInvitation, listMyTenantInvitations, rejectTenantInvitation } from '../../tenantInvitations';
import { onMaintenanceRequestCreated } from '../../maintenance';

const db = admin.firestore();
const B = 'BUS0000001';
const P = 'BUS0000001PNR001';
const T = 'TEN0000001';
const OWNER = 'owner-uid';
const STAFF = 'staff-uid';
const TENANT = 'tenant-uid';
const STRANGER = 'stranger-uid';

const call = (fn: any, data: any, uid?: string) =>
  fft.wrap(fn)(data, uid ? { auth: { uid, token: {} } } : {});

const paymentsCol = () => db.collection(`businesses/${B}/tenants/${T}/payments`);
const invoiceRef = (id: string) => db.doc(`businesses/${B}/tenants/${T}/rent_invoices/${id}`);

async function clearAll() {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, {
    method: 'DELETE',
  });
}

async function seed() {
  const now = admin.firestore.Timestamp.now();
  await db.doc(`businesses/${B}`).set({ name: 'Apex Living', ownerUserId: OWNER });
  await db.doc(`businesses/${B}/members/${OWNER}`).set({ role: 'owner', status: 'active' });
  await db.doc(`businesses/${B}/members/${STAFF}`).set({ role: 'staff', status: 'active' });
  await db.doc(`businesses/${B}/properties/${P}/access/${STAFF}`).set({ role: 'staff' });
  await db.doc(`users/${TENANT}`).set({ tenantId: T, role: 'tenant' });
  await db.doc(`tenants/${T}`).set({ name: 'Asha Rao', userId: TENANT });
  await db.doc(`businesses/${B}/tenants/${T}`).set({
    name: 'Asha Rao', userId: TENANT, propertyId: P, roomNumber: '101', bedNumber: '1', status: 'active',
  });
  for (const [id, month] of [['INV_MAR', 'March 2026'], ['INV_APR', 'April 2026']]) {
    await invoiceRef(id).set({ amount: 9000, month, status: 'unpaid', propertyId: P, tenantId: T, businessId: B, createdAt: now });
  }
  const property: Record<string, any> = {
    name: 'Green Nest', address: '12 Baner Road', city: 'Pune', pincode: '411045', status: 'active',
    billingStatus: 'paid', plan: { pricePerBed: 30 }, businessId: B, numberOfFloors: 1,
    pricing: { maxSharing: 1, sharing: [{ sharing: 1, nonAc: 9000, ac: null }], securityDeposit: 5000 },
    amenities: { wifi: true }, rules: { genderAllowed: 'Co-ed' }, images: [],
  };
  await db.doc(`businesses/${B}/properties/${P}`).set(property);
  await db.doc(`properties_by_city/Pune/properties/${P}`).set(property);
}

/** Runs the Firestore onCreate trigger the way the platform would. */
async function fireOnPaymentCreated(paymentId: string) {
  const snap = await paymentsCol().doc(paymentId).get();
  await fft.wrap(onPaymentCreated)(snap, { params: { businessId: B, tenantId: T, paymentId } });
}

/** Posts a Razorpay webhook with a valid (or forged) signature. */
async function postWebhook(body: any, secret = WEBHOOK_SECRET) {
  const raw = JSON.stringify(body);
  const sig = crypto.createHmac('sha256', secret).update(raw).digest('hex');
  let status = 0;
  const res: any = {
    status(code: number) { status = code; return res; },
    send() { return res; },
    json() { return res; },
  };
  await (razorpayPaymentWebhook as any)(
    { method: 'POST', headers: { 'x-razorpay-signature': sig }, body, rawBody: Buffer.from(raw) },
    res,
  );
  return status;
}

const linkPaid = (paymentId: string, invoiceId: string) => ({
  event: 'payment_link.paid',
  payload: {
    payment_link: { entity: { id: `plink_${paymentId}`, notes: { businessId: B, tenantId: T, rentInvoiceId: invoiceId } } },
    payment: { entity: { id: paymentId, amount: 900000, notes: { businessId: B, tenantId: T, rentInvoiceId: invoiceId } } },
  },
});

beforeEach(async () => {
  await clearAll();
  await seed();
});

afterAll(() => fft.cleanup());

describe('tenant pays rent by UPI, owner tracks and confirms it', () => {
  it('runs from "I paid" to a paid invoice', async () => {
    const r = await call(submitRentPayment, {
      businessId: B, amount: 9000, month: 'March 2026', paymentMode: 'UPI', transactionId: 'UTR123', rentInvoiceId: 'INV_MAR',
    }, TENANT);
    expect(r.status).toBe('pending_verification');

    // The owner sees it waiting...
    const pending = await paymentsCol().where('status', '==', 'pending_verification').get();
    expect(pending.size).toBe(1);
    expect(pending.docs[0].data()).toMatchObject({ amount: 9000, method: 'UPI', transactionId: 'UTR123', rentInvoiceId: 'INV_MAR', tenantName: 'Asha Rao' });

    // ...and gets it in their notifications list.
    await fireOnPaymentCreated(r.paymentId);
    const notes = await db.collection(`businesses/${B}/notifications`).get();
    expect(notes.size).toBe(1);
    expect(notes.docs[0].data()).toMatchObject({ type: 'payment', tenantId: T });

    // A second "I paid" for the same bill is refused.
    await expect(call(submitRentPayment, {
      businessId: B, amount: 9000, month: 'March 2026', paymentMode: 'UPI', transactionId: 'UTR124', rentInvoiceId: 'INV_MAR',
    }, TENANT)).rejects.toMatchObject({ code: 'already-exists' });

    // The tenant can't confirm their own payment.
    await expect(call(verifyRentPayment, { businessId: B, tenantId: T, paymentId: r.paymentId, action: 'confirm' }, TENANT))
      .rejects.toMatchObject({ code: 'permission-denied' });

    await call(verifyRentPayment, { businessId: B, tenantId: T, paymentId: r.paymentId, action: 'confirm' }, OWNER);
    expect((await paymentsCol().doc(r.paymentId).get()).data()!.status).toBe('Paid');
    expect((await invoiceRef('INV_MAR').get()).data()!.status).toBe('paid');
    expect((await invoiceRef('INV_APR').get()).data()!.status).toBe('unpaid');

    // Paying a paid invoice again is refused.
    await expect(call(submitRentPayment, {
      businessId: B, amount: 9000, month: 'March 2026', paymentMode: 'Cash', rentInvoiceId: 'INV_MAR',
    }, TENANT)).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('rejects a wrong amount, and a rejected claim can be sent again', async () => {
    await expect(call(submitRentPayment, {
      businessId: B, amount: 500, month: 'March 2026', paymentMode: 'Cash', rentInvoiceId: 'INV_MAR',
    }, TENANT)).rejects.toMatchObject({ code: 'invalid-argument' });

    const r = await call(submitRentPayment, {
      businessId: B, amount: 9000, month: 'March 2026', paymentMode: 'Cash', rentInvoiceId: 'INV_MAR',
    }, TENANT);
    await call(verifyRentPayment, { businessId: B, tenantId: T, paymentId: r.paymentId, action: 'reject', rejectionReason: 'Not received' }, OWNER);
    expect((await paymentsCol().doc(r.paymentId).get()).data()!.status).toBe('rejected');
    expect((await invoiceRef('INV_MAR').get()).data()!.status).not.toBe('paid');

    const again = await call(submitRentPayment, {
      businessId: B, amount: 9000, month: 'March 2026', paymentMode: 'Cash', rentInvoiceId: 'INV_MAR',
    }, TENANT);
    expect(again.status).toBe('pending_verification');
  });
});

describe('tenant pays rent online (Razorpay webhook)', () => {
  it('records the payment once and marks the invoice paid', async () => {
    // Razorpay sends both events for one payment, sometimes at once and retried.
    const statuses = await Promise.all([
      postWebhook(linkPaid('pay_1', 'INV_APR')),
      postWebhook({ event: 'payment.captured', payload: linkPaid('pay_1', 'INV_APR').payload }),
      postWebhook(linkPaid('pay_1', 'INV_APR')),
    ]);
    expect(statuses).toEqual([200, 200, 200]);

    const all = await paymentsCol().get();
    expect(all.size).toBe(1);
    expect(all.docs[0].id).toBe('rzp_pay_1');
    expect(all.docs[0].data()).toMatchObject({ amount: 9000, rentInvoiceId: 'INV_APR' });
    const inv = (await invoiceRef('INV_APR').get()).data()!;
    expect(inv).toMatchObject({ status: 'paid', mode: 'razorpay', razorpayPaymentId: 'pay_1' });

    // The owner sees it on the tenant and in notifications.
    expect((await db.doc(`businesses/${B}/tenants/${T}`).get()).data()!.lastPaymentAmount).toBe(9000);
    const notes = await db.collection(`businesses/${B}/notifications`).where('type', '==', 'rent_received').get();
    expect(notes.size).toBe(1);
    // Opens the property's payments in the business app.
    expect(notes.docs[0].data()).toMatchObject({ propertyId: P, tenantName: 'Asha Rao', metadata: { paidOnline: true } });
  });

  it('ignores a forged webhook', async () => {
    expect(await postWebhook(linkPaid('pay_x', 'INV_APR'), 'not-the-secret')).toBe(400);
    expect((await paymentsCol().get()).size).toBe(0);
    expect((await invoiceRef('INV_APR').get()).data()!.status).toBe('unpaid');
  });
});

describe('owner edits a listed property', () => {
  const details: Record<string, any> = {
    name: 'Green Nest Annexe', address: '12 Baner Road', pincode: '411045', numberOfFloors: 2, images: [],
    pricing: { maxSharing: 1, sharing: [{ sharing: 1, nonAc: 9500, ac: null }], securityDeposit: 6000 },
    amenities: { wifi: true, cctv: true }, rules: { genderAllowed: 'Female', noticePeriodDays: 15 },
    // Ignored: these never change through an edit.
    status: 'draft', billingStatus: 'unpaid', city: 'Mumbai',
  };

  it('saves the edit and keeps the public listing in sync', async () => {
    await call(updatePropertyDetails, { businessId: B, propertyId: P, details }, OWNER);
    for (const path of [`businesses/${B}/properties/${P}`, `properties_by_city/Pune/properties/${P}`]) {
      const d = (await db.doc(path).get()).data()!;
      expect(d).toMatchObject({ name: 'Green Nest Annexe', city: 'Pune', status: 'active', billingStatus: 'paid' });
      expect(d.pricing.sharing[0].nonAc).toBe(9500);
      expect(d.pricing.securityDeposit).toBe(6000);
      expect(d.rules.genderAllowed).toBe('Female');
      expect(d.amenities.cctv).toBe(true);
      expect(d.plan).toEqual({ pricePerBed: 30 });
    }
  });

  it('is refused for staff, outsiders and bad input', async () => {
    await expect(call(updatePropertyDetails, { businessId: B, propertyId: P, details }, STAFF)).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(call(updatePropertyDetails, { businessId: B, propertyId: P, details }, STRANGER)).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(call(updatePropertyDetails, { businessId: B, propertyId: P, details })).rejects.toMatchObject({ code: 'unauthenticated' });
    await expect(call(updatePropertyDetails, { businessId: B, propertyId: P, details: { ...details, pincode: '12' } }, OWNER))
      .rejects.toMatchObject({ code: 'invalid-argument' });
    expect((await db.doc(`businesses/${B}/properties/${P}`).get()).data()!.name).toBe('Green Nest');
  });
});

describe('owner invites a tenant who joins from the tenant app', () => {
  const NEWCOMER = 'newcomer-uid';
  const invite = (extra: Record<string, any> = {}) => call(createTenantInvitation, {
    tenantName: 'Ravi K', tenantPhone: '+919811100002', businessId: B, propertyId: P, propertyName: 'Green Nest',
    roomId: 'R101', roomNumber: '101', bedIndex: 1, bedNumber: '2', moveInDate: Date.now(), monthlyRent: 9000, ...extra,
  }, OWNER);

  it('creates, lists, accepts and occupies the bed', async () => {
    await db.doc(`users/${NEWCOMER}`).set({ phone: '9811100002' });

    await expect(call(createTenantInvitation, {
      tenantName: 'Ravi K', tenantPhone: '+919811100002', businessId: B, propertyId: P, roomId: 'R101', roomNumber: '101', moveInDate: Date.now(),
    }, STAFF)).rejects.toMatchObject({ code: 'permission-denied' });

    const { invitationId, tenantId } = await invite();
    expect(tenantId).toMatch(/^TEN\d{7}$/);

    // Only the invited person sees it.
    expect((await call(listMyTenantInvitations, {}, NEWCOMER)).invitations.map((i: any) => i.id)).toEqual([invitationId]);
    expect((await call(listMyTenantInvitations, {}, STRANGER)).invitations).toEqual([]);
    await expect(call(approveInvitation, { invitationId }, STRANGER)).rejects.toBeDefined();

    const r = await call(approveInvitation, { invitationId }, NEWCOMER);
    expect(r.tenantId).toBe(tenantId);

    const biz = (await db.doc(`businesses/${B}/tenants/${tenantId}`).get()).data()!;
    expect(biz).toMatchObject({ propertyId: P, status: 'active' });
    expect((await db.doc(`users/${NEWCOMER}`).get()).data()).toMatchObject({ tenantId, isTenant: true });
    expect((await db.collection(`tenants/${tenantId}/stays`).get()).size).toBe(1);
    const beds = await db.collection(`businesses/${B}/properties/${P}/rooms/R101/beds`).get();
    expect(beds.size).toBe(1);
    expect(beds.docs[0].data().tenantId).toBe(tenantId);
    const joined = await db.collection(`businesses/${B}/notifications`).where('type', '==', 'tenant_joined').get();
    expect(joined.size).toBe(1);
    expect((await db.doc(`tenant_invitations/${invitationId}`).get()).data()!.status).toBe('accepted');

    // Answering twice is refused.
    await expect(call(approveInvitation, { invitationId }, NEWCOMER)).rejects.toBeDefined();
  });

  it('can be declined', async () => {
    await db.doc(`users/${NEWCOMER}`).set({ phone: '+91 98111 00002' });
    const { invitationId } = await invite();
    await call(rejectTenantInvitation, { invitationId, reason: 'Found another place' }, NEWCOMER);
    expect((await db.doc(`tenant_invitations/${invitationId}`).get()).data()!.status).toBe('rejected');
    expect((await call(listMyTenantInvitations, {}, NEWCOMER)).invitations).toEqual([]);
  });
});

describe('tenant raises a maintenance request', () => {
  it('lands in the owner notifications', async () => {
    const ref = db.collection('maintenanceRequests').doc();
    await ref.set({
      businessId: B, propertyId: P, tenantId: T, tenantUid: TENANT, tenantName: 'Asha Rao', category: 'plumbing',
      title: 'Tap leaking', status: 'open', urgent: true, createdAt: admin.firestore.Timestamp.now(),
    });
    await fft.wrap(onMaintenanceRequestCreated)(await ref.get(), { params: { requestId: ref.id } });
    const notes = await db.collection(`businesses/${B}/notifications`).where('type', '==', 'maintenance_request').get();
    expect(notes.size).toBe(1);
    expect(notes.docs[0].data()).toMatchObject({ maintenanceRequestId: ref.id });
  });
});
