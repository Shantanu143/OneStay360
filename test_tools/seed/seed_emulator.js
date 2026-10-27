#!/usr/bin/env node
/**
 * Seeds the LOCAL Firebase Emulator Suite (Auth + Firestore) with realistic dummy
 * data for one PG business so every screen in the business and tenant apps has
 * something to show.
 *
 * SAFETY: refuses to run unless FIRESTORE_EMULATOR_HOST and
 * FIREBASE_AUTH_EMULATOR_HOST point at this machine. It wipes the emulator's
 * data first, so it can be re-run at any time. It cannot touch production.
 *
 *   firebase emulators:start --only auth,firestore --project onestay360-1
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
 *     node test_tools/seed/seed_emulator.js
 *
 * Run the apps against it with:  flutter run --dart-define=USE_EMULATOR=true
 */
const path = require('path');
const admin = require(path.join(__dirname, '../../functions/node_modules/firebase-admin'));

const PROJECT_ID = 'onestay360-1'; // must match the apps' Firebase project id
const LOCAL = /^(localhost|127\.0\.0\.1|\[::1\]):\d+$/;
const fsHost = process.env.FIRESTORE_EMULATOR_HOST || '';
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || '';
if (!LOCAL.test(fsHost) || !LOCAL.test(authHost)) {
  console.error('Refusing to run: FIRESTORE_EMULATOR_HOST and FIREBASE_AUTH_EMULATOR_HOST must point at localhost.');
  console.error(`  FIRESTORE_EMULATOR_HOST=${fsHost || '<unset>'}  FIREBASE_AUTH_EMULATOR_HOST=${authHost || '<unset>'}`);
  process.exit(1);
}

admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();
const auth = admin.auth();
const { Timestamp } = admin.firestore;

// ─── helpers ────────────────────────────────────────────────────────────────
const DAY = 86400000;
const NOW = new Date();
const ago = (days) => new Date(NOW.getTime() - days * DAY);
const ts = (d) => Timestamp.fromDate(d);
const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const monthLabel = (d) => `${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
const periodOf = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
const monthsBack = (n) => new Date(NOW.getFullYear(), NOW.getMonth() - n, 1);
const pad = (n, w) => String(n).padStart(w, '0');
const img = (seed) => `https://picsum.photos/seed/${seed}/900/600`;

const writer = db.bulkWriter();
writer.onWriteError((err) => { console.error('write failed', err.documentRef.path, err.message); return false; });
const set = (p, data) => { writer.set(db.doc(p), data); };

const PASSWORD = 'Test@1234';
const BUS = 'BUS0000001';
const BUS_NAME = 'Sunrise Stays';
const OWNER_UPI = 'sunrisestays@okhdfcbank';

// ─── people with logins ─────────────────────────────────────────────────────
const LOGINS = [
  { uid: 'u_owner', email: 'owner@onestay360.test', name: 'Rajesh Sharma', phone: '+919000000001', role: 'owner' },
  { uid: 'u_manager', email: 'manager@onestay360.test', name: 'Priya Nair', phone: '+919000000002', role: 'manager' },
  { uid: 'u_staff', email: 'staff@onestay360.test', name: 'Amit Verma', phone: '+919000000003', role: 'staff' },
  { uid: 'u_ten_rohan', email: 'rohan@onestay360.test', name: 'Rohan Mehta', phone: '+919000000101', role: 'tenant', tenantId: 'TEN0000001' },
  { uid: 'u_ten_ananya', email: 'ananya@onestay360.test', name: 'Ananya Iyer', phone: '+919000000102', role: 'tenant', tenantId: 'TEN0000014' },
  { uid: 'u_ten_karan', email: 'karan@onestay360.test', name: 'Karan Singh', phone: '+919000000103', role: 'tenant', tenantId: 'TEN0000028' },
];

// ─── properties ─────────────────────────────────────────────────────────────
// room = [roomNumber, floor, sharing, hasAC, genderLock]
const PRICES = {
  Bangalore: { 1: [14000, 17000], 2: [9500, 11500], 3: [7500, 9000], 4: [6000, 7500] },
  Pune: { 1: [12000, 14500], 2: [8000, 10000], 3: [6500, 8000], 4: [5200, 6500] },
};
const PROPS = [
  {
    id: `${BUS}BLR001`, name: 'Sunrise Boys PG', city: 'Bangalore', cityCode: 'BLR', pincode: '560034', floors: 3,
    address: '12, 5th Cross, 4th Block, Koramangala, Bangalore', landmarks: 'Near Forum Mall, 5 min walk to Sony Signal',
    description: 'Well-maintained boys PG in the heart of Koramangala. Walking distance to startups, cafes and the metro feeder. Daily housekeeping, high-speed WiFi and home-style meals.',
    gender: 'Male', status: 'active', billingStatus: 'paid', featured: true, rating: { average: 4.4, count: 37 },
    amenities: { wifi: true, ac: true, laundry: true, foodIncluded: true, parking: true, geyser: true, powerBackup: true, cctv: true, housekeeping: true },
    food: { breakfast: true, lunch: false, dinner: true },
    rooms: [['101', '1', 2, false], ['102', '1', 3, true], ['103', '1', 2, false], ['201', '2', 4, false], ['202', '2', 2, true], ['203', '2', 1, true], ['301', '3', 3, false], ['302', '3', 2, true]],
    fill: { '101': 2, '102': 3, '103': 1, '201': 3, '202': 2, '203': 1, '301': 1 },
  },
  {
    id: `${BUS}BLR002`, name: 'Lotus Ladies Hostel', city: 'Bangalore', cityCode: 'BLR', pincode: '560038', floors: 3,
    address: '44, 12th Main, HAL 2nd Stage, Indiranagar, Bangalore', landmarks: 'Opposite Indiranagar Metro, 200 m from 100 Feet Road',
    description: 'Safe and secure ladies hostel with biometric entry, 24x7 warden and CCTV. Fully furnished rooms with attached study desks and wardrobes.',
    gender: 'Female', status: 'active', billingStatus: 'due', featured: false, rating: { average: 4.6, count: 52 },
    amenities: { wifi: true, ac: true, laundry: true, foodIncluded: true, parking: false, geyser: true, powerBackup: true, cctv: true, housekeeping: true },
    food: { breakfast: true, lunch: true, dinner: true },
    rooms: [['G1', 'Ground', 2, false], ['G2', 'Ground', 3, false], ['101', '1', 2, true], ['102', '1', 4, false], ['201', '2', 2, true], ['202', '2', 3, true]],
    fill: { 'G1': 2, 'G2': 2, '101': 2, '102': 2, '201': 1, '202': 1 },
  },
  {
    id: `${BUS}PUN001`, name: 'Skyline Executive Stay', city: 'Pune', cityCode: 'PUN', pincode: '411014', floors: 2,
    address: 'Plot 7, EON IT Park Road, Kharadi, Pune', landmarks: 'Next to EON IT Park, 10 min from Pune Airport',
    description: 'Co-living for working professionals near Kharadi tech parks. Single and twin rooms with AC, gym access and weekly housekeeping.',
    gender: 'Co-ed', status: 'active', billingStatus: 'paid', featured: false, rating: { average: 4.1, count: 14 },
    amenities: { wifi: true, ac: true, laundry: true, foodIncluded: false, parking: true, geyser: true, powerBackup: true, cctv: true, housekeeping: true },
    food: { breakfast: false, lunch: false, dinner: false },
    rooms: [['A1', '1', 1, true, 'Male'], ['A2', '1', 1, true, 'Female'], ['A3', '1', 2, true, 'Female'], ['B1', '2', 2, false, 'Male'], ['B2', '2', 3, false, 'Male']],
    fill: { A1: 1, A2: 1, A3: 1, B1: 1 }, // tenants are placed explicitly below; this only feeds the available-bed count
  },
  {
    id: `${BUS}PUN002`, name: 'Green Valley Co-living', city: 'Pune', cityCode: 'PUN', pincode: '411045', floors: 1,
    address: '21, Baner-Pashan Link Road, Baner, Pune', landmarks: 'Behind Balewadi High Street',
    description: 'New property, setup in progress.',
    gender: 'Co-ed', status: 'draft', billingStatus: 'payment_due', featured: false, rating: { average: 0, count: 0 },
    amenities: { wifi: true, ac: false, laundry: false, foodIncluded: false, parking: true, geyser: true, powerBackup: true, cctv: false, housekeeping: false },
    food: { breakfast: false, lunch: false, dinner: false },
    rooms: [['101', '1', 2, false], ['102', '1', 3, false], ['103', '1', 4, false]],
    fill: {},
  },
];
const priceFor = (p, sharing, ac) => PRICES[p.city][sharing][ac ? 1 : 0];

// ─── tenants (27 staying + 1 prospective) ──────────────────────────────────
// [id, name, gender, propIdx, uid?]
const TENANTS = [
  ['TEN0000001', 'Rohan Mehta', 'Male', 0, 'u_ten_rohan'], ['TEN0000002', 'Arjun Reddy', 'Male', 0], ['TEN0000003', 'Vikram Patel', 'Male', 0],
  ['TEN0000004', 'Sandeep Kumar', 'Male', 0], ['TEN0000005', 'Karthik Iyer', 'Male', 0], ['TEN0000006', 'Aditya Singh', 'Male', 0],
  ['TEN0000007', 'Manish Gupta', 'Male', 0], ['TEN0000008', 'Rahul Desai', 'Male', 0], ['TEN0000009', 'Nikhil Joshi', 'Male', 0],
  ['TEN0000010', 'Siddharth Rao', 'Male', 0], ['TEN0000011', 'Faizan Ali', 'Male', 0], ['TEN0000012', 'Harsh Vardhan', 'Male', 0],
  ['TEN0000013', 'Pranav Nair', 'Male', 0],
  ['TEN0000014', 'Ananya Iyer', 'Female', 1, 'u_ten_ananya'], ['TEN0000015', 'Sneha Kulkarni', 'Female', 1], ['TEN0000016', 'Divya Menon', 'Female', 1],
  ['TEN0000017', 'Pooja Sharma', 'Female', 1], ['TEN0000018', 'Ritika Jain', 'Female', 1], ['TEN0000019', 'Neha Agarwal', 'Female', 1],
  ['TEN0000020', 'Shruti Bhat', 'Female', 1], ['TEN0000021', 'Kavya Reddy', 'Female', 1], ['TEN0000022', 'Isha Malhotra', 'Female', 1],
  ['TEN0000023', 'Meera Nambiar', 'Female', 1],
  ['TEN0000024', 'Aarav Kapoor', 'Male', 2, null, ['A1', 1]], ['TEN0000025', 'Tanvi Deshmukh', 'Female', 2, null, ['A2', 1]],
  ['TEN0000026', 'Zoya Khan', 'Female', 2, null, ['A3', 1]], ['TEN0000027', 'Rishi Banerjee', 'Male', 2, null, ['B1', 1]],
];
const COMPANIES = ['Flipkart', 'Swiggy', 'Razorpay', 'Infosys', 'Zerodha', 'Cred', 'Thoughtworks', 'Intel', 'Amazon', 'PhonePe'];

// ─── build ──────────────────────────────────────────────────────────────────
async function resetEmulators() {
  const f = await fetch(`http://${fsHost}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`, { method: 'DELETE' });
  const a = await fetch(`http://${authHost}/emulator/v1/projects/${PROJECT_ID}/accounts`, { method: 'DELETE' });
  if (!f.ok || !a.ok) throw new Error(`Emulator reset failed (firestore ${f.status}, auth ${a.status}). Is the emulator running?`);
}

async function main() {
  await resetEmulators();

  // Auth users
  for (const u of LOGINS) {
    await auth.createUser({ uid: u.uid, email: u.email, password: PASSWORD, displayName: u.name, phoneNumber: u.phone, emailVerified: true });
  }

  // users/{uid}
  for (const u of LOGINS) {
    const base = { uid: u.uid, email: u.email, fullName: u.name, name: u.name, phone: u.phone, mobileNumber: u.phone, authProviders: ['password'], createdAt: ts(ago(120)), updatedAt: ts(ago(2)), profileCompleted: true };
    if (u.role === 'tenant') {
      set(`users/${u.uid}`, { ...base, tenantId: u.tenantId, isTenant: true, profileComplete: true });
    } else {
      set(`users/${u.uid}`, { ...base, businessId: BUS, businessName: BUS_NAME });
    }
  }

  // business + team
  set(`businesses/${BUS}`, { id: BUS, name: BUS_NAME, ownerUid: 'u_owner', ownerUserId: 'u_owner', contactPhone: '+919000000001', contactEmail: 'owner@onestay360.test', createdAt: ts(ago(120)) });
  for (const u of LOGINS.filter((x) => x.role !== 'tenant')) {
    set(`businesses/${BUS}/members/${u.uid}`, { uid: u.uid, businessId: BUS, role: u.role, status: 'active', name: u.name, displayName: u.name, email: u.email, phone: u.phone, createdAt: ts(ago(u.role === 'owner' ? 120 : 60)), updatedAt: ts(ago(5)) });
  }
  set('plans/standard', { id: 'standard', name: 'Standard', pricePerBedInr: 30, isActive: true, isDefault: true });
  set('counters/tenant_counter', { count: 28 });
  set('counters/business_counter', { count: 1 });
  set('counters/property_BUS0000001_BLR', { count: 2 });
  set('counters/property_BUS0000001_PUN', { count: 2 });

  // payment methods + razorpay public settings
  set(`businesses/${BUS}/paymentMethods/pm_upi`, { id: 'pm_upi', businessId: BUS, type: 'upi', upiId: OWNER_UPI, phoneNumber: '+919000000001', accountHolderName: 'Rajesh Sharma', isActive: true, isPreferred: true, createdAt: ts(ago(100)), updatedAt: ts(ago(100)) });
  set(`businesses/${BUS}/paymentMethods/pm_bank`, { id: 'pm_bank', businessId: BUS, type: 'bank', accountHolderName: 'Sunrise Stays', accountNumber: '50100234567890', ifscCode: 'HDFC0000123', bankName: 'HDFC Bank', accountType: 'Current', isActive: true, isPreferred: false, createdAt: ts(ago(100)), updatedAt: ts(ago(100)) });
  set(`businesses/${BUS}/paymentMethods/pm_cash`, { id: 'pm_cash', businessId: BUS, type: 'cash', isActive: true, isPreferred: false, createdAt: ts(ago(100)), updatedAt: ts(ago(100)) });
  set(`businesses/${BUS}/settings/razorpay`, { paymentsEnabled: true, verified: true, verifiedAt: ts(ago(90)), merchantId: 'acc_DEMO000001', merchantName: BUS_NAME, upiId: OWNER_UPI, kycStatus: 'activated', businessId: BUS, updatedAt: ts(ago(90)) });

  // properties, rooms, beds
  const bedMap = {}; // propId -> room -> [beds]
  const roomsByProp = PROPS.map((p, pi) => {
    const rooms = p.rooms.map(([num, floor, sharing, hasAC, lock]) => ({ num, floor, sharing, hasAC, gender: lock || (p.gender === 'Co-ed' ? null : p.gender) }));
    const totalBeds = rooms.reduce((s, r) => s + r.sharing, 0);
    const rentFor = (r) => priceFor(p, r.sharing, r.hasAC);
    const pricing = {
      single: priceFor(p, 1, false), double: priceFor(p, 2, false), triple: priceFor(p, 3, false), quad: priceFor(p, 4, false),
      securityDeposit: 10000, oneTimeMaintenance: 1000, maintenanceDeductedFromDeposit: false, maxSharing: 4,
      sharing: [1, 2, 3, 4].map((s) => ({ sharing: s, nonAc: PRICES[p.city][s][0], ac: PRICES[p.city][s][1] })),
    };
    const active = p.status === 'active';
    const base = {
      id: p.id, propertyId: p.id, name: p.name, address: p.address, city: p.city, cityCode: p.cityCode, pincode: p.pincode,
      propertyType: 'PG', state: p.city === 'Pune' ? 'Maharashtra' : 'Karnataka',
      numberOfFloors: p.floors, description: p.description, landmarks: p.landmarks, googleMapsLink: `https://maps.google.com/?q=${encodeURIComponent(p.address)}`,
      pricing, amenities: p.amenities, foodPlan: { plan: p.food, notes: p.food.breakfast ? 'Veg and non-veg options on Sundays.' : '' },
      rules: { genderAllowed: p.gender, curfew: p.gender === 'Female', visitorsAllowed: p.gender !== 'Female', smokingAllowed: false, alcoholAllowed: false, noticePeriodDays: 30 },
      totals: { rooms: rooms.length, beds: totalBeds, availableBeds: totalBeds - Object.values(p.fill).reduce((a, b) => a + b, 0) },
      images: [img(`${p.cityCode}${pi}a`), img(`${p.cityCode}${pi}b`), img(`${p.cityCode}${pi}c`)],
      rating: p.rating, status: p.status, billingStatus: p.billingStatus, pricePerBed: 30,
      totalBeds, activeBedCount: active ? totalBeds : 0, billedBedCount: active ? totalBeds : 0,
      billingStartDate: active ? ts(ago(75)) : null, nextBillingDate: active ? ts(new Date(NOW.getTime() + (p.billingStatus === 'due' ? -2 : 19) * DAY)) : null,
      lastPaymentId: active && p.billingStatus === 'paid' ? `pay_DEMO${pi}001` : null,
      plan: { id: 'standard', name: 'Standard', pricePerBedInr: 30 },
      businessId: BUS, businessName: BUS_NAME, businessPhone: '+919000000001', featured: p.featured,
      createdAt: ts(ago(active ? 90 : 3)), updatedAt: ts(ago(active ? 1 : 0)),
    };
    set(`businesses/${BUS}/properties/${p.id}`, base);
    set(`properties_by_city/${p.city}/properties/${p.id}`, base);
    for (const r of rooms) {
      const roomPath = `businesses/${BUS}/properties/${p.id}/rooms/${r.num}`;
      set(roomPath, { roomNumber: r.num, floor: r.floor, occupancyType: ['', 'Single', 'Double', 'Triple', 'Quad'][r.sharing] + ' Sharing', sharingType: r.sharing, hasAC: r.hasAC, status: 'available', gender: r.gender, isActive: active, rent: rentFor(r) });
    }
    bedMap[p.id] = {};
    return { p, rooms };
  });
  for (const c of ['Bangalore', 'Pune', 'Mumbai']) set(`properties_by_city/${c}`, { name: c, updatedAt: ts(NOW) });

  // allocate tenants to beds
  const cursor = {}; // propId -> room -> next bed
  const placed = [];
  for (const [id, name, gender, pi, uid, forced] of TENANTS) {
    const { p, rooms } = roomsByProp[pi];
    let room, bed;
    if (forced) { room = rooms.find((r) => r.num === forced[0]); bed = forced[1]; }
    else {
      room = rooms.find((r) => ((cursor[`${p.id}|${r.num}`] || 0) < (p.fill[r.num] || 0)));
      bed = (cursor[`${p.id}|${room.num}`] || 0) + 1;
    }
    cursor[`${p.id}|${room.num}`] = Math.max(cursor[`${p.id}|${room.num}`] || 0, bed);
    placed.push({ id, name, gender, p, room, bed, uid });
  }
  // occupancy bookkeeping
  const occupied = {};
  placed.forEach((t) => { (occupied[`${t.p.id}|${t.room.num}`] ||= []).push(t.bed); });
  roomsByProp.forEach(({ p, rooms }) => rooms.forEach((r) => {
    for (let b = 1; b <= r.sharing; b++) {
      const t = placed.find((x) => x.p.id === p.id && x.room.num === r.num && x.bed === b);
      const path = `businesses/${BUS}/properties/${p.id}/rooms/${r.num}/beds/${b}`;
      if (t) set(path, { bedNumber: String(b), isOccupied: true, occupied: true, isActive: true, tenantId: t.id, tenantName: t.name, rent: priceFor(p, r.sharing, r.hasAC), occupiedAt: ts(ago(40 + (placed.indexOf(t) * 7) % 220)) });
      else set(path, { bedNumber: String(b), isOccupied: false, occupied: false, isActive: p.status === 'active' });
    }
  }));
  // mark full rooms as occupied and lock a room's gender to its first tenant
  roomsByProp.forEach(({ p, rooms }) => rooms.forEach((r) => {
    const occ = (occupied[`${p.id}|${r.num}`] || []).length;
    const path = `businesses/${BUS}/properties/${p.id}/rooms/${r.num}`;
    writer.set(db.doc(path), { status: occ >= r.sharing ? 'occupied' : 'available', gender: r.gender || (occ ? placed.find((x) => x.p.id === p.id && x.room.num === r.num).gender : null) }, { merge: true });
  }));

  // tenant records, rent invoices, payments
  let pendingCount = 0;
  const thisMonth = monthsBack(0);
  placed.forEach((t, i) => {
    const sharing = t.room.sharing;
    const rent = priceFor(t.p, sharing, t.room.hasAC);
    const phone = `+9190000002${pad(i + 1, 2)}`;
    const email = `${t.name.toLowerCase().replace(/[^a-z]+/g, '.')}@example.test`;
    const stayDays = t.id === 'TEN0000001' ? 210 : t.id === 'TEN0000014' ? 150 : 30 + ((i * 37) % 260);
    const checkIn = ago(stayDays);
    const billingDate = t.id === 'TEN0000001' ? 24 : Math.min(28, checkIn.getDate());
    const login = LOGINS.find((l) => l.uid === t.uid);
    const tenantData = {
      id: t.id, tenantId: t.id, userId: t.uid || null, name: t.name, fullName: t.name, phone: login ? login.phone : phone, mobileNumber: login ? login.phone : phone,
      email: login ? login.email : email, gender: t.gender, propertyId: t.p.id, businessId: BUS, roomId: t.room.num, bedId: String(t.bed),
      roomNumber: t.room.num, bedNumber: String(t.bed), propertyName: t.p.name, monthlyRent: rent, checkInDate: ts(checkIn), status: 'active',
      nationality: 'Indian', motherTongue: ['Hindi', 'Kannada', 'Tamil', 'Telugu', 'Malayalam', 'Marathi'][i % 6], idType: 'Aadhaar', idNumber: `XXXX XXXX ${pad(1000 + i * 37, 4)}`,
      addressLine1: `${10 + i}, MG Road`, city: ['Jaipur', 'Hyderabad', 'Chennai', 'Kochi', 'Nagpur', 'Lucknow'][i % 6], pincode: `${400000 + i * 113}`,
      alternatePhone: `+9190000003${pad(i + 1, 2)}`, emergencyContactName: `${t.name.split(' ')[1]} (Parent)`, emergencyContactPhone: `+9190000004${pad(i + 1, 2)}`,
      dateOfBirth: `${1996 + (i % 8)}-0${1 + (i % 9)}-1${i % 9}`, officeInstituteName: COMPANIES[i % COMPANIES.length], officeInstituteId: `EMP${1000 + i}`,
      enrollmentRequestId: null, createdAt: ts(checkIn), updatedAt: ts(ago(3)), linkedAt: t.uid ? ts(checkIn) : null, inviteSentAt: null,
      additionalInfo: { depositAmount: 10000, maintenanceAmount: 1000, foodAddon: t.p.food.breakfast ? 3000 : 0, foodDeduction: 0, proratedRent: 0, totalFirstMonth: rent + 11000, paymentMode: 'UPI', transactionId: `UTR${420000000000 + i * 7919}`, billingDate },
    };
    set(`tenants/${t.id}`, tenantData);
    set(`businesses/${BUS}/tenants/${t.id}`, { ...tenantData, lastPaymentDate: ts(ago(i % 25)), lastPaymentAmount: rent, lastPaymentMonth: monthLabel(i % 10 === 8 ? monthsBack(1) : thisMonth) });
    const stayId = `stay_${t.id}`;
    set(`tenants/${t.id}/stays/${stayId}`, { stayId, propertyId: t.p.id, businessId: BUS, roomId: t.room.num, bedId: String(t.bed), roomNumber: t.room.num, bedNumber: String(t.bed), propertyName: t.p.name, monthlyRent: rent, checkInDate: ts(checkIn), status: 'active', createdAt: ts(checkIn), updatedAt: ts(checkIn), hasAC: t.room.hasAC, sharingType: sharing, occupancyType: `${['', 'Single', 'Double', 'Triple', 'Quad'][sharing]} Sharing` });

    // invoice state for this month
    let state = ['paid', 'paid', 'paid', 'paid', 'paid', 'paid', 'unpaid', 'unpaid', 'overdue', 'pending'][i % 10];
    if (t.id === 'TEN0000001') state = 'unpaid'; // Rohan: shows the tenant app "Rent due" flow
    if (t.id === 'TEN0000014') state = 'paid';   // Ananya: all caught up
    if (t.id === 'TEN0000012') state = 'rejected';
    if (state === 'pending') pendingCount++;
    const methods = ['Razorpay', 'UPI', 'Cash'];

    // up to 3 previous months, all paid
    const months = Math.min(3, Math.floor(stayDays / 30));
    for (let m = months; m >= 1; m--) {
      const d = monthsBack(m);
      const invId = `inv_${t.id}_${periodOf(d)}`;
      const paidAt = new Date(d.getFullYear(), d.getMonth(), Math.min(28, billingDate) + (i % 4));
      const method = methods[(i + m) % 3];
      set(`businesses/${BUS}/tenants/${t.id}/rent_invoices/${invId}`, { invoiceId: invId, tenantId: t.id, businessId: BUS, propertyId: t.p.id, amount: rent, month: monthLabel(d), periodMonth: periodOf(d), dueDate: ts(new Date(d.getFullYear(), d.getMonth(), billingDate + 5)), status: 'paid', verification: 'verified', mode: method.toLowerCase(), razorpayPaymentLinkId: null, razorpayPaymentLinkUrl: null, razorpayPaymentId: method === 'Razorpay' ? `pay_DEMO${i}${m}` : null, paidAt: ts(paidAt), createdAt: ts(d), updatedAt: ts(paidAt) });
      set(`businesses/${BUS}/tenants/${t.id}/payments/pay_${t.id}_${periodOf(d)}`, { id: `pay_${t.id}_${periodOf(d)}`, tenantId: t.id, businessId: BUS, propertyId: t.p.id, tenantName: t.name, roomNumber: t.room.num, bedNumber: String(t.bed), amount: rent, month: monthLabel(d), date: ts(paidAt), status: 'Paid', verification: 'verified', method, mode: method.toLowerCase(), transactionId: method === 'Cash' ? null : `UTR${510000000000 + i * 131 + m}`, razorpayPaymentId: method === 'Razorpay' ? `pay_DEMO${i}${m}` : null, rentInvoiceId: invId, submittedBy: method === 'Razorpay' ? 'system' : 'tenant', recordedBy: method === 'Razorpay' ? 'razorpay_webhook' : 'u_owner', verifiedBy: method === 'Razorpay' ? null : 'u_owner', verifiedAt: ts(paidAt), createdAt: ts(paidAt) });
    }
    // current month
    const invId = `inv_${t.id}_${periodOf(thisMonth)}`;
    const due = new Date(thisMonth.getFullYear(), thisMonth.getMonth(), billingDate + 5);
    const overdue = state === 'overdue' || (state === 'unpaid' && due < NOW) || state === 'pending' && due < NOW;
    const invStatus = state === 'paid' ? 'paid' : overdue ? 'overdue' : 'unpaid';
    const paidAt = ago(1 + (i % 6));
    const method = methods[i % 3];
    set(`businesses/${BUS}/tenants/${t.id}/rent_invoices/${invId}`, { invoiceId: invId, tenantId: t.id, businessId: BUS, propertyId: t.p.id, amount: rent, month: monthLabel(thisMonth), periodMonth: periodOf(thisMonth), dueDate: ts(due), status: invStatus, verification: state === 'paid' ? 'verified' : 'unverified', mode: state === 'paid' ? method.toLowerCase() : null, razorpayPaymentLinkId: null, razorpayPaymentLinkUrl: null, razorpayPaymentId: state === 'paid' && method === 'Razorpay' ? `pay_DEMO${i}0` : null, paidAt: state === 'paid' ? ts(paidAt) : null, createdAt: ts(new Date(thisMonth.getFullYear(), thisMonth.getMonth(), billingDate)), updatedAt: ts(NOW) });
    const payBase = { tenantId: t.id, businessId: BUS, propertyId: t.p.id, tenantName: t.name, roomNumber: t.room.num, bedNumber: String(t.bed), amount: rent, month: monthLabel(thisMonth), rentInvoiceId: invId };
    if (state === 'paid') {
      set(`businesses/${BUS}/tenants/${t.id}/payments/pay_${t.id}_${periodOf(thisMonth)}`, { ...payBase, id: `pay_${t.id}_${periodOf(thisMonth)}`, date: ts(paidAt), status: 'Paid', verification: 'verified', method, mode: method.toLowerCase(), transactionId: method === 'Cash' ? null : `UTR${620000000000 + i * 211}`, razorpayPaymentId: method === 'Razorpay' ? `pay_DEMO${i}0` : null, submittedBy: method === 'Razorpay' ? 'system' : 'tenant', recordedBy: method === 'Razorpay' ? 'razorpay_webhook' : 'u_owner', verifiedBy: method === 'Razorpay' ? null : 'u_owner', verifiedAt: ts(paidAt), createdAt: ts(paidAt) });
    } else if (state === 'pending') {
      set(`businesses/${BUS}/tenants/${t.id}/payments/pay_${t.id}_${periodOf(thisMonth)}`, { ...payBase, id: `pay_${t.id}_${periodOf(thisMonth)}`, date: ts(ago(0.2)), status: 'pending_verification', method: 'UPI', transactionId: `UTR${730000000000 + i * 17}`, screenshotUrl: img(`upi${i}`), submittedBy: 'tenant', createdAt: ts(ago(0.2)), paymentSubmittedAt: ts(ago(0.2)) });
    } else if (state === 'rejected') {
      set(`businesses/${BUS}/tenants/${t.id}/payments/pay_${t.id}_${periodOf(thisMonth)}`, { ...payBase, id: `pay_${t.id}_${periodOf(thisMonth)}`, date: ts(ago(2)), status: 'rejected', method: 'UPI', transactionId: `UTR${740000000000 + i}`, submittedBy: 'tenant', rejectionReason: 'Amount received does not match the invoice. Please pay the full ₹' + rent + '.', rejectedBy: 'u_owner', rejectedAt: ts(ago(1)), createdAt: ts(ago(2)) });
    }
  });

  // prospective tenant Karan (profile only, no PG yet) + documents
  set('tenants/TEN0000028', { id: 'TEN0000028', tenantId: 'TEN0000028', userId: 'u_ten_karan', name: 'Karan Singh', fullName: 'Karan Singh', phone: '+919000000103', mobileNumber: '+919000000103', email: 'karan@onestay360.test', gender: 'Male', dateOfBirth: '1999-05-14', nationality: 'Indian', motherTongue: 'Hindi', idType: 'Aadhaar', idNumber: 'XXXX XXXX 4821', addressLine1: '88, Civil Lines', city: 'Lucknow', pincode: '226001', emergencyContactName: 'Ajay Singh (Father)', emergencyContactPhone: '+919000000999', officeInstituteName: 'Infosys', officeInstituteId: 'EMP5521', status: 'inactive', createdAt: ts(ago(10)), updatedAt: ts(ago(1)) });
  for (const [tid, uid] of [['TEN0000001', 'u_ten_rohan'], ['TEN0000014', 'u_ten_ananya'], ['TEN0000028', 'u_ten_karan']]) {
    set(`tenants/${tid}/documents/doc_aadhaar`, { tenantId: tid, type: 'aadhar', documentUrl: img(`aadhaar${tid}`), fileName: 'aadhaar-front.jpg', uploadedAt: ts(ago(30)) });
  }

  // enrollment requests (pipeline across every status)
  const REQ = (id, { age = 1, ...o }) => set(`enrollmentRequests/${id}`, { requestId: id, businessId: BUS, createdAt: ts(ago(age)), updatedAt: ts(ago(Math.max(0, age - 0.5))), kycDocumentUrl: img(`kyc${id}`), notes: '', roomType: 'Double Sharing', sharingType: '2', ...o });
  const P = PROPS;
  REQ('req_pending_1', { tenantId: 'u_prospect_1', tenantName: 'Mohit Saxena', tenantPhone: '+919000000501', tenantEmail: 'mohit@example.test', propertyId: P[0].id, propertyName: P[0].name, moveInDate: ts(ago(-6)), status: 'pending', notes: 'Joining Flipkart, need a quiet room. Prefer AC.', age: 0.1 });
  REQ('req_pending_2', { tenantId: 'u_prospect_2', tenantName: 'Ishaan Chopra', tenantPhone: '+919000000502', tenantEmail: 'ishaan@example.test', propertyId: P[0].id, propertyName: P[0].name, moveInDate: ts(ago(-12)), status: 'pending', roomType: 'Triple Sharing', sharingType: '3', age: 0.4 });
  REQ('req_pending_3', { tenantId: 'u_prospect_3', tenantName: 'Aditi Rao', tenantPhone: '+919000000503', tenantEmail: 'aditi@example.test', propertyId: P[1].id, propertyName: P[1].name, moveInDate: ts(ago(-9)), status: 'pending', notes: 'Intern at Razorpay for 6 months.', age: 0.8 });
  REQ('req_bill_sent', { tenantId: 'u_ten_karan', tenantName: 'Karan Singh', tenantPhone: '+919000000103', tenantEmail: 'karan@example.test', propertyId: P[0].id, propertyName: P[0].name, moveInDate: ts(ago(-4)), status: 'bill_sent', roomId: '302', bedId: '2', roomNumber: '302', bedNumber: '2', monthlyRent: 11500, depositAmount: 10000, maintenanceAmount: 1000, advanceAmount: 0, foodAddon: 3000, foodDeduction: 0, proratedRent: 0, totalFirstMonth: 25500, totalBillAmount: 25500, billingDate: 1, ownerUpiId: OWNER_UPI, billSentAt: ts(ago(0.3)), age: 2 });
  REQ('req_payment_submitted', { tenantId: 'u_prospect_4', tenantName: 'Devansh Trivedi', tenantPhone: '+919000000504', tenantEmail: 'devansh@example.test', propertyId: P[2].id, propertyName: P[2].name, moveInDate: ts(ago(-2)), status: 'payment_submitted', roomId: 'B2', bedId: '2', roomNumber: 'B2', bedNumber: '2', monthlyRent: 6500, depositAmount: 10000, maintenanceAmount: 1000, advanceAmount: 0, foodAddon: 0, foodDeduction: 0, proratedRent: 0, totalFirstMonth: 17500, totalBillAmount: 17500, billingDate: 1, ownerUpiId: OWNER_UPI, paymentMode: 'UPI', transactionId: 'UTR982736451209', paymentSubmittedAt: ts(ago(0.1)), age: 3 });
  REQ('req_confirmed_1', { tenantId: 'u_ten_rohan', tenantName: 'Rohan Mehta', tenantPhone: '+919000000101', tenantEmail: 'rohan@onestay360.test', propertyId: P[0].id, propertyName: P[0].name, moveInDate: ts(ago(210)), status: 'confirmed', roomId: '101', bedId: '1', roomNumber: '101', bedNumber: '1', monthlyRent: 9500, totalFirstMonth: 20500, totalBillAmount: 20500, paymentMode: 'UPI', transactionId: 'UTR420000000000', tenantDocId: 'TEN0000001', completedAt: ts(ago(209)), age: 212 });
  REQ('req_confirmed_2', { tenantId: 'u_ten_ananya', tenantName: 'Ananya Iyer', tenantPhone: '+919000000102', tenantEmail: 'ananya@onestay360.test', propertyId: P[1].id, propertyName: P[1].name, moveInDate: ts(ago(150)), status: 'confirmed', roomId: 'G1', bedId: '1', roomNumber: 'G1', bedNumber: '1', monthlyRent: 9500, totalFirstMonth: 20500, totalBillAmount: 20500, paymentMode: 'Razorpay', tenantDocId: 'TEN0000014', completedAt: ts(ago(149)), age: 152 });
  REQ('req_rejected', { tenantId: 'u_prospect_5', tenantName: 'Yash Malhotra', tenantPhone: '+919000000505', propertyId: P[1].id, propertyName: P[1].name, moveInDate: ts(ago(-20)), status: 'rejected', rejectionReason: 'This property is for women only.', age: 6 });

  // notifications
  const bn = (id, o) => set(`businesses/${BUS}/notifications/${id}`, { businessId: BUS, read: false, ...o });
  bn('n1', { title: '🏠 New Enrollment Request', message: 'Mohit Saxena wants to join Sunrise Boys PG.', type: 'enrollment_request', requestId: 'req_pending_1', propertyId: P[0].id, propertyName: P[0].name, tenantId: 'u_prospect_1', tenantName: 'Mohit Saxena', tenantPhone: '+919000000501', createdAt: ts(ago(0.1)) });
  bn('n2', { title: '💳 Payment Submitted', message: 'Devansh Trivedi submitted ₹17,500 (UTR982736451209) for verification.', type: 'payment_submitted', requestId: 'req_payment_submitted', propertyId: P[2].id, propertyName: P[2].name, tenantName: 'Devansh Trivedi', createdAt: ts(ago(0.1)) });
  bn('n3', { title: '💰 Rent Received', message: '₹9,500 received from Ananya Iyer for October 2026 via Razorpay.', type: 'payment', tenantId: 'TEN0000014', tenantName: 'Ananya Iyer', createdAt: ts(ago(0.6)), read: true });
  bn('n4', { title: '🏠 New Enrollment Request', message: 'Ishaan Chopra wants to join Sunrise Boys PG.', type: 'enrollment_request', requestId: 'req_pending_2', propertyId: P[0].id, propertyName: P[0].name, tenantName: 'Ishaan Chopra', createdAt: ts(ago(0.4)) });
  bn('n5', { title: '⚠️ Platform Bill Due', message: 'Lotus Ladies Hostel: your OneStay360 invoice of ₹480 is due.', type: 'billing_status_change', propertyId: P[1].id, propertyName: P[1].name, createdAt: ts(ago(1.2)) });
  bn('n6', { title: '👤 Tenant Update', message: 'Faizan Ali checked in to Room 201, Bed 2.', type: 'tenant_event', tenantId: 'TEN0000011', tenantName: 'Faizan Ali', createdAt: ts(ago(2)), read: true });
  const tn = (tid, id, o) => set(`tenants/${tid}/notifications/${id}`, { tenantId: tid, read: false, ...o });
  tn('TEN0000001', 'tn1', { title: '🏠 Rent Due', body: 'Your rent of ₹9,500 for ' + monthLabel(thisMonth) + ' is due. Pay now to avoid late fees.', message: 'Rent due', type: 'rent_due', createdAt: ts(ago(0.5)) });
  tn('TEN0000001', 'tn2', { title: '✅ Payment Confirmed', body: 'Your rent payment of ₹9,500 for ' + monthLabel(monthsBack(1)) + ' has been verified.', message: 'Payment confirmed', type: 'rent_payment_verified', createdAt: ts(ago(26)), read: true });
  tn('TEN0000014', 'tn1', { title: '✅ Payment Confirmed', body: 'Your rent payment of ₹9,500 for ' + monthLabel(thisMonth) + ' has been verified.', message: 'Payment confirmed', type: 'rent_payment_verified', createdAt: ts(ago(1)) });
  tn('TEN0000028', 'tn1', { title: '🧾 Bill Ready', body: 'Sunrise Boys PG sent your first-month bill of ₹25,500. Review and pay to confirm your bed.', message: 'Bill ready', type: 'bill_sent', requestId: 'req_bill_sent', enrollmentRequestId: 'req_bill_sent', createdAt: ts(ago(0.3)) });

  // platform billing (OneStay360 -> business)
  set('billing_invoices/inv_plat_blr002', { invoiceId: 'inv_plat_blr002', businessId: BUS, propertyId: P[1].id, purpose: 'monthly', periodStart: ts(ago(32)), periodEnd: ts(ago(2)), baseAmount: 480, discountAmount: 0, finalAmount: 480, status: 'due', dueDate: ts(ago(-3)), createdAt: ts(ago(32)) });
  set('billing_invoices/inv_plat_pun002', { invoiceId: 'inv_plat_pun002', businessId: BUS, propertyId: P[3].id, purpose: 'activation', baseAmount: 270, discountAmount: 0, finalAmount: 270, status: 'issued', dueDate: ts(ago(-7)), createdAt: ts(ago(3)) });
  [P[0], P[1], P[2]].forEach((p, pi) => [2, 1].forEach((m) => {
    set(`businesses/${BUS}/payments_to_onestay360/plat_${pi}_${m}`, { paymentId: `pay_PLAT${pi}${m}`, orderId: `order_PLAT${pi}${m}`, propertyId: p.id, purpose: m === 2 ? 'activation' : 'monthly', amount: pi === 0 ? 570 : pi === 1 ? 480 : 270, finalAmount: pi === 0 ? 570 : pi === 1 ? 480 : 270, status: 'success', gateway: 'Razorpay', createdAt: ts(ago(m * 30)) });
  }));

  // team: property access + audit trail + pinboard
  set(`businesses/${BUS}/properties/${P[0].id}/access/u_manager`, { uid: 'u_manager', role: 'manager', createdAt: ts(ago(55)) });
  set(`businesses/${BUS}/properties/${P[1].id}/access/u_manager`, { uid: 'u_manager', role: 'manager', createdAt: ts(ago(55)) });
  set(`businesses/${BUS}/properties/${P[0].id}/access/u_staff`, { uid: 'u_staff', role: 'staff', createdAt: ts(ago(40)) });
  const audit = [['tenant_created', 'tenant', 'TEN0000013', 0.2], ['bed_occupied', 'bed', '301-1', 0.2], ['property_access_granted', 'member', 'u_staff', 1.5], ['tenant_created', 'tenant', 'TEN0000011', 2], ['member_role_changed', 'member', 'u_manager', 5], ['bed_vacated', 'bed', '203-1', 8]];
  audit.forEach(([action, entityType, entityId, d], i) => set(`businesses/${BUS}/audit_logs/audit_${i}`, { actorUid: 'u_owner', actorRole: 'owner', action, entityType, entityId, propertyId: P[0].id, createdAt: ts(ago(d)) }));
  const pin = (id, { age, ...o }) => set(`pinboard/${id}`, { noteId: id, createdAt: ts(ago(age)), ...o });
  pin('pin1', { propertyId: P[0].id, authorId: 'u_ten_rohan', authorName: 'Rohan Mehta', authorPhone: '+919000000101', category: 'sports', content: 'Anyone up for badminton at the Koramangala indoor court this Saturday 7 AM? Need 2 more players 🏸', age: 0.3 });
  pin('pin2', { propertyId: P[0].id, authorId: 'u_ten_rohan', authorName: 'Arjun Reddy', authorPhone: '+919000000202', category: 'lost_found', content: 'Found a black Boat earphone case near the 2nd floor common area. Ping me to claim 🔑', age: 1 });
  pin('pin3', { propertyId: P[0].id, authorId: 'u_ten_rohan', authorName: 'Vikram Patel', authorPhone: '+919000000203', category: 'marketplace', content: 'Selling a study table lamp and a 5kg dumbbell set, barely used. ₹600 for both 📦', age: 2 });
  pin('pin4', { propertyId: P[0].id, authorId: 'u_ten_rohan', authorName: 'Sandeep Kumar', authorPhone: '+919000000204', category: 'social', content: 'Filter coffee + cricket match on the terrace tonight, all welcome ☕', age: 0.1 });

  await writer.close();

  console.log('\nSeeded the local emulator.\n');
  console.log(`  ${placed.length} tenants in 3 active properties (+1 draft), ${pendingCount + 1} payments awaiting verification, 8 enrollment requests.\n`);
  console.log('  Logins (password for all: ' + PASSWORD + ')');
  LOGINS.forEach((u) => console.log(`    ${u.role.padEnd(8)} ${u.email.padEnd(26)} ${u.name}${u.tenantId ? '  (' + u.tenantId + ')' : ''}`));
  console.log('\n  Business app: owner / manager / staff.   Tenant app: rohan (rent due), ananya (all paid), karan (bill to pay).\n');
}

main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
