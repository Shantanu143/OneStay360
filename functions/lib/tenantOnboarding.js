"use strict";
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
exports.resendTenantInvitation = exports.onTenantUserCreated = exports.onTenantCreated = exports.onEnrollmentStatusChanged = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const sendWhatsApp_1 = require("./sendWhatsApp");
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();
const messaging = admin.messaging();
// App download link - update this with your actual app link
const APP_DOWNLOAD_LINK = 'https://onestay360.page.link/tenant';
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
exports.onEnrollmentStatusChanged = functions.firestore
    .document('enrollmentRequests/{requestId}')
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const requestId = context.params.requestId;
    // Only process when status changes
    if (before.status === after.status) {
        return null;
    }
    const newStatus = after.status;
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
async function handleEnrollmentApproved(requestId, enrollment) {
    const { tenantId: tenantUserId, // This is the user's Firebase UID
    tenantName, tenantPhone, propertyId, businessId, propertyName, moveInDate, roomId, // Set during approval
    bedId, // Set during approval
    roomNumber, // Human readable
    bedNumber, // Human readable
    monthlyRent, // Set during approval
     } = enrollment;
    // Validate required fields for approval
    if (!roomId || !bedId) {
        console.error('❌ Enrollment approved without room/bed assignment!');
        // Update status back to pending with error
        await db.doc(`enrollmentRequests/${requestId}`).update({
            status: 'pending',
            approvalError: 'Room and bed must be assigned before approval',
        });
        return;
    }
    const now = admin.firestore.Timestamp.now();
    const tenantDocId = `${businessId}_${tenantUserId || tenantPhone.replace(/\D/g, '')}`;
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
            // 2. Create tenant record
            const tenantData = {
                id: tenantDocId,
                userId: tenantUserId || null, // Link to user account if they have one
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
                linkedAt: tenantUserId ? now : null, // Linked if user exists
                inviteSentAt: null,
            };
            // Master tenant record
            const masterTenantRef = db.doc(`tenants/${tenantDocId}`);
            tx.set(masterTenantRef, tenantData);
            // Business-scoped tenant record
            const bizTenantRef = db.doc(`businesses/${businessId}/tenants/${tenantDocId}`);
            tx.set(bizTenantRef, tenantData);
            // 3. Mark bed as occupied
            tx.set(bedRef, {
                occupied: true,
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
            // 5. If user exists, update their user document with property link
            if (tenantUserId) {
                const userRef = db.doc(`users/${tenantUserId}`);
                tx.update(userRef, {
                    tenantId: tenantDocId,
                    currentPropertyId: propertyId,
                    currentBusinessId: businessId,
                    isTenant: true,
                    updatedAt: now,
                });
            }
            // 6. Mark enrollment as completed
            tx.update(db.doc(`enrollmentRequests/${requestId}`), {
                tenantDocId,
                completedAt: now,
            });
        });
        console.log(`✅ Tenant record created: ${tenantDocId}`);
        // 7. Send notifications (non-blocking)
        await notifyTenantApproved(enrollment, tenantUserId, roomNumber || roomId, bedNumber || bedId);
    }
    catch (error) {
        console.error('❌ Failed to create tenant:', error);
        // Update enrollment with error
        await db.doc(`enrollmentRequests/${requestId}`).update({
            approvalError: error.message,
            status: 'approval_failed',
        });
        throw error;
    }
}
/**
 * Send notification to tenant when approved
 */
async function notifyTenantApproved(enrollment, tenantUserId, roomNumber, bedNumber) {
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
                .filter(Boolean);
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
        }
        catch (err) {
            console.warn('Push notification failed:', err);
        }
    }
    // Always send WhatsApp (works whether they have app or not)
    try {
        await (0, sendWhatsApp_1.sendWhatsAppTemplate)({
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
    }
    catch (err) {
        console.warn('WhatsApp notification failed:', err);
    }
}
/**
 * Handle rejected enrollment
 */
async function handleEnrollmentRejected(requestId, enrollment) {
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
                .filter(Boolean);
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
        }
        catch (err) {
            console.warn('Push notification failed:', err);
        }
    }
    // Send WhatsApp
    try {
        await (0, sendWhatsApp_1.sendWhatsAppTemplate)({
            to: tenantPhone,
            templateName: 'enrollment_rejected',
            templateParams: [
                tenantName,
                propertyName || 'the PG',
                rejectionReason || 'No rooms available currently',
            ],
        });
    }
    catch (err) {
        console.warn('WhatsApp notification failed:', err);
    }
}
/**
 * Handle bill_sent status - Reserve bed and notify tenant to pay
 * Flow: Owner clicks "Send Bill" → Tenant receives notification with bill
 */
async function handleBillSent(requestId, enrollment) {
    const { tenantId: tenantUserId, tenantName, tenantPhone, tenantEmail, propertyId, businessId, propertyName, roomId, roomNumber, bedId, bedNumber, depositAmount, advanceAmount, totalBillAmount, ownerUpiId, monthlyRent, } = enrollment;
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
                    .filter(Boolean);
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
            }
            catch (err) {
                console.warn('Push notification failed:', err);
            }
        }
        // 4. Create notification record for tenant app
        // Look up the actual tenant document ID (like TEN0000003) from user's document
        let actualTenantDocId = null;
        if (tenantUserId) {
            try {
                const userDoc = await db.collection('users').doc(tenantUserId).get();
                if (userDoc.exists) {
                    actualTenantDocId = userDoc.data()?.tenantId || null;
                }
            }
            catch (err) {
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
            }
            catch (err) {
                console.warn('Failed to query tenant by userId:', err);
            }
        }
        if (!actualTenantDocId) {
            console.warn(`Could not find tenant document ID for user ${tenantUserId}`);
            // Don't create notification if we can't find the correct tenant doc
        }
        else {
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
            }
            catch (err) {
                console.warn('Email send failed:', err);
            }
        }
        console.log(`✅ Bill notification sent for enrollment ${requestId}`);
    }
    catch (error) {
        console.error('❌ Failed to process bill_sent:', error);
    }
}
/**
 * Handle payment_submitted status - Notify owner to verify payment
 * Flow: Tenant submits transaction ID → Owner receives notification
 */
async function handlePaymentSubmitted(requestId, enrollment) {
    const { tenantName, tenantPhone, propertyId, businessId, propertyName, totalBillAmount, depositAmount, advanceAmount, transactionId, paymentSubmittedAt, } = enrollment;
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
                    }
                    catch (err) {
                        console.warn(`Failed to send to token ${token}:`, err);
                    }
                }
                console.log('📱 Payment notification sent to owner');
            }
        }
        catch (err) {
            console.warn('Owner notification failed:', err);
        }
        // 2. Create notification record for owner
        await db.collection('businesses').doc(businessId).collection('notifications').add({
            type: 'payment_submitted',
            title: '💳 Payment Confirmation Required',
            body: `${tenantName} paid ${formattedAmount}. Transaction ID: ${transactionId || 'Not provided'}`,
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
    }
    catch (error) {
        console.error('❌ Failed to process payment_submitted:', error);
    }
}
/**
 * Handle confirmed status - Create tenant record and notify
 * Flow: Owner confirms payment → Tenant record created → Both notified
 */
async function handlePaymentConfirmed(requestId, enrollment) {
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
exports.onTenantCreated = functions.firestore
    .document('businesses/{businessId}/tenants/{tenantId}')
    .onCreate(async (snap, context) => {
    const tenant = snap.data();
    const { businessId, tenantId } = context.params;
    // If tenant already has userId, they have the app - no need to invite
    if (tenant.userId) {
        console.log(`✅ Tenant ${tenantId} already linked to user ${tenant.userId}`);
        return null;
    }
    // If no phone, can't send invite
    if (!tenant.phone) {
        console.warn(`⚠️ Tenant ${tenantId} has no phone number for invitation`);
        return null;
    }
    console.log(`📨 Sending invitation to tenant ${tenant.name} at ${tenant.phone}`);
    try {
        // Get property name
        let propertyName = tenant.propertyName || '';
        if (!propertyName && tenant.propertyId) {
            const propSnap = await db.doc(`businesses/${businessId}/properties/${tenant.propertyId}`).get();
            propertyName = propSnap.data()?.name || tenant.propertyId;
        }
        // Send WhatsApp invitation
        await (0, sendWhatsApp_1.sendWhatsAppTemplate)({
            to: tenant.phone,
            templateName: 'tenant_invitation',
            templateParams: [
                tenant.name,
                propertyName,
                tenant.roomNumber || tenant.roomId || 'Assigned',
                tenant.bedNumber || tenant.bedId || 'Assigned',
                APP_DOWNLOAD_LINK,
            ],
        });
        // Mark invitation sent
        await snap.ref.update({
            inviteSentAt: admin.firestore.Timestamp.now(),
        });
        // Also update master tenant doc
        await db.doc(`tenants/${tenantId}`).update({
            inviteSentAt: admin.firestore.Timestamp.now(),
        }).catch(() => { }); // Ignore if doesn't exist
        console.log(`✅ Invitation sent to ${tenant.phone}`);
    }
    catch (err) {
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
exports.onTenantUserCreated = functions.firestore
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
        let matchedTenant = null;
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
            tx.update(matchedTenant.ref, {
                userId,
                linkedAt: now,
                updatedAt: now,
            });
            // Update master tenant doc if exists
            const masterRef = db.doc(`tenants/${matchedTenant.id}`);
            const masterSnap = await tx.get(masterRef);
            if (masterSnap.exists) {
                tx.update(masterRef, {
                    userId,
                    linkedAt: now,
                    updatedAt: now,
                });
            }
            // Update user doc with tenant info
            tx.update(snap.ref, {
                tenantId: matchedTenant.id,
                currentPropertyId: tenant.propertyId,
                currentBusinessId: tenant.businessId,
                isTenant: true,
                linkedAt: now,
                updatedAt: now,
            });
        });
        console.log(`🎉 Tenant ${tenant.name} linked to user ${userId}`);
        // Send welcome notification
        const tokensSnap = await db.collection('users').doc(userId).collection('deviceTokens').get();
        const tokens = tokensSnap.docs.map(d => d.data().token).filter(Boolean);
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
    }
    catch (err) {
        console.error('❌ Failed to link tenant:', err);
    }
    return null;
});
/**
 * =====================================================
 * CALLABLE: Resend tenant invitation
 * =====================================================
 */
exports.resendTenantInvitation = functions.https.onCall(async (data, context) => {
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
    const tenant = tenantSnap.data();
    if (tenant.userId) {
        throw new functions.https.HttpsError('failed-precondition', 'Tenant already has app installed');
    }
    if (!tenant.phone) {
        throw new functions.https.HttpsError('failed-precondition', 'Tenant has no phone number');
    }
    // Get property name
    let propertyName = tenant.propertyName || '';
    if (!propertyName && tenant.propertyId) {
        const propSnap = await db.doc(`businesses/${businessId}/properties/${tenant.propertyId}`).get();
        propertyName = propSnap.data()?.name || tenant.propertyId;
    }
    await (0, sendWhatsApp_1.sendWhatsAppTemplate)({
        to: tenant.phone,
        templateName: 'tenant_invitation',
        templateParams: [
            tenant.name,
            propertyName,
            tenant.roomNumber || tenant.roomId || 'Assigned',
            tenant.bedNumber || tenant.bedId || 'Assigned',
            APP_DOWNLOAD_LINK,
        ],
    });
    await tenantRef.update({
        inviteSentAt: admin.firestore.Timestamp.now(),
        inviteCount: admin.firestore.FieldValue.increment(1),
    });
    return { success: true, message: 'Invitation sent' };
});
//# sourceMappingURL=tenantOnboarding.js.map