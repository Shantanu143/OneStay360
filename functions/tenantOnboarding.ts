/**
 * Tenant Onboarding Cloud Functions
 * 
 * Flow 1: Tenant has app (enrollment request)
 *   1. Tenant submits enrollment request
 *   2. Business owner receives notification (existing: onEnrollmentRequestCreated)
 *   3. Owner approves with room/bed assignment → onEnrollmentStatusChanged
 *   4. System creates tenant record + notifies tenant
 * 
 * Flow 2: Tenant doesn't have app (manual add)
 *   1. Owner adds tenant manually (AddTenantScreen)
 *   2. onTenantCreated sends WhatsApp invitation
 *   3. When tenant signs up with same phone → onUserCreated auto-links
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { sendWhatsAppTemplate } from './sendWhatsApp';
import { assertPropertyPermission } from './permissions';
import { buildTenantInvitationEmail, sendEmail } from './sendEmail';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Generate a sequential tenant ID (TEN0000001)
 */
async function generateTenantId(): Promise<string> {
  const counterRef = db.collection('counters').doc('tenant_counter');
  
  return db.runTransaction(async (tx) => {
    const counterSnap = await tx.get(counterRef);
    let count = 1;
    
    if (counterSnap.exists) {
      count = (counterSnap.data()?.count || 0) + 1;
    }
    
    tx.set(counterRef, { count }, { merge: true });
    return `TEN${count.toString().padStart(7, '0')}`;
  });
}

// App download link - update this with your actual app link
const APP_DOWNLOAD_LINK = 'https://onestay360.page.link/tenant';

/**
 * Callable Function: Submit an enrollment request securely
 * Validates:
 * 1. User doesn't already have an active PG
 * 2. User hasn't already submitted a pending request to this business
 */
export const submitEnrollmentRequest = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'You must be logged in to submit an enrollment request.');
  }

  const {
    propertyId,
    businessId,
    tenantName,
    tenantPhone,
    moveInDate,
    propertyName,
    roomType,
    sharingType,
    notes,
    kycDocumentUrl
  } = data;

  if (!propertyId || !businessId || !tenantName || !tenantPhone || !moveInDate) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields.');
  }

  const uid = context.auth.uid;

  // 1. Check if user already has an active PG
  const userDoc = await db.collection('users').doc(uid).get();
  const userData = userDoc.data();
  if (userData?.tenantId) {
    const globalTenantSnap = await db.collection('tenants').doc(userData.tenantId).get();
    if (globalTenantSnap.exists && globalTenantSnap.data()?.status === 'active') {
      throw new functions.https.HttpsError('failed-precondition', 'You are already an active part of a PG. You must vacate your current PG before applying to a new one.');
    }
  }

  // 2. Check for existing pending requests to this business
  const pendingRequestsSnap = await db.collection('enrollmentRequests')
    .where('tenantId', '==', uid)
    .where('businessId', '==', businessId)
    .where('status', '==', 'pending')
    .get();

  if (!pendingRequestsSnap.empty) {
    throw new functions.https.HttpsError('already-exists', 'You already have a pending enrollment request for this property/business. Please wait for the owner to respond.');
  }

  const requestId = db.collection('enrollmentRequests').doc().id;

  await db.collection('enrollmentRequests').doc(requestId).set({
    requestId: requestId,
    tenantId: uid,
    tenantName: tenantName,
    tenantPhone: tenantPhone,
    propertyId: propertyId,
    businessId: businessId,
    propertyName: propertyName || '',
    moveInDate: moveInDate, // Assumed to be passed securely, perhaps as a string ISO
    roomType: roomType || '',
    sharingType: sharingType || '',
    notes: notes || '',
    kycDocumentUrl: kycDocumentUrl || '',
    status: 'pending',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`✅ Validated & submitted enrollment request: ${requestId} for user: ${uid}`);
  return { requestId };
});

/**
 * =====================================================
 * TRIGGER: When enrollment request status changes
 * Path: /enrollmentRequests/{requestId}
 * =====================================================
 * 
 * When owner approves:
 * - Creates tenant record
 * - Links to user account (if exists)
 * - Marks bed as occupied
 * - Sends notification to tenant
 */
export const onEnrollmentStatusChanged = functions.firestore
  .document('enrollmentRequests/{requestId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const requestId = context.params.requestId;

    // Only process when status changes
    if (before.status === after.status) {
      return null;
    }

    const newStatus = after.status as string;
    console.log(`📋 Enrollment ${requestId} status: ${before.status} → ${newStatus}`);

    switch (newStatus) {
      case 'approved':
        return handleEnrollmentApproved(requestId, after);
      case 'rejected':
        return handleEnrollmentRejected(requestId, after);
      case 'bill_sent':
        return handleBillSent(requestId, after);
      case 'payment_submitted':
        return handlePaymentSubmitted(requestId, after);
      case 'confirmed':
        return handlePaymentConfirmed(requestId, after);
      default:
        return null;
    }
  });

/**
 * Handle approved enrollment - create tenant record
 */
async function handleEnrollmentApproved(
  requestId: string,
  enrollment: FirebaseFirestore.DocumentData
): Promise<void> {
  const {
    tenantId: tenantUserId, // This is the user's Firebase UID
    tenantName,
    tenantPhone,
    propertyId,
    businessId,
    propertyName,
    moveInDate,
    roomId,      // Set during approval
    bedId,       // Set during approval
    roomNumber,  // Human readable
    bedNumber,   // Human readable
    monthlyRent, // Set during approval
  } = enrollment;

  // Validate required fields for approval
  if (!roomId || !bedId) {
    console.error('❌ Enrollment approved without room/bed assignment!');
    await db.doc(`enrollmentRequests/${requestId}`).update({
      status: 'pending',
      approvalError: 'Room and bed must be assigned before approval',
    });
    return;
  }

  const now = admin.firestore.Timestamp.now();

  // Resolve the actual tenantId (e.g. TEN0000003) from the user doc
  let tenantDocId: string | null = null;
  let profileGender: string | null = null;
  
  if (tenantUserId) {
    const userSnap = await db.doc(`users/${tenantUserId}`).get();
    const userData = userSnap.data();
    tenantDocId = userData?.tenantId || null;
  }

  // If still no friendly tenantId, generate one
  if (!tenantDocId) {
    tenantDocId = await generateTenantId();
    console.log(`✨ Generated new sequential tenantDocId: ${tenantDocId}`);
  } else {
    console.log(`📋 Reusing existing tenantDocId: ${tenantDocId}`);
  }

  // Read gender from the global tenant doc (/tenants/{TEN_ID})
  // This is where the full profile including gender is stored after profile completion
  if (tenantDocId) {
    const globalTenantSnap = await db.doc(`tenants/${tenantDocId}`).get();
    profileGender = globalTenantSnap.data()?.gender || null;
    console.log(`👤 Tenant profile gender resolved from /tenants/${tenantDocId}: ${profileGender}`);
  }

  try {
    await db.runTransaction(async (tx) => {
      // 1. Check if bed is already occupied
      const bedRef = db.doc(`businesses/${businessId}/properties/${propertyId}/rooms/${roomId}/beds/${bedId}`);
      const bedSnap = await tx.get(bedRef);
      
      if (bedSnap.exists) {
        const bedData = bedSnap.data();
        if (bedData?.occupied && bedData?.tenantId) {
          throw new Error(`Bed ${bedNumber || bedId} is already occupied`);
        }
      }

      // 1b. Check / enforce room gender lock
      const roomRef = db.doc(`businesses/${businessId}/properties/${propertyId}/rooms/${roomId}`);
      const roomSnap = await tx.get(roomRef);
      const roomData = roomSnap.data();
      const roomGender: string | null = roomData?.gender || null;
      // Priority: tenant's completed profile gender > enrollment request field (fallback for manual adds)
      const tenantGender: string | null = profileGender || enrollment.tenantGender || null;

      if (roomGender && tenantGender && roomGender !== tenantGender) {
        // Room is gender-locked and tenant doesn't match — REJECT
        throw new Error(`Room ${roomNumber || roomId} is reserved for ${roomGender} tenants only. This tenant is ${tenantGender}.`);
      }

      // 2. Create tenant record using the actual tenantId
      const tenantData = {
        id: tenantDocId,
        tenantId: tenantDocId,
        userId: tenantUserId || null,
        name: tenantName,
        phone: tenantPhone,
        email: enrollment.tenantEmail || null,
        propertyId,
        businessId,
        roomId,
        bedId,
        roomNumber: roomNumber || roomId,
        bedNumber: bedNumber || bedId,
        propertyName: propertyName || '',
        monthlyRent: monthlyRent || 0,
        checkInDate: moveInDate || now,
        status: 'active',
        enrollmentRequestId: requestId,
        createdAt: now,
        updatedAt: now,
        linkedAt: tenantUserId ? now : null,
        inviteSentAt: null,
        additionalInfo: {
          depositAmount: enrollment.depositAmount || 0,
          maintenanceAmount: enrollment.maintenanceAmount || 0,
          foodAddon: enrollment.foodAddon || 0,
          foodDeduction: enrollment.foodDeduction || 0,
          proratedRent: enrollment.proratedRent || 0,
          totalFirstMonth: enrollment.totalFirstMonth || 0,
          paymentMode: enrollment.paymentMode || '',
          transactionId: enrollment.transactionId || '',
          billingDate: enrollment.billingDate || 1,
        },
      };

      // Business-scoped tenant record (uses actual tenantId like TEN0000003)
      const bizTenantRef = db.doc(`businesses/${businessId}/tenants/${tenantDocId}`);
      tx.set(bizTenantRef, tenantData);

      // 3. Mark bed as occupied
      tx.set(bedRef, {
        occupied: true,
        isOccupied: true,
        tenantId: tenantDocId,
        tenantName,
        occupiedAt: now,
      }, { merge: true });

      // 4. Update property's occupancy count
      const propertyRef = db.doc(`businesses/${businessId}/properties/${propertyId}`);
      tx.update(propertyRef, {
        occupiedBeds: admin.firestore.FieldValue.increment(1),
        updatedAt: now,
      });

      // 4b. Lock room gender if this is the first tenant in the room
      if (!roomGender && tenantGender) {
        tx.set(roomRef, { gender: tenantGender, updatedAt: now }, { merge: true });
        console.log(`🔒 Room ${roomNumber || roomId} gender locked to: ${tenantGender}`);
      }

      // 5. If user exists, update their user document (Only essential fields)
      if (tenantUserId) {
        const userRef = db.doc(`users/${tenantUserId}`);
        // merge: a tenant who never finished their profile may have no user doc yet
        tx.set(userRef, {
          tenantId: tenantDocId,
          isTenant: true,
          updatedAt: now,
        }, { merge: true });
      }

      // 6. Sync room/bed/rent data to the global /tenants doc so tenant app can read it
      const globalTenantRef = db.doc(`tenants/${tenantDocId}`);
      tx.set(globalTenantRef, {
        propertyId,
        businessId,
        roomId,
        bedId,
        roomNumber: roomNumber || roomId,
        bedNumber: bedNumber || bedId,
        propertyName: propertyName || '',
        monthlyRent: monthlyRent || 0,
        checkInDate: moveInDate || now,
        status: 'active',
        updatedAt: now,
      }, { merge: true });

      // 6b. Create a history record in the stays subcollection
      const stayRef = globalTenantRef.collection('stays').doc();
      tx.set(stayRef, {
        stayId: stayRef.id,
        enrollmentRequestId: requestId,
        propertyId,
        businessId,
        roomId,
        bedId,
        roomNumber: roomNumber || roomId,
        bedNumber: bedNumber || bedId,
        propertyName: propertyName || '',
        monthlyRent: monthlyRent || 0,
        checkInDate: moveInDate || now,
        status: 'active',
        createdAt: now,
        updatedAt: now,
      });

      // 7. Create initial payment record in the payments subcollection
      const totalFirstMonth = enrollment.totalFirstMonth || monthlyRent || 0;
      const paymentRef = db.collection(`businesses/${businessId}/tenants/${tenantDocId}/payments`).doc();
      tx.set(paymentRef, {
        id: paymentRef.id,
        tenantId: tenantDocId,
        businessId,
        amount: totalFirstMonth,
        month: _getMonthLabel(moveInDate || now),
        date: now,
        status: enrollment.transactionId ? 'Paid' : 'Pending',
        method: enrollment.paymentMode || 'Not specified',
        transactionId: enrollment.transactionId || null,
        description: 'First month payment (onboarding)',
        createdAt: now,
      });

      // 8. Mark enrollment as completed
      tx.update(db.doc(`enrollmentRequests/${requestId}`), {
        tenantDocId,
        completedAt: now,
      });
    });

    console.log(`✅ Tenant record created: ${tenantDocId}`);

    // 9. Send notifications (non-blocking)
    await notifyTenantApproved(enrollment, tenantUserId, roomNumber || roomId, bedNumber || bedId);

  } catch (error) {
    console.error('❌ Failed to create tenant:', error);
    
    await db.doc(`enrollmentRequests/${requestId}`).update({
      approvalError: (error as Error).message,
      status: 'approval_failed',
    });
    
    throw error;
  }
}

/**
 * Helper to generate a month label like "March 2026" from a Firestore Timestamp or Date
 */
function _getMonthLabel(dateValue: any): string {
  const months = ['January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'];
  let date: Date;
  if (dateValue && typeof dateValue.toDate === 'function') {
    date = dateValue.toDate();
  } else if (dateValue instanceof Date) {
    date = dateValue;
  } else {
    date = new Date();
  }
  return `${months[date.getMonth()]} ${date.getFullYear()}`;
}

/**
 * Send notification to tenant when approved
 */
async function notifyTenantApproved(
  enrollment: FirebaseFirestore.DocumentData,
  tenantUserId: string | null,
  roomNumber: string,
  bedNumber: string
): Promise<void> {
  const { tenantName, tenantPhone, propertyName, moveInDate } = enrollment;

  // Format move-in date
  let moveInStr = 'As agreed';
  if (moveInDate) {
    const date = moveInDate.toDate ? moveInDate.toDate() : new Date(moveInDate);
    moveInStr = date.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
  }

  // If tenant has app (userId exists), send push notification
  if (tenantUserId) {
    try {
      const tokensSnap = await db
        .collection('users')
        .doc(tenantUserId)
        .collection('deviceTokens')
        .get();

      const tokens = tokensSnap.docs
        .map(d => d.data().token)
        .filter(Boolean) as string[];

      if (tokens.length > 0) {
        await messaging.sendEachForMulticast({
          tokens,
          notification: {
            title: '🎉 Enrollment Approved!',
            body: `Welcome to ${propertyName}! Room ${roomNumber}, Bed ${bedNumber}`,
          },
          data: {
            type: 'enrollment_approved',
            propertyName: propertyName || '',
            roomNumber,
            bedNumber,
          },
        });
        console.log('📱 Push notification sent to tenant');
      }
    } catch (err) {
      console.warn('Push notification failed:', err);
    }
  }

  // Always send WhatsApp (works whether they have app or not)
  try {
    await sendWhatsAppTemplate({
      to: tenantPhone,
      templateName: 'enrollment_approved',
      templateParams: [
        tenantName,
        propertyName || 'your new PG',
        roomNumber,
        bedNumber,
        moveInStr,
        APP_DOWNLOAD_LINK,
      ],
    });
    console.log('📱 WhatsApp notification sent to tenant');
  } catch (err) {
    console.warn('WhatsApp notification failed:', err);
  }
}

/**
 * Handle rejected enrollment
 */
async function handleEnrollmentRejected(
  requestId: string,
  enrollment: FirebaseFirestore.DocumentData
): Promise<void> {
  const { tenantId: tenantUserId, tenantName, tenantPhone, propertyName, rejectionReason } = enrollment;

  // Send push notification if user has app
  if (tenantUserId) {
    try {
      const tokensSnap = await db
        .collection('users')
        .doc(tenantUserId)
        .collection('deviceTokens')
        .get();

      const tokens = tokensSnap.docs
        .map(d => d.data().token)
        .filter(Boolean) as string[];

      if (tokens.length > 0) {
        await messaging.sendEachForMulticast({
          tokens,
          notification: {
            title: 'Enrollment Update',
            body: `Your request for ${propertyName || 'the PG'} was not approved.`,
          },
          data: {
            type: 'enrollment_rejected',
            propertyName: propertyName || '',
          },
        });
      }
    } catch (err) {
      console.warn('Push notification failed:', err);
    }
  }

  // Send WhatsApp
  try {
    await sendWhatsAppTemplate({
      to: tenantPhone,
      templateName: 'enrollment_rejected',
      templateParams: [
        tenantName,
        propertyName || 'the PG',
        rejectionReason || 'No rooms available currently',
      ],
    });
  } catch (err) {
    console.warn('WhatsApp notification failed:', err);
  }
}

/**
 * Handle bill_sent status - Reserve bed and notify tenant to pay
 * Flow: Owner clicks "Send Bill" → Tenant receives notification with bill
 */
async function handleBillSent(
  requestId: string,
  enrollment: FirebaseFirestore.DocumentData
): Promise<void> {
  const {
    tenantId: tenantUserId,
    tenantName,
    tenantPhone,
    tenantEmail,
    propertyId,
    businessId,
    propertyName,
    roomId,
    roomNumber,
    bedId,
    bedNumber,
    depositAmount,
    advanceAmount,
    totalBillAmount,
    ownerUpiId,
    monthlyRent,
  } = enrollment;

  const now = admin.firestore.Timestamp.now();

  try {
    // 1. Reserve the bed (mark as pending)
    if (roomId && bedId) {
      const bedRef = db.doc(`businesses/${businessId}/properties/${propertyId}/rooms/${roomId}/beds/${bedId}`);
      await bedRef.update({
        reserved: true,
        reservedFor: tenantUserId || tenantPhone,
        reservedAt: now,
        reservationType: 'pending_payment',
        enrollmentRequestId: requestId,
      });
      console.log(`🔒 Bed ${bedNumber || bedId} reserved for payment`);
    }

    // 2. Get business details for the bill
    const businessSnap = await db.collection('businesses').doc(businessId).get();
    const businessData = businessSnap.data();
    const businessName = businessData?.name || propertyName || 'PG';

    // Format bill amount
    const totalAmount = totalBillAmount || (depositAmount || 0) + (advanceAmount || 0);
    const formattedAmount = `₹${totalAmount.toLocaleString('en-IN')}`;

    // 3. Send push notification if tenant has app
    if (tenantUserId) {
      try {
        const tokensSnap = await db
          .collection('users')
          .doc(tenantUserId)
          .collection('deviceTokens')
          .get();

        const tokens = tokensSnap.docs
          .map(d => d.data().token)
          .filter(Boolean) as string[];

        if (tokens.length > 0) {
          await messaging.sendEachForMulticast({
            tokens,
            notification: {
              title: '💰 Payment Required',
              body: `Pay ${formattedAmount} to confirm your room at ${propertyName}`,
            },
            data: {
              type: 'bill_received',
              requestId,
              propertyName: propertyName || '',
              roomNumber: roomNumber || '',
              bedNumber: bedNumber || '',
              depositAmount: String(depositAmount || 0),
              advanceAmount: String(advanceAmount || 0),
              totalAmount: String(totalAmount),
              ownerUpiId: ownerUpiId || '',
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
          });
          console.log('📱 Push notification sent to tenant for bill');
        }
      } catch (err) {
        console.warn('Push notification failed:', err);
      }
    }

    // 4. Create notification record for tenant app
    // Look up the actual tenant document ID (like TEN0000003) from user's document
    let actualTenantDocId: string | null = null;
    
    if (tenantUserId) {
      try {
        const userDoc = await db.collection('users').doc(tenantUserId).get();
        if (userDoc.exists) {
          actualTenantDocId = userDoc.data()?.tenantId || null;
        }
      } catch (err) {
        console.warn('Failed to look up tenant doc ID from user:', err);
      }
    }
    
    // If we couldn't find it, try querying tenants collection by userId
    if (!actualTenantDocId && tenantUserId) {
      try {
        const tenantQuery = await db.collection('tenants')
          .where('userId', '==', tenantUserId)
          .limit(1)
          .get();
        if (!tenantQuery.empty) {
          actualTenantDocId = tenantQuery.docs[0].id;
        }
      } catch (err) {
        console.warn('Failed to query tenant by userId:', err);
      }
    }
    
    if (!actualTenantDocId) {
      console.warn(`Could not find tenant document ID for user ${tenantUserId}`);
      // Don't create notification if we can't find the correct tenant doc
    } else {
      const notificationData = {
        type: 'bill_received',
        title: '💰 Payment Required',
        body: `Pay ${formattedAmount} to confirm your room at ${propertyName}`,
        enrollmentRequestId: requestId,
        propertyId,
        businessId,
        propertyName,
        roomNumber: roomNumber || roomId,
        bedNumber: bedNumber || bedId,
        depositAmount: depositAmount || 0,
        advanceAmount: advanceAmount || 0,
        totalAmount,
        ownerUpiId: ownerUpiId || '',
        monthlyRent: monthlyRent || 0,
        read: false,
        createdAt: now,
      };
      
      // Write to the correct tenant document (e.g., TEN0000003)
      await db.collection('tenants').doc(actualTenantDocId).collection('notifications').add(notificationData);
      console.log(`📝 Notification saved to tenants/${actualTenantDocId}/notifications`);
    }

    // 5. Send email notification
    if (tenantEmail) {
      try {
        await db.collection('mail').add({
          to: tenantEmail,
          template: {
            name: 'bill_sent',
            data: {
              tenantName,
              businessName,
              propertyName,
              roomNumber: roomNumber || roomId || 'Assigned',
              bedNumber: bedNumber || bedId || 'Assigned',
              depositAmount: `₹${(depositAmount || 0).toLocaleString('en-IN')}`,
              advanceAmount: `₹${(advanceAmount || 0).toLocaleString('en-IN')}`,
              totalAmount: formattedAmount,
              monthlyRent: `₹${(monthlyRent || 0).toLocaleString('en-IN')}`,
              ownerUpiId: ownerUpiId || 'Contact owner',
              appLink: APP_DOWNLOAD_LINK,
            },
          },
        });
        console.log('📧 Email sent to tenant');
      } catch (err) {
        console.warn('Email send failed:', err);
      }
    }

    console.log(`✅ Bill notification sent for enrollment ${requestId}`);
  } catch (error) {
    console.error('❌ Failed to process bill_sent:', error);
  }
}

/**
 * Handle payment_submitted status - Notify owner to verify payment
 * Flow: Tenant submits transaction ID → Owner receives notification
 */
async function handlePaymentSubmitted(
  requestId: string,
  enrollment: FirebaseFirestore.DocumentData
): Promise<void> {
  const {
    tenantName,
    tenantPhone,
    propertyId,
    businessId,
    propertyName,
    totalBillAmount,
    depositAmount,
    advanceAmount,
    transactionId,
    paymentSubmittedAt,
  } = enrollment;

  const totalAmount = totalBillAmount || (depositAmount || 0) + (advanceAmount || 0);
  const formattedAmount = `₹${totalAmount.toLocaleString('en-IN')}`;

  try {
    // Get business owner's user ID
    const businessSnap = await db.collection('businesses').doc(businessId).get();
    const businessData = businessSnap.data();
    const ownerUserId = businessData?.ownerUserId || businessData?.ownerUid;

    if (!ownerUserId) {
      console.warn(`No owner userId for business ${businessId}`);
      return;
    }

    // 1. Send push notification to owner
    try {
      const tokensSnap = await db
        .collection('users')
        .doc(ownerUserId)
        .collection('deviceTokens')
        .where('active', '==', true)
        .get();

      const tokens = tokensSnap.docs.map(d => d.id).filter(Boolean);

      if (tokens.length > 0) {
        for (const token of tokens) {
          try {
            await messaging.send({
              token,
              notification: {
                title: '💳 Payment Confirmation Required',
                body: `${tenantName} paid ${formattedAmount}. Please verify & confirm.`,
              },
              data: {
                type: 'payment_submitted',
                requestId,
                tenantName,
                tenantPhone,
                propertyName: propertyName || '',
                transactionId: transactionId || 'Not provided',
                totalAmount: String(totalAmount),
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                 businessId,
              },
            });
          } catch (err) {
            console.warn(`Failed to send to token ${token}:`, err);
          }
        }
        console.log('📱 Payment notification sent to owner');
      }
    } catch (err) {
      console.warn('Owner notification failed:', err);
    }

    // 2. Create notification record for owner
    await db.collection('businesses').doc(businessId).collection('notifications').add({
      businessId,
      type: 'payment_submitted',
      title: '💳 Payment Confirmation Required',
      // `message`/`requestId` are what the business app reads; `body` and
      // `enrollmentRequestId` are kept for anything already using them.
      message: `${tenantName} paid ${formattedAmount}. Transaction ID: ${transactionId || 'Not provided'}`,
      body: `${tenantName} paid ${formattedAmount}. Transaction ID: ${transactionId || 'Not provided'}`,
      requestId,
      enrollmentRequestId: requestId,
      propertyId,
      tenantName,
      tenantPhone,
      propertyName,
      transactionId: transactionId || '',
      totalAmount,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      routing: {
        target: 'pending_payments',
        requestId,
        propertyId,
      },
    });

    console.log(`✅ Payment submitted notification sent for enrollment ${requestId}`);
  } catch (error) {
    console.error('❌ Failed to process payment_submitted:', error);
  }
}

/**
 * Handle confirmed status - Create tenant record and notify
 * Flow: Owner confirms payment → Tenant record created → Both notified
 */
async function handlePaymentConfirmed(
  requestId: string,
  enrollment: FirebaseFirestore.DocumentData
): Promise<void> {
  console.log(`💰 Payment confirmed for enrollment ${requestId}, creating tenant record`);
  
  // Reuse the approved handler logic since the outcome is the same
  // (creating tenant record, marking bed occupied, etc.)
  await handleEnrollmentApproved(requestId, {
    ...enrollment,
    status: 'approved', // Override status for the handler
  });
}

/**
 * =====================================================
 * TRIGGER: When tenant is created manually by owner
 * Path: /businesses/{businessId}/tenants/{tenantId}
 * =====================================================
 * 
 * Sends WhatsApp invitation if tenant doesn't have app
 */
export const onTenantCreated = functions.firestore
  .document('businesses/{businessId}/tenants/{tenantId}')
  .onCreate(async (snap, context) => {
    const tenant = snap.data();
    const { businessId, tenantId } = context.params;

    // If tenant already has userId, they have the app - no need to invite
    if (tenant.userId) {
      console.log(`✅ Tenant ${tenantId} already linked to user ${tenant.userId}`);
      return null;
    }

    const tenantPhone = tenant.phone || '';
    const tenantEmail = tenant.email || tenant.tenantEmail || '';

    // If no phone or email, can't send invite
    if (!tenantPhone && !tenantEmail) {
      console.warn(`⚠️ Tenant ${tenantId} has no phone/email for invitation`);
      return null;
    }

    console.log(`📨 Sending invitation to tenant ${tenant.name} at ${tenantPhone || tenantEmail}`);

    try {
      // Get property name
      let propertyName = tenant.propertyName || '';
      if (!propertyName && tenant.propertyId) {
        const propSnap = await db.doc(`businesses/${businessId}/properties/${tenant.propertyId}`).get();
        propertyName = (propSnap.data() as any)?.name || tenant.propertyId;
      }

      // Get business name (for email)
      let businessName = tenant.businessName || '';
      if (!businessName) {
        const bizSnap = await db.doc(`businesses/${businessId}`).get();
        businessName = (bizSnap.data() as any)?.name || 'OneStay360';
      }

      const roomNumber = tenant.roomNumber || tenant.roomId || 'Assigned';
      const bedNumber = tenant.bedNumber || tenant.bedId || 'Assigned';

      // Send WhatsApp invitation
      if (tenantPhone) {
        await sendWhatsAppTemplate({
          to: tenantPhone,
          templateName: 'tenant_invitation',
          templateParams: [
            tenant.name,
            propertyName,
            roomNumber,
            bedNumber,
            APP_DOWNLOAD_LINK,
          ],
        });
      }

      // Send email invitation
      if (tenantEmail) {
        const emailPayload = buildTenantInvitationEmail({
          tenantName: tenant.name || 'Tenant',
          businessName,
          propertyName,
          roomNumber,
          bedNumber,
          appLink: APP_DOWNLOAD_LINK,
          to: tenantEmail,
        });
        await sendEmail(emailPayload);
      }

      // Mark invitation sent
      await snap.ref.update({
        inviteSentAt: admin.firestore.Timestamp.now(),
      });

      // Also update master tenant doc
      await db.doc(`tenants/${tenantId}`).update({
        inviteSentAt: admin.firestore.Timestamp.now(),
      }).catch(() => {}); // Ignore if doesn't exist

      console.log(`✅ Invitation sent to ${tenant.phone}`);
    } catch (err) {
      console.error('❌ Failed to send invitation:', err);
    }

    return null;
  });

/**
 * =====================================================
 * TRIGGER: When new user signs up in tenant app
 * Path: /users/{userId}
 * =====================================================
 * 
 * Auto-links tenant record if phone matches
 */
export const onTenantUserCreated = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    const user = snap.data();
    const userId = context.params.userId;

    // Only process tenant app users
    if (user.userType !== 'tenant' && user.role !== 'tenant') {
      return null;
    }

    const phone = user.phone || user.phoneNumber;
    if (!phone) {
      console.log(`User ${userId} has no phone number for tenant linking`);
      return null;
    }

    // Normalize phone (last 10 digits)
    const normalizedPhone = phone.replace(/\D/g, '').slice(-10);
    
    console.log(`🔗 Checking for existing tenant record with phone ...${normalizedPhone.slice(-4)}`);

    try {
      // Find tenant record with matching phone
      const tenantsSnap = await db.collectionGroup('tenants')
        .where('userId', '==', null) // Not yet linked
        .get();

      let matchedTenant: FirebaseFirestore.QueryDocumentSnapshot | null = null;
      
      for (const doc of tenantsSnap.docs) {
        const tenantPhone = (doc.data().phone || '').replace(/\D/g, '').slice(-10);
        if (tenantPhone === normalizedPhone) {
          matchedTenant = doc;
          break;
        }
      }

      if (!matchedTenant) {
        console.log(`No unlinked tenant found for phone ...${normalizedPhone.slice(-4)}`);
        return null;
      }

      const tenant = matchedTenant.data();
      console.log(`✅ Found tenant record: ${tenant.name} at ${tenant.propertyName || tenant.propertyId}`);

      const now = admin.firestore.Timestamp.now();

      // Link tenant to user
      await db.runTransaction(async (tx) => {
        // Update business tenant doc
        tx.update(matchedTenant!.ref, {
          userId,
          linkedAt: now,
          updatedAt: now,
        });

        // Update master tenant doc if exists
        const masterRef = db.doc(`tenants/${matchedTenant!.id}`);
        const masterSnap = await tx.get(masterRef);
        if (masterSnap.exists) {
          tx.update(masterRef, {
            userId,
            linkedAt: now,
            updatedAt: now,
          });
        }

        // Update user doc with tenant info
        // Only update tenantId if it doesn't already have a friendly one
        const userUpdate: any = {
          isTenant: true,
          linkedAt: now,
          updatedAt: now,
        };

        if (!user.tenantId || !user.tenantId.startsWith('TEN')) {
          userUpdate.tenantId = matchedTenant!.id;
        }

        tx.update(snap.ref, userUpdate);

        // Also update the business-scoped tenant record to have the user's tenantId if it's better
        if (user.tenantId && user.tenantId.startsWith('TEN')) {
          tx.update(matchedTenant!.ref, {
            tenantId: user.tenantId,
            updatedAt: now,
          });
        }
      });

      console.log(`🎉 Tenant ${tenant.name} linked to user ${userId}`);

      // Send welcome notification
      const tokensSnap = await db.collection('users').doc(userId).collection('deviceTokens').get();
      const tokens = tokensSnap.docs.map(d => d.data().token).filter(Boolean) as string[];

      if (tokens.length > 0) {
        await messaging.sendEachForMulticast({
          tokens,
          notification: {
            title: '🏠 Welcome to Your PG!',
            body: `You're now connected to ${tenant.propertyName || 'your PG'}. View room details and pay rent in the app.`,
          },
          data: {
            type: 'tenant_linked',
            propertyId: tenant.propertyId || '',
            businessId: tenant.businessId || '',
          },
        });
      }

    } catch (err) {
      console.error('❌ Failed to link tenant:', err);
    }

    return null;
  });

/**
 * =====================================================
 * CALLABLE: Resend tenant invitation
 * =====================================================
 */
export const resendTenantInvitation = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }

  const { tenantId, businessId } = data;
  if (!tenantId || !businessId) {
    throw new functions.https.HttpsError('invalid-argument', 'tenantId and businessId required');
  }

  const tenantRef = db.doc(`businesses/${businessId}/tenants/${tenantId}`);
  const tenantSnap = await tenantRef.get();

  if (!tenantSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Tenant not found');
  }

  const tenant = tenantSnap.data()!;

  if (tenant.userId) {
    throw new functions.https.HttpsError('failed-precondition', 'Tenant already has app installed');
  }

  const tenantPhone = tenant.phone || '';
  const tenantEmail = tenant.email || tenant.tenantEmail || '';

  if (!tenantPhone && !tenantEmail) {
    throw new functions.https.HttpsError('failed-precondition', 'Tenant has no phone/email');
  }

  // Get property name
  let propertyName = tenant.propertyName || '';
  if (!propertyName && tenant.propertyId) {
    const propSnap = await db.doc(`businesses/${businessId}/properties/${tenant.propertyId}`).get();
    propertyName = (propSnap.data() as any)?.name || tenant.propertyId;
  }

  const roomNumber = tenant.roomNumber || tenant.roomId || 'Assigned';
  const bedNumber = tenant.bedNumber || tenant.bedId || 'Assigned';

  if (tenantPhone) {
    await sendWhatsAppTemplate({
      to: tenantPhone,
      templateName: 'tenant_invitation',
      templateParams: [
        tenant.name,
        propertyName,
        roomNumber,
        bedNumber,
        APP_DOWNLOAD_LINK,
      ],
    });
  }

  if (tenantEmail) {
    let businessName = tenant.businessName || '';
    if (!businessName) {
      const bizSnap = await db.doc(`businesses/${businessId}`).get();
      businessName = (bizSnap.data() as any)?.name || 'OneStay360';
    }

    const emailPayload = buildTenantInvitationEmail({
      tenantName: tenant.name || 'Tenant',
      businessName,
      propertyName,
      roomNumber,
      bedNumber,
      appLink: APP_DOWNLOAD_LINK,
      to: tenantEmail,
    });
    await sendEmail(emailPayload);
  }

  await tenantRef.update({
    inviteSentAt: admin.firestore.Timestamp.now(),
    inviteCount: admin.firestore.FieldValue.increment(1),
  });

  return { success: true, message: 'Invitation sent' };
});

/**
 * =====================================================
 * CALLABLE: Create tenant invitation (server-side write)
 * =====================================================
 */
export const createTenantInvitation = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }

  const uid = context.auth.uid;
  const {
    tenantId,
    tenantName,
    tenantPhone,
    tenantEmail,
    businessId,
    propertyId,
    propertyName,
    floor,
    roomId,
    roomNumber,
    bedIndex,
    bedNumber,
    moveInDate,
    moveOutDate,
    monthlyRent,
    deposit,
    maintenance,
    maintenanceDeductedFromDeposit,
    proratedRent,
    billingDay,
    lockInPeriodMonths,
    noticePeriodDays,
    paymentCycle,
    tenantDetails,
    gender,
  } = data || {};

  if (!tenantName || !tenantPhone || !businessId || !propertyId || !roomId || !roomNumber) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required invitation fields');
  }

  const memberSnap = await db.doc(`businesses/${businessId}/members/${uid}`).get();
  const member = memberSnap.data();
  if (!memberSnap.exists || member?.status !== 'active' || member?.role !== 'owner') {
    throw new functions.https.HttpsError('permission-denied', 'Only business owners can create invitations');
  }

  const moveInMs = typeof moveInDate === 'number' ? moveInDate : Date.parse(moveInDate || '');
  if (!moveInMs || Number.isNaN(moveInMs)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid moveInDate');
  }

  const moveOutMs = moveOutDate ? (typeof moveOutDate === 'number' ? moveOutDate : Date.parse(moveOutDate)) : null;
  let resolvedTenantId = tenantId || '';

  if (!resolvedTenantId) {
    const existingTenantSnap = await db
      .collection('tenants')
      .where('phone', '==', tenantPhone)
      .limit(1)
      .get();
    if (!existingTenantSnap.empty) {
      resolvedTenantId = existingTenantSnap.docs[0].id;
    }
  }

  if (!resolvedTenantId) {
    resolvedTenantId = await generateTenantId();
  }

  const tenantRef = db.doc(`tenants/${resolvedTenantId}`);
  const tenantSnap = await tenantRef.get();
  if (!tenantSnap.exists) {
    await tenantRef.set({
      tenantId: resolvedTenantId,
      name: tenantName,
      phone: tenantPhone,
      email: tenantEmail || null,
      businessId,
      // Explicit null so onTenantUserCreated (userId == null) can link it.
      userId: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  const invitationRef = db.collection('tenant_invitations').doc();

  const invitationData = {
    tenantId: resolvedTenantId,
    tenantName,
    tenantPhone,
    tenantEmail: tenantEmail || null,
    businessId,
    propertyId,
    propertyName: propertyName || '',
    floor: floor || '',
    roomId,
    roomNumber,
    bedIndex: typeof bedIndex === 'number' ? bedIndex : 0,
    bedNumber: bedNumber || '1',
    moveInDate: admin.firestore.Timestamp.fromMillis(moveInMs),
    moveOutDate: moveOutMs ? admin.firestore.Timestamp.fromMillis(moveOutMs) : null,
    monthlyRent: typeof monthlyRent === 'number' ? monthlyRent : 0,
    deposit: typeof deposit === 'number' ? deposit : null,
    maintenance: typeof maintenance === 'number' ? maintenance : null,
    maintenanceDeductedFromDeposit: typeof maintenanceDeductedFromDeposit === 'boolean'
      ? maintenanceDeductedFromDeposit
      : null,
    proratedRent: typeof proratedRent === 'number' ? proratedRent : null,
    billingDay: typeof billingDay === 'number' ? billingDay : null,
    lockInPeriodMonths: typeof lockInPeriodMonths === 'number' ? lockInPeriodMonths : null,
    noticePeriodDays: typeof noticePeriodDays === 'number' ? noticePeriodDays : null,
    paymentCycle: paymentCycle || 'Monthly',
    status: 'pending',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    tenantDetails: tenantDetails || null,
    gender: gender || null,
  };

  await invitationRef.set(invitationData);

  // Best-effort notification for tenant app
  try {
    await db.collection('tenants').doc(resolvedTenantId).collection('notifications').add({
        type: 'tenant_invitation',
        invitationId: invitationRef.id,
        title: 'New PG Invitation',
        message: `You have been invited to join ${propertyName || 'a PG'}, Room ${roomNumber}, Bed ${bedNumber}`,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  } catch (err) {
    functions.logger.warn('tenant_invite_notification_failed', err);
  }

  return { success: true, invitationId: invitationRef.id, tenantId: resolvedTenantId };
});

/**
 * =====================================================
 * TRIGGER: When tenant invitation is created
 * Path: /tenant_invitations/{invitationId}
 * =====================================================
 */
export const onTenantInvitationCreated = functions.firestore
  .document('tenant_invitations/{invitationId}')
  .onCreate(async (snap) => {
    const invitation = snap.data();
    if (!invitation) return null;

    if (invitation.inviteNotificationSentAt) {
      return null;
    }

    const tenantName = invitation.tenantName || 'Tenant';
    const tenantPhone = invitation.tenantPhone || '';
    const tenantEmail =
      invitation.tenantEmail
      || invitation.email
      || invitation.tenantDetails?.email
      || '';
    const businessId = invitation.businessId || '';
    const propertyId = invitation.propertyId || '';
    const roomNumber = invitation.roomNumber || invitation.roomId || 'Assigned';
    const bedNumber = invitation.bedNumber || 'Assigned';

    try {
      let propertyName = invitation.propertyName || '';
      if (!propertyName && businessId && propertyId) {
        const propSnap = await db.doc(`businesses/${businessId}/properties/${propertyId}`).get();
        propertyName = (propSnap.data() as any)?.name || propertyId;
      }

      let businessName = 'OneStay360';
      if (businessId) {
        const bizSnap = await db.doc(`businesses/${businessId}`).get();
        businessName = (bizSnap.data() as any)?.name || businessName;
      }

      if (tenantPhone) {
        try {
          await sendWhatsAppTemplate({
            to: tenantPhone,
            templateName: 'tenant_invitation',
            templateParams: [
              tenantName,
              propertyName || businessName,
              roomNumber,
              bedNumber,
              APP_DOWNLOAD_LINK,
            ],
          });
        } catch (err) {
          functions.logger.warn('tenant_invitation_whatsapp_failed', err);
        }
      }

      if (tenantEmail) {
        try {
          const emailPayload = buildTenantInvitationEmail({
            tenantName,
            businessName,
            propertyName: propertyName || businessName,
            roomNumber,
            bedNumber,
            appLink: APP_DOWNLOAD_LINK,
            to: tenantEmail,
          });
          await sendEmail(emailPayload);
        } catch (err) {
          functions.logger.warn('tenant_invitation_email_failed', err);
        }
      }

      await snap.ref.update({
        inviteNotificationSentAt: admin.firestore.Timestamp.now(),
      });
    } catch (err) {
      functions.logger.warn('tenant_invitation_notify_failed', err);
    }

    return null;
  });

/**
 * =====================================================
 * CALLABLE: Vacate Tenant
 * =====================================================
 */
export const vacateTenant = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }

  const { tenantId, businessId, propertyId, roomId, bedId } = data;
  
  if (!tenantId || !businessId || !propertyId || !roomId || !bedId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields: tenantId, businessId, propertyId, roomId, bedId');
  }

  // Removing a tenant is an owner decision.
  await assertPropertyPermission(context.auth.uid, businessId, propertyId, 'DELETE_TENANTS');

  console.log(`🚪 Vacating tenant ${tenantId} from property ${propertyId}, room ${roomId}, bed ${bedId}`);

  try {
    const now = admin.firestore.Timestamp.now();
    const globalTenantRef = db.doc(`tenants/${tenantId}`);

    // Query active stay to mark as vacated
    const activeStaysQuery = await globalTenantRef.collection('stays')
      .where('status', '==', 'active')
      .where('propertyId', '==', propertyId)
      .limit(1)
      .get();
    const activeStayRef = activeStaysQuery.empty ? null : activeStaysQuery.docs[0].ref;

    await db.runTransaction(async (tx) => {
      // ── ALL READS FIRST (Firestore requires reads before writes) ──
      const bedRef = db.doc(`businesses/${businessId}/properties/${propertyId}/rooms/${roomId}/beds/${bedId}`);
      const propertyRef = db.doc(`businesses/${businessId}/properties/${propertyId}`);
      const bizTenantRef = db.doc(`businesses/${businessId}/tenants/${tenantId}`);

      const globalSnap = await tx.get(globalTenantRef);

      // ── ALL WRITES AFTER ──

      // 1. Update bed status
      tx.set(bedRef, {
        occupied: false,
        isOccupied: false,
        tenantId: null,
        tenantName: null,
        occupiedAt: null,
        updatedAt: now,
      }, { merge: true });

      // 2. Decrement property occupancy count
      tx.update(propertyRef, {
        occupiedBeds: admin.firestore.FieldValue.increment(-1),
        updatedAt: now,
      });

      // 3. Update business-scoped tenant status
      tx.update(bizTenantRef, {
        status: 'vacated',
        vacatedAt: now,
        updatedAt: now,
      });

      // 4. Update global tenant status (with safety check)
      if (globalSnap.exists) {
        const globalData = globalSnap.data();
        // Only clear residency info if it matches the property being vacated
        // This prevents clearing info if the tenant has already moved into a new PG
        if (globalData?.propertyId === propertyId) {
          tx.update(globalTenantRef, {
            status: 'vacated',
            currentPropertyId: null,
            propertyId: null,
            roomId: null,
            roomNumber: null,
            bedId: null,
            bedNumber: null,
            vacatedAt: now,
            updatedAt: now,
          });

          if (activeStayRef) {
            tx.update(activeStayRef, {
              status: 'vacated',
              vacatedAt: now,
              updatedAt: now,
            });
          }
        } else {
          console.log(`⚠️ Global tenant doc for ${tenantId} points to different property (${globalData?.propertyId}), skipping residency clear.`);
          tx.update(globalTenantRef, {
            updatedAt: now,
          });
        }
      }
    });

    // 5. After the transaction: check if all beds in the room are now empty.
    //    If yes, reset the room gender lock to null.
    //    (Cannot do collection query inside a Firestore transaction.)
    const bedsSnap = await db
      .collection(`businesses/${businessId}/properties/${propertyId}/rooms/${roomId}/beds`)
      .get();

    const anyOccupied = bedsSnap.docs.some((doc) => doc.data()?.isOccupied === true);
    
    if (!anyOccupied) {
      await db
        .doc(`businesses/${businessId}/properties/${propertyId}/rooms/${roomId}`)
        .update({ gender: null, updatedAt: admin.firestore.Timestamp.now() });
      console.log(`🔓 Room ${roomId} is now fully vacant — gender lock reset.`);
    } else {
      console.log(`🔒 Room ${roomId} still has occupied beds — gender lock preserved.`);
    }

    console.log(`✅ Successfully vacated tenant ${tenantId}`);
    return { success: true };
  } catch (err) {
    console.error('❌ Failed to vacate tenant:', err);
    throw new functions.https.HttpsError('internal', err instanceof Error ? err.message : 'Unknown error during vacate');
  }
});
