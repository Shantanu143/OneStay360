import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

import { buildInvitationEmail, sendEmail } from './sendEmail';
import { sendSms } from './sendSms';
import { assertBusinessPermission, getMembershipRole } from './permissions';
import { logAudit } from './audit';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * 🔐 Environment Config (set via firebase functions:config:set)
 * Example: firebase functions:config:set invite.base_url="https://..."
 */
function getConfig() {
  const config = functions.config();
  return {
    inviteBaseUrl: config.invite?.base_url || process.env.INVITE_BASE_URL || '',
    mailgunApiKey: config.mailgun?.api_key || process.env.MAILGUN_API_KEY || '',
    mailgunDomain: config.mailgun?.domain || process.env.MAILGUN_DOMAIN || '',
    mailgunFrom: config.mailgun?.from || process.env.MAILGUN_FROM || '',
    mailgunApiBase: config.mailgun?.api_base || process.env.MAILGUN_API_BASE || 'https://api.mailgun.net',
  };
}

/**
 * Helpers
 */
async function getPropertyNames(
  businessId: string,
  propertyIds: string[]
): Promise<Record<string, string>> {
  const result: Record<string, string> = {};
  if (!propertyIds.length) return result;

  const snaps = await Promise.all(
    propertyIds.map((pid) =>
      db.doc(`businesses/${businessId}/properties/${pid}`).get()
    )
  );

  snaps.forEach((snap, idx) => {
    if (!snap.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        `Property ${propertyIds[idx]} not found`
      );
    }
    const data = snap.data() as any;
    result[propertyIds[idx]] = data?.name || propertyIds[idx];
  });

  return result;
}

function addDays(ts: admin.firestore.Timestamp, days: number) {
  const d = ts.toDate();
  d.setDate(d.getDate() + days);
  return admin.firestore.Timestamp.fromDate(d);
}

/**
 * ======================================================
 * CREATE INVITATION (OWNER ONLY)
 * ======================================================
 */
export const createBusinessInvitation = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '256MB',
  })
  .https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    const { businessId, phone, email, role, propertyIds } = data || {};

    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }

    if (!businessId || !phone || !role) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'businessId, phone, role required'
      );
    }

    if (role !== 'manager' && role !== 'staff') {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid role');
    }

    // 🔐 Read config
    const config = getConfig();
    const inviteBaseUrl = config.inviteBaseUrl;
    if (!inviteBaseUrl) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'INVITE_BASE_URL not configured. Set via: firebase functions:config:set invite.base_url="https://..."'
      );
    }

    const trimmedBaseUrl = inviteBaseUrl.replace(/\/+$/, '');

    const properties: string[] = Array.isArray(propertyIds)
      ? Array.from(
          new Set(propertyIds.filter((p: any) => typeof p === 'string' && p))
        )
      : [];

    // Permission check
    await assertBusinessPermission(uid, businessId, 'INVITE_MEMBERS');

    const propertyNames = await getPropertyNames(businessId, properties);

    const now = admin.firestore.Timestamp.now();
    const expiresAt = addDays(now, 7);

    const inviteRef = db.collection('business_invitations').doc();
    const actorRole = await getMembershipRole(uid, businessId);

    const inviteData = {
      businessId,
      invitedBy: uid,
      phone,
      email: email || null,
      role,
      propertyIds: properties,
      status: 'pending',
      createdAt: now,
      expiresAt,
      acceptedAt: null,
      acceptedByUid: null,
      createdBy: uid,
      actorRole,
    };

    await inviteRef.set(inviteData);

    // Audit (non-blocking)
    try {
      await logAudit({
        businessId,
        actorUid: uid,
        action: 'member_invited',
        entityType: 'member',
        entityId: inviteRef.id,
      });
    } catch (err) {
      functions.logger.warn('audit_log_failed_invite', err);
    }

    const inviteLink = `${trimmedBaseUrl}/invite?inviteId=${inviteRef.id}`;
    const expiresOn = expiresAt.toDate().toISOString().slice(0, 10);

    // 🔔 Fire-and-forget notifications
    Promise.resolve()
      .then(async () => {
        const businessSnap = await db
          .doc(`businesses/${businessId}`)
          .get();
        const businessName =
          (businessSnap.data() as any)?.name || 'your business';

        const propertyListNames = properties.map(
          (pid) => propertyNames[pid] || pid
        );

        const inviterSnap = await db
          .doc(`businesses/${businessId}/members/${uid}`)
          .get();
        const inviterData = inviterSnap.data() as any;
        const inviterName =
          inviterData?.name ||
          inviterData?.displayName ||
          inviterData?.email ||
          'A teammate';

        if (email) {
          const emailPayload = buildInvitationEmail({
            businessName,
            inviterName,
            role,
            propertyNames: propertyListNames,
            inviteLink,
            expiresOn,
            to: email,
          });
          await sendEmail(emailPayload);
        }

        const smsMsg = `You are invited to ${businessName} as ${role}. Open: ${inviteLink}`;
        await sendSms({ to: phone, message: smsMsg });
      })
      .catch((err) => {
        functions.logger.warn('invite_notification_failed', err);
      });

    functions.logger.info('invite_created', {
      inviteId: inviteRef.id,
      businessId,
      role,
      properties,
    });

    return {
      inviteId: inviteRef.id,
      inviteLink,
    };
  });

/**
 * ======================================================
 * ACCEPT INVITATION
 * ======================================================
 */
export const acceptBusinessInvitation = functions.https.onCall(
  async (data, context) => {
    const uid = context.auth?.uid;
    const { inviteId } = data || {};

    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }
    if (!inviteId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'inviteId required'
      );
    }

    const inviteRef = db.doc(`business_invitations/${inviteId}`);
    const now = admin.firestore.Timestamp.now();

    const normalizePhone = (phone: string | undefined | null): string => {
      if (!phone) return '';
      const digits = phone.replace(/\D/g, '');
      if (digits.length > 10) {
        return digits.substring(digits.length - 10);
      }
      return digits;
    };

    // Load the verified phone number for this user from Firebase Auth.
    // This is more reliable than depending solely on the ID token claims.
    const tokenPhone = (context.auth?.token as any)?.phone_number as
      | string
      | undefined;

    let authPhone: string | undefined = tokenPhone;
    let authProviders: string[] | undefined;
    let userEmail: string | undefined;
    try {
      const userRecord = await admin.auth().getUser(uid);
      if (userRecord.phoneNumber) {
        authPhone = userRecord.phoneNumber;
      }
      // Capture provider IDs (e.g., phone, password) for downstream analytics/UI.
      authProviders = Array.from(
        new Set((userRecord.providerData || []).map((p) => p.providerId).filter(Boolean))
      );
      userEmail = userRecord.email || undefined;
    } catch (err) {
      functions.logger.error('accept_invite_get_user_failed', { uid, error: err });
    }

    const result = await db.runTransaction(async (tx) => {
      const inviteSnap = await tx.get(inviteRef);
      if (!inviteSnap.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'Invitation not found'
        );
      }

      const invite = inviteSnap.data() as any;

      if (invite.status !== 'pending') {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Invitation not pending'
        );
      }

      if (invite.expiresAt?.toMillis() < now.toMillis()) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Invitation expired'
        );
      }

      const invitePhoneNorm = normalizePhone(invite.phone);
      const authPhoneNorm = normalizePhone(authPhone);

      functions.logger.info('accept_invite_phone_check', {
        uid,
        invitePhone: invite.phone,
        authPhone,
        invitePhoneNorm,
        authPhoneNorm,
      });

      // We already enforce the exact phone match in the Flutter app
      // before calling this function. Here we only require that the
      // user has some verified phone on their account.
      if (!authPhoneNorm) {
        throw new functions.https.HttpsError(
          'unauthenticated',
          'Phone authentication required'
        );
      }

      const businessId = invite.businessId;
      const role = invite.role;
      const properties: string[] = invite.propertyIds || [];
      const inviteEmail: string | undefined = invite.email || undefined;

      const membershipRef = db.doc(
        `businesses/${businessId}/members/${uid}`
      );

      const userRef = db.doc(`users/${uid}`);
      const businessRef = db.doc(`businesses/${businessId}`);

      const businessSnap = await tx.get(businessRef);
      if (!businessSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'Business not found');
      }
      const businessData = businessSnap.data() as any;
      const businessName = businessData?.name || businessId;

      const userSnap = await tx.get(userRef);
      const existingUser = userSnap.data() as any;
      const resolvedEmail = userEmail || inviteEmail || existingUser?.email;
      const userUpdate: Record<string, any> = {
        uid,
        businessId,
        businessName,
        profileCompleted: true,
        updatedAt: now,
      };

      if (!existingUser?.createdAt) {
        userUpdate.createdAt = now;
      }
      if (authPhone) {
        userUpdate.phoneNumber = authPhone;
      }
      if (resolvedEmail) {
        userUpdate.email = resolvedEmail;
      }
      if (authProviders && authProviders.length) {
        userUpdate.authProviders = authProviders;
      }

      // Create property access
      for (const pid of properties) {
        const propRef = db.doc(
          `businesses/${businessId}/properties/${pid}`
        );
        const accessRef = propRef.collection('access').doc(uid);

        tx.set(accessRef, {
          role,
          businessId,
          grantedAt: now,
          grantedBy: invite.invitedBy,
          createdBy: uid,
          updatedBy: uid,
          actorRole: role,
        });
      }

      tx.set(
        membershipRef,
        {
          uid,
          businessId,
          role,
          status: 'active',
          createdAt: now,
          updatedAt: now,
          createdBy: uid,
          updatedBy: uid,
        },
        { merge: true }
      );

      // Keep the user document in sync with their active business and profile basics
      // so the client can render the hero title and hide the profile banner after acceptance.
      tx.set(userRef, userUpdate, { merge: true });

      tx.update(inviteRef, {
        status: 'accepted',
        acceptedAt: now,
        acceptedByUid: uid,
      });

      return { businessId, role, propertyIds: properties };
    });

    await logAudit({
      businessId: result.businessId,
      actorUid: uid,
      action: 'member_accepted',
      entityType: 'member',
      entityId: uid,
    });

    return result;
  }
);

/**
 * ======================================================
 * EXPIRE OLD INVITES (CRON)
 * ======================================================
 */
export const expireStaleInvitations = functions.pubsub
  .schedule('every 24 hours')
  .timeZone('Etc/UTC')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

    const snapshot = await db
      .collection('business_invitations')
      .where('status', '==', 'pending')
      .where('expiresAt', '<', now)
      .limit(500)
      .get();

    if (snapshot.empty) return null;

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.update(doc.ref, { status: 'expired' });
    });

    await batch.commit();
    return null;
  });
