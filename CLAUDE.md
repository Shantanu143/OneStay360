# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

OneStay360 is a PG/hostel management platform for India (INR, UPI, Razorpay, WhatsApp). One Firebase project (`onestay360-1`) backs everything:

- `apps/business` — Flutter app for PG owners/managers/staff (properties, rooms/beds, tenants, rent, team invites)
- `apps/tenant` — Flutter app for tenants (explore PGs, enroll, pay rent)
- `apps/admin-web` — Next.js 16 / React 19 / MUI super-admin console (no tests)
- `apps/web` — Next.js 16 static site: marketing landing, sign in/up, and full owner + tenant dashboards. Runs on an in-browser demo backend; see its README
- `functions/` — Firebase Cloud Functions (TypeScript, Node 20, firebase-functions **v1 API**)
- `packages/{models,firebase_services,common_ui,utils}` — shared Dart packages, consumed by both Flutter apps as `path:` dependencies
- `firestore.rules`, `storage.rules`, `firestore.indexes.json`, `hosting/app-links` (Android assetlinks + invite landing page)
- `lib_backup/` is a stale pre-monorepo copy of the old app. Ignore it.

## Commands

There is no workspace tooling: each Flutter package/app, `functions/`, `apps/admin-web/` and `apps/web/` is installed and run on its own.

**Flutter apps and packages** (run inside `apps/business`, `apps/tenant`, or `packages/<name>`; needs Flutter with Dart ≥ 3.8.1 and JDK 17 for Android builds):
```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test                                   # whole suite (apps' test/integration/ are plain unit tests, no device needed)
flutter test test/unit/view_models/add_tenant_viewmodel_test.dart --plain-name "gender"   # single file / single test
flutter run -d <device-id>                     # `flutter devices` to list; no emulator wiring, see below
flutter build apk --debug
```
Mocks are `build_runner`-generated only where `@GenerateMocks` is used: `dart run build_runner build --delete-conflicting-outputs`.

**Cloud Functions** (`functions/`):
```bash
npm ci
npx tsc --noEmit            # typecheck;  `npm run build` emits to functions/lib
npm test                    # jest
npx jest test/unit/billing_logic_test.ts -t "overdue"     # single file / single test
npm run deploy              # build + `firebase deploy --only functions` -> deploys to PRODUCTION
```
- `functions/lib/*.js` is **committed** and is the deploy entry (`"main": "lib/index.js"`). After editing a `.ts` file, run `npm run build` so `lib/` stays in sync.
- `jest.config.js` whitelists test files explicitly in `testMatch` (billing, tenant billing, member access, invitation phone, tenant invitation and maintenance logic tests). A new test file will NOT run until added there. `test/unit/billing_test.ts` is excluded on purpose: it needs the Firestore/Auth emulators (`test/setup.ts` points at localhost:8080/9099).
- The Jest tests exercise extracted pure logic, not the callable functions themselves.
- `test/e2e/` runs the real callables, the signed Razorpay webhook and triggers against the Firestore emulator (rent by UPI/cash and online, property edit, tenant invitations, maintenance): `npx firebase emulators:exec --only firestore --project demo-onestay "cd functions && npx jest -c jest.e2e.config.js"` from the repo root. Not part of `npm test`.

**Web app** (`apps/web/`):
```bash
npm install
npm run dev | typecheck | build
npm run test:e2e            # after build: serves ./out and drives owner/tenant/team flows in Chromium
```
Screens use only the `Backend` interface (`lib/backend/api.ts`); the app currently returns `DemoBackend` (`lib/backend/demo/`), a seeded localStorage workspace that mimics the Cloud Functions' behaviour. Demo logins: `asha@onestay.demo` (owner), `vikram@onestay.demo` (manager), `rahul@onestay.demo` (tenant), password `demo1234`. Pages that take an id read it from `?id=` because the site is a static export.

**Admin web** (`apps/admin-web/`):
```bash
npm install
npm run dev | build | typecheck
```
`npm run lint` is broken (`next lint` was removed in Next 16 and there is no `eslint.config.*`). There are no tests despite vitest/playwright being in devDependencies. Firebase config comes from `NEXT_PUBLIC_FIREBASE_*` (see `.env.example`); without them it falls back to mock values.

## Architecture

### Everything talks to production
No Flutter or web code connects to the Firebase emulators (`firebase.json` defines them, but nothing calls `use*Emulator`). `flutter run` hits the live `onestay360-1` project: real Auth (Google / email / phone OTP), real Firestore, real Cloud Functions. Be deliberate about writes, and don't create test data casually. In debug builds Firebase App Check uses the **debug provider** and prints a token to the log; that token must be registered in Firebase Console → App Check for backend calls to succeed.

### Flutter app structure
Both apps share one look: the design system in `presentation/design/` (tokens, theme, motion, components; `Biz*` in business, `App*` in tenant, kept as parallel copies) with Inter, the green palette and a floating glass tab bar. Screens sit on ChangeNotifier view models that take an injected source, so they are tested with fakes.

The tenant app (`apps/tenant/lib`): `app/` (auth gate, tab shell, routes, `TenantApp` providers), `data/` (`models.dart`, abstract `sources.dart`, `firestore_sources.dart` implementing all of them as `FirestoreTenantBackend`, `TenantSession`), and `presentation/<feature>/` (home, explore, property, stay, payments, maintenance, notifications, invitations, pinboard, profile, auth). `StayFeed` and `ActivityFeed` are app-level live feeds shared by several screens. Tests use `test/support/fakes.dart` (`FakeBackend`) and `harness.dart` (the real app, signed in, on the fake backend); `test/preview` renders screens to PNG when `RENDER_DIR` is set.

The business app layers `presentation/views` (screens) → `presentation/view_models` (ChangeNotifier) → `data/providers` + `services` → `packages/firebase_services` (Firestore/Auth/Storage wrappers and repositories) → `packages/models`. State is `provider`; `main.dart` builds the `MultiProvider` tree and the splash → `AuthWrapper` → home flow. Several files exist in parallel in both apps (`login_screen`, `device_token_service`, `splash`, `auth_wrapper`, and each app has both a `business_state_provider` and a `tenant_state_provider`, implemented differently). They are not shared code, so a bug in one often exists in the other.

The business app also handles deep links: `https://app.onestay360.brandedpatil.in/invite?inviteId=…` is routed to `/invite` via `app_links` (host verification file lives in `hosting/app-links/.well-known/assetlinks.json`).

### Roles and permissions: copies to keep in sync
Roles are `owner | manager | staff`, scoped at two levels: business membership (`businesses/{id}/members/{uid}`, must be `status == active`) and per-property access docs (`businesses/{id}/properties/{pid}/access/{uid}`; owners implicitly have all property access). The matrix is implemented independently in:
1. `functions/permissions.ts` (`assertBusinessPermission` / `assertPropertyPermission`, used by callables)
2. `firestore.rules` (helper functions at the top)
3. `apps/business/lib/utils/permissions.dart` (UI gating only)
4. `apps/web/lib/permissions.ts` (web UI gating; the demo backend repeats the checks)

Changing a permission means touching all of them.

### Firestore layout
- Business-scoped data nests under `businesses/{businessId}/…`: `members`, `properties/{pid}/{rooms/{rid}/beds, access}`, `tenants`, `payments`, `rent_invoices`, `paymentMethods`, `audit_logs`, `settings`.
- Top-level collections: `users` (+ `deviceTokens`, `notifications`), global `tenants` (a tenant's profile, ids like `TEN0000001`), `enrollmentRequests`, `tenant_invitations`, `business_invitations`, `business_activation`, `billing_invoices`, `platform_payments`, `payment_transactions`, `payment_attempts`, `promo_redemptions`, `plans`, `counters`, `properties_by_city` (public listing index for the tenant app's Explore), `pinboard`.
- Sequential human-readable ids (`TEN0000001`, business/property ids) come from transactional `counters/*` docs, in functions (`generateTenantId`) and client-side `IdGenerationService`.
- Many writes are deliberately **callable-only**; rules deny client writes to notifications, billing fields, plans, etc. Prefer adding/using a callable over loosening rules.

### Two separate money flows
1. **Platform → business (SaaS billing)**: `functions/billing.ts` + `activateProperty.ts`. Invariants documented at the top of those files: pricing is per bed and platform-owned (`plans`), each property stores an immutable plan snapshot, clients never write billing fields, `property.billingStatus` changes only in `processMonthlyBilling` (scheduler) and `confirmActivationPayment`. State machine from invoice due date: `due` → `grace` (+5d) → `past_due` (+12d) → `suspended`; `paid` is terminal. Invoice ids are deterministic (`{propertyId}_{periodStartMillis}`) for idempotency. Promos apply only to the final payable amount.
2. **Tenant → business (rent)**: `tenantBilling.ts` (monthly `rent_invoices`, overdue marking), `billing.ts` (`submitRentPayment` / `verifyRentPayment` / `recordPayment`), and `razorpay.ts` (per-owner Razorpay onboarding, payment links, `razorpayPaymentWebhook`). Tenants can pay by Razorpay, UPI (owner confirms), or cash.

Razorpay keys come from `functions.config().razorpay.{key_id,key_secret}` or env `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET`.

### Tenant onboarding (`functions/tenantOnboarding.ts`, `enrollmentNotifications.ts`)
Two entry paths converge on a tenant record:
- **Tenant has the app**: `submitEnrollmentRequest` callable creates `enrollmentRequests/{id}`; the owner moves it through `pending → approved → bill_sent → payment_submitted → confirmed` (or `rejected`). The Firestore trigger `onEnrollmentStatusChanged` reacts to each status transition (creates the tenant, marks the bed occupied, sends notifications). Approval requires a room and bed to be assigned, otherwise the trigger resets it to `pending`.
- **Tenant has no app**: owner adds the tenant manually; `onTenantCreated` sends a WhatsApp/email invitation, and `onTenantUserCreated` auto-links when someone later signs up with the same phone.
- **Owner invites through the wizard**: `createTenantInvitation` writes `tenant_invitations/{id}`; the tenant app lists and answers it through `listMyTenantInvitations`, `getMyTenantInvitation`, `approveInvitation` and `rejectTenantInvitation` (`tenantInvitations.ts`, matched by tenant id or phone). Accepting creates the business tenant, the active stay and occupies the bed.

### Maintenance requests
`maintenanceRequests/{id}` (top level): tenants create them for the business they stay with and may cancel an open one; any active member of that business moves them `open → in_progress → resolved` (rules restrict which fields change). `maintenance.ts` notifies the owner on create and pushes the tenant on progress. Business UI: `presentation/maintenance/`, surfaced in Home's "Needs attention" and notifications.

### Cloud Functions layout
`functions/index.ts` only re-exports the function modules. `sendSms`, `sendEmail`, `sendWhatsApp`, `audit`, `plan`, `permissions`, `seed_pgs` are helper modules imported by others (not exported functions). Each module guards `admin.initializeApp()` itself. Almost all functions are `functions.https.onCall`, Firestore triggers, or schedulers (the Razorpay webhook is the one `onRequest`). Notable side effects: `auditTriggers.ts` writes `audit_logs`; push notifications use FCM tokens registered through `registerDeviceToken`.

### Android notes
Application ids are `com.onestay360.business` / `com.onestay360.tenant`; each has its own `google-services.json` for `onestay360-1`. Release signing reads `android/key.properties` (see `key.properties.example`) and silently falls back to the debug keystore when it is absent.

## CI
`.github/workflows/ci.yml` runs on main/staging/develop: functions (`npm ci`, `npm audit --audit-level moderate`, build, jest), both apps (`flutter analyze`, unit and widget tests), the packages, the web app (typecheck, build, Playwright e2e), then deploys functions + rules + indexes via `firebase deploy` (staging branch → staging, main → production).
