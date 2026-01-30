import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

export type Plan = {
  id: string;
  name: string;
  description?: string;
  pricePerBedInr: number;
  maxBeds?: number;
  features?: Record<string, any>;
  isActive: boolean;
  isDefault: boolean;
};

const db = admin.firestore();

export async function getDefaultActivePlan(tx?: FirebaseFirestore.Transaction): Promise<Plan> {
  const plansRef = db.collection('plans').where('isActive', '==', true).where('isDefault', '==', true).limit(2);
  const snap = tx ? await tx.get(plansRef) : await plansRef.get();
  if (snap.empty) {
    const message = 'No default active plan configured (require exactly one active default plan)';
    functions.logger.error(message);
    throw new functions.https.HttpsError('internal', message);
  }
  if (snap.docs.length > 1) {
    const message = 'Multiple default plans configured (require exactly one active default plan)';
    functions.logger.error(message);
    throw new functions.https.HttpsError('internal', message);
  }
  const doc = snap.docs[0];
  const data = doc.data();
  const price = Number(data.pricePerBedInr);
  if (!Number.isFinite(price) || price <= 0) {
    throw new functions.https.HttpsError('internal', 'Invalid default plan pricing');
  }
  return {
    id: data.id || doc.id,
    name: data.name || 'Plan',
    description: data.description,
    pricePerBedInr: price,
    maxBeds: data.maxBeds,
    features: data.features,
    isActive: !!data.isActive,
    isDefault: !!data.isDefault,
  };
}
