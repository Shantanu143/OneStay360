const admin = require("firebase-admin");

admin.initializeApp({
  projectId: "onestay360-1",
});

const db = admin.firestore();
const messaging = admin.messaging();

async function sendBillingNotification() {
  const businessId = "BUS0000001";
  
  console.log("\n📬 Sending billing notification...");

  try {
    // Get business owner
    const businessSnap = await db.collection("businesses").doc(businessId).get();
    if (!businessSnap.exists) {
      console.log("❌ Business not found");
      process.exit(1);
    }

    const businessData = businessSnap.data();
    const ownerUserId = businessData.ownerUserId || businessData.ownerUid;
    console.log("   Owner User ID:", ownerUserId);

    if (!ownerUserId) {
      console.log("❌ No owner found");
      process.exit(1);
    }

    // Get device tokens
    const deviceTokensSnap = await db
      .collection("users")
      .doc(ownerUserId)
      .collection("deviceTokens")
      .where("active", "==", true)
      .limit(100)
      .get();

    if (deviceTokensSnap.empty) {
      console.log("❌ No active device tokens found");
      
      // Check if there are any tokens at all
      const allTokensSnap = await db
        .collection("users")
        .doc(ownerUserId)
        .collection("deviceTokens")
        .limit(10)
        .get();
      
      if (allTokensSnap.empty) {
        console.log("   No device tokens registered at all for this user");
      } else {
        console.log("   Found", allTokensSnap.size, "tokens but none are active:");
        allTokensSnap.docs.forEach(doc => {
          console.log("   -", doc.id.substring(0, 30) + "...", "active:", doc.data().active);
        });
      }
      process.exit(1);
    }

    console.log("   Found", deviceTokensSnap.size, "active device tokens");

    const notification = {
      title: "💰 Monthly Payment Due",
      body: "Payment of ₹180 for Ram Nivas PG is now due. Please pay within 5 days.",
    };

    const data = {
      type: "billing_status_change",
      propertyId: "BUS0000001PNR001",
      propertyName: "Ram Nivas PG",
      billingStatus: "due",
      previousStatus: "paid",
      invoiceAmount: "180",
    };

    for (const doc of deviceTokensSnap.docs) {
      const token = doc.id;
      console.log("\n   Sending to:", token.substring(0, 40) + "...");

      try {
        const result = await messaging.send({
          token: token,
          notification: notification,
          data: data,
          android: {
            priority: "high",
            notification: {
              title: notification.title,
              body: notification.body,
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
              sound: "default",
              channelId: "billing_notifications",
            },
          },
          apns: {
            payload: {
              aps: {
                alert: {
                  title: notification.title,
                  body: notification.body,
                },
                sound: "default",
                badge: 1,
              },
            },
          },
        });
        console.log("   ✅ Sent! Message ID:", result);
      } catch (error) {
        console.error("   ❌ Failed:", error.message);
        
        // Mark invalid tokens as inactive
        if (
          error.message.includes("registration token is invalid") ||
          error.message.includes("registration token is not registered")
        ) {
          await doc.ref.update({ active: false });
          console.log("   Marked token as inactive");
        }
      }
    }

    console.log("\n✅ Done!");

  } catch (error) {
    console.error("❌ Error:", error.message);
  }

  process.exit(0);
}

sendBillingNotification();
