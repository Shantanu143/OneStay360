// Demo backend: the whole platform running in the browser over a seeded
// workspace kept in localStorage. Each mutation reproduces what the matching
// Cloud Function or trigger does server-side (named in comments), so the
// owner and tenant dashboards drive the same lifecycles as the mobile apps:
// a join request moving pending → bill_sent → payment_submitted → confirmed
// creates the tenant and occupies the bed, a verified UPI payment closes its
// invoice, and so on. Sign in as several demo accounts in one browser to see
// both sides of a flow.
import { BackendError } from "../api";
import type {
  Backend,
  BillInput,
  EnrollmentDraft,
  MaintenanceDraft,
  MemberInviteInput,
  PlacementInput,
  PropertyDraft,
  RecordPaymentInput,
  RentSubmissionInput,
  SignUpInput,
  TenantInviteInput,
} from "../api";
import type {
  Account,
  Activity,
  AppNotification,
  BusinessRole,
  CheckoutQuote,
  MaintenanceStatus,
  Payment,
  PinCategory,
  Property,
  RentInvoice,
  Tenant,
} from "../../types";
import { DAY, money, monthLabel, periodOf, phoneDigits, proratedRent } from "../../format";
import { buildSeed, hashPassword, STATE_VERSION, type DemoState, type DemoUser } from "./seed";

const STORE_KEY = "onestay360.demo.v1";
const SESSION_KEY = "onestay360.demo.session";
const LATENCY = 120;

const clone = <T,>(v: T): T => JSON.parse(JSON.stringify(v)) as T;
const uid = (p: string) => `${p}-${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}`;
const wait = () => new Promise((r) => setTimeout(r, LATENCY));

function strip(u: DemoUser): Account {
  const { passwordHash: _ignored, ...account } = u;
  return clone(account);
}

export class DemoBackend implements Backend {
  readonly mode = "demo" as const;
  private state!: DemoState;
  private sessionUid: string | null = null;
  private listeners = new Set<() => void>();
  private loaded = false;

  constructor() {
    if (typeof window !== "undefined") {
      this.load();
      window.addEventListener("storage", (e) => {
        if (e.key === STORE_KEY || e.key === SESSION_KEY) {
          this.load();
          this.emit();
        }
      });
    }
  }

  // ── Storage ──────────────────────────────────────────────

  private load() {
    let state: DemoState | null = null;
    try {
      const raw = localStorage.getItem(STORE_KEY);
      if (raw) state = JSON.parse(raw) as DemoState;
    } catch {
      state = null;
    }
    if (!state || state.version !== STATE_VERSION) {
      state = buildSeed();
      this.persist(state);
    }
    this.state = state;
    try {
      this.sessionUid = localStorage.getItem(SESSION_KEY);
    } catch {
      this.sessionUid = null;
    }
    this.refreshOverdue();
    this.loaded = true;
  }

  private persist(state = this.state) {
    try {
      localStorage.setItem(STORE_KEY, JSON.stringify(state));
    } catch {
      // Private mode or quota: keep working in memory.
    }
  }

  private emit() {
    for (const l of this.listeners) l();
  }

  private async commit<T>(fn: () => T): Promise<T> {
    await wait();
    const out = fn();
    this.persist();
    this.emit();
    return out;
  }

  subscribe(listener: () => void) {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  async ready() {
    if (!this.loaded && typeof window !== "undefined") this.load();
  }

  async resetDemo() {
    this.state = buildSeed();
    this.persist();
    this.setSession(null);
    this.emit();
  }

  /** markOverdueInvoices scheduler: unpaid invoices past their due date. */
  private refreshOverdue() {
    const now = Date.now();
    for (const inv of this.state.invoices) {
      if (inv.status === "unpaid" && inv.dueDate < now - DAY) inv.status = "overdue";
    }
  }

  // ── Session helpers ──────────────────────────────────────

  private setSession(uidValue: string | null) {
    this.sessionUid = uidValue;
    try {
      if (uidValue) localStorage.setItem(SESSION_KEY, uidValue);
      else localStorage.removeItem(SESSION_KEY);
    } catch {
      // ignore
    }
  }

  private me(): DemoUser {
    const u = this.state.users.find((x) => x.uid === this.sessionUid);
    if (!u) throw new BackendError("Your session expired. Sign in again.");
    return u;
  }

  private bizId(): string {
    const u = this.me();
    if (u.kind !== "business" || !u.businessId) throw new BackendError("Set up your business first.");
    return u.businessId;
  }

  private role(): BusinessRole {
    return this.me().role ?? "staff";
  }

  private requireOwner(what: string) {
    if (this.role() !== "owner") throw new BackendError(`Only the owner can ${what}.`);
  }

  /** Property ids the signed-in member may open (per-property access docs). */
  private visiblePropertyIds(): Set<string> {
    const bid = this.bizId();
    const u = this.me();
    const all = this.state.properties.filter((p) => p.businessId === bid).map((p) => p.id);
    if (u.role === "owner") return new Set(all);
    const member = this.state.members.find((m) => m.businessId === bid && m.uid === u.uid);
    return new Set((member?.propertyIds ?? []).filter((id) => all.includes(id)));
  }

  private property(id: string): Property {
    const p = this.state.properties.find((x) => x.id === id);
    if (!p) throw new BackendError("Property not found.");
    return p;
  }

  private assertPropertyAccess(propertyId: string) {
    if (!this.visiblePropertyIds().has(propertyId)) throw new BackendError("You don't have access to this property.");
  }

  private notify(uids: (string | undefined)[], n: Omit<AppNotification, "id" | "uid" | "read" | "createdAt">) {
    for (const u of new Set(uids.filter(Boolean) as string[])) {
      this.state.notifications.unshift({ ...n, id: uid("N"), uid: u, read: false, createdAt: Date.now() });
    }
  }

  /** Active members of a business who can see the property (owners always). */
  private staffFor(businessId: string, propertyId?: string) {
    return this.state.members
      .filter((m) => m.businessId === businessId && m.status === "active" && m.uid)
      .filter((m) => m.role === "owner" || !propertyId || m.propertyIds.includes(propertyId))
      .map((m) => m.uid);
  }

  private log(businessId: string, kind: Activity["kind"], text: string) {
    this.state.activity.unshift({ id: uid("A"), businessId, kind, text, at: Date.now() });
    this.state.activity = this.state.activity.slice(0, 200);
  }

  private nextTenantId() {
    this.state.counters.tenant += 1;
    return `TEN${String(this.state.counters.tenant).padStart(7, "0")}`;
  }

  private bedHolder(p: Property, roomNumber: string, bedNumber: string) {
    const room = p.rooms.find((r) => r.number === roomNumber);
    const bed = room?.beds.find((b) => b.number === bedNumber);
    if (!room || !bed) throw new BackendError(`Room ${roomNumber} · Bed ${bedNumber} doesn't exist.`);
    return bed;
  }

  /** Beds held by open requests or pending invitations (not yet tenants). */
  private heldBeds(propertyId: string, exceptId?: string) {
    const held = new Set<string>();
    for (const r of this.state.requests) {
      if (r.propertyId === propertyId && r.id !== exceptId && ["approved", "bill_sent", "payment_submitted"].includes(r.status) && r.roomNumber && r.bedNumber) {
        held.add(`${r.roomNumber}/${r.bedNumber}`);
      }
    }
    for (const i of this.state.invitations) {
      if (i.propertyId === propertyId && i.id !== exceptId && i.status === "pending") held.add(`${i.roomNumber}/${i.bedNumber}`);
    }
    return held;
  }

  private assertBedFree(p: Property, roomNumber: string, bedNumber: string, exceptId?: string) {
    const bed = this.bedHolder(p, roomNumber, bedNumber);
    if (bed.tenantId) throw new BackendError(`Room ${roomNumber} · Bed ${bedNumber} is already occupied.`);
    if (this.heldBeds(p.id, exceptId).has(`${roomNumber}/${bedNumber}`)) {
      throw new BackendError(`Room ${roomNumber} · Bed ${bedNumber} is held for another tenant.`);
    }
  }

  /** onTenantCreated / approveInvitation: the business tenant, the bed and the first invoice. */
  private createTenant(input: {
    businessId: string;
    property: Property;
    roomNumber: string;
    bedNumber: string;
    name: string;
    phone: string;
    email: string;
    gender: Tenant["gender"];
    monthlyRent: number;
    deposit: number;
    maintenance: number;
    billingDay: number;
    moveIn: number;
    uid?: string;
    firstMonthPaid?: boolean;
  }): Tenant {
    const tenant: Tenant = {
      id: this.nextTenantId(),
      businessId: input.businessId,
      propertyId: input.property.id,
      propertyName: input.property.name,
      roomNumber: input.roomNumber,
      bedNumber: input.bedNumber,
      name: input.name,
      phone: input.phone,
      email: input.email,
      gender: input.gender,
      uid: input.uid,
      monthlyRent: input.monthlyRent,
      deposit: input.deposit,
      maintenance: input.maintenance,
      billingDay: input.billingDay,
      moveIn: input.moveIn,
      status: "active",
      createdAt: Date.now(),
    };
    // onTenantUserCreated: link an existing tenant account with the same phone.
    if (!tenant.uid) {
      const match = this.state.users.find((u) => u.kind === "tenant" && phoneDigits(u.phone) === phoneDigits(tenant.phone) && !u.tenantId);
      if (match) tenant.uid = match.uid;
    }
    this.state.tenants.push(tenant);
    this.bedHolder(input.property, input.roomNumber, input.bedNumber).tenantId = tenant.id;
    if (tenant.uid) {
      const user = this.state.users.find((u) => u.uid === tenant.uid);
      if (user) user.tenantId = tenant.id;
    }
    const d = new Date(Math.max(input.moveIn, Date.now()));
    const inv: RentInvoice = {
      id: `${tenant.id}_${periodOf(d)}`,
      businessId: tenant.businessId,
      tenantId: tenant.id,
      tenantName: tenant.name,
      propertyId: tenant.propertyId,
      amount: tenant.monthlyRent,
      month: monthLabel(d),
      periodMonth: periodOf(d),
      dueDate: new Date(d.getFullYear(), d.getMonth(), tenant.billingDay).getTime(),
      status: input.firstMonthPaid ? "paid" : "unpaid",
      paidAt: input.firstMonthPaid ? Date.now() : undefined,
    };
    this.state.invoices.push(inv);
    return tenant;
  }

  // ── Auth ─────────────────────────────────────────────────

  currentAccount(): Account | null {
    if (!this.loaded) return null;
    const u = this.state.users.find((x) => x.uid === this.sessionUid);
    return u ? strip(u) : null;
  }

  async signIn(email: string, password: string) {
    await wait();
    const u = this.state.users.find((x) => x.email.toLowerCase() === email.trim().toLowerCase());
    if (!u || u.passwordHash !== hashPassword(u.email, password)) throw new BackendError("Email or password is incorrect.");
    this.setSession(u.uid);
    this.emit();
    return strip(u);
  }

  async signUp(input: SignUpInput) {
    const email = input.email.trim().toLowerCase();
    if (!/^\S+@\S+\.\S+$/.test(email)) throw new BackendError("Enter a valid email address.");
    if (input.password.length < 6) throw new BackendError("Use at least 6 characters for your password.");
    if (phoneDigits(input.phone).length !== 10) throw new BackendError("Enter a 10-digit mobile number.");
    if (this.state.users.some((u) => u.email.toLowerCase() === email)) throw new BackendError("An account with this email already exists. Sign in instead.");
    return this.commit(() => {
      const user: DemoUser = {
        uid: uid("u"),
        kind: input.kind,
        name: input.name.trim(),
        email,
        phone: phoneDigits(input.phone),
        favorites: [],
        createdAt: Date.now(),
        passwordHash: hashPassword(email, input.password),
      };
      this.state.users.push(user);
      // onTenantUserCreated: a tenant record added by an owner with this phone is linked.
      if (user.kind === "tenant") {
        const t = this.state.tenants.find((x) => x.status === "active" && !x.uid && phoneDigits(x.phone) === user.phone);
        if (t) {
          t.uid = user.uid;
          user.tenantId = t.id;
        }
      }
      this.setSession(user.uid);
      return strip(user);
    });
  }

  async signOut() {
    this.setSession(null);
    this.emit();
  }

  async updateAccount(patch: Partial<Pick<Account, "name" | "phone">>) {
    return this.commit(() => {
      const u = this.me();
      if (patch.name !== undefined) u.name = patch.name.trim();
      if (patch.phone !== undefined) u.phone = phoneDigits(patch.phone);
    });
  }

  // ── Business ─────────────────────────────────────────────

  async createBusiness(input: { name: string; phone: string; city: string; address: string }) {
    const u = this.me();
    if (u.kind !== "business") throw new BackendError("Only business accounts can create a business.");
    if (u.businessId) throw new BackendError("You already have a business.");
    if (!input.name.trim()) throw new BackendError("Give your business a name.");
    return this.commit(() => {
      this.state.counters.business += 1;
      const id = `BUS${String(this.state.counters.business).padStart(7, "0")}`;
      const business = {
        id,
        name: input.name.trim(),
        ownerUid: u.uid,
        phone: phoneDigits(input.phone) || u.phone,
        email: u.email,
        city: input.city.trim(),
        address: input.address.trim(),
        onlinePaymentsEnabled: false,
        kycStatus: "not_started" as const,
        createdAt: Date.now(),
      };
      this.state.businesses.push(business);
      this.state.members.push({ id: uid("MEM"), businessId: id, uid: u.uid, name: u.name, phone: u.phone, email: u.email, role: "owner", status: "active", propertyIds: [], invitedAt: Date.now(), joinedAt: Date.now() });
      u.businessId = id;
      u.role = "owner";
      this.log(id, "team", `${u.name} created ${business.name}`);
      return clone(business);
    });
  }

  async getBusiness() {
    await wait();
    const u = this.me();
    if (!u.businessId) return null;
    return clone(this.state.businesses.find((b) => b.id === u.businessId) ?? null);
  }

  async updateBusiness(patch: Parameters<Backend["updateBusiness"]>[0]) {
    this.requireOwner("edit business details");
    return this.commit(() => {
      const b = this.state.businesses.find((x) => x.id === this.bizId())!;
      Object.assign(b, patch);
      for (const p of this.state.properties.filter((x) => x.businessId === b.id)) {
        p.businessName = b.name;
        p.businessPhone = b.phone;
      }
    });
  }

  async submitKyc(kyc: { legalName: string; pan: string; gstin?: string; aadhaarLast4: string }) {
    this.requireOwner("submit KYC");
    if (!/^[A-Z]{5}[0-9]{4}[A-Z]$/.test(kyc.pan.toUpperCase())) throw new BackendError("PAN should look like ABCDE1234F.");
    if (!/^\d{4}$/.test(kyc.aadhaarLast4)) throw new BackendError("Enter the last 4 digits of the Aadhaar.");
    if (kyc.gstin && !/^[0-9A-Z]{15}$/.test(kyc.gstin.toUpperCase())) throw new BackendError("GSTIN has 15 characters.");
    return this.commit(() => {
      const b = this.state.businesses.find((x) => x.id === this.bizId())!;
      b.kyc = { ...kyc, pan: kyc.pan.toUpperCase(), gstin: kyc.gstin?.toUpperCase() || undefined, submittedAt: Date.now() };
      b.kycStatus = "submitted";
      this.log(b.id, "team", "KYC documents submitted for review");
    });
  }

  async listMyTeamInvites() {
    await wait();
    const u = this.me();
    return clone(
      this.state.members.filter(
        (m) => m.status === "invited" && (phoneDigits(m.phone) === phoneDigits(u.phone) || m.email.toLowerCase() === u.email.toLowerCase()),
      ),
    );
  }

  async acceptTeamInvite(memberId: string) {
    const u = this.me();
    if (u.kind !== "business") throw new BackendError("Use a business account to join a team.");
    if (u.businessId) throw new BackendError("This account already belongs to a business.");
    return this.commit(() => {
      const m = this.state.members.find((x) => x.id === memberId && x.status === "invited");
      if (!m) throw new BackendError("This invitation is no longer valid.");
      m.status = "active";
      m.uid = u.uid;
      m.name = u.name;
      m.joinedAt = Date.now();
      u.businessId = m.businessId;
      u.role = m.role;
      const owner = this.state.businesses.find((b) => b.id === m.businessId)?.ownerUid;
      this.notify([owner], { title: "Invitation accepted", body: `${u.name} joined as ${m.role}.`, kind: "team", href: "/dashboard/owner/team/" });
      this.log(m.businessId, "team", `${u.name} joined the team as ${m.role}`);
    });
  }

  // ── Properties ───────────────────────────────────────────

  async listProperties() {
    await wait();
    const visible = this.visiblePropertyIds();
    return clone(this.state.properties.filter((p) => visible.has(p.id)).sort((a, b) => a.createdAt - b.createdAt));
  }

  async getProperty(id: string) {
    await wait();
    if (!this.visiblePropertyIds().has(id)) return null;
    return clone(this.state.properties.find((p) => p.id === id) ?? null);
  }

  private validateDraft(d: PropertyDraft) {
    if (!d.name.trim()) throw new BackendError("Give the property a name.");
    if (!d.city.trim()) throw new BackendError("Choose the city.");
    if (!d.address.trim()) throw new BackendError("Add the street address.");
    if (d.rooms.length === 0) throw new BackendError("Add at least one room.");
    const seen = new Set<string>();
    for (const r of d.rooms) {
      if (!r.number.trim()) throw new BackendError("Every room needs a number.");
      if (seen.has(r.number.trim())) throw new BackendError(`Room ${r.number} is listed twice.`);
      seen.add(r.number.trim());
      if (r.sharing < 1 || r.sharing > 8) throw new BackendError(`Room ${r.number}: sharing must be 1 to 8.`);
      if (r.rentPerBed <= 0) throw new BackendError(`Room ${r.number}: set the rent per bed.`);
    }
  }

  async createProperty(d: PropertyDraft) {
    this.requireOwner("add properties");
    this.validateDraft(d);
    return this.commit(() => {
      const bid = this.bizId();
      const biz = this.state.businesses.find((b) => b.id === bid)!;
      const n = this.state.properties.filter((p) => p.businessId === bid).length + 1;
      let pid = `${bid}-P${String(n).padStart(2, "0")}`;
      while (this.state.properties.some((p) => p.id === pid)) pid += "x";
      const p: Property = {
        id: pid,
        businessId: bid,
        businessName: biz.name,
        businessPhone: biz.phone,
        ...clone(d),
        name: d.name.trim(),
        rooms: d.rooms.map((r) => ({ ...clone(r), id: `R${r.number.trim()}`, number: r.number.trim(), beds: Array.from({ length: r.sharing }, (_, i) => ({ number: String.fromCharCode(65 + i), tenantId: null })) })),
        status: "active",
        // A property goes live on Explore once its activation is paid.
        billingStatus: "payment_due",
        pricePerBed: 30,
        nextBillingDate: Date.now(),
        coverHue: Math.floor(Math.random() * 360),
        rating: 0,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      };
      this.state.properties.push(p);
      const owner = this.state.members.find((m) => m.businessId === bid && m.role === "owner");
      if (owner && !owner.propertyIds.includes(pid)) owner.propertyIds.push(pid);
      this.log(bid, "property", `Added ${p.name} with ${p.rooms.reduce((s, r) => s + r.sharing, 0)} beds`);
      return clone(p);
    });
  }

  async updateProperty(id: string, d: PropertyDraft) {
    this.requireOwner("edit properties");
    this.validateDraft(d);
    return this.commit(() => {
      const p = this.property(id);
      if (p.businessId !== this.bizId()) throw new BackendError("Property not found.");
      // updatePropertyDetails: occupied beds can't disappear from under a tenant.
      const rooms = d.rooms.map((r) => {
        const existing = p.rooms.find((x) => x.number === r.number.trim());
        const beds = Array.from({ length: r.sharing }, (_, i) => {
          const number = String.fromCharCode(65 + i);
          return { number, tenantId: existing?.beds.find((b) => b.number === number)?.tenantId ?? null };
        });
        const dropped = existing?.beds.filter((b) => b.tenantId && !beds.some((nb) => nb.number === b.number)) ?? [];
        if (dropped.length) throw new BackendError(`Room ${r.number}: bed ${dropped[0]!.number} is occupied. Vacate the tenant before reducing sharing.`);
        return { ...clone(r), id: existing?.id ?? `R${r.number.trim()}`, number: r.number.trim(), beds };
      });
      for (const old of p.rooms) {
        if (!rooms.some((r) => r.number === old.number) && old.beds.some((b) => b.tenantId)) {
          throw new BackendError(`Room ${old.number} has tenants. Vacate them before removing the room.`);
        }
      }
      Object.assign(p, clone(d), { rooms, name: d.name.trim(), updatedAt: Date.now() });
      for (const t of this.state.tenants.filter((x) => x.propertyId === id)) t.propertyName = p.name;
      this.log(p.businessId, "property", `Updated details of ${p.name}`);
    });
  }

  async setPropertyStatus(id: string, status: Property["status"]) {
    this.requireOwner("change property status");
    return this.commit(() => {
      const p = this.property(id);
      p.status = status;
      p.updatedAt = Date.now();
      this.log(p.businessId, "property", `${p.name} is now ${status === "active" ? "listed" : "hidden from Explore"}`);
    });
  }

  // ── Tenants ──────────────────────────────────────────────

  async listTenants(filter?: { propertyId?: string; status?: Tenant["status"] }) {
    await wait();
    const visible = this.visiblePropertyIds();
    return clone(
      this.state.tenants
        .filter((t) => visible.has(t.propertyId))
        .filter((t) => !filter?.propertyId || t.propertyId === filter.propertyId)
        .filter((t) => !filter?.status || t.status === filter.status)
        .sort((a, b) => b.createdAt - a.createdAt),
    );
  }

  async getTenant(id: string) {
    await wait();
    const t = this.state.tenants.find((x) => x.id === id);
    if (!t || !this.visiblePropertyIds().has(t.propertyId)) return null;
    return clone(t);
  }

  async updateTenant(id: string, patch: Parameters<Backend["updateTenant"]>[1]) {
    return this.commit(() => {
      const t = this.state.tenants.find((x) => x.id === id);
      if (!t) throw new BackendError("Tenant not found.");
      this.assertPropertyAccess(t.propertyId);
      if (this.role() === "staff") throw new BackendError("Staff can't edit tenant details.");
      Object.assign(t, patch);
      if (patch.name) {
        for (const inv of this.state.invoices.filter((i) => i.tenantId === id)) inv.tenantName = patch.name;
      }
    });
  }

  async addTenant(input: TenantInviteInput) {
    if (this.role() === "staff") throw new BackendError("Staff can't add tenants.");
    this.assertPropertyAccess(input.propertyId);
    if (!input.tenantName.trim()) throw new BackendError("Enter the tenant's name.");
    if (phoneDigits(input.tenantPhone).length !== 10) throw new BackendError("Enter the tenant's 10-digit mobile number.");
    if (input.monthlyRent <= 0) throw new BackendError("Set the monthly rent.");
    if (input.billingDay < 1 || input.billingDay > 28) throw new BackendError("Billing day must be between 1 and 28.");
    return this.commit(() => {
      const bid = this.bizId();
      const p = this.property(input.propertyId);
      this.assertBedFree(p, input.roomNumber, input.bedNumber);
      const biz = this.state.businesses.find((b) => b.id === bid)!;
      if (input.direct) {
        const t = this.createTenant({
          businessId: bid,
          property: p,
          roomNumber: input.roomNumber,
          bedNumber: input.bedNumber,
          name: input.tenantName.trim(),
          phone: phoneDigits(input.tenantPhone),
          email: input.tenantEmail.trim(),
          gender: input.gender,
          monthlyRent: input.monthlyRent,
          deposit: input.deposit,
          maintenance: input.maintenance,
          billingDay: input.billingDay,
          moveIn: input.moveIn,
        });
        this.log(bid, "tenant", `Added ${t.name} to ${p.name}, Room ${t.roomNumber} · Bed ${t.bedNumber}`);
        if (t.uid) this.notify([t.uid], { title: `Welcome to ${p.name}`, body: `Your stay in Room ${t.roomNumber} · Bed ${t.bedNumber} is set up.`, kind: "invitation", href: "/dashboard/tenant/stay/" });
        return { tenantId: t.id };
      }
      // createTenantInvitation
      const inv = {
        id: uid("INV"),
        businessId: bid,
        businessName: biz.name,
        propertyId: p.id,
        propertyName: p.name,
        roomNumber: input.roomNumber,
        bedNumber: input.bedNumber,
        tenantName: input.tenantName.trim(),
        tenantPhone: phoneDigits(input.tenantPhone),
        tenantEmail: input.tenantEmail.trim(),
        gender: input.gender,
        monthlyRent: input.monthlyRent,
        deposit: input.deposit,
        maintenance: input.maintenance,
        proratedRent: proratedRent(input.monthlyRent, input.moveIn, input.billingDay),
        billingDay: input.billingDay,
        noticeDays: input.noticeDays,
        lockInMonths: input.lockInMonths,
        moveIn: input.moveIn,
        status: "pending" as const,
        createdAt: Date.now(),
      };
      this.state.invitations.unshift(inv);
      const invitee = this.state.users.find((u) => u.kind === "tenant" && phoneDigits(u.phone) === inv.tenantPhone);
      this.notify([invitee?.uid], { title: `Invitation from ${biz.name}`, body: `${p.name} · Room ${inv.roomNumber} · Bed ${inv.bedNumber} at ${money(inv.monthlyRent)}/month.`, kind: "invitation", href: "/dashboard/tenant/invitations/" });
      this.log(bid, "tenant", `Invited ${inv.tenantName} to Room ${inv.roomNumber} · Bed ${inv.bedNumber}`);
      return { invitationId: inv.id };
    });
  }

  async listTenantInvitations() {
    await wait();
    const visible = this.visiblePropertyIds();
    return clone(this.state.invitations.filter((i) => visible.has(i.propertyId)).sort((a, b) => b.createdAt - a.createdAt));
  }

  async cancelTenantInvitation(id: string) {
    return this.commit(() => {
      const inv = this.state.invitations.find((x) => x.id === id);
      if (!inv || inv.status !== "pending") throw new BackendError("Only pending invitations can be cancelled.");
      this.assertPropertyAccess(inv.propertyId);
      inv.status = "cancelled";
      this.log(inv.businessId, "tenant", `Cancelled the invitation for ${inv.tenantName}`);
    });
  }

  async vacateTenant(id: string, moveOut: number) {
    if (this.role() !== "owner") throw new BackendError("Only the owner can vacate tenants.");
    return this.commit(() => {
      const t = this.state.tenants.find((x) => x.id === id);
      if (!t || t.status !== "active") throw new BackendError("This tenant isn't active.");
      const p = this.property(t.propertyId);
      const bed = p.rooms.find((r) => r.number === t.roomNumber)?.beds.find((b) => b.number === t.bedNumber);
      if (bed && bed.tenantId === t.id) bed.tenantId = null;
      t.status = "vacated";
      t.moveOut = moveOut;
      const u = this.state.users.find((x) => x.uid === t.uid);
      if (u && u.tenantId === t.id) u.tenantId = undefined;
      this.notify([t.uid], { title: "Stay ended", body: `Your stay at ${t.propertyName} was closed by the owner.`, kind: "general" });
      this.log(t.businessId, "tenant", `${t.name} vacated Room ${t.roomNumber} · Bed ${t.bedNumber}`);
    });
  }

  // ── Enrollment requests ──────────────────────────────────

  async listRequests() {
    await wait();
    const visible = this.visiblePropertyIds();
    return clone(this.state.requests.filter((r) => visible.has(r.propertyId)).sort((a, b) => b.updatedAt - a.updatedAt));
  }

  private request(id: string) {
    const r = this.state.requests.find((x) => x.id === id);
    if (!r) throw new BackendError("This request no longer exists.");
    this.assertPropertyAccess(r.propertyId);
    return r;
  }

  private applyPlacement(id: string, s: PlacementInput) {
    const r = this.request(id);
    const p = this.property(r.propertyId);
    this.assertBedFree(p, s.roomNumber, s.bedNumber, id);
    const prorated = proratedRent(s.monthlyRent, s.moveIn, new Date(s.moveIn).getDate());
    Object.assign(r, {
      roomNumber: s.roomNumber,
      bedNumber: s.bedNumber,
      monthlyRent: s.monthlyRent,
      deposit: s.deposit,
      maintenance: s.maintenance,
      proratedRent: prorated,
      moveIn: s.moveIn,
      total: s.monthlyRent + s.deposit + s.maintenance,
      updatedAt: Date.now(),
    });
    return r;
  }

  async approveRequest(id: string, s: PlacementInput) {
    if (this.role() === "staff") throw new BackendError("Staff can't approve requests.");
    return this.commit(() => {
      const r = this.applyPlacement(id, s);
      if (r.status !== "pending") throw new BackendError("Only pending requests can be approved.");
      r.status = "approved";
      this.notify([r.tenantUid], { title: "Request approved", body: `${r.propertyName} reserved Room ${r.roomNumber} · Bed ${r.bedNumber} for you. Your first bill is on its way.`, kind: "request", href: "/dashboard/tenant/requests/" });
      this.log(r.businessId, "request", `Approved ${r.tenantName} for Room ${r.roomNumber} · Bed ${r.bedNumber}`);
    });
  }

  async sendBill(id: string, bill: BillInput) {
    if (this.role() === "staff") throw new BackendError("Staff can't send bills.");
    return this.commit(() => {
      const r = this.applyPlacement(id, bill);
      if (!["pending", "approved", "bill_sent"].includes(r.status)) throw new BackendError("A bill can't be sent at this stage.");
      const bid = r.businessId;
      const biz = this.state.businesses.find((b) => b.id === bid)!;
      const method = bill.methodId ? this.state.payoutMethods.find((m) => m.id === bill.methodId) : undefined;
      r.status = "bill_sent";
      r.paymentMode = bill.paymentMode;
      r.paymentRejectionReason = undefined;
      r.ownerUpiId = bill.paymentMode === "upi" ? method?.upiId ?? biz.upiId : undefined;
      r.bank = bill.paymentMode === "bank" && method ? { bankName: method.bankName ?? "", accountNumber: method.accountNumber ?? "", ifsc: method.ifsc ?? "", holder: method.holder ?? "" } : undefined;
      if (bill.paymentMode === "upi" && !r.ownerUpiId) throw new BackendError("Add a UPI ID under Collections first.");
      if (bill.paymentMode === "bank" && !r.bank) throw new BackendError("Choose a bank account to receive the payment.");
      this.notify([r.tenantUid], { title: "Your first bill is ready", body: `${money(r.total ?? 0)} for ${r.propertyName}. Pay to confirm your bed.`, kind: "request", href: "/dashboard/tenant/requests/" });
      this.log(bid, "request", `Sent a ${money(r.total ?? 0)} bill to ${r.tenantName}`);
    });
  }

  /** onEnrollmentStatusChanged → confirmed: tenant, stay, occupied bed, first payment. */
  async confirmRequestPayment(id: string) {
    if (this.role() === "staff") throw new BackendError("Staff can't confirm payments.");
    return this.commit(() => {
      const r = this.request(id);
      if (r.status !== "payment_submitted" && !(r.status === "bill_sent" && r.paymentMode === "cash")) {
        throw new BackendError("There's no payment to confirm yet.");
      }
      const p = this.property(r.propertyId);
      const bed = this.bedHolder(p, r.roomNumber!, r.bedNumber!);
      if (bed.tenantId) throw new BackendError("That bed was taken meanwhile. Re-assign the request.");
      const user = this.state.users.find((u) => u.uid === r.tenantUid);
      const t = this.createTenant({
        businessId: r.businessId,
        property: p,
        roomNumber: r.roomNumber!,
        bedNumber: r.bedNumber!,
        name: r.tenantName,
        phone: r.tenantPhone,
        email: user?.email ?? "",
        gender: p.gender === "female" ? "female" : "other",
        monthlyRent: r.monthlyRent ?? 0,
        deposit: r.deposit ?? 0,
        maintenance: r.maintenance ?? 0,
        billingDay: Math.min(28, new Date(r.moveIn).getDate()),
        moveIn: r.moveIn,
        uid: r.tenantUid,
        firstMonthPaid: true,
      });
      this.state.payments.unshift({
        id: uid("PAY"),
        businessId: r.businessId,
        tenantId: t.id,
        tenantName: t.name,
        propertyId: p.id,
        propertyName: p.name,
        amount: r.total ?? 0,
        month: monthLabel(new Date(Math.max(r.moveIn, Date.now()))),
        method: r.paymentMode === "cash" ? "Cash" : r.paymentMode === "bank" ? "Bank Transfer" : "UPI",
        reference: r.transactionId,
        note: "First bill: rent, deposit and maintenance",
        status: "paid",
        source: "tenant",
        createdAt: Date.now(),
        verifiedAt: Date.now(),
      });
      r.status = "confirmed";
      r.tenantId = t.id;
      r.updatedAt = Date.now();
      this.notify([r.tenantUid], { title: "You're all set!", body: `Welcome to ${p.name}. Room ${t.roomNumber} · Bed ${t.bedNumber} is yours from ${new Date(t.moveIn).toLocaleDateString("en-IN", { day: "numeric", month: "short" })}.`, kind: "request", href: "/dashboard/tenant/stay/" });
      this.log(r.businessId, "tenant", `${t.name} moved into Room ${t.roomNumber} · Bed ${t.bedNumber}`);
    });
  }

  async rejectRequestPayment(id: string, reason: string) {
    return this.commit(() => {
      const r = this.request(id);
      if (r.status !== "payment_submitted") throw new BackendError("There's no submitted payment to reject.");
      r.status = "bill_sent";
      r.paymentRejectionReason = reason.trim() || "The payment couldn't be found.";
      r.updatedAt = Date.now();
      this.notify([r.tenantUid], { title: "Payment not received", body: r.paymentRejectionReason, kind: "request", href: "/dashboard/tenant/requests/" });
      this.log(r.businessId, "request", `Rejected the first-bill payment from ${r.tenantName}`);
    });
  }

  async rejectRequest(id: string, reason: string) {
    return this.commit(() => {
      const r = this.request(id);
      if (r.status === "confirmed" || r.status === "rejected") throw new BackendError("This request is already closed.");
      r.status = "rejected";
      r.rejectionReason = reason.trim() || "No beds match your request right now.";
      r.updatedAt = Date.now();
      this.notify([r.tenantUid], { title: "Request declined", body: `${r.propertyName}: ${r.rejectionReason}`, kind: "request", href: "/dashboard/tenant/requests/" });
      this.log(r.businessId, "request", `Declined ${r.tenantName}'s request`);
    });
  }

  // ── Rent ─────────────────────────────────────────────────

  async listInvoices(filter?: { tenantId?: string }) {
    await wait();
    this.refreshOverdue();
    const visible = this.visiblePropertyIds();
    return clone(
      this.state.invoices
        .filter((i) => visible.has(i.propertyId))
        .filter((i) => !filter?.tenantId || i.tenantId === filter.tenantId)
        .sort((a, b) => b.periodMonth.localeCompare(a.periodMonth) || a.dueDate - b.dueDate),
    );
  }

  async generateInvoices() {
    if (this.role() === "staff") throw new BackendError("Staff can't generate invoices.");
    return this.commit(() => {
      const bid = this.bizId();
      const d = new Date();
      let created = 0;
      for (const t of this.state.tenants.filter((x) => x.businessId === bid && x.status === "active")) {
        const id = `${t.id}_${periodOf(d)}`;
        if (this.state.invoices.some((i) => i.id === id)) continue;
        this.state.invoices.push({ id, businessId: bid, tenantId: t.id, tenantName: t.name, propertyId: t.propertyId, amount: t.monthlyRent, month: monthLabel(d), periodMonth: periodOf(d), dueDate: new Date(d.getFullYear(), d.getMonth(), t.billingDay).getTime(), status: "unpaid" });
        this.notify([t.uid], { title: `Rent for ${monthLabel(d)}`, body: `${money(t.monthlyRent)} is due on ${new Date(d.getFullYear(), d.getMonth(), t.billingDay).toLocaleDateString("en-IN", { day: "numeric", month: "short" })}.`, kind: "payment", href: "/dashboard/tenant/rent/" });
        created++;
      }
      this.refreshOverdue();
      if (created) this.log(bid, "payment", `Generated ${created} rent invoice${created > 1 ? "s" : ""} for ${monthLabel(d)}`);
      return created;
    });
  }

  async listPayments(filter?: { status?: Payment["status"]; tenantId?: string }) {
    await wait();
    const visible = this.visiblePropertyIds();
    return clone(
      this.state.payments
        .filter((p) => visible.has(p.propertyId))
        .filter((p) => !filter?.status || p.status === filter.status)
        .filter((p) => !filter?.tenantId || p.tenantId === filter.tenantId)
        .sort((a, b) => b.createdAt - a.createdAt),
    );
  }

  /** Marks the invoice a payment settles: by id, else the oldest open one for that month label. */
  private settleInvoice(pay: Payment) {
    const open = this.state.invoices.filter((i) => i.tenantId === pay.tenantId && i.status !== "paid");
    const inv = (pay.invoiceId && open.find((i) => i.id === pay.invoiceId)) || open.filter((i) => i.month === pay.month).sort((a, b) => a.dueDate - b.dueDate)[0];
    if (inv) {
      inv.status = "paid";
      inv.paidAt = Date.now();
      pay.invoiceId = inv.id;
    }
  }

  async verifyPayment(id: string, action: "approve" | "reject", reason?: string) {
    if (this.role() === "staff") throw new BackendError("Staff can't verify payments.");
    return this.commit(() => {
      const pay = this.state.payments.find((p) => p.id === id);
      if (!pay) throw new BackendError("Payment not found.");
      this.assertPropertyAccess(pay.propertyId);
      if (pay.status !== "pending") throw new BackendError("This payment was already reviewed.");
      const t = this.state.tenants.find((x) => x.id === pay.tenantId);
      if (action === "approve") {
        pay.status = "paid";
        pay.verifiedAt = Date.now();
        this.settleInvoice(pay);
        this.notify([t?.uid], { title: "Payment confirmed", body: `${money(pay.amount)} for ${pay.month} was received.`, kind: "payment", href: "/dashboard/tenant/rent/" });
        this.log(pay.businessId, "payment", `Verified ${money(pay.amount)} from ${pay.tenantName} (${pay.method})`);
      } else {
        pay.status = "rejected";
        pay.rejectionReason = reason?.trim() || "Payment not found in the account.";
        this.notify([t?.uid], { title: "Payment rejected", body: `${money(pay.amount)} for ${pay.month}: ${pay.rejectionReason}`, kind: "payment", href: "/dashboard/tenant/rent/" });
        this.log(pay.businessId, "payment", `Rejected ${money(pay.amount)} from ${pay.tenantName}`);
      }
    });
  }

  async recordPayment(input: RecordPaymentInput) {
    if (this.role() === "staff") throw new BackendError("Staff can't record payments.");
    if (!(input.amount > 0)) throw new BackendError("Enter the amount received.");
    return this.commit(() => {
      const t = this.state.tenants.find((x) => x.id === input.tenantId);
      if (!t) throw new BackendError("Tenant not found.");
      this.assertPropertyAccess(t.propertyId);
      const pay: Payment = {
        id: uid("PAY"),
        businessId: t.businessId,
        tenantId: t.id,
        tenantName: t.name,
        propertyId: t.propertyId,
        propertyName: t.propertyName,
        amount: input.amount,
        month: input.month,
        method: input.method,
        reference: input.reference?.trim() || undefined,
        note: input.note?.trim() || undefined,
        status: "paid",
        source: "owner",
        createdAt: Date.now(),
        verifiedAt: Date.now(),
      };
      this.settleInvoice(pay);
      this.state.payments.unshift(pay);
      this.notify([t.uid], { title: "Payment recorded", body: `${money(pay.amount)} (${pay.method}) for ${pay.month}.`, kind: "payment", href: "/dashboard/tenant/rent/" });
      this.log(t.businessId, "payment", `Recorded ${money(pay.amount)} ${pay.method.toLowerCase()} from ${t.name}`);
    });
  }

  // ── Maintenance ──────────────────────────────────────────

  async listMaintenance() {
    await wait();
    const visible = this.visiblePropertyIds();
    return clone(this.state.maintenance.filter((m) => visible.has(m.propertyId)).sort((a, b) => b.createdAt - a.createdAt));
  }

  async updateMaintenance(id: string, status: MaintenanceStatus, note?: string) {
    return this.commit(() => {
      const m = this.state.maintenance.find((x) => x.id === id);
      if (!m) throw new BackendError("Request not found.");
      this.assertPropertyAccess(m.propertyId);
      const order = ["open", "in_progress", "resolved"];
      if (m.status === "cancelled" || m.status === "resolved") throw new BackendError("This request is closed.");
      if (order.indexOf(status) <= order.indexOf(m.status)) throw new BackendError("Requests only move forward: open → in progress → resolved.");
      m.status = status;
      if (note?.trim()) m.ownerNote = note.trim();
      m.updatedAt = Date.now();
      // onMaintenanceRequestUpdated pushes the tenant.
      const label = status === "in_progress" ? "is being worked on" : "is resolved";
      const tenantUid = m.tenantUid || this.state.tenants.find((t) => t.id === m.tenantId)?.uid;
      this.notify([tenantUid], { title: `Maintenance ${status === "in_progress" ? "in progress" : "resolved"}`, body: `${m.title} ${label}.${m.ownerNote ? ` ${m.ownerNote}` : ""}`, kind: "maintenance", href: "/dashboard/tenant/maintenance/" });
      this.log(m.businessId, "maintenance", `${m.title} (Room ${m.roomNumber}) ${label}`);
    });
  }

  // ── Team ─────────────────────────────────────────────────

  async listMembers() {
    await wait();
    const bid = this.bizId();
    return clone(this.state.members.filter((m) => m.businessId === bid).sort((a, b) => a.invitedAt - b.invitedAt));
  }

  async inviteMember(input: MemberInviteInput) {
    this.requireOwner("invite team members");
    if (!input.name.trim()) throw new BackendError("Enter their name.");
    if (phoneDigits(input.phone).length !== 10 && !/^\S+@\S+\.\S+$/.test(input.email)) throw new BackendError("Add a 10-digit phone or an email.");
    if (input.propertyIds.length === 0) throw new BackendError("Give access to at least one property.");
    return this.commit(() => {
      const bid = this.bizId();
      const phone = phoneDigits(input.phone);
      if (this.state.members.some((m) => m.businessId === bid && ((phone && phoneDigits(m.phone) === phone) || (input.email && m.email.toLowerCase() === input.email.toLowerCase())))) {
        throw new BackendError("This person is already on your team or invited.");
      }
      this.state.members.push({ id: uid("MEM"), businessId: bid, name: input.name.trim(), phone, email: input.email.trim().toLowerCase(), role: input.role, status: "invited", propertyIds: input.propertyIds, invitedAt: Date.now() });
      const invitee = this.state.users.find((u) => u.kind === "business" && ((phone && phoneDigits(u.phone) === phone) || (input.email && u.email === input.email.trim().toLowerCase())));
      const biz = this.state.businesses.find((b) => b.id === bid)!;
      this.notify([invitee?.uid], { title: `Join ${biz.name}`, body: `You're invited as ${input.role}.`, kind: "team", href: "/dashboard/owner/" });
      this.log(bid, "team", `Invited ${input.name.trim()} as ${input.role}`);
    });
  }

  async updateMember(id: string, role: Exclude<BusinessRole, "owner">, propertyIds: string[]) {
    this.requireOwner("change team access");
    if (propertyIds.length === 0) throw new BackendError("Give access to at least one property.");
    return this.commit(() => {
      const m = this.state.members.find((x) => x.id === id && x.businessId === this.bizId());
      if (!m) throw new BackendError("Member not found.");
      if (m.role === "owner") throw new BackendError("The owner's access can't be changed.");
      m.role = role;
      m.propertyIds = propertyIds;
      const u = this.state.users.find((x) => x.uid === m.uid);
      if (u) u.role = role;
      this.notify([m.uid], { title: "Your access changed", body: `You're now ${role} with access to ${propertyIds.length} propert${propertyIds.length > 1 ? "ies" : "y"}.`, kind: "team" });
      this.log(m.businessId, "team", `Updated ${m.name}'s access (${role})`);
    });
  }

  async removeMember(id: string) {
    this.requireOwner("remove team members");
    return this.commit(() => {
      const m = this.state.members.find((x) => x.id === id && x.businessId === this.bizId());
      if (!m) throw new BackendError("Member not found.");
      if (m.role === "owner") throw new BackendError("The owner can't be removed.");
      this.state.members = this.state.members.filter((x) => x.id !== id);
      const u = this.state.users.find((x) => x.uid === m.uid);
      if (u) {
        u.businessId = undefined;
        u.role = undefined;
      }
      this.log(m.businessId, "team", `${m.status === "invited" ? "Withdrew the invite for" : "Removed"} ${m.name}`);
    });
  }

  // ── Collections setup ────────────────────────────────────

  async listPayoutMethods() {
    await wait();
    const bid = this.bizId();
    return clone(this.state.payoutMethods.filter((m) => m.businessId === bid).sort((a, b) => Number(b.preferred) - Number(a.preferred) || a.createdAt - b.createdAt));
  }

  async savePayoutMethod(input: Parameters<Backend["savePayoutMethod"]>[0]) {
    this.requireOwner("change payment methods");
    if (input.type === "upi" && !/^[\w.-]{2,}@[a-zA-Z]{2,}$/.test(input.upiId ?? "")) throw new BackendError("UPI ID should look like name@bank.");
    if (input.type === "bank") {
      if (!/^\d{9,18}$/.test(input.accountNumber ?? "")) throw new BackendError("Account number should be 9–18 digits.");
      if (!/^[A-Z]{4}0[A-Z0-9]{6}$/.test((input.ifsc ?? "").toUpperCase())) throw new BackendError("IFSC should look like HDFC0001234.");
      if (!input.holder?.trim()) throw new BackendError("Enter the account holder's name.");
    }
    return this.commit(() => {
      const bid = this.bizId();
      if (input.preferred) for (const m of this.state.payoutMethods.filter((x) => x.businessId === bid)) m.preferred = false;
      const existing = input.id ? this.state.payoutMethods.find((m) => m.id === input.id) : undefined;
      const data = { ...input, ifsc: input.ifsc?.toUpperCase() };
      if (existing) Object.assign(existing, data);
      else this.state.payoutMethods.push({ ...data, id: uid("PM"), businessId: bid, createdAt: Date.now() } as never);
      if (input.type === "upi" && input.preferred) {
        const b = this.state.businesses.find((x) => x.id === bid)!;
        b.upiId = input.upiId;
      }
    });
  }

  async deletePayoutMethod(id: string) {
    this.requireOwner("change payment methods");
    return this.commit(() => {
      this.state.payoutMethods = this.state.payoutMethods.filter((m) => !(m.id === id && m.businessId === this.bizId()));
    });
  }

  async setOnlinePayments(enabled: boolean) {
    this.requireOwner("change online payments");
    return this.commit(() => {
      const b = this.state.businesses.find((x) => x.id === this.bizId())!;
      if (enabled && b.kycStatus === "not_started") throw new BackendError("Submit KYC before turning on online payments.");
      b.onlinePaymentsEnabled = enabled;
      this.log(b.id, "payment", `Online rent payments turned ${enabled ? "on" : "off"}`);
    });
  }

  // ── Platform billing ─────────────────────────────────────

  async listPlatformInvoices() {
    await wait();
    this.requireOwner("see billing");
    const bid = this.bizId();
    return clone(this.state.platformInvoices.filter((i) => i.businessId === bid).sort((a, b) => b.periodStart - a.periodStart));
  }

  private quote(propertyId: string, promoCode?: string): CheckoutQuote {
    const p = this.property(propertyId);
    if (p.businessId !== this.bizId()) throw new BackendError("Property not found.");
    const beds = p.rooms.reduce((s, r) => s + r.beds.length, 0);
    const baseAmount = beds * p.pricePerBed;
    let promo: CheckoutQuote["promo"];
    if (promoCode?.trim()) {
      const found = this.state.promos.find((x) => x.code === promoCode.trim().toUpperCase());
      if (!found) throw new BackendError("This promo code isn't valid.");
      promo = { code: found.code, percent: found.percent };
    }
    // Promos apply only to the final payable amount (activateProperty.ts).
    const gst = 0;
    const gross = baseAmount;
    const discount = promo ? Math.round((gross * promo.percent) / 100) : 0;
    const start = new Date();
    const periodStart = new Date(start.getFullYear(), start.getMonth(), start.getDate()).getTime();
    return { propertyId, beds, pricePerBed: p.pricePerBed, baseAmount, gst, discount, finalAmount: gross - discount, promo, periodStart, periodEnd: periodStart + 30 * DAY };
  }

  async checkoutQuote(propertyId: string, promoCode?: string) {
    await wait();
    this.requireOwner("pay for properties");
    return this.quote(propertyId, promoCode);
  }

  async payActivation(propertyId: string, promoCode?: string) {
    this.requireOwner("pay for properties");
    return this.commit(() => {
      const q = this.quote(propertyId, promoCode);
      const p = this.property(propertyId);
      this.state.platformInvoices.unshift({ id: `${p.id}_${q.periodStart}`, businessId: p.businessId, propertyId: p.id, propertyName: p.name, beds: q.beds, pricePerBed: q.pricePerBed, amount: q.finalAmount, discount: q.discount, promoCode: q.promo?.code, periodStart: q.periodStart, periodEnd: q.periodEnd, status: "paid", paidAt: Date.now(), reference: uid("pay") });
      p.billingStatus = "paid";
      p.nextBillingDate = q.periodEnd;
      this.log(p.businessId, "billing", `Paid ${money(q.finalAmount)} to activate ${p.name} for 30 days`);
    });
  }

  async listActivity() {
    await wait();
    const bid = this.bizId();
    return clone(this.state.activity.filter((a) => a.businessId === bid).slice(0, 40));
  }

  // ── Tenant side ──────────────────────────────────────────

  private myTenant(): Tenant | null {
    const u = this.me();
    return (
      this.state.tenants.find((t) => t.status === "active" && (t.uid === u.uid || (u.tenantId && t.id === u.tenantId))) ?? null
    );
  }

  async getStay() {
    await wait();
    const t = this.myTenant();
    if (!t) return null;
    const property = this.state.properties.find((p) => p.id === t.propertyId)!;
    return clone({ tenant: t, property, room: property.rooms.find((r) => r.number === t.roomNumber) });
  }

  async listMyInvoices() {
    await wait();
    this.refreshOverdue();
    const t = this.myTenant();
    if (!t) return [];
    return clone(this.state.invoices.filter((i) => i.tenantId === t.id).sort((a, b) => b.periodMonth.localeCompare(a.periodMonth)));
  }

  async listMyPayments() {
    await wait();
    const u = this.me();
    const ids = new Set(this.state.tenants.filter((t) => t.uid === u.uid || t.id === u.tenantId).map((t) => t.id));
    return clone(this.state.payments.filter((p) => ids.has(p.tenantId)).sort((a, b) => b.createdAt - a.createdAt));
  }

  async paymentSettings(businessId: string) {
    await wait();
    const b = this.state.businesses.find((x) => x.id === businessId);
    const preferredUpi = this.state.payoutMethods.find((m) => m.businessId === businessId && m.type === "upi" && m.active && m.preferred)?.upiId;
    return { onlineEnabled: !!b?.onlinePaymentsEnabled, upiId: preferredUpi ?? b?.upiId };
  }

  async payOnline(invoiceId: string) {
    return this.commit(() => {
      const t = this.myTenant();
      const inv = this.state.invoices.find((i) => i.id === invoiceId && i.tenantId === t?.id);
      if (!t || !inv) throw new BackendError("Invoice not found.");
      if (inv.status === "paid") throw new BackendError("This invoice is already paid.");
      const b = this.state.businesses.find((x) => x.id === t.businessId);
      if (!b?.onlinePaymentsEnabled) throw new BackendError("Your PG doesn't accept online payments yet. Pay by UPI or cash.");
      // razorpayPaymentWebhook: payment.captured → paid payment + closed invoice, exactly once.
      const pay: Payment = { id: uid("PAY"), businessId: t.businessId, tenantId: t.id, tenantName: t.name, propertyId: t.propertyId, propertyName: t.propertyName, amount: inv.amount, month: inv.month, method: "Online", reference: uid("pay_rzp"), status: "paid", invoiceId: inv.id, source: "gateway", createdAt: Date.now(), verifiedAt: Date.now() };
      this.state.payments.unshift(pay);
      inv.status = "paid";
      inv.paidAt = Date.now();
      this.notify(this.staffFor(t.businessId, t.propertyId), { title: "Rent received online", body: `${t.name} paid ${money(inv.amount)} for ${inv.month}.`, kind: "payment", href: "/dashboard/owner/payments/" });
      this.log(t.businessId, "payment", `${t.name} paid ${money(inv.amount)} online for ${inv.month}`);
    });
  }

  async submitRentPayment(input: RentSubmissionInput) {
    if (!(input.amount > 0)) throw new BackendError("Enter the amount you paid.");
    if (input.mode === "UPI" && !input.reference?.trim()) throw new BackendError("Enter the UPI transaction ID (UTR) so your owner can match it.");
    return this.commit(() => {
      const t = this.myTenant();
      if (!t) throw new BackendError("You don't have an active stay.");
      if (this.state.payments.some((p) => p.tenantId === t.id && p.status === "pending" && (p.invoiceId === input.invoiceId || p.month === input.month))) {
        throw new BackendError(`A payment for ${input.month} is already waiting for your owner to confirm.`);
      }
      this.state.payments.unshift({ id: uid("PAY"), businessId: t.businessId, tenantId: t.id, tenantName: t.name, propertyId: t.propertyId, propertyName: t.propertyName, amount: input.amount, month: input.month, method: input.mode, reference: input.reference?.trim() || undefined, status: "pending", invoiceId: input.invoiceId, source: "tenant", createdAt: Date.now() });
      // onPaymentCreated notifies the owner.
      this.notify(this.staffFor(t.businessId, t.propertyId), { title: "Payment to verify", body: `${t.name} paid ${money(input.amount)} by ${input.mode} for ${input.month}.`, kind: "payment", href: "/dashboard/owner/payments/" });
      this.log(t.businessId, "payment", `${t.name} reported a ${money(input.amount)} ${input.mode} payment`);
    });
  }

  async explore(filter?: { city?: string; query?: string; gender?: Property["gender"] | "any" }) {
    await wait();
    const q = filter?.query?.trim().toLowerCase();
    return clone(
      this.state.properties
        // properties_by_city lists active properties whose activation is paid.
        .filter((p) => p.status === "active" && ["paid", "grace", "past_due"].includes(p.billingStatus))
        .filter((p) => !filter?.city || filter.city === "All" || p.city === filter.city)
        .filter((p) => !filter?.gender || filter.gender === "any" || p.gender === filter.gender)
        .filter((p) => !q || [p.name, p.address, p.city, p.landmarks, ...p.amenities].join(" ").toLowerCase().includes(q))
        .sort((a, b) => b.rating - a.rating),
    );
  }

  async getPublicProperty(id: string) {
    await wait();
    const p = this.state.properties.find((x) => x.id === id && x.status === "active" && ["paid", "grace", "past_due"].includes(x.billingStatus));
    return clone(p ?? null);
  }

  async setFavorite(propertyId: string, favorite: boolean) {
    return this.commit(() => {
      const u = this.me();
      u.favorites = favorite ? [...new Set([...u.favorites, propertyId])] : u.favorites.filter((x) => x !== propertyId);
    });
  }

  async submitEnrollment(d: EnrollmentDraft) {
    if (!d.name.trim()) throw new BackendError("Enter your name.");
    if (phoneDigits(d.phone).length !== 10) throw new BackendError("Enter your 10-digit mobile number.");
    return this.commit(() => {
      const u = this.me();
      if (u.kind !== "tenant") throw new BackendError("Use a tenant account to join a PG.");
      const p = this.state.properties.find((x) => x.id === d.propertyId && x.status === "active");
      if (!p) throw new BackendError("This PG isn't accepting requests right now.");
      if (this.myTenant()) throw new BackendError("You already have an active stay. Ask your owner to close it first.");
      if (this.state.requests.some((r) => r.tenantUid === u.uid && r.propertyId === p.id && !["confirmed", "rejected"].includes(r.status))) {
        throw new BackendError("You already have an open request for this PG.");
      }
      const id = uid("REQ");
      this.state.requests.unshift({ id, tenantUid: u.uid, tenantName: d.name.trim(), tenantPhone: phoneDigits(d.phone), businessId: p.businessId, propertyId: p.id, propertyName: p.name, moveIn: d.moveIn, sharing: d.sharing, notes: d.notes.trim(), status: "pending", createdAt: Date.now(), updatedAt: Date.now() });
      // onEnrollmentRequestCreated notifies the owner and managers.
      this.notify(this.staffFor(p.businessId, p.id), { title: "New join request", body: `${d.name.trim()} wants to join ${p.name}.`, kind: "request", href: "/dashboard/owner/requests/" });
      this.log(p.businessId, "request", `${d.name.trim()} requested to join ${p.name}`);
      return id;
    });
  }

  async listMyRequests() {
    await wait();
    const u = this.me();
    return clone(this.state.requests.filter((r) => r.tenantUid === u.uid).sort((a, b) => b.updatedAt - a.updatedAt));
  }

  async payBill(requestId: string, reference: string) {
    if (!reference.trim()) throw new BackendError("Enter the transaction ID from your payment app.");
    return this.commit(() => {
      const u = this.me();
      const r = this.state.requests.find((x) => x.id === requestId && x.tenantUid === u.uid);
      if (!r || r.status !== "bill_sent") throw new BackendError("There's no bill to pay on this request.");
      r.status = "payment_submitted";
      r.transactionId = reference.trim();
      r.paymentRejectionReason = undefined;
      r.updatedAt = Date.now();
      this.notify(this.staffFor(r.businessId, r.propertyId), { title: "First bill paid", body: `${r.tenantName} submitted ${money(r.total ?? 0)} for Room ${r.roomNumber} · Bed ${r.bedNumber}.`, kind: "request", href: "/dashboard/owner/requests/" });
      this.log(r.businessId, "request", `${r.tenantName} paid the first bill`);
    });
  }

  async withdrawRequest(requestId: string) {
    return this.commit(() => {
      const u = this.me();
      const r = this.state.requests.find((x) => x.id === requestId && x.tenantUid === u.uid);
      if (!r || r.status !== "pending") throw new BackendError("Only requests the owner hasn't answered can be withdrawn.");
      this.state.requests = this.state.requests.filter((x) => x.id !== requestId);
      this.log(r.businessId, "request", `${r.tenantName} withdrew their request`);
    });
  }

  async listMyInvitations() {
    await wait();
    const u = this.me();
    return clone(this.state.invitations.filter((i) => phoneDigits(i.tenantPhone) === phoneDigits(u.phone) || (i.tenantEmail && i.tenantEmail.toLowerCase() === u.email.toLowerCase())).sort((a, b) => b.createdAt - a.createdAt));
  }

  async acceptInvitation(id: string) {
    return this.commit(() => {
      const u = this.me();
      const inv = this.state.invitations.find((i) => i.id === id);
      if (!inv || inv.status !== "pending") throw new BackendError("This invitation is no longer open.");
      if (phoneDigits(inv.tenantPhone) !== phoneDigits(u.phone) && inv.tenantEmail.toLowerCase() !== u.email.toLowerCase()) throw new BackendError("This invitation is for someone else.");
      if (this.myTenant()) throw new BackendError("You already have an active stay.");
      const p = this.property(inv.propertyId);
      const bed = this.bedHolder(p, inv.roomNumber, inv.bedNumber);
      if (bed.tenantId) throw new BackendError("That bed is no longer free. Ask the owner to send a new invitation.");
      const t = this.createTenant({ businessId: inv.businessId, property: p, roomNumber: inv.roomNumber, bedNumber: inv.bedNumber, name: inv.tenantName, phone: inv.tenantPhone, email: inv.tenantEmail || u.email, gender: inv.gender, monthlyRent: inv.monthlyRent, deposit: inv.deposit, maintenance: inv.maintenance, billingDay: inv.billingDay, moveIn: inv.moveIn, uid: u.uid });
      inv.status = "accepted";
      inv.tenantId = t.id;
      this.notify(this.staffFor(inv.businessId, inv.propertyId), { title: "Invitation accepted", body: `${t.name} accepted Room ${t.roomNumber} · Bed ${t.bedNumber}.`, kind: "invitation", href: `/dashboard/owner/tenant/?id=${t.id}` });
      this.log(inv.businessId, "tenant", `${t.name} accepted the invitation and moved in`);
    });
  }

  async declineInvitation(id: string, reason?: string) {
    return this.commit(() => {
      const u = this.me();
      const inv = this.state.invitations.find((i) => i.id === id);
      if (!inv || inv.status !== "pending") throw new BackendError("This invitation is no longer open.");
      if (phoneDigits(inv.tenantPhone) !== phoneDigits(u.phone) && inv.tenantEmail.toLowerCase() !== u.email.toLowerCase()) throw new BackendError("This invitation is for someone else.");
      inv.status = "rejected";
      inv.reason = reason?.trim() || undefined;
      this.notify(this.staffFor(inv.businessId, inv.propertyId), { title: "Invitation declined", body: `${inv.tenantName} declined Room ${inv.roomNumber} · Bed ${inv.bedNumber}.${inv.reason ? ` “${inv.reason}”` : ""}`, kind: "invitation", href: "/dashboard/owner/tenants/" });
      this.log(inv.businessId, "tenant", `${inv.tenantName} declined the invitation`);
    });
  }

  async listMyMaintenance() {
    await wait();
    const u = this.me();
    const t = this.myTenant();
    return clone(this.state.maintenance.filter((m) => m.tenantUid === u.uid || (t && m.tenantId === t.id)).sort((a, b) => b.createdAt - a.createdAt));
  }

  async raiseMaintenance(d: MaintenanceDraft) {
    if (!d.title.trim()) throw new BackendError("Add a short title.");
    return this.commit(() => {
      const u = this.me();
      const t = this.myTenant();
      if (!t) throw new BackendError("You need an active stay to raise a request.");
      this.state.maintenance.unshift({ id: uid("MNT"), tenantUid: u.uid, tenantId: t.id, tenantName: t.name, tenantPhone: t.phone, businessId: t.businessId, propertyId: t.propertyId, propertyName: t.propertyName, roomNumber: t.roomNumber, bedNumber: t.bedNumber, category: d.category, title: d.title.trim(), description: d.description.trim(), urgent: d.urgent, status: "open", createdAt: Date.now(), updatedAt: Date.now() });
      // onMaintenanceRequestCreated notifies the owner.
      this.notify(this.staffFor(t.businessId, t.propertyId), { title: d.urgent ? "Urgent maintenance" : "New maintenance request", body: `${d.title.trim()} — Room ${t.roomNumber}, ${t.propertyName}.`, kind: "maintenance", href: "/dashboard/owner/maintenance/" });
      this.log(t.businessId, "maintenance", `Maintenance raised: ${d.title.trim()} (Room ${t.roomNumber})`);
    });
  }

  async cancelMaintenance(id: string) {
    return this.commit(() => {
      const u = this.me();
      const m = this.state.maintenance.find((x) => x.id === id && x.tenantUid === u.uid);
      if (!m || m.status !== "open") throw new BackendError("Only open requests can be cancelled.");
      m.status = "cancelled";
      m.updatedAt = Date.now();
    });
  }

  async listPins() {
    await wait();
    const t = this.myTenant();
    if (!t) return [];
    const now = Date.now();
    return clone(this.state.pins.filter((p) => p.propertyId === t.propertyId && p.expiresAt > now).sort((a, b) => b.createdAt - a.createdAt));
  }

  async addPin(category: PinCategory, content: string) {
    if (!content.trim()) throw new BackendError("Write something to pin.");
    if (content.length > 280) throw new BackendError("Keep notes under 280 characters.");
    return this.commit(() => {
      const u = this.me();
      const t = this.myTenant();
      if (!t) throw new BackendError("Join a PG to use its pinboard.");
      this.state.pins.unshift({ id: uid("PIN"), propertyId: t.propertyId, authorUid: u.uid, authorName: u.name, category, content: content.trim(), createdAt: Date.now(), expiresAt: Date.now() + 48 * 3600_000 });
    });
  }

  async deletePin(id: string) {
    return this.commit(() => {
      const u = this.me();
      const pin = this.state.pins.find((p) => p.id === id);
      if (!pin || pin.authorUid !== u.uid) throw new BackendError("You can only remove your own notes.");
      this.state.pins = this.state.pins.filter((p) => p.id !== id);
    });
  }

  // ── Notifications ────────────────────────────────────────

  async listNotifications() {
    await wait();
    const u = this.me();
    return clone(this.state.notifications.filter((n) => n.uid === u.uid).sort((a, b) => b.createdAt - a.createdAt).slice(0, 60));
  }

  async markNotificationsRead(ids?: string[]) {
    return this.commit(() => {
      const u = this.me();
      for (const n of this.state.notifications) {
        if (n.uid === u.uid && (!ids || ids.includes(n.id))) n.read = true;
      }
    });
  }
}
