// The sample workspace demo mode starts from: two businesses, five PGs in
// four cities, tenants with six months of rent history, and one of every
// open item (a join request, a payment to verify, maintenance, a team invite)
// so each dashboard screen has something to act on.
import type {
  Account,
  Activity,
  AppNotification,
  Business,
  EnrollmentRequest,
  MaintenanceRequest,
  Member,
  Payment,
  PayoutMethod,
  PinNote,
  PlatformInvoice,
  Property,
  RentInvoice,
  Room,
  Tenant,
  TenantInvitation,
} from "../../types";
import { DAY, monthLabel, periodOf } from "../../format";

export interface DemoUser extends Account {
  passwordHash: string;
}

export interface DemoState {
  version: number;
  counters: { business: number; tenant: number; seq: number };
  users: DemoUser[];
  businesses: Business[];
  properties: Property[];
  tenants: Tenant[];
  invoices: RentInvoice[];
  payments: Payment[];
  requests: EnrollmentRequest[];
  invitations: TenantInvitation[];
  members: Member[];
  maintenance: MaintenanceRequest[];
  pins: PinNote[];
  payoutMethods: PayoutMethod[];
  platformInvoices: PlatformInvoice[];
  notifications: AppNotification[];
  activity: Activity[];
  promos: { code: string; percent: number }[];
}

export const STATE_VERSION = 2;
export const DEMO_PASSWORD = "demo1234";
export const DEMO_ACCOUNTS = {
  owner: "asha@onestay.demo",
  manager: "vikram@onestay.demo",
  tenant: "rahul@onestay.demo",
} as const;

/** Not security: demo accounts live in this browser only. */
export function hashPassword(email: string, password: string) {
  let h = 0x811c9dc5;
  for (const ch of `${email.toLowerCase()}::${password}`) {
    h ^= ch.charCodeAt(0);
    h = Math.imul(h, 0x01000193);
  }
  return (h >>> 0).toString(16);
}

type RoomSpec = [number: string, floor: number, sharing: number, ac: boolean, rent: number];

function rooms(specs: RoomSpec[]): Room[] {
  return specs.map(([number, floor, sharing, ac, rent]) => ({
    id: `R${number}`,
    number,
    floor,
    sharing,
    ac,
    attachedBath: ac || sharing <= 2,
    rentPerBed: rent,
    beds: Array.from({ length: sharing }, (_, i) => ({ number: String.fromCharCode(65 + i), tenantId: null })),
  }));
}

const firstNames = ["Rahul", "Ananya", "Karthik", "Sneha", "Arjun", "Meera", "Rohan", "Divya", "Aditya", "Pooja", "Nikhil", "Isha", "Siddharth", "Kavya", "Varun", "Neha", "Manish", "Tanvi"];
const lastNames = ["Mehta", "Iyer", "Reddy", "Sharma", "Nair", "Kulkarni", "Gupta", "Menon", "Joshi", "Rao", "Shetty", "Bhat"];
const occupations = ["Software engineer", "Product designer", "MBA student", "Data analyst", "Consultant", "Marketing associate"];

export function buildSeed(now = Date.now()): DemoState {
  const today = new Date(now);
  const ago = (days: number) => now - days * DAY;

  const users: DemoUser[] = [
    { uid: "u-asha", kind: "business", name: "Asha Rao", email: DEMO_ACCOUNTS.owner, phone: "9876500001", businessId: "BUS0000001", role: "owner", favorites: [], createdAt: ago(240), passwordHash: hashPassword(DEMO_ACCOUNTS.owner, DEMO_PASSWORD) },
    { uid: "u-vikram", kind: "business", name: "Vikram Singh", email: DEMO_ACCOUNTS.manager, phone: "9876500002", businessId: "BUS0000001", role: "manager", favorites: [], createdAt: ago(120), passwordHash: hashPassword(DEMO_ACCOUNTS.manager, DEMO_PASSWORD) },
    { uid: "u-rahul", kind: "tenant", name: "Rahul Mehta", email: DEMO_ACCOUNTS.tenant, phone: "9876511111", tenantId: "TEN0000001", favorites: ["BUS0000002-P01"], createdAt: ago(170), passwordHash: hashPassword(DEMO_ACCOUNTS.tenant, DEMO_PASSWORD) },
    { uid: "u-priya", kind: "tenant", name: "Priya Desai", email: "priya@onestay.demo", phone: "9876522222", favorites: [], createdAt: ago(3), passwordHash: hashPassword("priya@onestay.demo", DEMO_PASSWORD) },
    { uid: "u-kunal", kind: "tenant", name: "Kunal Shah", email: "kunal@onestay.demo", phone: "9876533333", favorites: [], createdAt: ago(5), passwordHash: hashPassword("kunal@onestay.demo", DEMO_PASSWORD) },
  ];

  const businesses: Business[] = [
    { id: "BUS0000001", name: "Sunrise Stays", ownerUid: "u-asha", phone: "9876500001", email: DEMO_ACCOUNTS.owner, city: "Bangalore", address: "80 Feet Road, Koramangala", upiId: "sunrisestays@okhdfc", onlinePaymentsEnabled: true, kycStatus: "verified", kyc: { legalName: "Sunrise Stays LLP", pan: "ABCFS1234K", gstin: "29ABCFS1234K1Z5", aadhaarLast4: "4321", submittedAt: ago(200) }, createdAt: ago(240) },
    { id: "BUS0000002", name: "Green Nest Living", ownerUid: "u-greennest", phone: "9822200002", email: "hello@greennest.demo", city: "Pune", address: "Baner Road, Pune", upiId: "greennest@okicici", onlinePaymentsEnabled: false, kycStatus: "verified", createdAt: ago(400) },
  ];

  const amenitiesAll = ["WiFi", "Power backup", "Housekeeping", "Laundry", "Hot water", "CCTV", "Gym", "Parking", "Fridge", "TV lounge", "Study room", "Lift"];
  const base = (p: Partial<Property> & Pick<Property, "id" | "businessId" | "name" | "city" | "address" | "rooms" | "gender">): Property => {
    const biz = businesses.find((b) => b.id === p.businessId)!;
    return {
      businessName: biz.name,
      businessPhone: biz.phone,
      pincode: "560034",
      description: "",
      landmarks: "",
      mapsLink: "",
      amenities: amenitiesAll.slice(0, 7),
      food: { included: true, meals: ["Breakfast", "Dinner"], monthlyDeduction: 2500 },
      rules: { noticeDays: 30, lockInMonths: 3, gateClosesAt: "23:00", visitorsAllowed: true, smokingAllowed: false },
      pricing: { deposit: 15000, maintenance: 1000 },
      status: "active",
      billingStatus: "paid",
      pricePerBed: 30,
      nextBillingDate: now + 18 * DAY,
      coverHue: 160,
      rating: 4.5,
      createdAt: ago(230),
      updatedAt: ago(10),
      ...p,
    };
  };

  const properties: Property[] = [
    base({
      id: "BUS0000001-P01", businessId: "BUS0000001", name: "Sunrise Residency", city: "Bangalore", gender: "coed",
      address: "14, 5th Cross, Koramangala 4th Block", pincode: "560034", landmarks: "Near Forum Mall",
      description: "Bright, fully furnished co-living rooms five minutes from Koramangala's tech parks. Home-style meals, daily housekeeping and a quiet study lounge.",
      amenities: ["WiFi", "Power backup", "Housekeeping", "Laundry", "Hot water", "CCTV", "Gym", "Study room", "Lift"],
      rooms: rooms([["101", 1, 2, true, 14000], ["102", 1, 3, false, 9500], ["103", 1, 1, true, 21000], ["201", 2, 2, true, 14000], ["202", 2, 3, false, 9500], ["203", 2, 2, false, 11500], ["301", 3, 1, true, 21000], ["302", 3, 3, true, 11000]]),
      coverHue: 158, rating: 4.7, createdAt: ago(230),
    }),
    base({
      id: "BUS0000001-P02", businessId: "BUS0000001", name: "Sunrise Ladies Nest", city: "Bangalore", gender: "female",
      address: "27th Main, HSR Layout Sector 2", pincode: "560102", landmarks: "Opposite BDA Complex",
      description: "A safe, women-only PG with biometric entry, a warden on site and vegetarian meals. Walking distance to HSR's offices and cafés.",
      amenities: ["WiFi", "Power backup", "Housekeeping", "Hot water", "CCTV", "Fridge", "TV lounge"],
      food: { included: true, meals: ["Breakfast", "Lunch", "Dinner"], monthlyDeduction: 3000 },
      rules: { noticeDays: 30, lockInMonths: 2, gateClosesAt: "22:00", visitorsAllowed: false, smokingAllowed: false },
      rooms: rooms([["G1", 0, 2, false, 10500], ["G2", 0, 3, false, 8500], ["11", 1, 2, true, 12500], ["12", 1, 2, true, 12500], ["13", 1, 1, true, 18000]]),
      billingStatus: "payment_due", nextBillingDate: now - 2 * DAY, coverHue: 330, rating: 4.6, createdAt: ago(40),
    }),
    base({
      id: "BUS0000002-P01", businessId: "BUS0000002", name: "Green Nest Baner", city: "Pune", gender: "male",
      address: "Lane 4, Baner Road", pincode: "411045", landmarks: "Near Balewadi High Street",
      description: "Spacious rooms for working professionals with a terrace garden, gym and weekend community dinners.",
      rooms: rooms([["A1", 1, 2, true, 11000], ["A2", 1, 3, false, 8000], ["B1", 2, 2, true, 11000], ["B2", 2, 1, true, 16000]]),
      coverHue: 120, rating: 4.4,
    }),
    base({
      id: "BUS0000002-P02", businessId: "BUS0000002", name: "Green Nest Powai", city: "Mumbai", gender: "coed",
      address: "Hiranandani Gardens, Powai", pincode: "400076", landmarks: "Near IIT Main Gate",
      description: "Lake-view co-living in Powai with high-speed internet, workspace pods and three meals a day.",
      amenities: ["WiFi", "Power backup", "Housekeeping", "Laundry", "Hot water", "CCTV", "Lift", "Study room"],
      pricing: { deposit: 25000, maintenance: 1500 },
      rooms: rooms([["301", 3, 2, true, 19000], ["302", 3, 3, true, 14500], ["401", 4, 1, true, 28000]]),
      coverHue: 200, rating: 4.8,
    }),
    base({
      id: "BUS0000002-P03", businessId: "BUS0000002", name: "Green Nest Gachibowli", city: "Hyderabad", gender: "female",
      address: "DLF Road, Gachibowli", pincode: "500032", landmarks: "Near DLF Cyber City",
      description: "Women's co-living next to the financial district, with a shuttle to HITEC City and a 24×7 warden.",
      rooms: rooms([["1A", 1, 2, true, 12000], ["1B", 1, 3, false, 9000], ["2A", 2, 2, true, 12000]]),
      coverHue: 265, rating: 4.5,
    }),
  ];

  // ── Tenants with history ────────────────────────────────
  const tenants: Tenant[] = [];
  const invoices: RentInvoice[] = [];
  const payments: Payment[] = [];
  let tenantCounter = 0;
  let nameIdx = 0;

  const occupy = (prop: Property, roomNo: string, bed: string, opts: { name?: string; phone?: string; email?: string; uid?: string; monthsAgo: number; gender?: Tenant["gender"]; payPattern?: "good" | "late" | "pendingUpi" }) => {
    const room = prop.rooms.find((r) => r.number === roomNo)!;
    const tid = `TEN${String(++tenantCounter).padStart(7, "0")}`;
    const name = opts.name ?? `${firstNames[nameIdx % firstNames.length]} ${lastNames[(nameIdx * 7) % lastNames.length]}`;
    nameIdx++;
    const moveIn = new Date(today.getFullYear(), today.getMonth() - opts.monthsAgo, Math.min(28, 3 + (nameIdx % 20)));
    const t: Tenant = {
      id: tid,
      businessId: prop.businessId,
      propertyId: prop.id,
      propertyName: prop.name,
      roomNumber: roomNo,
      bedNumber: bed,
      name,
      phone: opts.phone ?? `98${String(45000000 + nameIdx * 7919).slice(0, 8)}`,
      email: opts.email ?? `${name.split(" ")[0]!.toLowerCase()}.${name.split(" ")[1]!.toLowerCase()}@example.com`,
      gender: opts.gender ?? (prop.gender === "female" ? "female" : nameIdx % 2 ? "male" : "female"),
      uid: opts.uid,
      monthlyRent: room.rentPerBed,
      deposit: prop.pricing.deposit,
      maintenance: prop.pricing.maintenance,
      billingDay: Math.min(28, moveIn.getDate()),
      moveIn: moveIn.getTime(),
      status: "active",
      occupation: occupations[nameIdx % occupations.length],
      emergencyContact: `98${String(76000000 + nameIdx * 3571).slice(0, 8)}`,
      createdAt: moveIn.getTime(),
    };
    tenants.push(t);
    room.beds.find((b) => b.number === bed)!.tenantId = tid;

    for (let m = opts.monthsAgo; m >= 0; m--) {
      const d = new Date(today.getFullYear(), today.getMonth() - m, 1);
      const due = new Date(d.getFullYear(), d.getMonth(), t.billingDay).getTime();
      const inv: RentInvoice = {
        id: `${tid}_${periodOf(d)}`,
        businessId: prop.businessId,
        tenantId: tid,
        tenantName: t.name,
        propertyId: prop.id,
        amount: t.monthlyRent,
        month: monthLabel(d),
        periodMonth: periodOf(d),
        dueDate: due,
        status: "unpaid",
      };
      const isCurrent = m === 0;
      const pattern = opts.payPattern ?? "good";
      const paidThisMonth = !isCurrent || (pattern === "good" && due < now - DAY);
      if (paidThisMonth && !(pattern === "late" && m <= 1)) {
        const paidAt = Math.min(now - DAY, due + ((nameIdx + m) % 4) * DAY);
        inv.status = "paid";
        inv.paidAt = paidAt;
        const method = (["UPI", "Online", "Cash", "UPI"] as const)[(nameIdx + m) % 4];
        payments.push({
          id: `PAY-${tid}-${periodOf(d)}`,
          businessId: prop.businessId,
          tenantId: tid,
          tenantName: t.name,
          propertyId: prop.id,
          propertyName: prop.name,
          amount: t.monthlyRent,
          month: inv.month,
          method,
          reference: method === "Cash" ? undefined : String(412000000000 + (paidAt % 1e9)).slice(0, 12),
          status: "paid",
          invoiceId: inv.id,
          source: method === "Online" ? "gateway" : method === "Cash" ? "owner" : "tenant",
          createdAt: paidAt,
          verifiedAt: paidAt,
        });
      } else {
        inv.status = due < now ? "overdue" : "unpaid";
        if (isCurrent && pattern === "pendingUpi") {
          payments.push({
            id: `PAY-${tid}-pending`,
            businessId: prop.businessId,
            tenantId: tid,
            tenantName: t.name,
            propertyId: prop.id,
            propertyName: prop.name,
            amount: t.monthlyRent,
            month: inv.month,
            method: "UPI",
            reference: "441902773112",
            status: "pending",
            invoiceId: inv.id,
            source: "tenant",
            createdAt: now - 5 * 3600_000,
          });
        }
      }
      invoices.push(inv);
    }
    return t;
  };

  const [p1, p2, p3, p4, p5] = properties as [Property, Property, Property, Property, Property];
  occupy(p1, "101", "A", { name: "Rahul Mehta", phone: "9876511111", email: DEMO_ACCOUNTS.tenant, uid: "u-rahul", monthsAgo: 5, gender: "male" });
  occupy(p1, "101", "B", { monthsAgo: 4 });
  occupy(p1, "102", "A", { monthsAgo: 5, payPattern: "late" });
  occupy(p1, "102", "B", { monthsAgo: 3 });
  occupy(p1, "103", "A", { monthsAgo: 5, payPattern: "pendingUpi" });
  occupy(p1, "201", "A", { monthsAgo: 2 });
  occupy(p1, "201", "B", { monthsAgo: 4 });
  occupy(p1, "202", "A", { monthsAgo: 1 });
  occupy(p1, "202", "C", { monthsAgo: 5, payPattern: "late" });
  occupy(p1, "301", "A", { monthsAgo: 3 });
  occupy(p1, "302", "B", { monthsAgo: 2 });
  occupy(p2, "G1", "A", { monthsAgo: 1, gender: "female" });
  occupy(p2, "11", "A", { monthsAgo: 1, gender: "female" });
  occupy(p2, "11", "B", { monthsAgo: 1, gender: "female", payPattern: "late" });
  occupy(p2, "13", "A", { monthsAgo: 1, gender: "female" });
  occupy(p3, "A1", "A", { monthsAgo: 4, gender: "male" });
  occupy(p3, "B1", "B", { monthsAgo: 2, gender: "male" });
  occupy(p4, "301", "A", { monthsAgo: 3 });
  occupy(p4, "302", "C", { monthsAgo: 2 });
  occupy(p5, "1A", "A", { monthsAgo: 2, gender: "female" });

  // ── Open items ──────────────────────────────────────────
  const requests: EnrollmentRequest[] = [
    {
      id: "REQ-priya", tenantUid: "u-priya", tenantName: "Priya Desai", tenantPhone: "9876522222",
      businessId: "BUS0000001", propertyId: p1.id, propertyName: p1.name, moveIn: now + 6 * DAY,
      sharing: "Double sharing", notes: "Joining a new job at Koramangala next week. Prefer a room with AC.",
      status: "pending", createdAt: ago(1), updatedAt: ago(1),
    },
    {
      id: "REQ-kunal", tenantUid: "u-kunal", tenantName: "Kunal Shah", tenantPhone: "9876533333",
      businessId: "BUS0000001", propertyId: p1.id, propertyName: p1.name, moveIn: now + 2 * DAY,
      sharing: "Triple sharing", notes: "", status: "payment_submitted",
      roomNumber: "102", bedNumber: "C", monthlyRent: 9500, proratedRent: 0, deposit: 15000, maintenance: 1000, total: 25500,
      paymentMode: "upi", ownerUpiId: "sunrisestays@okhdfc", transactionId: "552810993421",
      createdAt: ago(4), updatedAt: ago(0.2),
    },
  ];

  const invitations: TenantInvitation[] = [
    {
      id: "INV-neha", businessId: "BUS0000001", businessName: "Sunrise Stays", propertyId: p1.id, propertyName: p1.name,
      roomNumber: "203", bedNumber: "A", tenantName: "Neha Kapoor", tenantPhone: "9876544444", tenantEmail: "neha@onestay.demo",
      gender: "female", monthlyRent: 11500, deposit: 15000, maintenance: 1000, proratedRent: 0, billingDay: 5,
      noticeDays: 30, lockInMonths: 3, moveIn: now + 4 * DAY, status: "pending", createdAt: ago(0.5),
    },
  ];

  const members: Member[] = [
    { id: "MEM-asha", businessId: "BUS0000001", uid: "u-asha", name: "Asha Rao", phone: "9876500001", email: DEMO_ACCOUNTS.owner, role: "owner", status: "active", propertyIds: [p1.id, p2.id], invitedAt: ago(240), joinedAt: ago(240) },
    { id: "MEM-vikram", businessId: "BUS0000001", uid: "u-vikram", name: "Vikram Singh", phone: "9876500002", email: DEMO_ACCOUNTS.manager, role: "manager", status: "active", propertyIds: [p1.id], invitedAt: ago(121), joinedAt: ago(120) },
    { id: "MEM-lakshmi", businessId: "BUS0000001", name: "Lakshmi N", phone: "9876500003", email: "lakshmi@onestay.demo", role: "staff", status: "invited", propertyIds: [p2.id], invitedAt: ago(2) },
  ];

  const maintenance: MaintenanceRequest[] = [
    { id: "MNT-1", tenantUid: "", tenantId: "TEN0000005", tenantName: tenants[4]!.name, tenantPhone: tenants[4]!.phone, businessId: "BUS0000001", propertyId: p1.id, propertyName: p1.name, roomNumber: "103", bedNumber: "A", category: "electrical", title: "AC not cooling", description: "The AC runs but the air is warm since yesterday evening.", urgent: true, status: "open", createdAt: ago(0.3), updatedAt: ago(0.3) },
    { id: "MNT-2", tenantUid: "", tenantId: "TEN0000007", tenantName: tenants[6]!.name, tenantPhone: tenants[6]!.phone, businessId: "BUS0000001", propertyId: p1.id, propertyName: p1.name, roomNumber: "201", bedNumber: "B", category: "plumbing", title: "Leaking tap in bathroom", description: "Tap keeps dripping through the night.", urgent: false, status: "in_progress", ownerNote: "Plumber booked for tomorrow 10am.", createdAt: ago(2), updatedAt: ago(1) },
    { id: "MNT-3", tenantUid: "u-rahul", tenantId: "TEN0000001", tenantName: "Rahul Mehta", tenantPhone: "9876511111", businessId: "BUS0000001", propertyId: p1.id, propertyName: p1.name, roomNumber: "101", bedNumber: "A", category: "internet", title: "WiFi drops every evening", description: "Router on floor 1 disconnects between 8 and 10pm.", urgent: false, status: "resolved", ownerNote: "Replaced the router with a dual-band unit.", createdAt: ago(12), updatedAt: ago(10) },
  ];

  const pins: PinNote[] = [
    { id: "PIN-1", propertyId: p1.id, authorUid: "u-other1", authorName: tenants[1]!.name, category: "food", content: "Ordering biryani from Meghana's tonight around 8 — anyone want to split?", createdAt: now - 2 * 3600_000, expiresAt: now + 46 * 3600_000 },
    { id: "PIN-2", propertyId: p1.id, authorUid: "u-other2", authorName: tenants[5]!.name, category: "lost_found", content: "Found a black water bottle in the study room. It's at the reception desk.", createdAt: now - 20 * 3600_000, expiresAt: now + 28 * 3600_000 },
    { id: "PIN-3", propertyId: p1.id, authorUid: "u-other3", authorName: tenants[9]!.name, category: "ride", content: "Driving to Electronic City at 9am on weekdays — 2 seats free.", createdAt: now - 30 * 3600_000, expiresAt: now + 18 * 3600_000 },
  ];

  const payoutMethods: PayoutMethod[] = [
    { id: "PM-1", businessId: "BUS0000001", type: "upi", label: "Business UPI", upiId: "sunrisestays@okhdfc", preferred: true, active: true, createdAt: ago(200) },
    { id: "PM-2", businessId: "BUS0000001", type: "bank", label: "HDFC current account", bankName: "HDFC Bank", accountNumber: "50200012345678", ifsc: "HDFC0000123", holder: "Sunrise Stays LLP", preferred: false, active: true, createdAt: ago(190) },
  ];

  const platformInvoices: PlatformInvoice[] = [];
  for (let m = 5; m >= 0; m--) {
    const start = new Date(today.getFullYear(), today.getMonth() - m, 1).getTime();
    const end = new Date(today.getFullYear(), today.getMonth() - m + 1, 0).getTime();
    const beds = p1.rooms.reduce((s, r) => s + r.beds.length, 0);
    platformInvoices.push({ id: `${p1.id}_${start}`, businessId: "BUS0000001", propertyId: p1.id, propertyName: p1.name, beds, pricePerBed: 30, amount: beds * 30, discount: 0, periodStart: start, periodEnd: end, status: "paid", paidAt: start + 2 * DAY, reference: `pay_${(start % 1e8).toString(36)}` });
  }

  const notifications: AppNotification[] = [
    { id: "N-1", uid: "u-asha", title: "New join request", body: "Priya Desai wants to join Sunrise Residency.", kind: "request", href: "/dashboard/owner/requests/", read: false, createdAt: ago(1) },
    { id: "N-2", uid: "u-asha", title: "Payment to verify", body: `${tenants[4]!.name} paid ₹21,000 by UPI for ${monthLabel(today)}.`, kind: "payment", href: "/dashboard/owner/payments/", read: false, createdAt: now - 5 * 3600_000 },
    { id: "N-3", uid: "u-asha", title: "Urgent maintenance", body: "AC not cooling — Room 103, Sunrise Residency.", kind: "maintenance", href: "/dashboard/owner/maintenance/", read: false, createdAt: ago(0.3) },
    { id: "N-4", uid: "u-asha", title: "First bill paid", body: "Kunal Shah submitted ₹25,500 for Room 102 · Bed C.", kind: "request", href: "/dashboard/owner/requests/", read: true, createdAt: ago(0.2) },
    { id: "N-5", uid: "u-rahul", title: "Maintenance resolved", body: "WiFi drops every evening — Replaced the router with a dual-band unit.", kind: "maintenance", href: "/dashboard/tenant/maintenance/", read: true, createdAt: ago(10) },
    { id: "N-6", uid: "u-rahul", title: `Rent for ${monthLabel(today)}`, body: `₹14,000 is due on ${new Date(tenants[0]!.billingDay ? new Date(today.getFullYear(), today.getMonth(), tenants[0]!.billingDay) : today).toLocaleDateString("en-IN", { day: "numeric", month: "short" })}.`, kind: "payment", href: "/dashboard/tenant/rent/", read: false, createdAt: ago(2) },
    { id: "N-7", uid: "u-vikram", title: "Urgent maintenance", body: "AC not cooling — Room 103, Sunrise Residency.", kind: "maintenance", href: "/dashboard/owner/maintenance/", read: false, createdAt: ago(0.3) },
  ];

  const activity: Activity[] = [
    { id: "A-1", businessId: "BUS0000001", text: "Kunal Shah paid the first bill for Room 102 · Bed C", kind: "request", at: ago(0.2) },
    { id: "A-2", businessId: "BUS0000001", text: "Maintenance raised: AC not cooling (Room 103)", kind: "maintenance", at: ago(0.3) },
    { id: "A-3", businessId: "BUS0000001", text: "Invited Neha Kapoor to Room 203 · Bed A", kind: "tenant", at: ago(0.5) },
    { id: "A-4", businessId: "BUS0000001", text: "Priya Desai requested to join Sunrise Residency", kind: "request", at: ago(1) },
    { id: "A-5", businessId: "BUS0000001", text: "Invited Lakshmi N as staff", kind: "team", at: ago(2) },
    { id: "A-6", businessId: "BUS0000001", text: `Platform bill paid for Sunrise Residency`, kind: "billing", at: ago(today.getDate() - 2) },
  ];

  return {
    version: STATE_VERSION,
    counters: { business: 2, tenant: tenantCounter, seq: 0 },
    users,
    businesses,
    properties,
    tenants,
    invoices,
    payments,
    requests,
    invitations,
    members,
    maintenance,
    pins,
    payoutMethods,
    platformInvoices,
    notifications,
    activity,
    promos: [
      { code: "WELCOME20", percent: 20 },
      { code: "ONESTAY50", percent: 50 },
    ],
  };
}
