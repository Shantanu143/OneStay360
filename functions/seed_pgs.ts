import * as admin from 'firebase-admin';

// Check if running on emulator (default to localhost emulator if set, or production if not)
if (process.env.FIRESTORE_EMULATOR_HOST) {
  console.log(`🔌 Connecting to Firestore Emulator at ${process.env.FIRESTORE_EMULATOR_HOST}`);
}

if (admin.apps.length === 0) {
  admin.initializeApp({
    projectId: process.env.GCP_PROJECT || process.env.FIREBASE_PROJECT_ID || 'onestay360-1',
  });
}

const db = admin.firestore();

// -------------------------------------------------------------
// SEED DATA CONFIGURATION & GENERATORS
// -------------------------------------------------------------

const CITIES = [
  { name: 'Bangalore', code: 'BLR', areas: ['Koramangala', 'HSR Layout', 'Indiranagar', 'Whitefield', 'Marathahalli'] },
  { name: 'Mumbai', code: 'BOM', areas: ['Andheri West', 'Bandra West', 'Thane West', 'Powai', 'Kharghar'] },
  { name: 'Delhi', code: 'DEL', areas: ['Karol Bagh', 'Lajpat Nagar', 'Connaught Place', 'Saket', 'Dwarka'] },
  { name: 'Pune', code: 'PNQ', areas: ['Koregaon Park', 'Viman Nagar', 'Hinjewadi', 'Kothrud', 'Baner'] },
  { name: 'Hyderabad', code: 'HYD', areas: ['Gachibowli', 'Madhapur', 'Kondapur', 'Jubilee Hills', 'Banjara Hills'] },
  { name: 'Chennai', code: 'MAA', areas: ['Adyar', 'Velachery', 'OMR', 'T-Nagar', 'Anna Nagar'] },
  { name: 'Kolkata', code: 'CCU', areas: ['Salt Lake Sector V', 'New Town', 'Ballygunge', 'Gariahat', 'Park Street'] },
  { name: 'Ahmedabad', code: 'AMD', areas: ['Satellite', 'Ghatlodia', 'Bodakdev', 'C G Road', 'Vastrapur'] }
];

const AMENITIES_POOL = [
  { wifi: true, ac: true, geyser: true, powerBackup: true, gym: true, laundry: true, cleaning: true, parking: true },
  { wifi: true, ac: false, geyser: true, powerBackup: true, gym: false, laundry: true, cleaning: true, parking: true },
  { wifi: true, ac: true, geyser: true, powerBackup: true, gym: false, laundry: true, cleaning: true, parking: false },
  { wifi: true, ac: false, geyser: true, powerBackup: false, gym: false, laundry: false, cleaning: true, parking: true },
];

const FOOD_PLANS = [
  { veg: true, nonVeg: false, breakfast: true, lunch: true, dinner: true, description: 'Pure Vegetarian meals provided daily.' },
  { veg: true, nonVeg: true, breakfast: true, lunch: false, dinner: true, description: 'Veg and Non-Veg breakfast and dinner included.' },
  { veg: true, nonVeg: true, breakfast: true, lunch: true, dinner: true, description: 'All 3 meals included daily. Non-veg served on Wed/Sun.' },
];

const GENDERS = ['male', 'female', 'co-ed'];

// Collection of real high-quality Unsplash hostel & co-living room images
const IMAGE_URLS = [
  'https://images.unsplash.com/photo-1595526114035-0d45ed16cfbf?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1505691938895-1758d7feb511?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1598928506311-c55ded91a20c?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1616046229478-9901c5536a45?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1631049307264-da0ec9d70304?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1540518614846-7eded433c457?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1566665797739-1674de7a421a?auto=format&fit=crop&w=800&q=80'
];

const PG_NAMES = [
  'Starlight Luxury PG', 'Zolo Stay Comfort', 'Prism Coliving Space',
  'Elite Nest PG', 'Serene Hostels', 'NestAway Premium', 'Royal Stay Living',
  'Hustlehub Coliving', 'Isthara Smart PG', 'Olive Stay', 'Saffron Hostels',
  'Urban Living PG', 'Comfort Zone Stay', 'Skyline Co-living', 'Greenwood PG',
  'Nexus Premium Hostels', 'Grand Stay PG', 'Homely Haven PG', 'Silver Oak Coliving',
  'Prestige PG', 'Unity Hostels', 'Metro Living PG', 'Classic Stay Comfort',
  'Springfield PG', 'Signature Coliving', 'Trident Stay', 'Silicon Valley PG',
  'Maple Wood Co-living', 'Ambience Premium PG', 'Felicity Hostels'
];

const BUSINESSES = [
  { id: 'BIZ_001', name: 'Zolo Living Private Limited', phone: '9876500001' },
  { id: 'BIZ_002', name: 'Isthara Co-living Services', phone: '9876500002' },
  { id: 'BIZ_003', name: 'NestAway PG Chains', phone: '9876500003' },
  { id: 'BIZ_004', name: 'Olive Premium Housing Group', phone: '9876500004' },
  { id: 'BIZ_005', name: 'HustleHub Properties LLC', phone: '9876500005' },
];

function getRandomItem<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

function getRandomSubarray<T>(arr: T[], size: number): T[] {
  const shuffled = [...arr].sort(() => 0.5 - Math.random());
  return shuffled.slice(0, size);
}

function generateRandomPG(index: number, cityInfo: typeof CITIES[0]): any {
  const nameBase = getRandomItem(PG_NAMES);
  const name = `${nameBase} ${cityInfo.name} (${index})`;
  const area = getRandomItem(cityInfo.areas);
  const address = `${Math.floor(Math.random() * 200) + 1}, Main Road, near Metro Pillar, ${area}, ${cityInfo.name}`;
  const pincode = `${Math.floor(Math.random() * 900) + 100}${Math.floor(Math.random() * 90) + 10}`;
  const numberOfFloors = Math.floor(Math.random() * 5) + 2;
  const description = `Welcome to ${name}. Located in the popular hub of ${area}, this co-living PG offers a clean, secure, and modern lifestyle. Fully equipped with premium facilities, it is perfect for working professionals and students alike.`;
  const landmarks = `Near ${area} Metro Station, opposite Axis Bank`;
  const googleMapsLink = 'https://maps.google.com/?q=' + encodeURIComponent(name);

  // Pricing configuration
  const singlePrice = Math.floor(Math.random() * 6000) + 10000; // 10k - 16k
  const doublePrice = Math.floor(Math.random() * 4000) + 7000;   // 7k - 11k
  const triplePrice = Math.floor(Math.random() * 2000) + 5000;   // 5k - 7k
  const pricing = {
    single: singlePrice,
    double: doublePrice,
    triple: triplePrice,
    depositMonths: 2
  };

  // Rooms generation
  const roomsCount = Math.floor(Math.random() * 10) + 5; // 5 - 15 rooms
  const rooms: any[] = [];
  let totalBedsCount = 0;
  
  for (let i = 1; i <= roomsCount; i++) {
    const floor = Math.floor(i / 4) + 1;
    const roomNumber = `${floor}0${i % 4 || 4}`;
    const sharingType = getRandomItem(['single', 'double', 'triple']);
    const bedsCount = sharingType === 'single' ? 1 : sharingType === 'double' ? 2 : 3;
    totalBedsCount += bedsCount;

    const beds: any[] = [];
    for (let b = 1; b <= bedsCount; b++) {
      beds.push({
        id: `${roomNumber}_bed_${b}`,
        bedNumber: `${b}`,
        isOccupied: Math.random() > 0.5,
        status: 'available',
      });
    }

    const sharingTypeNum = sharingType === 'single' ? 1 : sharingType === 'double' ? 2 : 3;
    const occupancyType = sharingType === 'single' ? 'Single' : sharingType === 'double' ? 'Double' : 'Triple';

    rooms.push({
      roomId: `ROOM_${roomNumber}`,
      roomNumber,
      floor: String(floor),
      occupancyType,
      sharingType: sharingTypeNum,
      maxBeds: bedsCount,
      beds,
      isActive: true,
      price: sharingType === 'single' ? singlePrice : sharingType === 'double' ? doublePrice : triplePrice,
    });
  }

  const occupiedBeds = rooms.reduce((acc, room) => acc + room.beds.filter((b: any) => b.isOccupied).length, 0);
  const availableBeds = totalBedsCount - occupiedBeds;

  const amenities = getRandomItem(AMENITIES_POOL);
  const foodPlan = getRandomItem(FOOD_PLANS);
  const genderAllowed = getRandomItem(GENDERS);

  const rules = {
    genderAllowed,
    guestPolicy: 'Guests allowed in common areas till 8 PM.',
    gateClosingTime: '11:00 PM',
    smokingAllowed: false,
    drinkingAllowed: false,
  };

  const totals = {
    rooms: roomsCount,
    beds: totalBedsCount,
    availableBeds,
  };

  const imagesCount = Math.floor(Math.random() * 3) + 2; // 2 - 5 images
  const images = getRandomSubarray(IMAGE_URLS, imagesCount);

  const ratingValue = (Math.random() * 1.5 + 3.5); // 3.5 - 5.0
  const rating = {
    average: parseFloat(ratingValue.toFixed(1)),
    count: Math.floor(Math.random() * 100) + 10,
  };

  const business = getRandomItem(BUSINESSES);

  return {
    name,
    address,
    city: cityInfo.name,
    cityCode: cityInfo.code,
    pincode,
    numberOfFloors,
    description,
    landmarks,
    googleMapsLink,
    pricing,
    rooms,
    amenities,
    foodPlan,
    rules,
    totals,
    images,
    rating,
    status: 'active',
    billingStatus: 'paid',
    pricePerBed: 30,
    totalBeds: totalBedsCount,
    activeBedCount: totalBedsCount,
    billedBedCount: totalBedsCount,
    billingStartDate: admin.firestore.Timestamp.fromDate(new Date()),
    nextBillingDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)),
    businessId: business.id,
    businessName: business.name,
    businessPhone: business.phone,
    createdAt: admin.firestore.Timestamp.fromDate(new Date()),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date()),
    featured: Math.random() > 0.8 // 20% featured
  };
}

// -------------------------------------------------------------
// SEED PROCESS EXECUTION
// -------------------------------------------------------------

async function seedDatabase() {
  console.log('🚀 Seeding 50 PGs with images starting...');

  // 1. Create Business Owner records if they don't exist
  for (const biz of BUSINESSES) {
    const bizRef = db.collection('businesses').doc(biz.id);
    const snap = await bizRef.get();
    if (!snap.exists) {
      console.log(`🏢 Seeding Business metadata for: ${biz.name}`);
      await bizRef.set({
        businessId: biz.id,
        name: biz.name,
        phone: biz.phone,
        ownerUserId: `owner_${biz.id}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      // Set owner membership
      await bizRef.collection('members').doc(`owner_${biz.id}`).set({
        uid: `owner_${biz.id}`,
        name: 'Manager Stay',
        role: 'owner',
        status: 'active',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }

  // 2. Clear previous seeded mock data in properties (optional, but let's keep it safe and cumulative)
  // 3. Generate and set 50 PG listings
  let totalPropertiesSeeded = 0;

  for (let i = 1; i <= 50; i++) {
    // Distribute evenly among cities
    const cityInfo = CITIES[(i - 1) % CITIES.length];
    const propertyData = generateRandomPG(i, cityInfo);
    const propertyId = `PROP_${cityInfo.code}_${String(i).padStart(3, '0')}`;

    console.log(`✍️ Seeding [${i}/50] ${propertyData.name} (City: ${propertyData.city})`);

    const batch = db.batch();

    // Store in global /properties collection
    const globalPropRef = db.collection('properties').doc(propertyId);
    batch.set(globalPropRef, propertyData);

    // Store in /properties_by_city/{city}/properties collection
    const cityPropRef = db
      .collection('properties_by_city')
      .doc(propertyData.city)
      .collection('properties')
      .doc(propertyId);
    batch.set(cityPropRef, propertyData);

    // Store in /businesses/{businessId}/properties collection
    const bizPropRef = db
      .collection('businesses')
      .doc(propertyData.businessId)
      .collection('properties')
      .doc(propertyId);
    batch.set(bizPropRef, propertyData);

    await batch.commit();
    totalPropertiesSeeded++;
  }

  console.log(`✅ Database Seeding completed successfully. Seeded ${totalPropertiesSeeded} properties across ${CITIES.length} cities.`);
}

// Run the script
seedDatabase().catch((err) => {
  console.error('❌ Seeding failed with error: ', err);
  process.exit(1);
});
