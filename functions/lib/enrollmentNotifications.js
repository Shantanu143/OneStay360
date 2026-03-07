"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanupInactiveDeviceTokens = exports.registerDeviceToken = exports.onEnrollmentRequestCreated = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();
const messaging = admin.messaging();
/**
 * Firestore trigger: Send push notification to business owner when new enrollment request is received
 * Triggers on: /enrollmentRequests/{requestId}
 *
 * The enrollment request contains:
 * - propertyId: Which property is being requested
 * - tenantId: Who is requesting
 * - tenantName: Tenant's name
 * - tenantPhone: Tenant's phone
 * - moveInDate: Requested move-in date
 * - status: 'pending' (initial)
 */
exports.onEnrollmentRequestCreated = functions.firestore
    .document('enrollmentRequests/{requestId}')
    .onCreate(async (snap, context) => {
    try {
        const enrollmentRequest = snap.data();
        const requestId = context.params.requestId;
        // Extract data from enrollment request
        const propertyId = enrollmentRequest.propertyId;
        const storedBusinessId = enrollmentRequest.businessId;
        const storedPropertyName = enrollmentRequest.propertyName;
        const tenantId = enrollmentRequest.tenantId;
        const tenantName = enrollmentRequest.tenantName;
        const tenantPhone = enrollmentRequest.tenantPhone;
        const moveInDate = enrollmentRequest.moveInDate;
        if (!propertyId) {
            throw new Error('Property ID not found in enrollment request');
        }
        // Prefer stored businessId, otherwise fall back to deriving from propertyId
        let businessId = storedBusinessId;
        if (!businessId || businessId.length < 3) {
            businessId = propertyId.substring(0, 10);
        }
        if (!businessId || !businessId.startsWith('BUS')) {
            throw new Error(`Invalid business ID when processing property ${propertyId}`);
        }
        console.log(`📍 Processing enrollment for property: ${propertyId}, businessId: ${businessId}`);
        // For now, use propertyId as display name if we can't fetch property details
        // This ensures notification is sent even if property fetch fails
        let propertyName = storedPropertyName || propertyId;
        // Try to get property name, but don't fail if we can't
        try {
            const propertySnap = await db
                .collection('businesses')
                .doc(businessId)
                .collection('properties')
                .doc(propertyId)
                .get();
            if (propertySnap.exists) {
                const propertyData = propertySnap.data();
                propertyName = propertyData?.name || propertyId;
                console.log(`✅ Property loaded: ${propertyName}`);
            }
            else {
                console.warn(`⚠️ Property not found, using ID as name: ${propertyId}`);
            }
        }
        catch (error) {
            console.warn(`⚠️ Could not fetch property details, using ID as name:`, error);
        }
        // Get business owner's device token
        const businessSnap = await db.collection('businesses').doc(businessId).get();
        if (!businessSnap.exists) {
            throw new Error(`Business not found: ${businessId}`);
        }
        const businessData = businessSnap.data();
        const ownerUserId = businessData?.ownerUserId || businessData?.ownerUid;
        if (!ownerUserId) {
            console.warn(`Business ${businessId} does not have ownerUserId or ownerUid set. Notification not sent.`);
            return;
        }
        // Get device tokens for the business owner
        const deviceTokensSnap = await db
            .collection('users')
            .doc(ownerUserId)
            .collection('deviceTokens')
            .where('active', '==', true)
            .limit(100)
            .get();
        if (deviceTokensSnap.empty) {
            console.log(`No active device tokens found for business owner ${ownerUserId}. ` +
                `User may not have registered for notifications.`);
            return;
        }
        // Format move-in date
        let moveInDateFormatted = 'Not specified';
        if (moveInDate) {
            try {
                const date = moveInDate.toDate
                    ? moveInDate.toDate()
                    : new Date(moveInDate);
                moveInDateFormatted = date.toLocaleDateString('en-IN');
            }
            catch (e) {
                console.warn('Could not format move-in date:', e);
            }
        }
        // Prepare notification payload
        const notification = {
            title: `New Enrollment Request`,
            body: `${tenantName} is interested in ${propertyName}`,
        };
        const data = {
            requestId: requestId,
            propertyId: propertyId,
            businessId: businessId,
            propertyName: propertyName,
            tenantId: tenantId,
            tenantName: tenantName,
            tenantPhone: tenantPhone,
            moveInDate: moveInDateFormatted,
            type: 'enrollment_request',
            notificationTimestamp: new Date().toISOString(),
        };
        // Send notifications to all device tokens
        const deviceTokens = deviceTokensSnap.docs.map((doc) => doc.id);
        const failedTokens = [];
        const sendPromises = deviceTokens.map(async (token) => {
            try {
                await messaging.send({
                    token: token,
                    notification: notification,
                    data: data,
                    android: {
                        priority: 'high',
                        notification: {
                            title: notification.title,
                            body: notification.body,
                            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
                            sound: 'default',
                            channelId: 'enrollment_requests',
                        },
                    },
                    apns: {
                        payload: {
                            aps: {
                                alert: {
                                    title: notification.title,
                                    body: notification.body,
                                },
                                sound: 'default',
                                badge: 1,
                            },
                        },
                    },
                    webpush: {
                        notification: {
                            title: notification.title,
                            body: notification.body,
                            icon: '/icons/icon-192x192.png',
                            badge: '/icons/badge-72x72.png',
                        },
                        data: data,
                    },
                });
                console.log(`✅ Notification sent to token: ${token}`);
            }
            catch (error) {
                console.error(`❌ Failed to send to token ${token}:`, error);
                failedTokens.push(token);
                // If token is invalid, mark it as inactive
                if (error instanceof Error &&
                    (error.message.includes('registration token is invalid') ||
                        error.message.includes('registration token is not registered'))) {
                    await db
                        .collection('users')
                        .doc(ownerUserId)
                        .collection('deviceTokens')
                        .doc(token)
                        .update({ active: false, deactivatedAt: new Date() })
                        .catch((e) => console.warn(`Could not mark token inactive: ${token}`, e));
                }
            }
        });
        await Promise.all(sendPromises);
        try {
            await db
                .collection('businesses')
                .doc(businessId)
                .collection('notifications')
                .add({
                businessId,
                title: notification.title,
                message: notification.body,
                type: data.type ?? 'enrollment_request',
                requestId,
                propertyId,
                propertyName,
                tenantId,
                tenantName,
                tenantPhone,
                read: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                metadata: {
                    moveInDate: moveInDateFormatted,
                },
                routing: {
                    target: 'property_requests',
                    requestId,
                    propertyId,
                },
            });
        }
        catch (error) {
            console.error('⚠️ Failed to persist business notification document:', error);
        }
        // Log the notification event
        await db.collection('enrollmentRequests').doc(requestId).update({
            notificationsSentAt: new Date(),
            notificationsSentTo: deviceTokens.length,
            notificationsFailed: failedTokens.length,
            lastUpdated: new Date(),
        });
        console.log(`✅ Enrollment request notification complete for request ${requestId}: ` +
            `sent to ${deviceTokens.length - failedTokens.length} devices, ` +
            `${failedTokens.length} failed`);
    }
    catch (error) {
        console.error('❌ Error in onEnrollmentRequestCreated:', error);
        // Don't throw - we don't want the write to fail if notification fails
    }
});
/**
 * HTTP function to register/update device token for a user
 * Call from mobile app when app initializes
 *
 * Request body:
 * {
 *   "deviceToken": "firebase-cloud-messaging-token",
 *   "deviceName": "iPhone 12 Pro", // optional
 *   "deviceModel": "iOS 15.0" // optional
 * }
 */
exports.registerDeviceToken = functions.https.onCall(async (data, context) => {
    // Verify user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be logged in to register device token');
    }
    const userId = context.auth.uid;
    const { deviceToken, deviceName, deviceModel } = data;
    if (!deviceToken || typeof deviceToken !== 'string') {
        throw new functions.https.HttpsError('invalid-argument', 'deviceToken is required and must be a string');
    }
    try {
        // Register/update device token
        await db
            .collection('users')
            .doc(userId)
            .collection('deviceTokens')
            .doc(deviceToken)
            .set({
            token: deviceToken,
            active: true,
            registeredAt: admin.firestore.FieldValue.serverTimestamp(),
            lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
            deviceName: deviceName || 'Unknown Device',
            deviceModel: deviceModel || 'Unknown Model',
        }, { merge: true });
        console.log(`✅ Device token registered for user ${userId}`);
        return {
            success: true,
            message: 'Device token registered successfully',
        };
    }
    catch (error) {
        console.error('Error registering device token:', error);
        throw new functions.https.HttpsError('internal', 'Failed to register device token');
    }
});
/*
 * DISABLED - This functionality is now handled by tenantOnboarding.ts → handleBillSent()
 * Keeping this commented out for reference
 *
 * Firestore trigger: Send push notification to tenant when bill is sent
 * Triggers on: /enrollmentRequests/{requestId} update when status changes to 'bill_sent'
 */
/*
export const onBillSentToTenant = functions.firestore
  .document('enrollmentRequests/{requestId}')
  .onUpdate(async (change, context) => {
    // ... disabled - see tenantOnboarding.ts handleBillSent() instead
  });
*/
/**
 * Scheduled function to clean up inactive device tokens (daily)
 * Removes tokens that have been inactive for more than 30 days
 */
exports.cleanupInactiveDeviceTokens = functions.pubsub
    .schedule('every day 02:00')
    .timeZone('Asia/Kolkata')
    .onRun(async (context) => {
    try {
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        const usersSnap = await db.collection('users').get();
        let totalDeleted = 0;
        for (const userDoc of usersSnap.docs) {
            const tokensSnap = await userDoc.ref
                .collection('deviceTokens')
                .where('lastSeenAt', '<', thirtyDaysAgo)
                .get();
            for (const tokenDoc of tokensSnap.docs) {
                await tokenDoc.ref.delete();
                totalDeleted++;
            }
        }
        console.log(`✅ Cleanup complete: Deleted ${totalDeleted} inactive tokens`);
        return null;
    }
    catch (error) {
        console.error('Error cleaning up inactive tokens:', error);
        return null;
    }
});
//# sourceMappingURL=enrollmentNotifications.js.map