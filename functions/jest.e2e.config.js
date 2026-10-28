// End-to-end tests against the Firestore emulator (see test/e2e). Not part
// of `npm test`; run with:
//   npx firebase emulators:exec --only firestore --project demo-onestay "npx jest -c jest.e2e.config.js"
const base = require('./jest.config');

module.exports = {
  ...base,
  testMatch: ['**/test/e2e/*_e2e_test.ts'],
  // `npx tsc --noEmit` type-checks the sources; here we only run them.
  transform: {
    '^.+\\.ts$': ['ts-jest', { diagnostics: false, tsconfig: { strict: false, esModuleInterop: true } }],
  },
  testTimeout: 30000,
};
