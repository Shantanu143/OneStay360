import { maintenanceStatusMessage, ownerMaintenanceNotification } from '../../maintenanceLogic';

describe('ownerMaintenanceNotification', () => {
  it('tells the owner who raised what, and where', () => {
    const n = ownerMaintenanceNotification('MR1', {
      businessId: 'BUS1',
      propertyId: 'P1',
      propertyName: 'Green Nest',
      tenantName: 'Asha',
      roomNumber: '101',
      title: 'Fan not working',
      priority: 'normal',
    });
    expect(n).toEqual(
      expect.objectContaining({
        businessId: 'BUS1',
        propertyId: 'P1',
        type: 'maintenance_request',
        maintenanceRequestId: 'MR1',
        title: 'New maintenance request',
        read: false,
      }),
    );
    expect(n.message).toBe('Asha (Room 101, Green Nest): Fan not working');
  });

  it('flags urgent requests', () => {
    const n = ownerMaintenanceNotification('MR1', { tenantName: 'Asha', title: 'Water leak', priority: 'urgent' });
    expect(n.title).toBe('Urgent maintenance request');
    expect(n.message).toBe('Asha: Water leak');
  });
});

describe('maintenanceStatusMessage', () => {
  it('says nothing when the status did not change', () => {
    expect(maintenanceStatusMessage({ status: 'open' }, { status: 'open', title: 'x' })).toBeNull();
  });

  it('says nothing when the tenant cancelled it themselves', () => {
    expect(maintenanceStatusMessage({ status: 'open' }, { status: 'cancelled', title: 'x' })).toBeNull();
  });

  it('tells the tenant work has started', () => {
    expect(maintenanceStatusMessage({ status: 'open' }, { status: 'in_progress', title: 'Fan' })).toEqual({
      title: 'Work started',
      body: '"Fan" is being worked on.',
    });
  });

  it('tells the tenant it is resolved, with the owner note', () => {
    expect(
      maintenanceStatusMessage({ status: 'in_progress' }, { status: 'resolved', title: 'Fan', ownerNote: 'Replaced capacitor' }),
    ).toEqual({ title: 'Request resolved', body: '"Fan" is fixed. Replaced capacitor' });
  });
});
