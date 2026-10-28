"use strict";
// What an owner may change on a listed property, checked and flattened into
// a Firestore update. Billing, plan, status, city and rooms are never in it.
// Pure, for unit tests; updatePropertyDetails (propertyEdit.ts) applies it.
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanPropertyEdit = cleanPropertyEdit;
const AMENITIES = ['wifi', 'ac', 'laundry', 'foodIncluded', 'parking', 'geyser', 'powerBackup', 'cctv', 'housekeeping'];
const GENDERS = ['Male', 'Female', 'Co-ed'];
const text = (v, max = 2000) => (typeof v === 'string' ? v.trim().slice(0, max) : '');
const money = (v) => (v === null || v === undefined || v === '' ? null : Number(v));
function cleanPropertyEdit(input) {
    const name = text(input.name, 120);
    if (!name)
        return { ok: false, message: 'Enter the property name.' };
    const address = text(input.address, 500);
    if (!address)
        return { ok: false, message: 'Enter the full address.' };
    const pincode = text(input.pincode, 10);
    if (!/^\d{6}$/.test(pincode))
        return { ok: false, message: 'PIN codes have 6 digits.' };
    const floors = Number(input.numberOfFloors ?? 0);
    if (!Number.isInteger(floors) || floors < 0 || floors > 60)
        return { ok: false, message: 'Check the number of floors.' };
    const images = Array.isArray(input.images) ? input.images.slice(0, 20) : [];
    if (images.some((u) => typeof u !== 'string' || !/^https:\/\//.test(u))) {
        return { ok: false, message: 'Photos must be uploaded images.' };
    }
    const pricing = input.pricing || {};
    const maxSharing = Number(pricing.maxSharing ?? 0);
    const sharing = [];
    for (const row of Array.isArray(pricing.sharing) ? pricing.sharing : []) {
        const s = Number(row?.sharing);
        if (!Number.isInteger(s) || s < 1 || s > 12)
            continue;
        const nonAc = money(row.nonAc);
        const ac = money(row.ac);
        for (const p of [nonAc, ac]) {
            if (p !== null && (!Number.isFinite(p) || p < 0))
                return { ok: false, message: 'Rents must be zero or more.' };
        }
        sharing.push({ sharing: s, nonAc, ac });
    }
    if (!sharing.some((r) => (r.nonAc ?? 0) > 0 || (r.ac ?? 0) > 0)) {
        return { ok: false, message: 'Add a rent for at least one sharing type.' };
    }
    const legacy = (s) => sharing.find((r) => r.sharing === s)?.nonAc ?? sharing.find((r) => r.sharing === s)?.ac ?? 0;
    const deposit = money(pricing.securityDeposit) ?? 0;
    const maintenance = money(pricing.oneTimeMaintenance) ?? 0;
    if (deposit < 0 || maintenance < 0 || !Number.isFinite(deposit) || !Number.isFinite(maintenance)) {
        return { ok: false, message: 'Charges must be zero or more.' };
    }
    const rules = input.rules || {};
    if (!GENDERS.includes(rules.genderAllowed))
        return { ok: false, message: 'Choose who can stay.' };
    const notice = Number(rules.noticePeriodDays ?? 30);
    const amenities = input.amenities || {};
    const update = {
        name,
        address,
        pincode,
        description: text(input.description),
        landmarks: text(input.landmarks, 300),
        googleMapsLink: text(input.googleMapsLink, 500),
        numberOfFloors: floors,
        images,
        'pricing.maxSharing': Number.isInteger(maxSharing) && maxSharing > 0 ? maxSharing : sharing.length,
        'pricing.sharing': sharing,
        'pricing.single': legacy(1),
        'pricing.double': legacy(2),
        'pricing.triple': legacy(3),
        'pricing.securityDeposit': deposit,
        'pricing.oneTimeMaintenance': maintenance,
        'pricing.maintenanceDeductedFromDeposit': pricing.maintenanceDeductedFromDeposit === true,
        'rules.genderAllowed': rules.genderAllowed,
        'rules.curfew': rules.curfew === true,
        'rules.visitorsAllowed': rules.visitorsAllowed === true,
        'rules.smokingAllowed': rules.smokingAllowed === true,
        'rules.alcoholAllowed': rules.alcoholAllowed === true,
        'rules.noticePeriodDays': Number.isInteger(notice) && notice >= 0 && notice <= 365 ? notice : 30,
    };
    for (const key of AMENITIES)
        update[`amenities.${key}`] = amenities[key] === true;
    update.foodPlan = amenities.foodIncluded === true && input.foodPlan && typeof input.foodPlan === 'object'
        ? { plan: input.foodPlan.plan || {}, notes: text(input.foodPlan.notes, 500) }
        : null;
    return { ok: true, update };
}
//# sourceMappingURL=propertyEditLogic.js.map