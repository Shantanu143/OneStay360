# OneStay360 Web

Marketing site, sign in / sign up, and full owner and tenant dashboards for OneStay360, in one Next.js 16 app exported as static files.

- **Landing** (`/`): hero with a dashboard preview, every Business and Tenant app feature (what it does, why it matters, a use case), how it works, who it's for, pricing, FAQ.
- **Feature deep-dives**: `/features/business/` and `/features/tenant/`, each feature linking straight into the demo.
- **Auth**: `/signin/` and `/signup/` (owner or tenant), with one-click demo accounts.
- **Owner dashboard** (`/dashboard/owner/…`): home (collections, occupancy, needs attention, activity), properties (stepped add/edit, floor plan, tenants, payments, requests, QR), tenants (invite wizard or direct add, edit, vacate), join requests (assign bed → first bill → confirm payment), rent & payments (verify UPI/cash, dues, record, CSV), reports, payment methods (UPI/bank, online toggle), billing (per-bed activation, promo codes), maintenance, team (manager/staff, per-property access), notifications, profile & KYC.
- **Tenant dashboard** (`/dashboard/tenant/…`): home, explore (city, gender, search, favourites), PG page and join request, request tracker with first-bill payment, invitations (accept/decline), my stay, rent (online, UPI with UTR, cash; history), maintenance, pinboard, notifications, profile.
- **Public PG page** (`/pg/?id=…`): what a property's QR code opens.

Glassmorphism UI with the apps' green palette and Inter, light/dark/system theme, responsive down to phone widths. Roles follow `apps/business/lib/utils/permissions.dart` (see `lib/permissions.ts`).

## Run

```bash
npm install
npm run dev          # http://localhost:3000
npm run typecheck
npm run build        # static export to ./out
npm run test:e2e     # after build: serves ./out and drives every flow in Chromium
```

`SHOTS=1 npm run test:e2e` also saves desktop and phone screenshots of every route to `e2e/shots/`.

## Data: demo backend

Screens talk only to the `Backend` contract in `lib/backend/api.ts`. Each method names the Firestore path or callable Cloud Function it corresponds to (`submitEnrollmentRequest`, `verifyRentPayment`, `createTenantInvitation`, `vacateTenant`, `createBusinessInvitation`, `createCheckoutQuote`, …).

The app currently runs on `DemoBackend` (`lib/backend/demo/`): a seeded workspace stored in the browser's localStorage that reproduces the server-side behaviour. A confirmed join request creates the tenant, occupies the bed and raises the first invoice; verifying a UPI payment closes its invoice; beds are held while a request or invitation is open; and so on. Sign in as different demo accounts in the same browser to see both sides of a flow. "Reset demo" in the dashboard banner restores the seed.

| Demo account | Email | Password |
| --- | --- | --- |
| Owner | asha@onestay.demo | demo1234 |
| Manager | vikram@onestay.demo | demo1234 |
| Tenant | rahul@onestay.demo | demo1234 |

Connecting the live `onestay360-1` project means adding a `FirebaseBackend` that implements the same interface with the Firebase JS SDK (Auth, Firestore, callable functions, and App Check with reCAPTCHA for web) and returning it from `lib/backend/index.ts`.

## SEO and configuration

Set these at build time:

| Variable | Purpose |
| --- | --- |
| `NEXT_PUBLIC_SITE_URL` | Production origin used for canonical URLs, the sitemap, robots.txt and Open Graph tags. Defaults to `https://app.onestay360.brandedpatil.in`. |
| `NEXT_PUBLIC_CONTACT_EMAIL` | Optional. When set, the footer and pricing show a contact email. |

Public pages (`/`, `/features/business/`, `/features/tenant/`, `/signup/`) have their own title, description, canonical URL and Open Graph/Twitter card (`public/og.png`). The home page carries Organization, WebSite, SoftwareApplication (with prices) and FAQPage structured data; feature pages carry breadcrumbs. `robots.txt` and `sitemap.xml` are generated at build. Sign-in, the public PG page and the whole dashboard are `noindex`.

## Design rules

The UI follows a written set of rules: 16px body text and labels, 14px minimum supporting text, a 4/8/16/24/32/48/64 spacing scale, one 30px page heading per screen with its main actions beside it, labels above every field with inline errors, descriptive button labels, explicit loading/empty/error states, statuses shown as text (not colour alone), tables that stack into labelled cards on phones, and reduced-motion support. `axe-core` reports no WCAG 2 A/AA or best-practice violations on the public pages and dashboards in light or dark theme.

## Deploy

`out/` is plain static files (`trailingSlash: true`, ids passed as `?id=` query params), so any static host works. The repo's `firebase.json` hosting target currently serves `hosting/app-links`; to host this site on Firebase, add a separate hosting target pointing at `apps/web/out`.
