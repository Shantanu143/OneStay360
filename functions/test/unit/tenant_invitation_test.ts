import {
  buildAcceptedTenantRecords,
  checkInvitationResponse,
  resolveTenantDocId,
} from '../../tenantInvitationLogic';

const pending = {
  tenantId: 'TEN0000007',
  tenantName: 'Asha Rao',
  tenantPhone: '+91 98111 00001',
  businessId: 'BUS0000001',
  propertyId: 'BUS0000001PNR001',
  propertyName: 'Green Nest',
  roomId: 'R101',
  roomNumber: '101',
  bedIndex: 1,
  bedNumber: '2',
  monthlyRent: 9000,
  deposit: 18000,
  billingDay: 5,
  status: 'pending',
};

describe('checkInvitationResponse', () => {
  it('is not found when there is no invitation', () => {
    const r = checkInvitationResponse(undefined, { tenantId: null, phones: [] });
    expect(r).toEqual(expect.objectContaining({ ok: false, code: 'not-found' }));
  });

  it('lets the invited tenant answer by tenant id', () => {
    expect(checkInvitationResponse(pending, { tenantId: 'TEN0000007', phones: [] })).toEqual({ ok: true });
  });

  it('lets the invited tenant answer by phone, however it is written', () => {
    expect(checkInvitationResponse(pending, { tenantId: null, phones: [null, '9811100001'] })).toEqual({ ok: true });
  });

  it('refuses someone else', () => {
    const r = checkInvitationResponse(pending, { tenantId: 'TEN0000099', phones: ['9811100002'] });
    expect(r).toEqual(expect.objectContaining({ ok: false, code: 'permission-denied' }));
  });

  it('refuses an invitation that was already answered', () => {
    const r = checkInvitationResponse({ ...pending, status: 'accepted' }, { tenantId: 'TEN0000007', phones: [] });
    expect(r).toEqual(expect.objectContaining({ ok: false, code: 'failed-precondition' }));
  });
});

describe('resolveTenantDocId', () => {
  it("uses the caller's own tenant id when they have one", () => {
    expect(resolveTenantDocId('TEN0000003', 'TEN0000007')).toBe('TEN0000003');
  });

  it("otherwise uses the invitation's", () => {
    expect(resolveTenantDocId(null, 'TEN0000007')).toBe('TEN0000007');
    expect(resolveTenantDocId('', 'TEN0000007')).toBe('TEN0000007');
  });

  it('ignores a user id that is not a tenant id', () => {
    expect(resolveTenantDocId('some-uid', 'TEN0000007')).toBe('TEN0000007');
  });
});

describe('buildAcceptedTenantRecords', () => {
  const now = 'NOW';
  const moveIn = 'MOVE_IN';
  const r = buildAcceptedTenantRecords(pending, {
    invitationId: 'INV1',
    tenantDocId: 'TEN0000007',
    uid: 'uid-1',
    now,
    moveIn,
  });

  it('creates an active business tenant linked to the user', () => {
    expect(r.bizTenant).toEqual(
      expect.objectContaining({
        tenantId: 'TEN0000007',
        userId: 'uid-1',
        name: 'Asha Rao',
        businessId: 'BUS0000001',
        propertyId: 'BUS0000001PNR001',
        roomId: 'R101',
        bedId: '2',
        roomNumber: '101',
        bedNumber: '2',
        monthlyRent: 9000,
        checkInDate: moveIn,
        status: 'active',
        invitationId: 'INV1',
        linkedAt: now,
      }),
    );
    expect(r.bizTenant.additionalInfo).toEqual(
      expect.objectContaining({ depositAmount: 18000, billingDate: 5 }),
    );
  });

  it('records an active stay the tenant app can read', () => {
    expect(r.stay).toEqual(
      expect.objectContaining({
        businessId: 'BUS0000001',
        propertyId: 'BUS0000001PNR001',
        propertyName: 'Green Nest',
        roomId: 'R101',
        bedId: '2',
        monthlyRent: 9000,
        status: 'active',
        invitationId: 'INV1',
      }),
    );
    expect(r.globalTenant).toEqual(expect.objectContaining({ userId: 'uid-1', status: 'active' }));
  });

  it('marks the bed (1-based id from the index) as occupied', () => {
    expect(r.bedId).toBe('2');
    expect(r.bed).toEqual(
      expect.objectContaining({ occupied: true, isOccupied: true, tenantId: 'TEN0000007' }),
    );
  });

  it('falls back to billing on the 1st without a billing day', () => {
    const plain = buildAcceptedTenantRecords(
      { ...pending, billingDay: null },
      { invitationId: 'INV1', tenantDocId: 'TEN0000007', uid: 'uid-1', now, moveIn },
    );
    expect(plain.bizTenant.additionalInfo.billingDate).toBe(1);
  });
});
