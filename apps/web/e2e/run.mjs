// End-to-end check of the exported site (run `npm run build` first):
// serves ./out, then drives the main owner/tenant/team flows in Chromium in
// demo mode and visits every dashboard route at desktop and phone widths.
//   node e2e/run.mjs            # SHOTS=1 also saves screenshots to e2e/shots
import { createServer } from "node:http";
import { readFile, stat, mkdir } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");
const root = fileURLToPath(new URL("../out", import.meta.url));
const shotsDir = fileURLToPath(new URL("./shots", import.meta.url));
const SHOTS = process.env.SHOTS === "1";
const types = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".png": "image/png", ".ttf": "font/ttf", ".json": "application/json", ".svg": "image/svg+xml", ".txt": "text/plain", ".ico": "image/x-icon" };

const server = createServer(async (req, res) => {
  let p = normalize(decodeURIComponent(new URL(req.url, "http://x").pathname)).replace(/^(\.\.[/\\])+/, "");
  let file = join(root, p);
  try {
    if ((await stat(file)).isDirectory()) file = join(file, "index.html");
  } catch {
    file = join(root, "404.html");
  }
  try {
    const body = await readFile(file);
    res.writeHead(200, { "content-type": types[extname(file)] ?? "application/octet-stream" });
    res.end(body);
  } catch {
    res.writeHead(404).end("not found");
  }
});
await new Promise((r) => server.listen(0, r));
const base = `http://localhost:${server.address().port}`;

const browser = await chromium.launch();
const context = await browser.newContext({ viewport: { width: 1360, height: 900 } });
const page = await context.newPage();
const errors = [];
page.on("pageerror", (e) => errors.push(`${page.url()}: ${e.message}`));
page.on("console", (m) => m.type() === "error" && errors.push(`${page.url()}: ${m.text()}`));

let passed = 0;
const failures = [];
async function step(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`  ✓ ${name}`);
  } catch (e) {
    failures.push(name);
    console.log(`  ✗ ${name}\n    ${String(e.message).split("\n").slice(0, 4).join("\n    ")}`);
    if (SHOTS) await page.screenshot({ path: join(shotsDir, `fail-${failures.length}.png`) }).catch(() => {});
  }
}
const go = (path) => page.goto(base + path, { waitUntil: "networkidle" });
const toast = (text) => page.locator(".toast", { hasText: text }).first().waitFor({ timeout: 5000 });
const modal = () => page.locator(".modal").last();
const signIn = async (email, password = "demo1234") => {
  await go("/signin/");
  await page.fill('input[type="email"]', email);
  await page.fill('input[autocomplete="current-password"]', password);
  await page.click('button:has-text("Sign in")');
  await page.waitForURL(/\/dashboard\//);
  await page.locator(".page-head h1").waitFor();
};
const signOut = async () => {
  await page.evaluate(() => localStorage.removeItem("onestay360.demo.session"));
};
const signUp = async ({ kind, name, email, phone }) => {
  await signOut();
  await go(`/signup/?kind=${kind}`);
  await page.fill('input[autocomplete="name"]', name);
  await page.fill('input[type="email"]', email);
  await page.fill('input[type="tel"]', phone);
  await page.fill('input[autocomplete="new-password"]', "secret123");
  await page.click("form button.btn-primary");
  await page.waitForURL(/\/dashboard\//);
  await page.locator(".page-head h1").waitFor();
};
const expectText = async (text, scope = page) => {
  await scope.getByText(text, { exact: false }).first().waitFor({ timeout: 5000 });
};

if (SHOTS) await mkdir(shotsDir, { recursive: true });
console.log(`Serving ${root} at ${base}\n`);

// ── Public site ──────────────────────────────────────────
await step("landing tells the three-chapter journey with real screenshots", async () => {
  await go("/");
  await expectText("PG management that runs itself");
  for (const id of ["journey", "pricing", "faq"]) await page.locator(`#${id}`).waitFor();
  for (const t of ["Set up once. See every bed, live.", "without the calls", "Rent that collects itself."]) await expectText(t);
  const shots = await page.locator("img.shot").count();
  if (shots < 10) throw new Error(`expected screenshot images, found ${shots}`);
  const broken = await page.evaluate(async () => {
    const imgs = [...document.querySelectorAll("img.shot-light")];
    await Promise.all(imgs.map((i) => (i.loading = "eager", i.decode().catch(() => null))));
    return imgs.filter((i) => !i.naturalWidth).map((i) => i.src);
  });
  if (broken.length) throw new Error(`broken screenshots: ${broken.join(", ")}`);
});
await step("sign-in has no sample-data shortcut and sends each role home", async () => {
  await signOut();
  await go("/signin/");
  if (await page.getByText("sample data", { exact: false }).count()) throw new Error("sample-data option still shown");
  await signIn("rahul@onestay.demo");
  if (!page.url().includes("/dashboard/tenant/")) throw new Error(`tenant landed on ${page.url()}`);
  await signOut();
  await signIn("vikram@onestay.demo");
  if (!page.url().includes("/dashboard/owner/")) throw new Error(`manager landed on ${page.url()}`);
  await signOut();
});
await step("sign-in and sign-up fit one screen without scrolling", async () => {
  for (const [w, h] of [[1366, 768], [1440, 900], [390, 844]]) {
    await page.setViewportSize({ width: w, height: h });
    for (const path of ["/signin/", "/signup/"]) {
      await go(path);
      const over = await page.evaluate(() => document.documentElement.scrollHeight - window.innerHeight);
      if (over > 1) throw new Error(`${path} at ${w}x${h} scrolls by ${over}px`);
    }
  }
  await page.setViewportSize({ width: 1360, height: 900 });
});
await step("theme toggle switches to dark and persists", async () => {
  await go("/");
  await page.click(".nav .icon-btn[aria-label*='theme']");
  const stored = await page.evaluate(() => localStorage.getItem("onestay360.theme"));
  if (!stored) throw new Error("theme not stored");
  await page.reload({ waitUntil: "networkidle" });
  const attr = await page.evaluate(() => document.documentElement.getAttribute("data-theme"));
  if (attr !== stored) throw new Error(`data-theme ${attr} != ${stored}`);
  await page.evaluate(() => localStorage.removeItem("onestay360.theme"));
});
await step("feature pages list every feature", async () => {
  await go("/features/business/");
  await expectText("Join requests & approvals");
  await expectText("Team & roles");
  await go("/features/tenant/");
  await expectText("Pay rent your way");
});
await step("dashboard redirects signed-out visitors to sign in", async () => {
  await go("/dashboard/owner/payments/");
  await page.waitForURL(/\/signin\/\?next=/);
});
await step("wrong password shows an error", async () => {
  await go("/signin/");
  await page.fill('input[type="email"]', "asha@onestay.demo");
  await page.fill('input[autocomplete="current-password"]', "nope");
  await page.click('button:has-text("Sign in")');
  await expectText("Email or password is incorrect");
});

// ── Join request lifecycle across tenant and owner ───────
await step("new tenant signs up and requests to join a PG", async () => {
  await signUp({ kind: "tenant", name: "Test Tenant", email: "tt@example.com", phone: "9000011111" });
  await go("/dashboard/tenant/explore/");
  await page.click("text=Sunrise Residency");
  await page.waitForURL(/\/dashboard\/tenant\/pg\//);
  await page.click('button:has-text("Request to join")');
  await modal().locator("textarea").fill("Need a bed near my office");
  await modal().locator('button:has-text("Send request")').click();
  await toast("Request sent");
  await page.waitForURL(/\/dashboard\/tenant\/requests\//);
  await expectText("Request sent");
});
await step("owner approves, assigns a bed and sends a UPI bill", async () => {
  await signOut();
  await signIn("asha@onestay.demo");
  await go("/dashboard/owner/requests/");
  await page.click('.list-row:has-text("Test Tenant")');
  await modal().locator('button:has-text("Approve & send bill")').click();
  await modal().locator("button.bed.free").first().click();
  await modal().locator('button:has-text("Send bill")').click();
  await toast("sent to Test Tenant");
});
await step("tenant pays the first bill with a UTR", async () => {
  await signOut();
  await signIn("tt@example.com", "secret123");
  await go("/dashboard/tenant/requests/");
  await expectText("sunrisestays@okhdfc");
  await page.fill('input[placeholder="e.g. 412345678901"]', "412345678901");
  await page.click("button:has-text(\"I've paid\")");
  await toast("Payment submitted");
});
await step("owner confirms payment → tenant created, bed occupied", async () => {
  await signOut();
  await signIn("asha@onestay.demo");
  await go("/dashboard/owner/requests/");
  await page.click('.list-row:has-text("Test Tenant")');
  await modal().locator('button:has-text("Confirm payment")').click();
  await toast("is now a tenant");
  await go("/dashboard/owner/tenants/");
  await expectText("Test Tenant");
});
await step("tenant sees the stay and pays rent by UPI; owner verifies", async () => {
  await signOut();
  await signIn("tt@example.com", "secret123");
  await go("/dashboard/tenant/stay/");
  await expectText("Room");
  await go("/dashboard/tenant/rent/");
  const payBtn = page.locator('.list-row button:has-text("Pay")');
  if (await payBtn.count()) {
    await payBtn.first().click();
    await modal().locator('button.chip:has-text("UPI")').click();
    await modal().locator('input[placeholder="e.g. 412345678901"]').fill("998877665544");
    await modal().locator("button:has-text(\"I've paid\")").click();
    await toast("Sent to your owner");
    await signOut();
    await signIn("asha@onestay.demo");
    await go("/dashboard/owner/payments/");
    await page.locator('.list-row:has-text("Test Tenant") button:has-text("Confirm")').click();
    await toast("verified");
  }
});

// ── Existing tenant: online rent, maintenance, pinboard ──
await step("demo tenant pays rent online", async () => {
  await signOut();
  await signIn("rahul@onestay.demo");
  await go("/dashboard/tenant/rent/");
  const pay = page.locator('.list-row button:has-text("Pay")');
  if (!(await pay.count())) return; // already paid this month
  await pay.first().click();
  await modal().locator('button:has-text("Continue to pay")').click();
  await modal().locator('button:has-text("Complete payment")').click();
  await toast("Paid");
});
await step("tenant raises maintenance; owner starts and resolves it", async () => {
  await go("/dashboard/tenant/maintenance/");
  await page.click('button:has-text("Raise request")');
  await modal().locator('input[placeholder="e.g. Fan not working"]').fill("Geyser not heating");
  await modal().locator('button:has-text("Send to owner")').click();
  await toast("Request sent");
  await signOut();
  await signIn("asha@onestay.demo");
  await go("/dashboard/owner/maintenance/");
  const card = page.locator('.card:has-text("Geyser not heating")');
  await card.locator('button:has-text("Start work")').click();
  await modal().locator("textarea").fill("Electrician at 5pm");
  await modal().locator('button:has-text("Start work")').click();
  await toast("in progress");
  await card.locator('button:has-text("Mark resolved")').click();
  await modal().locator('button:has-text("Resolve")').click();
  await toast("resolved");
  await signOut();
  await signIn("rahul@onestay.demo");
  await go("/dashboard/tenant/maintenance/");
  await expectText("Electrician at 5pm");
});
await step("tenant posts and deletes a pinboard note", async () => {
  await go("/dashboard/tenant/pinboard/");
  await page.fill('textarea[aria-label="Note"]', "Movie night on the terrace at 9!");
  await page.click('button:has-text("Pin it")');
  await toast("Pinned");
  await page.locator('.card:has-text("Movie night") button[aria-label="Delete note"]').click();
  await toast("Note removed");
});

// ── Owner invitation → tenant accepts ────────────────────
await step("owner invites a tenant with the wizard; tenant accepts", async () => {
  await signOut();
  await signIn("asha@onestay.demo");
  await go("/dashboard/owner/tenants/");
  await page.click('.page-actions button:has-text("Add a tenant")');
  await modal().locator("button.bed.free").first().click();
  await modal().locator('button:has-text("Continue")').click();
  await modal().locator('input[placeholder="Tenant\'s name"]').fill("Invited Ira");
  await modal().locator('input[placeholder="98765 43210"]').fill("9000022222");
  await modal().locator('button:has-text("Continue")').click();
  await modal().locator('button:has-text("Continue")').click();
  await modal().locator('button:has-text("Send invitation")').click();
  await toast("Invitation sent");
  await signUp({ kind: "tenant", name: "Invited Ira", email: "ira@example.com", phone: "9000022222" });
  await go("/dashboard/tenant/invitations/");
  await page.click('button:has-text("Accept & move in")');
  await toast("Welcome");
  await go("/dashboard/tenant/stay/");
  await expectText("Sunrise");
});

// ── Owner: properties, billing, team, payments ───────────
await step("owner adds a property with the stepped form and activates it with a promo", async () => {
  await signOut();
  await signIn("asha@onestay.demo");
  await go("/dashboard/owner/property-form/");
  await page.fill('input[placeholder="e.g. Sunrise Residency"]', "Test Towers");
  await page.fill('input[placeholder="Building, street, area"]', "1 MG Road");
  for (let i = 0; i < 4; i++) await page.click('button:has-text("Continue")');
  await page.click('button:has-text("Create property")');
  await toast("Property added");
  await page.waitForURL(/\/dashboard\/owner\/property\/\?id=/);
  await page.click('a:has-text("Activate property")');
  await page.waitForURL(/billing/);
  await modal().locator('input[placeholder="e.g. WELCOME20"]').fill("WELCOME20");
  await modal().locator('button:has-text("Apply")').click();
  await expectText("Promo WELCOME20", modal());
  await modal().locator('button:has-text("Pay")').click();
  await modal().locator('button:has-text("Complete payment")').click();
  await toast("is active");
});
await step("owner records a cash payment and exports CSV", async () => {
  await go("/dashboard/owner/payments/");
  await page.click('.page-actions button:has-text("Record a payment")');
  await modal().locator('button:has-text("Record ₹")').click();
  await toast("Payment recorded");
  await page.click('button[role="tab"]:has-text("All payments")');
  const [download] = await Promise.all([page.waitForEvent("download"), page.click('button:has-text("Export CSV")')]);
  if (!download.suggestedFilename().endsWith(".csv")) throw new Error("no csv");
});
await step("owner invites a staff member who signs up and joins", async () => {
  await go("/dashboard/owner/team/");
  await page.click('.page-actions button:has-text("Invite a team member")');
  await modal().locator("input").first().fill("Sam Staff");
  await modal().locator('input[placeholder="10-digit mobile"]').fill("9000033333");
  await modal().locator('button:has-text("staff")').click();
  await modal().locator('button:has-text("Send invite")').click();
  await toast("Invitation sent");
  await signUp({ kind: "business", name: "Sam Staff", email: "sam@example.com", phone: "9000033333" });
  await expectText("You've been invited to a team");
  await page.click('button:has-text("Accept")');
  await toast("You joined the team");
  await page.locator('.side-link:has-text("Maintenance")').waitFor();
  if (await page.locator('.side-link:has-text("Billing")').count()) throw new Error("staff can see billing");
});
await step("new owner signs up, creates a business and sees an empty portfolio", async () => {
  await signUp({ kind: "business", name: "New Owner", email: "owner2@example.com", phone: "9000044444" });
  await page.fill('input[placeholder="e.g. Sunrise Stays"]', "Fresh Stays");
  await page.click('button:has-text("Create business")');
  await toast("Business created");
  await expectText("Add your first property");
});

// ── Every route renders, desktop and phone ───────────────
const ownerRoutes = ["", "properties/", "property/?id=BUS0000001-P01", "property-form/?id=BUS0000001-P01", "tenants/", "tenant/?id=TEN0000001", "requests/", "payments/", "reports/", "collections/", "billing/", "maintenance/", "team/", "notifications/", "profile/"].map((r) => `/dashboard/owner/${r}`);
const tenantRoutes = ["", "explore/", "pg/?id=BUS0000002-P02", "stay/", "rent/", "requests/", "invitations/", "maintenance/", "pinboard/", "notifications/", "profile/"].map((r) => `/dashboard/tenant/${r}`);
for (const [width, label] of [
  [1360, "desktop"],
  [390, "phone"],
]) {
  await page.setViewportSize({ width, height: 860 });
  for (const [email, routes] of [
    ["asha@onestay.demo", ownerRoutes],
    ["rahul@onestay.demo", tenantRoutes],
  ]) {
    await signOut();
    await signIn(email);
    for (const r of routes) {
      await step(`${label} ${r} renders without overflow`, async () => {
        await go(r);
        await page.locator(".page-head h1").waitFor();
        await page.waitForTimeout(250);
        const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
        if (overflow > 1) throw new Error(`horizontal overflow ${overflow}px`);
        if (SHOTS) await page.screenshot({ path: join(shotsDir, `${label}-${r.replace(/[/?=]+/g, "_")}.png`), fullPage: false });
      });
    }
  }
  for (const r of ["/", "/features/business/", "/features/tenant/", "/signin/", "/signup/", "/pg/?id=BUS0000001-P01"]) {
    await signOut();
    await step(`${label} ${r} renders without overflow`, async () => {
      await go(r);
      await page.evaluate(() => document.querySelectorAll(".reveal").forEach((e) => e.classList.add("in")));
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
      if (overflow > 1) throw new Error(`horizontal overflow ${overflow}px`);
      if (SHOTS) await page.screenshot({ path: join(shotsDir, `${label}-public-${r.replace(/[/?=]+/g, "_")}.png`), fullPage: false });
    });
  }
}

await step("no uncaught page or console errors", async () => {
  const real = errors.filter((e) => !e.includes("favicon"));
  if (real.length) throw new Error(real.slice(0, 5).join("\n"));
});

await browser.close();
server.close();
console.log(`\n${passed} passed, ${failures.length} failed`);
process.exit(failures.length ? 1 : 0);
