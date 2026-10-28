"use strict";
// Pure helpers for maintenance requests (maintenanceRequests/{id}), kept free
// of firebase-admin for unit tests. maintenance.ts does the writes.
Object.defineProperty(exports, "__esModule", { value: true });
exports.ownerMaintenanceNotification = ownerMaintenanceNotification;
exports.maintenanceStatusMessage = maintenanceStatusMessage;
/** The in-app notification an owner gets when a tenant raises a request. */
function ownerMaintenanceNotification(requestId, r) {
    const where = [r.roomNumber ? `Room ${r.roomNumber}` : null, r.propertyName || null].filter(Boolean).join(', ');
    const who = `${r.tenantName || 'A tenant'}${where ? ` (${where})` : ''}`;
    return {
        businessId: r.businessId || null,
        propertyId: r.propertyId || null,
        type: 'maintenance_request',
        maintenanceRequestId: requestId,
        title: r.priority === 'urgent' ? 'Urgent maintenance request' : 'New maintenance request',
        message: `${who}: ${r.title || 'New request'}`,
        read: false,
    };
}
/** The push a tenant gets when the owner moves their request on, or null. */
function maintenanceStatusMessage(before, after) {
    if (before.status === after.status)
        return null;
    const subject = `"${after.title || 'Your request'}"`;
    switch (after.status) {
        case 'in_progress':
            return { title: 'Work started', body: `${subject} is being worked on.` };
        case 'resolved':
            return {
                title: 'Request resolved',
                body: `${subject} is fixed.${after.ownerNote ? ` ${after.ownerNote}` : ''}`,
            };
        default:
            return null;
    }
}
//# sourceMappingURL=maintenanceLogic.js.map