module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/test'],
  // Only match files ending in _test.ts inside unit/ — excludes setup.ts
  // and emulator-dependent billing_test.ts
  testMatch: [
    '**/test/unit/billing_logic_test.ts',
    '**/test/unit/tenant_billing_test.ts',
    '**/test/unit/member_access_test.ts',
    '**/test/unit/invitation_phone_test.ts',
    '**/test/unit/tenant_invitation_test.ts',
    '**/test/unit/maintenance_test.ts',
    '**/test/unit/payment_tracking_test.ts',
  ],
  transform: {
    '^.+\\.ts$': ['ts-jest', {
      tsconfig: {
        strict: false,
        esModuleInterop: true,
      }
    }],
  },
  collectCoverageFrom: [
    '**/*.ts',
    '!**/*.d.ts',
    '!**/node_modules/**',
    '!**/lib/**',
    '!**/test/**',
    '!**/index.ts',
  ],
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'lcov'],
  testTimeout: 15000,
};
