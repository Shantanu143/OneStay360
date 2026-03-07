const admin = require("firebase-admin");

// Initialize 
admin.initializeApp({
  projectId: "onestay360-1",
});

const db = admin.firestore();

async function triggerBillingForProperty() {
  const businessId = "BUS0000001";
  const propertyId = "BUS0000001PNR001";

  console.log(`\n🔄 Manually triggering billing for property: ${propertyId}`);
  console.log(`   Business: ${businessId}\n`);

  try {
    // Get default plan
    const plansSnap = await db.collection("plans").where("isDefault", "==", true).limit(1).get();
    let defaultPlan = { id: "all_in_one", name: "All-In-One", pricePerBedInr: 30, isActive: true, isDefault: true };
    if (!plansSnap.empty) {
      defaultPlan = plansSnap.docs[0].data();
    }
    console.log("📋 Using plan:", defaultPlan.name, "at ₹", defaultPlan.pricePerBedInr, "/bed");

    // Get property
    const propertyRef = db.collection("businesses").doc(businessId).collection("properties").doc(propertyId);
    const propSnap = await propertyRef.get();

    if (!propSnap.exists) {
      console.log("❌ Property not found!");
      process.exit(1);
    }

    const prop = propSnap.data();
    console.log("\n📊 Property State Before:");
    console.log("   Status:", prop.status);
    console.log("   Billing Status:", prop.billingStatus || "NOT SET");
    console.log("   Total Beds:", prop.totalBeds);
    console.log("   Next Billing Date:", prop.nextBillingDate?.toDate?.());

    const now = admin.firestore.Timestamp.now();
    const nextBillingDate = prop.nextBillingDate;

    if (!nextBillingDate) {
      console.log("\n⚠️ No nextBillingDate - cannot process billing");
      process.exit(1);
    }

    if (now.toMillis() < nextBillingDate.toMillis()) {
      console.log("\n⚠️ Billing date hasn't passed yet");
      console.log("   Now:", now.toDate());
      console.log("   Next Billing:", nextBillingDate.toDate());
      process.exit(1);
    }

    console.log("\n✅ Billing date has passed - processing...");

    // Calculate billing
    const periodStart = nextBillingDate;
    const periodEnd = new Date(periodStart.toDate());
    periodEnd.setDate(periodEnd.getDate() + 30);
    const dueDate = new Date(periodStart.toDate());
    dueDate.setDate(dueDate.getDate() + 5);

    const planFromProperty = prop.plan;
    const plan = planFromProperty && typeof planFromProperty.pricePerBedInr === 'number'
      ? planFromProperty
      : defaultPlan;

    const baseAmount = Number(plan.pricePerBedInr) * Number(prop.totalBeds || 0);
    console.log("\n💰 Invoice Calculation:");
    console.log("   Plan:", plan.name);
    console.log("   Price per bed: ₹", plan.pricePerBedInr);
    console.log("   Total beds:", prop.totalBeds);
    console.log("   Base amount: ₹", baseAmount);

    // Create invoice ID
    const invoiceId = `${propertyId}_${periodStart.toMillis()}`;
    console.log("\n📝 Creating Invoice:", invoiceId);

    // Check if invoice already exists
    const billingInvoiceRef = db.collection("billing_invoices").doc(invoiceId);
    const existingInvoice = await billingInvoiceRef.get();

    if (existingInvoice.exists) {
      console.log("   Invoice already exists:", existingInvoice.data().status);
    } else {
      // Create new invoice
      const invoiceData = {
        invoiceId,
        businessId,
        propertyId,
        purpose: 'monthly',
        periodStart: admin.firestore.Timestamp.fromDate(periodStart.toDate()),
        periodEnd: admin.firestore.Timestamp.fromDate(periodEnd),
        baseAmount,
        discountAmount: 0,
        finalAmount: baseAmount,
        status: 'due',  // Since billing date has passed, it's already due
        dueDate: admin.firestore.Timestamp.fromDate(dueDate),
        paidAt: null,
        paymentId: null,
        promoCode: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await billingInvoiceRef.set(invoiceData);
      console.log("   ✅ Invoice created!");

      // Also add to property's invoices subcollection for easy access
      await propertyRef.collection("invoices").doc(invoiceId).set({
        ...invoiceData,
        type: 'monthly',
        amount: baseAmount,
      });
      console.log("   ✅ Added to property invoices subcollection");
    }

    // Calculate billing status
    function computeStateFromDue(now, dueDate) {
      const graceEndMs = dueDate.getTime() + (5 * 24 * 60 * 60 * 1000);
      const suspensionAtMs = dueDate.getTime() + (12 * 24 * 60 * 60 * 1000);

      if (now.getTime() <= dueDate.getTime()) return 'due';
      if (now.getTime() <= graceEndMs) return 'grace';
      if (now.getTime() <= suspensionAtMs) return 'past_due';
      return 'suspended';
    }

    const billingStatus = computeStateFromDue(now.toDate(), dueDate);
    console.log("\n📊 Billing Status:", billingStatus);

    // Update property
    const updates = { 
      billingStatus,
    };
    
    if (billingStatus === 'suspended') {
      updates.status = 'suspended';
    }

    await propertyRef.update(updates);
    console.log("   ✅ Property updated with billingStatus:", billingStatus);

    // Final state
    const finalSnap = await propertyRef.get();
    const finalProp = finalSnap.data();
    console.log("\n📊 Property State After:");
    console.log("   Status:", finalProp.status);
    console.log("   Billing Status:", finalProp.billingStatus);

    console.log("\n✅ Billing processed successfully!");
    console.log("\n⚠️  NOTE: You should now receive a billing notification in the app.");
    console.log("   If you don't, check that device tokens are registered and active.");

  } catch (error) {
    console.error("❌ Error:", error.message);
    console.error(error);
  }

  process.exit(0);
}

triggerBillingForProperty();
