# OneStay360 User Acceptance Testing (UAT) Checklist

## Beta Testing Program Setup

### Participants
- 5 PG business owners (mix of small 5-bed and large 50-bed properties)
- 20-30 tenants (mix of tech-savvy and non-tech users)
- 2 QA testers for edge cases

### Duration: 2 weeks
### Environment: Production Firebase project with test data

---

## Business Owner Journey

### 1. Onboarding
- [ ] Owner downloads business app from Play Store
- [ ] Google Sign-In works without issues
- [ ] Business creation flow completes successfully
- [ ] Profile completion (email + phone verification) works
- [ ] First property can be added independently (no support needed)
- [ ] Rooms and beds can be added to property
- [ ] Property images upload successfully
- [ ] Property activation payment works via Razorpay

### 2. Property Management
- [ ] Can add multiple properties
- [ ] Can edit property details
- [ ] Can add/remove rooms and beds
- [ ] Room gender lock works correctly
- [ ] Property status reflects billing status
- [ ] Suspended property shows correct UI

### 3. Tenant Enrollment
- [ ] Enrollment requests appear in real-time
- [ ] Push notification received for new request
- [ ] Can view tenant details in request
- [ ] Can approve with room/bed assignment
- [ ] Can reject with reason
- [ ] Bill sending works (UPI ID shown to tenant)
- [ ] Payment confirmation creates tenant record
- [ ] Tenant appears in tenant list after enrollment

### 4. Team Management
- [ ] Can invite team member via link
- [ ] Invitation link works on recipient's device
- [ ] Manager role has correct permissions
- [ ] Staff role has correct permissions
- [ ] Can assign properties to team members
- [ ] Can revoke access

### 5. Monthly Billing
- [ ] Invoice generated automatically on billing date
- [ ] Push notification received when invoice generated
- [ ] Pending payments screen shows UPI submissions
- [ ] Can confirm payment (marks invoice paid)
- [ ] Can reject payment with reason
- [ ] Tenant notified of confirmation/rejection
- [ ] Payment history shows correctly

### 6. Razorpay Setup
- [ ] Can add Razorpay API keys in settings
- [ ] Key verification works
- [ ] UPI ID saved and shown to tenants
- [ ] Online payment link generated for invoices
- [ ] Webhook auto-reconciles payments

### 7. Notifications
- [ ] All notification types received correctly
- [ ] Notification taps navigate to correct screen
- [ ] Notification badge count updates
- [ ] Mark as read works

---

## Tenant Journey

### 1. Onboarding
- [ ] Downloads tenant app from Play Store
- [ ] Google Sign-In works
- [ ] Profile completion screen appears
- [ ] Can fill all profile fields (name, phone, KYC)
- [ ] QR code generated after profile completion

### 2. Explore PGs
- [ ] Properties load in Explore screen
- [ ] City filter works
- [ ] Search by name/area works
- [ ] Property detail screen shows correct info
- [ ] Amenities shown correctly (from actual property data)
- [ ] Room types and pricing visible
- [ ] Images load correctly

### 3. Enrollment
- [ ] Can submit enrollment request from property detail
- [ ] "Browse first" message shown from home quick action
- [ ] Pending application banner appears on home
- [ ] Cannot submit duplicate request to same business
- [ ] Cannot enroll if already in active PG

### 4. Bill Payment
- [ ] Bill notification received when owner sends bill
- [ ] Tapping notification opens BillReviewScreen
- [ ] Bill details shown correctly (deposit, advance, total)
- [ ] UPI deep-link opens payment app
- [ ] Transaction ID entry works
- [ ] Payment submitted successfully
- [ ] Waiting for confirmation screen shown

### 5. Monthly Rent Payment
- [ ] Rent due notification received on billing date
- [ ] Tapping notification navigates to My PG
- [ ] Invoice banner shows on My PG screen
- [ ] "All Caught Up" shown when no dues
- [ ] Overdue invoice shown in red

#### Razorpay (Online)
- [ ] "Pay via OneStay" option shown when enabled
- [ ] Payment link opens in browser/UPI app
- [ ] After payment, confirmation dialog shown
- [ ] Invoice marked paid automatically (webhook)

#### UPI Manual
- [ ] Owner UPI ID shown correctly
- [ ] "Pay via UPI App" opens UPI app
- [ ] Amount field locked to invoice amount
- [ ] Transaction ID required
- [ ] Submission creates pending_verification record
- [ ] Owner notified of submission

#### Cash
- [ ] Cash option available
- [ ] Amount field locked to invoice amount
- [ ] Submission creates pending_verification record
- [ ] Owner notified

### 6. My PG Screen
- [ ] Current PG name shown correctly
- [ ] Monthly rent shown correctly
- [ ] Due date shown correctly
- [ ] Room and bed details shown
- [ ] Amenities from actual property shown
- [ ] Payment history accessible
- [ ] PG details link works

### 7. Profile
- [ ] Can edit personal details
- [ ] Can complete KYC (ID type, number)
- [ ] Can upload documents
- [ ] QR code shown when profile complete
- [ ] Settings tab works

---

## Edge Cases to Test

### Network Conditions
- [ ] App works on 2G/slow connection
- [ ] Offline mode shows appropriate messages
- [ ] App recovers after network restoration
- [ ] No data loss on connection drop during payment

### Device Compatibility
- [ ] Android 8.0+ (API 26+)
- [ ] Android 14 (latest)
- [ ] Low-end device (2GB RAM)
- [ ] High-end device (8GB RAM)
- [ ] Small screen (5 inch)
- [ ] Large screen (6.7 inch)

### Data Edge Cases
- [ ] Property with 0 beds
- [ ] Tenant with no active stay
- [ ] Business with no properties
- [ ] Invoice with ₹0 amount (should not be created)
- [ ] Very long property names (overflow handling)
- [ ] Special characters in names

---

## UAT Sign-Off Criteria

| Feature | Pass Rate Required | Actual | Status |
|---------|-------------------|--------|--------|
| Business onboarding | 100% | | ☐ |
| Tenant enrollment | 95% | | ☐ |
| Payment flows | 99% | | ☐ |
| Notifications | 90% | | ☐ |
| Monthly billing | 98% | | ☐ |
| Team management | 95% | | ☐ |
| Explore/Search | 90% | | ☐ |

**Overall UAT Pass Rate Required: 95%**

---

## Known Issues Tracker

| Issue | Severity | Status | Assigned To |
|-------|----------|--------|-------------|
| | | | |

---

## UAT Feedback Collection

### Feedback Form Questions
1. How easy was it to complete onboarding? (1-5)
2. Did you encounter any errors? (Yes/No + description)
3. Was the payment process clear? (1-5)
4. What feature was most confusing?
5. What feature worked best?
6. Would you recommend this app? (1-10 NPS)

### Success Metrics
- NPS score > 7
- Onboarding completion rate > 85%
- Zero critical bugs in payment flows
- Support ticket rate < 5% of active users
