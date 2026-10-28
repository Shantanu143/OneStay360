/**
 * Maintenance requests (maintenanceRequests/{id}).
 *
 * Tenants create them from the tenant app and may cancel an open one; owners
 * and their team move them open -> in_progress -> resolved. Both sides write
 * directly (see firestore.rules); these triggers only notify.
 */
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { maintenanceStatusMessage, ownerMaintenanceNotification } from './maintenanceLogic';

if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

export const onMaintenanceRequestCreated = functions.firestore
  .document('maintenanceRequests/{requestId}')
  .onCreate(async (snap, context) => {
    const r = snap.data();
    if (!r?.businessId) return null;
    await db
      .collection('businesses')
      .doc(r.businessId)
      .collection('notifications')
      .add({
        ...ownerMaintenanceNotification(context.params.requestId, r),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    return null;
  });

export const onMaintenanceRequestUpdated = functions.firestore
  .document('maintenanceRequests/{requestId}')
  .onUpdate(async (change, context) => {
    const after = change.after.data();
    const message = maintenanceStatusMessage(change.before.data(), after);
    if (!message || !after.tenantUid) return null;

    const tokens = await db
      .collection('users')
      .doc(after.tenantUid)
      .collection('deviceTokens')
      .where('active', '==', true)
      .limit(20)
      .get();
    await Promise.all(
      tokens.docs.map((t) =>
        admin
          .messaging()
          .send({
            token: t.id,
            notification: message,
            data: { type: 'maintenance_update', maintenanceRequestId: context.params.requestId },
          })
          .catch((err) => functions.logger.warn('maintenance_push_failed', err?.code || err)),
      ),
    );
    return null;
  });
