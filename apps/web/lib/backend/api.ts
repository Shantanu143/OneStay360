// What the web screens ask of the backend. Each method maps to a Firestore
// path or a callable Cloud Function used by the Flutter apps (named in the
// comments), so a Firebase implementation can sit behind the same contract.
import type {
  Account,
  Activity,
  AppNotification,
  Business,
  BusinessRole,
  CheckoutQuote,
  EnrollmentRequest,
  Gender,
  MaintenanceCategory,
  MaintenanceRequest,
  MaintenanceStatus,
  Member,
  Payment,
  PaymentMethodLabel,
  PayoutMethod,
  PinCategory,
  PinNote,
  PlatformInvoice,
  Property,
  RentInvoice,
  Room,
  Stay,
  Tenant,
  TenantInvitation,
} from "../types";

/** A failure with a message fit to show as it is. */
export class BackendError extends Error {}

export interface SignUpInput {
  kind: "business" | "tenant";
  name: string;
  email: string;
  phone: string;
  password: string;
}

export interface PropertyDraft {
  name: string;
  address: string;
  city: string;
  pincode: string;
  description: string;
  landmarks: string;
  mapsLink: string;
  gender: Gender;
  amenities: string[];
  food: Property["food"];
  rules: Property["rules"];
  pricing: Property["pricing"];
  rooms: Omit<Room, "id">[];
}

export interface TenantInviteInput {
  propertyId: string;
  roomNumber: string;
  bedNumber: string;
  tenantName: string;
  tenantPhone: string;
  tenantEmail: string;
  gender: "male" | "female" | "other";
  monthlyRent: number;
  deposit: number;
  maintenance: number;
  billingDay: number;
  moveIn: number;
  noticeDays: number;
  lockInMonths: number;
  /** true: create the tenant right away (tenant has no app); false: send an invitation to accept. */
  direct: boolean;
}

export interface PlacementInput {
  roomNumber: string;
  bedNumber: string;
  monthlyRent: number;
  deposit: number;
  maintenance: number;
  moveIn: number;
}

export interface BillInput extends PlacementInput {
  paymentMode: "upi" | "bank" | "cash";
  methodId?: string;
}

export interface RecordPaymentInput {
  tenantId: string;
  amount: number;
  month: string;
  method: PaymentMethodLabel;
  reference?: string;
  note?: string;
}

export interface RentSubmissionInput {
  amount: number;
  month: string;
  mode: "UPI" | "Cash";
  reference?: string;
  invoiceId?: string;
}

export interface EnrollmentDraft {
  propertyId: string;
  name: string;
  phone: string;
  moveIn: number;
  sharing: string;
  notes: string;
}

export interface MaintenanceDraft {
  category: MaintenanceCategory;
  title: string;
  description: string;
  urgent: boolean;
}

export interface MemberInviteInput {
  name: string;
  phone: string;
  email: string;
  role: Exclude<BusinessRole, "owner">;
  propertyIds: string[];
}

export interface Backend {
  readonly mode: "demo" | "firebase";

  /** Calls [listener] after any change that may affect what screens show. */
  subscribe(listener: () => void): () => void;

  // ── Auth ─────────────────────────────────────────────────
  currentAccount(): Account | null;
  ready(): Promise<void>;
  signIn(email: string, password: string): Promise<Account>;
  signUp(input: SignUpInput): Promise<Account>;
  signOut(): Promise<void>;
  updateAccount(patch: Partial<Pick<Account, "name" | "phone">>): Promise<void>;
  resetDemo?(): Promise<void>;

  // ── Business: setup, profile, KYC ────────────────────────
  /** create_business_service: first business for an owner account. */
  createBusiness(input: { name: string; phone: string; city: string; address: string }): Promise<Business>;
  getBusiness(): Promise<Business | null>;
  updateBusiness(patch: Partial<Pick<Business, "name" | "phone" | "email" | "city" | "address" | "upiId">>): Promise<void>;
  submitKyc(kyc: { legalName: string; pan: string; gstin?: string; aadhaarLast4: string }): Promise<void>;

  /** Team invites addressed to the signed-in business account (acceptBusinessInvitation). */
  listMyTeamInvites(): Promise<Member[]>;
  acceptTeamInvite(memberId: string): Promise<void>;

  // ── Properties (owners create/edit; managers/staff see assigned ones) ─
  listProperties(): Promise<Property[]>;
  getProperty(id: string): Promise<Property | null>;
  createProperty(draft: PropertyDraft): Promise<Property>;
  /** updatePropertyDetails callable. */
  updateProperty(id: string, draft: PropertyDraft): Promise<void>;
  setPropertyStatus(id: string, status: Property["status"]): Promise<void>;

  // ── Tenants ──────────────────────────────────────────────
  listTenants(filter?: { propertyId?: string; status?: Tenant["status"] }): Promise<Tenant[]>;
  getTenant(id: string): Promise<Tenant | null>;
  updateTenant(id: string, patch: Partial<Pick<Tenant, "name" | "phone" | "email" | "monthlyRent" | "billingDay" | "emergencyContact" | "occupation">>): Promise<void>;
  /** createTenantInvitation callable, or a direct tenant record (onTenantCreated). */
  addTenant(input: TenantInviteInput): Promise<{ invitationId?: string; tenantId?: string }>;
  listTenantInvitations(): Promise<TenantInvitation[]>;
  cancelTenantInvitation(id: string): Promise<void>;
  /** vacateTenant callable. */
  vacateTenant(id: string, moveOut: number): Promise<void>;

  // ── Enrollment requests (owner side) ─────────────────────
  listRequests(): Promise<EnrollmentRequest[]>;
  approveRequest(id: string, placement: PlacementInput): Promise<void>;
  sendBill(id: string, bill: BillInput): Promise<void>;
  confirmRequestPayment(id: string): Promise<void>;
  rejectRequestPayment(id: string, reason: string): Promise<void>;
  rejectRequest(id: string, reason: string): Promise<void>;

  // ── Rent ─────────────────────────────────────────────────
  listInvoices(filter?: { tenantId?: string }): Promise<RentInvoice[]>;
  /** triggerRentInvoiceGeneration callable. Returns how many invoices were created. */
  generateInvoices(): Promise<number>;
  listPayments(filter?: { status?: Payment["status"]; tenantId?: string }): Promise<Payment[]>;
  /** verifyRentPayment callable. */
  verifyPayment(id: string, action: "approve" | "reject", reason?: string): Promise<void>;
  /** recordPayment callable. */
  recordPayment(input: RecordPaymentInput): Promise<void>;

  // ── Maintenance (owner side) ─────────────────────────────
  listMaintenance(): Promise<MaintenanceRequest[]>;
  updateMaintenance(id: string, status: MaintenanceStatus, note?: string): Promise<void>;

  // ── Team ─────────────────────────────────────────────────
  listMembers(): Promise<Member[]>;
  /** createBusinessInvitation callable. */
  inviteMember(input: MemberInviteInput): Promise<void>;
  /** updateMemberPropertyAccess callable. */
  updateMember(id: string, role: Exclude<BusinessRole, "owner">, propertyIds: string[]): Promise<void>;
  removeMember(id: string): Promise<void>;

  // ── Collections setup ────────────────────────────────────
  listPayoutMethods(): Promise<PayoutMethod[]>;
  savePayoutMethod(method: Omit<PayoutMethod, "id" | "businessId" | "createdAt"> & { id?: string }): Promise<void>;
  deletePayoutMethod(id: string): Promise<void>;
  setOnlinePayments(enabled: boolean): Promise<void>;

  // ── Platform billing (createCheckoutQuote / createActivationOrder / confirmActivationPayment) ─
  listPlatformInvoices(): Promise<PlatformInvoice[]>;
  checkoutQuote(propertyId: string, promoCode?: string): Promise<CheckoutQuote>;
  payActivation(propertyId: string, promoCode?: string): Promise<void>;

  listActivity(): Promise<Activity[]>;

  // ── Tenant side ──────────────────────────────────────────
  getStay(): Promise<Stay | null>;
  listMyInvoices(): Promise<RentInvoice[]>;
  listMyPayments(): Promise<Payment[]>;
  paymentSettings(businessId: string): Promise<{ onlineEnabled: boolean; upiId?: string }>;
  /** createPaymentLink + Razorpay checkout + razorpayPaymentWebhook. */
  payOnline(invoiceId: string): Promise<void>;
  /** submitRentPayment callable. */
  submitRentPayment(input: RentSubmissionInput): Promise<void>;

  /** properties_by_city index. */
  explore(filter?: { city?: string; query?: string; gender?: Gender | "any" }): Promise<Property[]>;
  getPublicProperty(id: string): Promise<Property | null>;
  setFavorite(propertyId: string, favorite: boolean): Promise<void>;

  /** submitEnrollmentRequest callable. */
  submitEnrollment(draft: EnrollmentDraft): Promise<string>;
  listMyRequests(): Promise<EnrollmentRequest[]>;
  payBill(requestId: string, reference: string): Promise<void>;
  withdrawRequest(requestId: string): Promise<void>;

  /** listMyTenantInvitations / approveInvitation / rejectTenantInvitation. */
  listMyInvitations(): Promise<TenantInvitation[]>;
  acceptInvitation(id: string): Promise<void>;
  declineInvitation(id: string, reason?: string): Promise<void>;

  listMyMaintenance(): Promise<MaintenanceRequest[]>;
  raiseMaintenance(draft: MaintenanceDraft): Promise<void>;
  cancelMaintenance(id: string): Promise<void>;

  listPins(): Promise<PinNote[]>;
  addPin(category: PinCategory, content: string): Promise<void>;
  deletePin(id: string): Promise<void>;

  // ── Both ─────────────────────────────────────────────────
  listNotifications(): Promise<AppNotification[]>;
  markNotificationsRead(ids?: string[]): Promise<void>;
}
