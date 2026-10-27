import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { assertPropertyPermission } from './permissions';
import { cleanPropertyEdit } from './propertyEditLogic';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Owners edit a listed property's details (name, address, photos, pricing,
 * amenities, rules, food). Rules block client updates once a property is
 * active, so this is the one write path; billing, plan, status, city and
 * rooms are never touched. The public city index gets the same update.
 */
export const updatePropertyDetails = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in first.');

  const businessId = typeof data?.businessId === 'string' ? data.businessId : '';
  const propertyId = typeof data?.propertyId === 'string' ? data.propertyId : '';
  if (!businessId || !propertyId) {
    throw new functions.https.HttpsError('invalid-argument', 'businessId and propertyId are required.');
  }
  await assertPropertyPermission(uid, businessId, propertyId, 'MANAGE_PROPERTY_STATE');

  const result = cleanPropertyEdit(data?.details || {});
  if ('message' in result) throw new functions.https.HttpsError('invalid-argument', result.message);

  const propertyRef = db.collection('businesses').doc(businessId).collection('properties').doc(propertyId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(propertyRef);
    if (!snap.exists) throw new functions.https.HttpsError('not-found', 'Property not found.');
    const city = snap.get('city');
    const cityRef = city
      ? db.collection('properties_by_city').doc(String(city)).collection('properties').doc(propertyId)
      : null;
    // Transactions read before they write.
    const citySnap = cityRef ? await tx.get(cityRef) : null;

    const update = {
      ...(result as { update: Record<string, any> }).update,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: uid,
    };
    tx.update(propertyRef, update);
    if (cityRef && citySnap?.exists) tx.update(cityRef, update);
  });
  return { success: true };
});
