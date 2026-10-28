"use strict";
// Pure helpers for recording and tracking tenant rent payments, kept free of
// firebase-admin so they can be unit tested. Used by razorpay.ts, billing.ts
// and rentPaymentNotifications.ts.
Object.defineProperty(exports, "__esModule", { value: true });
exports.razorpayPaymentDocId = razorpayPaymentDocId;
exports.buildRazorpayRentPayment = buildRazorpayRentPayment;
exports.callerMayPayInvoice = callerMayPayInvoice;
exports.ownerRentSubmissionNotification = ownerRentSubmissionNotification;
/**
 * The payment document id for a Razorpay payment. Razorpay sends both
 * payment_link.paid and payment.captured for one payment, sometimes at the
 * same moment; a deterministic id lets a transaction record it exactly once.
 */
function razorpayPaymentDocId(razorpayPaymentId) {
    return `rzp_${razorpayPaymentId}`;
}
/** The payment record for rent paid online and verified by Razorpay. */
function buildRazorpayRentPayment(i) {
    return {
        id: i.docId,
        tenantId: i.tenantId,
        businessId: i.businessId,
        tenantName: i.tenant.name || '',
        propertyId: i.tenant.propertyId || null,
        roomNumber: i.tenant.roomNumber || i.tenant.roomId || '',
        bedNumber: i.tenant.bedNumber || i.tenant.bedId || '',
        amount: i.amountInr,
        month: i.invoice.month || '',
        date: i.now,
        status: 'Paid',
        verification: 'verified',
        method: 'Razorpay',
        mode: 'razorpay',
        razorpayPaymentId: i.razorpayPaymentId,
        razorpayPaymentLinkId: i.paymentLinkId,
        rentInvoiceId: i.rentInvoiceId,
        submittedBy: 'system',
        recordedBy: 'razorpay_webhook',
        createdAt: i.now,
    };
}
/** Who may ask for a payment link for a tenant's invoice. */
function callerMayPayInvoice(c) {
    return c.isBusinessMember || (!!c.callerTenantId && c.callerTenantId === c.invoiceTenantId);
}
const inr = (n) => `₹${Number(n || 0).toLocaleString('en-IN')}`;
/** The in-app notification an owner gets when a tenant reports a payment. */
function ownerRentSubmissionNotification(businessId, tenantId, propertyId, payment) {
    const who = payment.tenantName || 'A tenant';
    const how = String(payment.method || '').toLowerCase() === 'cash'
        ? 'in cash'
        : `by ${payment.method || 'UPI'}${payment.transactionId ? ` (ref ${payment.transactionId})` : ''}`;
    return {
        businessId,
        type: 'payment',
        title: 'Rent payment to confirm',
        message: `${who} says they paid ${inr(payment.amount)} for ${payment.month || 'rent'} ${how}. Check and confirm.`,
        tenantId,
        tenantName: payment.tenantName || null,
        propertyId: propertyId || null,
        read: false,
    };
}
//# sourceMappingURL=paymentTrackingLogic.js.map