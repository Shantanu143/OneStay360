import {
  buildRazorpayRentPayment,
  callerMayPayInvoice,
  ownerRentSubmissionNotification,
  razorpayPaymentDocId,
} from '../../paymentTrackingLogic';

describe('razorpayPaymentDocId', () => {
  it('is the same for every event about one payment, so it is recorded once', () => {
    expect(razorpayPaymentDocId('pay_ABC123')).toBe('rzp_pay_ABC123');
    expect(razorpayPaymentDocId('pay_ABC123')).toBe(razorpayPaymentDocId('pay_ABC123'));
  });
});

describe('buildRazorpayRentPayment', () => {
  it('records a verified online payment the owner and tenant both read', () => {
    const p = buildRazorpayRentPayment({
      docId: 'rzp_pay_1',
      businessId: 'BUS1',
      tenantId: 'TEN1',
      tenant: { name: 'Asha', roomNumber: '101', bedNumber: '2', propertyId: 'P1' },
      invoice: { month: 'March 2026' },
      rentInvoiceId: 'I1',
      razorpayPaymentId: 'pay_1',
      paymentLinkId: 'plink_1',
      amountInr: 9000,
      now: 'NOW',
    });
    expect(p).toEqual(expect.objectContaining({
      id: 'rzp_pay_1',
      tenantId: 'TEN1',
      tenantName: 'Asha',
      propertyId: 'P1',
      roomNumber: '101',
      amount: 9000,
      month: 'March 2026',
      date: 'NOW',
      status: 'Paid',
      method: 'Razorpay',
      rentInvoiceId: 'I1',
      razorpayPaymentId: 'pay_1',
      submittedBy: 'system',
    }));
  });
});

describe('callerMayPayInvoice', () => {
  it('lets the tenant pay their own invoice', () => {
    expect(callerMayPayInvoice({ callerTenantId: 'TEN1', invoiceTenantId: 'TEN1', isBusinessMember: false })).toBe(true);
  });
  it('lets the business team make a link for the tenant', () => {
    expect(callerMayPayInvoice({ callerTenantId: null, invoiceTenantId: 'TEN1', isBusinessMember: true })).toBe(true);
  });
  it('refuses anyone else', () => {
    expect(callerMayPayInvoice({ callerTenantId: 'TEN2', invoiceTenantId: 'TEN1', isBusinessMember: false })).toBe(false);
    expect(callerMayPayInvoice({ callerTenantId: null, invoiceTenantId: 'TEN1', isBusinessMember: false })).toBe(false);
  });
});

describe('ownerRentSubmissionNotification', () => {
  it('lands in the owner notifications as a payment to confirm', () => {
    const n = ownerRentSubmissionNotification('BUS1', 'TEN1', 'P1', {
      tenantName: 'Asha',
      amount: 9000,
      month: 'March 2026',
      method: 'UPI',
      transactionId: 'UTR1',
    });
    expect(n).toEqual(expect.objectContaining({
      businessId: 'BUS1',
      type: 'payment',
      tenantId: 'TEN1',
      tenantName: 'Asha',
      propertyId: 'P1',
      title: 'Rent payment to confirm',
      read: false,
    }));
    expect(n.message).toBe('Asha says they paid ₹9,000 for March 2026 by UPI (ref UTR1). Check and confirm.');
  });

  it('reads well for cash without a reference', () => {
    const n = ownerRentSubmissionNotification('BUS1', 'TEN1', null, { amount: 500, month: 'May 2026', method: 'Cash' });
    expect(n.message).toBe('A tenant says they paid ₹500 for May 2026 in cash. Check and confirm.');
    expect(n.propertyId).toBeNull();
  });
});
