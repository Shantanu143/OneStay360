import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

type Role = 'owner' | 'manager' | 'staff';

type BusinessPermission =
  | 'INVITE_MEMBERS'
  | 'ASSIGN_PROPERTIES'
  | 'VIEW_BILLING'
  | 'PAY_INVOICES'
  | 'VIEW_REPORTS';

type PropertyPermission =
  | 'VIEW_PROPERTY'
  | 'MANAGE_PROPERTY_STATE'
  | 'CREATE_ROOMS_BEDS'
  | 'UPDATE_ROOMS_BEDS'
  | 'UPDATE_BED_OCCUPANCY'
  | 'CREATE_TENANTS'
  | 'UPDATE_TENANTS'
  | 'DELETE_TENANTS';

const businessPermissions: Record<Role, Set<BusinessPermission>> = {
  owner: new Set(['INVITE_MEMBERS', 'ASSIGN_PROPERTIES', 'VIEW_BILLING', 'PAY_INVOICES', 'VIEW_REPORTS']),
  manager: new Set(['VIEW_REPORTS']),
  staff: new Set([]),
};

const propertyPermissions: Record<Role, Set<PropertyPermission>> = {
  owner: new Set([
    'VIEW_PROPERTY',
    'MANAGE_PROPERTY_STATE',
    'CREATE_ROOMS_BEDS',
    'UPDATE_ROOMS_BEDS',
    'UPDATE_BED_OCCUPANCY',
    'CREATE_TENANTS',
    'UPDATE_TENANTS',
    'DELETE_TENANTS',
  ]),
  manager: new Set([
    'VIEW_PROPERTY',
    'UPDATE_BED_OCCUPANCY',
    'CREATE_TENANTS',
    'UPDATE_TENANTS',
  ]),
  staff: new Set([
    'VIEW_PROPERTY',
    'UPDATE_BED_OCCUPANCY',
    'CREATE_TENANTS',
    'UPDATE_TENANTS',
  ]),
};

function businessPermissionsForRole(role: Role): BusinessPermission[] {
  return Array.from(businessPermissions[role] ?? []);
}

function propertyPermissionsForRole(role: Role): PropertyPermission[] {
  return Array.from(propertyPermissions[role] ?? []);
}

const db = admin.firestore();

async function getMembershipRole(uid: string, businessId: string): Promise<Role> {
  const snap = await db.doc(`businesses/${businessId}/members/${uid}`).get();
  if (!snap.exists) {
    throw new functions.https.HttpsError('permission-denied', 'Not a business member');
  }
  const data = snap.data() as any;
  if (data.status !== 'active') {
    throw new functions.https.HttpsError('permission-denied', 'Inactive membership');
  }
  const role = (data.role as Role) || 'staff';
  return role;
}

async function getPropertyRole(uid: string, businessId: string, propertyId: string): Promise<Role> {
  const businessRole = await getMembershipRole(uid, businessId);
  if (businessRole === 'owner') return 'owner';

  const accessRef = db.doc(`businesses/${businessId}/properties/${propertyId}/access/${uid}`);
  const accessSnap = await accessRef.get();
  if (!accessSnap.exists) {
    throw new functions.https.HttpsError('permission-denied', 'No property access');
  }
  const role = (accessSnap.data()?.role as Role) || 'staff';
  return role;
}

export async function assertBusinessPermission(
  uid: string,
  businessId: string,
  permission: BusinessPermission
) {
  const role = await getMembershipRole(uid, businessId);
  if (!businessPermissions[role].has(permission)) {
    throw new functions.https.HttpsError('permission-denied', 'Permission denied');
  }
}

export async function assertPropertyPermission(
  uid: string,
  businessId: string,
  propertyId: string,
  permission: PropertyPermission
) {
  const role = await getPropertyRole(uid, businessId, propertyId);
  if (!propertyPermissions[role].has(permission)) {
    throw new functions.https.HttpsError('permission-denied', 'Permission denied');
  }
}

export {
  BusinessPermission,
  PropertyPermission,
  Role,
  getMembershipRole,
  getPropertyRole,
  businessPermissionsForRole,
  propertyPermissionsForRole,
};
