import { cleanPropertyEdit } from '../../propertyEditLogic';

const valid: Record<string, any> = {
  name: ' Green Nest ',
  address: '12 Baner Road',
  pincode: '411045',
  description: 'Calm',
  landmarks: 'Near metro',
  googleMapsLink: 'https://maps.app.goo.gl/x',
  numberOfFloors: 2,
  images: ['https://firebasestorage.googleapis.com/a.jpg'],
  pricing: {
    maxSharing: 2,
    sharing: [{ sharing: 1, nonAc: 12000, ac: null }, { sharing: 2, nonAc: 8000, ac: 9500 }],
    securityDeposit: 10000,
    oneTimeMaintenance: 500,
    maintenanceDeductedFromDeposit: true,
  },
  amenities: { wifi: true, ac: false, laundry: true, foodIncluded: false, parking: false, geyser: true, powerBackup: true, cctv: true, housekeeping: false },
  rules: { genderAllowed: 'Co-ed', curfew: false, visitorsAllowed: true, smokingAllowed: false, alcoholAllowed: false, noticePeriodDays: 30 },
  foodPlan: null,
};

describe('cleanPropertyEdit', () => {
  it('keeps the editable fields, trimmed', () => {
    const r = cleanPropertyEdit(valid);
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    expect(r.update.name).toBe('Green Nest');
    expect(r.update['pricing.securityDeposit']).toBe(10000);
    expect(r.update['pricing.sharing']).toEqual(valid.pricing.sharing);
    expect(r.update['pricing.single']).toBe(12000);
    expect(r.update['pricing.double']).toBe(8000);
    expect(r.update['pricing.triple']).toBe(0);
    expect(r.update['rules.genderAllowed']).toBe('Co-ed');
    expect(r.update['amenities.wifi']).toBe(true);
    expect(r.update.images).toEqual(valid.images);
  });

  it('never touches billing, status, city or rooms', () => {
    const r = cleanPropertyEdit({
      ...valid,
      status: 'active',
      billingStatus: 'paid',
      city: 'Mumbai',
      plan: { pricePerBedInr: 0 },
      rooms: [],
      businessId: 'OTHER',
    });
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    for (const key of Object.keys(r.update)) {
      expect(key).not.toMatch(/^(status|billingStatus|city|cityCode|plan|rooms|businessId|pricePerBed|totals)/);
    }
  });

  it('rejects what would break the listing', () => {
    expect(cleanPropertyEdit({ ...valid, name: ' ' })).toEqual({ ok: false, message: 'Enter the property name.' });
    expect(cleanPropertyEdit({ ...valid, pincode: '41' })).toEqual({ ok: false, message: 'PIN codes have 6 digits.' });
    expect(cleanPropertyEdit({ ...valid, pricing: { ...valid.pricing, sharing: [{ sharing: 1, nonAc: -5 }] } }))
      .toEqual({ ok: false, message: 'Rents must be zero or more.' });
    expect(cleanPropertyEdit({ ...valid, pricing: { ...valid.pricing, sharing: [] } }))
      .toEqual({ ok: false, message: 'Add a rent for at least one sharing type.' });
    expect(cleanPropertyEdit({ ...valid, images: ['javascript:alert(1)'] }))
      .toEqual({ ok: false, message: 'Photos must be uploaded images.' });
    expect(cleanPropertyEdit({ ...valid, rules: { ...valid.rules, genderAllowed: 'Anyone' } }))
      .toEqual({ ok: false, message: 'Choose who can stay.' });
  });

  it('keeps a food plan only with meals on', () => {
    const plan = { plan: { Monday: ['Breakfast'] }, notes: 'Veg' };
    const on = cleanPropertyEdit({ ...valid, amenities: { ...valid.amenities, foodIncluded: true }, foodPlan: plan });
    expect(on.ok && on.update.foodPlan).toEqual(plan);
    const off = cleanPropertyEdit({ ...valid, foodPlan: plan });
    expect(off.ok && off.update.foodPlan).toBeNull();
  });
});
