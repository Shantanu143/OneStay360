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
exports.updatePropertyDetails = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const permissions_1 = require("./permissions");
const propertyEditLogic_1 = require("./propertyEditLogic");
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
exports.updatePropertyDetails = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid)
        throw new functions.https.HttpsError('unauthenticated', 'Sign in first.');
    const businessId = typeof data?.businessId === 'string' ? data.businessId : '';
    const propertyId = typeof data?.propertyId === 'string' ? data.propertyId : '';
    if (!businessId || !propertyId) {
        throw new functions.https.HttpsError('invalid-argument', 'businessId and propertyId are required.');
    }
    await (0, permissions_1.assertPropertyPermission)(uid, businessId, propertyId, 'MANAGE_PROPERTY_STATE');
    const result = (0, propertyEditLogic_1.cleanPropertyEdit)(data?.details || {});
    if (!result.ok)
        throw new functions.https.HttpsError('invalid-argument', result.message);
    const propertyRef = db.collection('businesses').doc(businessId).collection('properties').doc(propertyId);
    await db.runTransaction(async (tx) => {
        const snap = await tx.get(propertyRef);
        if (!snap.exists)
            throw new functions.https.HttpsError('not-found', 'Property not found.');
        const city = snap.get('city');
        const cityRef = city
            ? db.collection('properties_by_city').doc(String(city)).collection('properties').doc(propertyId)
            : null;
        // Transactions read before they write.
        const citySnap = cityRef ? await tx.get(cityRef) : null;
        const update = {
            ...result.update,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedBy: uid,
        };
        tx.update(propertyRef, update);
        if (cityRef && citySnap?.exists)
            tx.update(cityRef, update);
    });
    return { success: true };
});
//# sourceMappingURL=propertyEdit.js.map