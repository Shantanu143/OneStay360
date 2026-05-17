export type BillingStatus = 'paid' | 'due' | 'grace' | 'past_due' | 'suspended';
export type InvoiceStatus = 'draft' | 'issued' | 'paid' | 'failed' | 'void';

// Tenant rent invoice types
export type RentInvoiceStatus = 'unpaid' | 'paid' | 'overdue';
export type PaymentVerification = 'verified' | 'unverified';
export type PaymentMode = 'razorpay' | 'upi' | 'cash';
