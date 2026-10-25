# OneStay360 Security Testing Checklist

## Authentication & Authorization

### Firebase Auth
- [ ] Google Sign-In works on both apps
- [ ] Session tokens expire correctly
- [ ] Logout clears all local state and tokens
- [ ] Re-authentication required for sensitive operations
- [ ] App Check blocks unauthenticated API calls

### Firestore Security Rules
Run these manual tests against the live Firestore rules:

#### Business Data Isolation
```javascript
// Test: Tenant cannot read another business's data
// Expected: PERMISSION_DENIED
firebase.firestore()
  .collection('businesses')
  .doc('OTHER_BUSINESS_ID')
  .get()
```

#### Role Escalation Prevention
```javascript
// Test: Staff cannot update their own role to owner
// Expected: PERMISSION_DENIED
firebase.firestore()
  .collection('businesses')
  .doc(businessId)
  .collection('members')
  .doc(uid)
  .update({ role: 'owner' })
```

#### Billing Field Protection
```javascript
// Test: Client cannot set billing fields on property creation
// Expected: PERMISSION_DENIED
firebase.firestore()
  .collection('businesses')
  .doc(businessId)
  .collection('properties')
  .add({
    name: 'Test',
    billingStatus: 'paid',  // Should be blocked
    pricePerBed: 0,         // Should be blocked
  })
```

#### Tenant Data Protection
```javascript
// Test: Tenant cannot read another tenant's data
// Expected: PERMISSION_DENIED
firebase.firestore()
  .collection('tenants')
  .doc('OTHER_TENANT_ID')
  .get()
```

#### Payment Immutability
```javascript
// Test: Cannot update payment_transactions
// Expected: PERMISSION_DENIED
firebase.firestore()
  .collection('payment_transactions')
  .doc(transactionId)
  .update({ amount: 1 })
```

## Input Validation

### Cloud Functions
- [ ] `submitEnrollmentRequest`: validates all required fields
- [ ] `submitRentPayment`: validates amount > 0, businessId present
- [ ] `verifyRentPayment`: validates action is 'confirm' or 'reject'
- [ ] `recordPayment`: validates amount, month, businessId, tenantId
- [ ] `createPaymentLink`: validates businessId, tenantId, rentInvoiceId
- [ ] All functions reject unauthenticated calls

### Flutter Forms
- [ ] Phone number validation (10 digits minimum)
- [ ] Email format validation
- [ ] Amount fields reject negative values
- [ ] Date fields reject past dates where inappropriate
- [ ] Text fields have max length limits

## Payment Security

### Razorpay Integration
- [ ] Webhook signature verified with HMAC SHA256
- [ ] API keys stored in private Firestore doc (not client-accessible)
- [ ] Payment amounts validated server-side
- [ ] Duplicate webhook calls handled idempotently
- [ ] Payment link reuse prevented for paid invoices

### Amount Enforcement
- [ ] Invoice amount cannot be manipulated by tenant
- [ ] `submitRentPayment` validates amount matches invoice (±₹1)
- [ ] `verifyRentPayment` uses stored invoice ID, not client-provided amount

## Data Privacy

### PII Protection
- [ ] Tenant Aadhaar numbers not logged
- [ ] Phone numbers not exposed in error messages
- [ ] Payment transaction IDs not in client-visible logs
- [ ] Firebase debug tokens removed in production builds

### Data Retention
- [ ] Inactive device tokens cleaned up (30-day CRON)
- [ ] Audit logs retained for compliance
- [ ] Payment records immutable (no delete allowed)

## Network Security

### App Check
- [ ] Play Integrity enabled for Android production
- [ ] DeviceCheck enabled for iOS production
- [ ] Debug tokens only in debug builds
- [ ] App Check enforced on all Cloud Functions

### HTTPS
- [ ] All Firebase connections use HTTPS
- [ ] No HTTP fallback
- [ ] Certificate pinning considered for production

## Penetration Testing Scenarios

### Scenario 1: Unauthorized Property Access
```
1. Login as Tenant A (businessId: BUS001)
2. Attempt to read businesses/BUS002/properties
3. Expected: PERMISSION_DENIED
```

### Scenario 2: Payment Amount Manipulation
```
1. Create invoice for ₹10,000
2. Submit payment with amount ₹1
3. Expected: Cloud Function throws 'invalid-argument'
```

### Scenario 3: Role Escalation
```
1. Login as staff member
2. Attempt to update own role to 'owner'
3. Expected: PERMISSION_DENIED from Firestore rules
```

### Scenario 4: Cross-Business Tenant Access
```
1. Login as owner of BUS001
2. Attempt to read businesses/BUS002/tenants
3. Expected: PERMISSION_DENIED
```

### Scenario 5: Invoice Replay Attack
```
1. Pay invoice INV001 via Razorpay
2. Replay the same webhook event
3. Expected: Idempotency check prevents double-payment
```

### Scenario 6: Unauthenticated API Call
```
1. Call submitEnrollmentRequest without auth token
2. Expected: 'unauthenticated' error from Cloud Function
```

## Security Testing Tools

### Automated Scanning
```bash
# Dependency vulnerability scan
cd functions && npm audit --audit-level moderate

# Flutter dependency check
cd apps/business && flutter pub deps --style=compact

# Firebase rules testing
firebase emulators:start --only firestore
firebase emulators:exec --only firestore "npm run test:rules"
```

### Manual Testing
```bash
# Test Firestore rules with emulator
firebase emulators:start --only firestore,auth

# Run security rule tests
cd functions && npm run test:security
```

## Pre-Launch Security Sign-Off

| Check | Status | Verified By | Date |
|-------|--------|-------------|------|
| Firestore rules reviewed | ☐ | | |
| Cloud Functions auth verified | ☐ | | |
| Payment webhook security | ☐ | | |
| App Check production config | ☐ | | |
| PII data audit | ☐ | | |
| Dependency vulnerabilities | ☐ | | |
| Penetration test completed | ☐ | | |
| Security review sign-off | ☐ | | |
