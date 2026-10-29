// Domain model shared by every screen. Field names follow the Firestore
// documents the Flutter apps and Cloud Functions read and write (see
// CLAUDE.md, "Firestore layout"), so a backend can map them one to one.

export type BusinessRole = "owner" | "manager" | "staff";
export type AccountKind = "business" | "tenant";

export interface Account {
  uid: string;
  kind: AccountKind;
  name: string;
  email: string;
  phone: string;
  /** Business accounts: the business they belong to and their role in it. */
  businessId?: string;
  role?: BusinessRole;
  /** Tenant accounts: the global tenant id (TEN0000001) once they have a stay. */
  tenantId?: string;
  favorites: string[];
  createdAt: number;
}

export type KycStatus = "not_started" | "submitted" | "verified";

export interface Business {
  id: string;
  name: string;
  ownerUid: string;
  phone: string;
  email: string;
  city: string;
  address: string;
  upiId?: string;
  /** Razorpay online collection for rent (settings/razorpay.paymentsEnabled). */
  onlinePaymentsEnabled: boolean;
  kycStatus: KycStatus;
  kyc?: { legalName: string; pan: string; gstin?: string; aadhaarLast4: string; submittedAt: number };
  createdAt: number;
}

export interface Bed {
  number: string;
  /** Business tenant id when occupied. */
  tenantId?: string | null;
}

export interface Room {
  id: string;
  number: string;
  floor: number;
  sharing: number;
  ac: boolean;
  attachedBath: boolean;
  rentPerBed: number;
  beds: Bed[];
}

export type Gender = "male" | "female" | "coed";
export type BillingStatus = "paid" | "payment_due" | "grace" | "past_due" | "suspended";

export interface Property {
  id: string;
  businessId: string;
  businessName: string;
  businessPhone: string;
  name: string;
  address: string;
  city: string;
  pincode: string;
  description: string;
  landmarks: string;
  mapsLink: string;
  gender: Gender;
  amenities: string[];
  food: { included: boolean; meals: string[]; monthlyDeduction: number };
  rules: { noticeDays: number; lockInMonths: number; gateClosesAt: string; visitorsAllowed: boolean; smokingAllowed: boolean };
  pricing: { deposit: number; maintenance: number };
  rooms: Room[];
  status: "active" | "inactive";
  billingStatus: BillingStatus;
  pricePerBed: number;
  nextBillingDate: number;
  coverHue: number;
  rating: number;
  createdAt: number;
  updatedAt: number;
}

export interface Tenant {
  id: string;
  businessId: string;
  propertyId: string;
  propertyName: string;
  roomNumber: string;
  bedNumber: string;
  name: string;
  phone: string;
  email: string;
  gender: "male" | "female" | "other";
  /** Auth uid once the tenant has the app/web account linked. */
  uid?: string;
  monthlyRent: number;
  deposit: number;
  maintenance: number;
  billingDay: number;
  moveIn: number;
  moveOut?: number;
  status: "active" | "vacated";
  emergencyContact?: string;
  occupation?: string;
  createdAt: number;
}

export type InvoiceStatus = "unpaid" | "overdue" | "paid";

export interface RentInvoice {
  id: string;
  businessId: string;
  tenantId: string;
  tenantName: string;
  propertyId: string;
  amount: number;
  /** "March 2026" — the label submitRentPayment matches on. */
  month: string;
  /** "2026-03" */
  periodMonth: string;
  dueDate: number;
  status: InvoiceStatus;
  paidAt?: number;
}

export type PaymentMethodLabel = "UPI" | "Cash" | "Online" | "Bank Transfer" | "Cheque";
export type PaymentStatus = "pending" | "paid" | "rejected";

export interface Payment {
  id: string;
  businessId: string;
  tenantId: string;
  tenantName: string;
  propertyId: string;
  propertyName: string;
  amount: number;
  month: string;
  method: PaymentMethodLabel;
  reference?: string;
  note?: string;
  status: PaymentStatus;
  rejectionReason?: string;
  invoiceId?: string;
  source: "tenant" | "owner" | "gateway";
  createdAt: number;
  verifiedAt?: number;
}

export type EnrollmentStatus = "pending" | "approved" | "bill_sent" | "payment_submitted" | "confirmed" | "rejected";

export interface EnrollmentRequest {
  id: string;
  tenantUid: string;
  tenantName: string;
  tenantPhone: string;
  businessId: string;
  propertyId: string;
  propertyName: string;
  moveIn: number;
  sharing: string;
  notes: string;
  status: EnrollmentStatus;
  roomNumber?: string;
  bedNumber?: string;
  monthlyRent?: number;
  proratedRent?: number;
  deposit?: number;
  maintenance?: number;
  total?: number;
  paymentMode?: "upi" | "bank" | "cash";
  ownerUpiId?: string;
  bank?: { bankName: string; accountNumber: string; ifsc: string; holder: string };
  transactionId?: string;
  paymentRejectionReason?: string;
  rejectionReason?: string;
  tenantId?: string;
  createdAt: number;
  updatedAt: number;
}

export interface TenantInvitation {
  id: string;
  businessId: string;
  businessName: string;
  propertyId: string;
  propertyName: string;
  roomNumber: string;
  bedNumber: string;
  tenantName: string;
  tenantPhone: string;
  tenantEmail: string;
  gender: "male" | "female" | "other";
  monthlyRent: number;
  deposit: number;
  maintenance: number;
  proratedRent: number;
  billingDay: number;
  noticeDays: number;
  lockInMonths: number;
  moveIn: number;
  status: "pending" | "accepted" | "rejected" | "cancelled";
  reason?: string;
  tenantId?: string;
  createdAt: number;
}

export interface Member {
  id: string;
  businessId: string;
  uid?: string;
  name: string;
  phone: string;
  email: string;
  role: BusinessRole;
  status: "active" | "invited";
  /** Properties a manager/staff member may open. Owners see everything. */
  propertyIds: string[];
  invitedAt: number;
  joinedAt?: number;
}

export type MaintenanceCategory = "plumbing" | "electrical" | "furniture" | "cleaning" | "appliance" | "internet" | "other";
export type MaintenanceStatus = "open" | "in_progress" | "resolved" | "cancelled";

export interface MaintenanceRequest {
  id: string;
  tenantUid: string;
  tenantId?: string;
  tenantName: string;
  tenantPhone: string;
  businessId: string;
  propertyId: string;
  propertyName: string;
  roomNumber: string;
  bedNumber: string;
  category: MaintenanceCategory;
  title: string;
  description: string;
  urgent: boolean;
  status: MaintenanceStatus;
  ownerNote?: string;
  createdAt: number;
  updatedAt: number;
}

export type PinCategory = "social" | "food" | "lost_found" | "ride" | "sell" | "alert";

export interface PinNote {
  id: string;
  propertyId: string;
  authorUid: string;
  authorName: string;
  category: PinCategory;
  content: string;
  createdAt: number;
  expiresAt: number;
}

export interface PayoutMethod {
  id: string;
  businessId: string;
  type: "upi" | "bank";
  label: string;
  upiId?: string;
  bankName?: string;
  accountNumber?: string;
  ifsc?: string;
  holder?: string;
  preferred: boolean;
  active: boolean;
  createdAt: number;
}

export interface PlatformInvoice {
  id: string;
  businessId: string;
  propertyId: string;
  propertyName: string;
  beds: number;
  pricePerBed: number;
  amount: number;
  discount: number;
  promoCode?: string;
  periodStart: number;
  periodEnd: number;
  status: "paid" | "due";
  paidAt?: number;
  reference?: string;
}

export interface CheckoutQuote {
  propertyId: string;
  beds: number;
  pricePerBed: number;
  baseAmount: number;
  discount: number;
  gst: number;
  finalAmount: number;
  promo?: { code: string; percent: number };
  periodStart: number;
  periodEnd: number;
}

export interface AppNotification {
  id: string;
  /** Recipient account uid. */
  uid: string;
  title: string;
  body: string;
  kind: "request" | "payment" | "maintenance" | "invitation" | "billing" | "team" | "general";
  href?: string;
  read: boolean;
  createdAt: number;
}

export interface Activity {
  id: string;
  businessId: string;
  text: string;
  kind: "tenant" | "payment" | "property" | "request" | "maintenance" | "team" | "billing";
  at: number;
}

/** A tenant's current stay, joined from the business tenant record. */
export interface Stay {
  tenant: Tenant;
  property: Property;
  room?: Room;
}
