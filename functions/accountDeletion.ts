import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Callable function to safely delete / anonymize user account and revoke auth.
 * Complies with Apple Guideline 5.1.1(v) & Google Play Data Safety requirements.
 */
export const deleteUserAccount = functions
  .runWith({ timeoutSeconds: 30, memory: '256MB' })
  .https.onCall(async (_data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to delete account');
    }

    try {
      const userRef = db.collection('users').doc(uid);
      const userSnap = await userRef.get();
      const userData = userSnap.data() || {};
      const userType = userData.userType;
      const tenantId = userData.tenantId;
      const businessId = userData.businessId;

      // 1. If Tenant, update tenant profile to deleted/anonymized
      if (userType === 'tenant' && tenantId) {
        await db.collection('tenants').doc(tenantId).set({
          name: 'Former Tenant',
          email: '',
          phone: '',
          status: 'deleted',
          deletedAt: admin.firestore.Timestamp.now(),
        }, { merge: true });
      }

      // 2. If Business Member / Owner, update membership status
      if (businessId) {
        const memberRef = db.doc(`businesses/${businessId}/members/${uid}`);
        const memberSnap = await memberRef.get();
        if (memberSnap.exists) {
          await memberRef.set({
            status: 'deleted',
            deletedAt: admin.firestore.Timestamp.now(),
          }, { merge: true });
        }
      }

      // 3. Clear device tokens
      const tokensSnap = await userRef.collection('deviceTokens').get();
      const batch = db.batch();
      tokensSnap.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();

      // 4. Anonymize user document
      await userRef.set({
        uid,
        status: 'deleted',
        email: '',
        displayName: 'Former User',
        photoURL: '',
        deletedAt: admin.firestore.Timestamp.now(),
      }, { merge: true });

      // 5. Delete Firebase Authentication user record
      await admin.auth().deleteUser(uid);

      functions.logger.info('user_account_deleted_successfully', { uid, userType });
      return { success: true };
    } catch (err: any) {
      functions.logger.error('failed_to_delete_user_account', { uid, error: err.message });
      throw new functions.https.HttpsError('internal', `Failed to delete account: ${err.message}`);
    }
  });
