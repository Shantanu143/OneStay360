import * as admin from 'firebase-admin';

// Initialize Admin SDK once before loading function modules.
if (admin.apps.length === 0) {
	admin.initializeApp();
}

// Entry point: expose all callable/scheduled functions.
export * from './activateProperty';
export * from './billing';
export * from './invitations';
export * from './auditTriggers';
export * from './memberAccess';
export * from './enrollmentNotifications';
export * from './tenantOnboarding'; // includes vacateTenant
export * from './rentPaymentNotifications';
export * from './razorpay';
export * from './tenantBilling';
export * from './accountDeletion';
export * from './tenantInvitations';
export * from './maintenance';
