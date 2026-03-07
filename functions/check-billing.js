const admin = require("firebase-admin");

// Initialize with default credentials (uses GOOGLE_APPLICATION_CREDENTIALS or ADC)
admin.initializeApp({
  projectId: "onestay360-1",
});

const db = admin.firestore();

async function checkPropertyBilling() {
  const businessId = "BUS0000001";
  const propertyId = "BUS0000001PNR001";

  console.log(`\n🔍 Checking billing for property: ${propertyId}`);
  console.log(`   Business: ${businessId}\n`);

  try {
    // Get property document
    const propertyRef = db
      .collection("businesses")
      .doc(businessId)
      .collection("properties")
      .doc(propertyId);

    const propertyDoc = await propertyRef.get();

    if (!propertyDoc.exists) {
      console.log("❌ Property not found!");
      return;
    }

    const property = propertyDoc.data();
    console.log("📋 Property Data:");
    console.log("   Name:", property.name);
    console.log("   Status:", property.status);
    console.log("   Plan:", property.plan);
    console.log("   Next Billing Date:", property.nextBillingDate?.toDate?.() || property.nextBillingDate || "NOT SET");
    console.log("   Billing Amount:", property.billingAmount);
    console.log("   Activation Payment:", property.activationPaymentStatus);
    console.log("   Created At:", property.createdAt?.toDate?.() || property.createdAt);

    // Check billing conditions
    console.log("\n📊 Billing Checks:");
    const isActive = property.status === "active";
    const hasBillingDate = !!property.nextBillingDate;
    const now = new Date();
    const billingDate = property.nextBillingDate?.toDate?.() || null;
    const billingDatePassed = billingDate ? now >= billingDate : false;

    console.log(`   Current time (now): ${now.toISOString()}`);
    console.log(`   Billing date: ${billingDate?.toISOString() || "NOT SET"}`);
    console.log(`   ✓ Status is active: ${isActive ? "YES ✅" : "NO ❌"}`);
    console.log(`   ✓ Has nextBillingDate: ${hasBillingDate ? "YES ✅" : "NO ❌"}`);
    console.log(`   ✓ Billing date passed: ${billingDatePassed ? "YES ✅" : "NO ❌"}`);

    if (!hasBillingDate) {
      console.log("\n⚠️  ISSUE FOUND: nextBillingDate is NOT SET!");
      console.log("   This is why billing notifications are not being sent.");
      console.log("   The property was likely set to active manually without going through the activation payment flow.");
    }

    // Check recent invoices
    console.log("\n📑 Recent Invoices:");
    const invoicesSnap = await propertyRef
      .collection("invoices")
      .orderBy("createdAt", "desc")
      .limit(5)
      .get();

    if (invoicesSnap.empty) {
      console.log("   No invoices found");
    } else {
      invoicesSnap.docs.forEach((doc, i) => {
        const inv = doc.data();
        console.log(`   ${i + 1}. ${inv.type} - ₹${inv.amount} - ${inv.status} (${inv.createdAt?.toDate?.().toLocaleDateString() || "N/A"})`);
      });
    }

  } catch (error) {
    console.error("Error:", error.message);
  }

  process.exit(0);
}

checkPropertyBilling();
