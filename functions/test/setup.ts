/**
 * Jest global setup — points ALL Firebase calls to local emulators.
 * NO live Google Cloud calls. NO billing.
 */

// Must be set BEFORE any firebase-admin import
process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';
process.env.FIREBASE_STORAGE_EMULATOR_HOST = 'localhost:9199';
process.env.GCLOUD_PROJECT = 'onestay360-test';

import * as admin from 'firebase-admin';

// Initialize once for all tests
if (admin.apps.length === 0) {
  admin.initializeApp({
    projectId: 'onestay360-test',
  });
}

// Global timeout for async tests
jest.setTimeout(15000);
