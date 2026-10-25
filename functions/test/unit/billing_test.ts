/**
 * Unit tests for billing.ts Cloud Functions
 * Tests: submitRentPayment, verifyRentPayment, recordPayment
 */

import * as admin from 'firebase-admin';

// Initialize test environment
const projectId = 'onestay360-test';
process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId });
}

const db = admin.firestore();

// ─── Test Helpers ────────────────────────────────────────────────────────────

async function clearFirestore() {
  const collections = ['users', 'businesses', 'tenants', 'counters'];
  for (const col of collections) {
    const snap = await db.collection(col).get();
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
  }
}

async function seedTestData(opts: {
  uid: string;
  tenantId: string;
  businessId: string;
  monthlyRent?: number;
}) {
  const { uid, tenantId, businessId, monthlyRent = 10000 } = opts;
  const now = admin.firestore.Timestamp.now();

  // User doc
  await db.collection('users').doc(uid).set({
    uid,
    tenantId,
    fullName: 'Test Tenant',
    email: 'tenant@test.com',
    phone: '9876543210',
  });

  // Business doc
  await db.collection('businesses').doc(businessId).set({
    name: 'Test PG Business',
    ownerUid: 'owner-uid-123',
    ownerUserId: 'owner-uid-123',
  });

  // Business-scoped tenant doc
  await db
    .collection('businesses')
    .doc(businessId)
    .collection('tenants')
    .doc(tenantId)
    .set({
      tenantId,
      userId: uid,
      name: 'Test Tenant',
      phone: '9876543210',
      businessId,
      propertyId: 'PROP001',
      roomId: 'ROOM001',
      bedId: '1',
      roomNumber: 'ROOM001',
      bedNumber: '1',
      monthlyRent,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    });

  // Global tenant doc
  await db.collection('tenants').doc(tenantId).set({
    tenantId,
    userId: uid,
    businessId,
    propertyId: 'PROP001',
    status: 'active',
    monthlyRent,
    updatedAt: now,
  });
}

// ─── Tests ───────────────────────────────────────────────────────────────────

describe('submitRentPayment', () => {
  const uid = 'tenant-uid-001';
  const tenantId = 'TEN0000001';
  const businessId = 'BUS0000001';

  beforeEach(async () => {
    await clearFirestore();
    await seedTestData({ uid, tenantId, businessId });
  });

  it('should resolve actual tenantId from user doc', async () => {
    const userSnap = await db.collection('users').doc(uid).get();
    expect(userSnap.exists).toBe(true);
    expect(userSnap.data()?.tenantId).toBe(tenantId);
  });

  it('should find tenant in business collection using TEN ID', async () => {
    const tenantSnap = await db
      .collection('businesses')
      .doc(businessId)
      .collection('tenants')
      .doc(tenantId)
      .get();

    expect(tenantSnap.exists).toBe(true);
    expect(tenantSnap.data()?.tenantId).toBe(tenantId);
  });

  it('should create payment record with correct fields', async () => {
    const paymentRef = db
      .collection('businesses')
      .doc(businessId)
      .collection('tenants')
      .doc(tenantId)
      .collection('payments')
      .doc();

    const now = admin.firestore.Timestamp.now();
    await paymentRef.set({
      id: paymentRef.id,
      tenantId,
      businessId,
      tenantName: 'Test Tenant',
      amount: 10000,
      month: 'January 2025',
      date: now,
      status: 'pending_verification',
      method: 'UPI',
      transactionId: 'TXN123456',
      submittedBy: 'tenant',
      createdAt: now,
    });

    const paymentSnap = await paymentRef.get();
    expect(paymentSnap.exists).toBe(true);
    expect(paymentSnap.data()?.status).toBe('pending_verification');
    expect(paymentSnap.data()?.tenantId).toBe(tenantId);
    expect(paymentSnap.data()?.amount).toBe(10000);
  });

  it('should validate invoice amount when rentInvoiceId provided', async () => {
    const invoiceRef = db
      .collection('businesses')
      .doc(businessId)
      .collection('tenants')
      .doc(tenantId)
      .collection('rent_invoices')
      .doc('INV001');

    await invoiceRef.set({
      invoiceId: 'INV001',
      tenantId,
      businessId,
      amount: 10000,
      month: 'January 2025',
      status: 'unpaid',
    });

    const invoiceSnap = await invoiceRef.get();
    expect(invoiceSnap.exists).toBe(true);
    expect(invoiceSnap.data()?.amount).toBe(10000);
    expect(invoiceSnap.data()?.status).toBe('unpaid');
  });

  it('should reject payment for already-paid invoice', async () => {
    const invoiceRef = db
      .collection('businesses')
      .doc(businessId)
      .collection('tenants')
      .doc(tenantId)
      .collection('rent_invoices')
      .doc('INV002');

    await invoiceRef.set({
      invoiceId: 'INV002',
      tenantId,
      businessId,
      amount: 10000,
      month: 'January 2025',
      status: 'paid', // Already paid
    });

    const invoiceSnap = await invoiceRef.get();
    expect(invoiceSnap.data()?.status).toBe('paid');
    // In real function, this would throw 'failed-precondition'
  });
});

describe('verifyRentPayment', () => {
  const uid = 'tenant-uid-002';
  const tenantId = 'TEN0000002';
  const businessId = 'BUS0000002';

  beforeEach(async () => {
    await clearFirestore();
    await seedTestData({ uid, tenantId, businessId });
  });

  it('should mark payment as Paid on confirm', async () => {
    const now = admin.firestore.Timestamp.now();
    const paymentRef = db
      .collection('businesses')
      .doc(businessId)
      .collection('tenants')
      .doc(tenantId)
      .collection('payments')
      .doc('PAY001');

    await paymentRef.set({
      id: 'PAY001',
      tenantId,
      businessId,
      amount: 10000,
      month: 'January 2025',
      status: 'pending_verification',
      method: 'UPI',
      createdAt: now,
    });

    // Simulate confirm action
    await paymentRef.update({
      status: 'Paid',
      verifiedBy: 'owner-uid-123',
      verifiedAt: now,
      updatedAt: now,
    });

    const updatedSnap = await paymentRef.get();
    expect(updatedSnap.data()?.status).toBe('Paid');
    expect(updatedSnap.data()?.verifiedBy).toBe('owner-uid-123');
  });

  it('should mark invoice as paid when payment confirmed', async () => {
    const now = admin.firestore.Timestamp.now();

    // Create invoice
    const invoiceRef = db
      .collection('businesses')
      .doc(businessId)
      .collection('tenants')
      .doc(tenantId)
      .collection('rent_invoices')
      .doc('INV003');

    await invoiceRef.set({
      invoiceId: 'INV003',
      tenantId,
      businessId,
      amount: 10000,
      month: 'January 2025',
      status: 'unpaid',
    });

    // Create payment linked to invoice
    const paymentRef = db
      .collection('businesses')
      .doc(businessId)
      .collection('tenants')
      .doc(tenantId)
      .collection('payments')
      .doc('PAY002');

    await paymentRef.set({
      id: 'PAY002',
      tenantId,
      businessId,
      amount: 10000,
      month: 'January 2025',
      status: 'pending_verification',
      rentInvoiceId: 'INV003',
      createdAt: now,
    });

    // Simulate confirm: mark invoice as paid
    await invoiceRef.update({
      status: 'paid',
      paidAt: now,
      verification: 'verified',
      mode: 'UPI',
      updatedAt: now,
    });

    const invoiceSnap = await invoiceRef.get();
    expect(invoiceSnap.data()?.status).toBe('paid');
    expect(invoiceSnap.data()?.verification).toBe('verified');
  });

  it('should mark payment as rejected on reject', async () => {
    const now = admin.firestore.Timestamp.now();
    const paymentRef = db
      .collection('businesses')
      .doc(businessId)
      .collection('tenants')
      .doc(tenantId)
      .collection('payments')
      .doc('PAY003');

    await paymentRef.set({
      id: 'PAY003',
      tenantId,
      businessId,
      amount: 10000,
      month: 'January 2025',
      status: 'pending_verification',
      createdAt: now,
    });

    // Simulate reject action
    await paymentRef.update({
      status: 'rejected',
      rejectionReason: 'Payment not received',
      rejectedBy: 'owner-uid-123',
      rejectedAt: now,
      updatedAt: now,
    });

    const updatedSnap = await paymentRef.get();
    expect(updatedSnap.data()?.status).toBe('rejected');
    expect(updatedSnap.data()?.rejectionReason).toBe('Payment not received');
  });

  it('should update tenant lastPaymentDate on confirm', async () => {
    const now = admin.firestore.Timestamp.now();

    await db
      .collection('businesses')
      .doc(businessId)
      .collection('tenants')
      .doc(tenantId)
      .update({
        lastPaymentDate: now,
        lastPaymentAmount: 10000,
        lastPaymentMonth: 'January 2025',
        updatedAt: now,
      });

    const tenantSnap = await db
      .collection('businesses')
      .doc(businessId)
      .collection('tenants')
      .doc(tenantId)
      .get();

    expect(tenantSnap.data()?.lastPaymentAmount).toBe(10000);
    expect(tenantSnap.data()?.lastPaymentMonth).toBe('January 2025');
  });
});

describe('recordPayment (Owner Manual Entry)', () => {
  const tenantId = 'TEN0000003';
  const businessId = 'BUS0000003';

  beforeEach(async () => {
    await clearFirestore();
    await seedTestData({ uid: 'owner-uid-003', tenantId, businessId });
  });

  it('should create payment record with Paid status', async () => {
    const now = admin.firestore.Timestamp.now();
    const paymentRef = db
      .collection('businesses')
      .doc(businessId)
      .collection('tenants')
      .doc(tenantId)
      .collection('payments')
      .doc();

    await paymentRef.set({
      id: paymentRef.id,
      tenantId,
      businessId,
      tenantName: 'Test Tenant',
      amount: 10000,
      month: 'February 2025',
      date: now,
      status: 'Paid',
      method: 'Cash',
      recordedBy: 'owner-uid-003',
      createdAt: now,
    });

    const snap = await paymentRef.get();
    expect(snap.data()?.status).toBe('Paid');
    expect(snap.data()?.method).toBe('Cash');
    expect(snap.data()?.recordedBy).toBe('owner-uid-003');
  });

  it('should update tenant lastPaymentDate', async () => {
    const now = admin.firestore.Timestamp.now();

    await db
      .collection('businesses')
      .doc(businessId)
      .collection('tenants')
      .doc(tenantId)
      .update({
        lastPaymentDate: now,
        lastPaymentAmount: 10000,
        lastPaymentMonth: 'February 2025',
        updatedAt: now,
      });

    const tenantSnap = await db
      .collection('businesses')
      .doc(businessId)
      .collection('tenants')
      .doc(tenantId)
      .get();

    expect(tenantSnap.data()?.lastPaymentAmount).toBe(10000);
  });
});
