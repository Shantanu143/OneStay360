// Captures the real product screenshots used on the landing and auth pages
// (public/shots/*.jpg), in light and dark theme, from the built site running
// on the demo workspace. Run after `npm run build`:
//   npm run screenshots
import { createServer } from "node:http";
import { mkdir, readFile, stat } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");
const root = fileURLToPath(new URL("../out", import.meta.url));
const outDir = fileURLToPath(new URL("../public/shots", import.meta.url));
const types = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".png": "image/png", ".jpg": "image/jpeg", ".woff2": "font/woff2", ".json": "application/json", ".txt": "text/plain" };

const server = createServer(async (req, res) => {
  let file = join(root, normalize(decodeURIComponent(new URL(req.url, "http://x").pathname)).replace(/^(\.\.[/\\])+/, ""));
  try {
    if ((await stat(file)).isDirectory()) file = join(file, "index.html");
    res.writeHead(200, { "content-type": types[extname(file)] ?? "application/octet-stream" });
    res.end(await readFile(file));
  } catch {
    res.writeHead(404).end();
  }
});
await new Promise((r) => server.listen(0, r));
const base = `http://localhost:${server.address().port}`;
await mkdir(outDir, { recursive: true });

// Hide the demo-mode banner: the screenshots show the product, not the demo.
const css = `.demo-banner{display:none!important} .toasts{display:none!important} *{transition:none!important;animation:none!important}`;

const browser = await chromium.launch();

async function session(scheme, viewport, email, scale = 1) {
  const ctx = await browser.newContext({ viewport, colorScheme: scheme, deviceScaleFactor: scale, reducedMotion: "reduce" });
  const page = await ctx.newPage();
  await page.goto(`${base}/signin/`, { waitUntil: "networkidle" });
  await page.evaluate(() => localStorage.clear());
  await page.reload({ waitUntil: "networkidle" });
  await page.fill('input[type="email"]', email);
  await page.fill('input[autocomplete="current-password"]', "demo1234");
  await page.click('form button[type="submit"], form button.btn-primary');
  await page.waitForURL(/\/dashboard\//);
  await page.locator(".page-head h1").waitFor();
  const open = async (path) => {
    await page.goto(base + path, { waitUntil: "networkidle" });
    await page.addStyleTag({ content: css });
    await page.locator(".page-head h1").waitFor();
    await page.waitForTimeout(500);
  };
  return { ctx, page, open };
}

const jpg = { type: "jpeg", quality: 82 };
const shot = (name, scheme) => join(outDir, `${name}-${scheme}.jpg`);

for (const scheme of ["light", "dark"]) {
  // Owner: full window, dashboard home.
  {
    const { ctx, page, open } = await session(scheme, { width: 1440, height: 900 }, "asha@onestay.demo");
    await open("/dashboard/owner/");
    await page.screenshot({ path: shot("owner-home", scheme), ...jpg });

    // Feature shots: the content area only (no sidebar), so details read larger.
    const content = { x: 272, y: 0, width: 1168, height: 820 };
    await open("/dashboard/owner/property/?id=BUS0000001-P01&tab=layout");
    await page.evaluate(() => document.querySelector(".prop-cover")?.closest("div")?.remove());
    await page.screenshot({ path: shot("owner-layout", scheme), clip: content, ...jpg });

    await open("/dashboard/owner/payments/");
    await page.screenshot({ path: shot("owner-payments", scheme), clip: { ...content, height: 640 }, ...jpg });

    // Approving a join request: a tall window so the whole dialog fits.
    await page.setViewportSize({ width: 1440, height: 1700 });
    await open("/dashboard/owner/requests/?id=REQ-priya");
    await page.locator(".modal").waitFor();
    await page.click('.modal button:has-text("Approve & send bill")');
    await page.locator(".modal button.bed.free").nth(3).click();
    await page.evaluate(() => document.querySelector(".modal")?.scrollTo(0, 0));
    await page.waitForTimeout(300);
    await page.locator(".modal").screenshot({ path: shot("owner-approve", scheme), ...jpg });
    await ctx.close();
  }
  // Tenant: phone-sized screens.
  {
    const { ctx, page, open } = await session(scheme, { width: 390, height: 844 }, "rahul@onestay.demo", 2);
    await open("/dashboard/tenant/explore/");
    await page.screenshot({ path: shot("tenant-explore", scheme), ...jpg });

    await open("/dashboard/tenant/");
    await page.screenshot({ path: shot("tenant-home", scheme), ...jpg });

    await open("/dashboard/tenant/maintenance/");
    await page.screenshot({ path: shot("tenant-maintenance", scheme), ...jpg });
    await ctx.close();
  }
  // Tenant with rent due: the pay sheet open on this month's invoice.
  {
    const { ctx, page, open } = await session(scheme, { width: 390, height: 844 }, "rahul@onestay.demo", 2);
    // Re-open this month's invoice so the pay sheet has something to show.
    await page.evaluate(() => {
      const key = "onestay360.demo.v1";
      const st = JSON.parse(localStorage.getItem(key));
      const mine = st.invoices.filter((i) => i.tenantId === "TEN0000001").sort((a, b) => b.periodMonth.localeCompare(a.periodMonth))[0];
      mine.status = "unpaid";
      delete mine.paidAt;
      st.payments = st.payments.filter((p) => p.invoiceId !== mine.id);
      localStorage.setItem(key, JSON.stringify(st));
    });
    await open("/dashboard/tenant/rent/");
    await page.click('.list-row button:has-text("Pay")');
    await page.locator(".modal").waitFor();
    await page.waitForTimeout(300);
    await page.screenshot({ path: shot("tenant-pay", scheme), ...jpg });
    await ctx.close();
  }
}

await browser.close();
server.close();
console.log(`Saved screenshots to ${outDir}`);
