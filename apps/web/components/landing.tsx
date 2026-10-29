"use client";
// The landing page tells one story: a PG stay from listing to monthly rent,
// in three chapters, each shown with real screenshots of the product.
import Link from "next/link";
import { ArrowDown, ArrowRight, Check } from "lucide-react";
import { SiteFooter, SiteNav } from "./site";
import { BrowserFrame, PhoneFrame } from "./shots";
import { useReveal } from "./ui";
import { faqs } from "@/lib/content";
import { site } from "@/lib/site";

type Who = "you" | "tenant" | "auto";
const whoLabel: Record<Who, string> = { you: "Owner", tenant: "Tenant", auto: "Automatic" };

function Flow({ steps }: { steps: { who: Who; title: string; body: string }[] }) {
  return (
    <ol className="flow">
      {steps.map((s) => (
        <li key={s.title}>
          <span className={`badge who who-${s.who}`}>{whoLabel[s.who]}</span>
          <div>
            <b>{s.title}</b>
            <span className="what">{s.body}</span>
          </div>
        </li>
      ))}
    </ol>
  );
}

function Chapter({ n, kicker, title, promise, steps, visual, flip }: { n: number; kicker: string; title: string; promise: string; steps: { who: Who; title: string; body: string }[]; visual: React.ReactNode; flip?: boolean }) {
  return (
    <article className={`chapter reveal ${flip ? "flip" : ""}`} aria-labelledby={`ch-${n}`}>
      <div>
        <p className="chapter-num">
          <b aria-hidden>{n}</b> {kicker}
        </p>
        <h3 id={`ch-${n}`}>{title}</h3>
        <p className="promise">{promise}</p>
        <Flow steps={steps} />
      </div>
      <div className="chapter-visual">{visual}</div>
    </article>
  );
}

export function Landing() {
  useReveal();
  return (
    <>
      <SiteNav />
      <main id="main">
        {/* ── Hero ─────────────────────────────────────── */}
        <section className="hero" aria-labelledby="hero-title">
          <div className="container">
            <a href="#journey" className="pill glass">
              <span className="badge badge-green">For PG owners and tenants</span>
              See how a stay works, start to finish <ArrowDown size={15} aria-hidden />
            </a>
            <h1 className="h1" id="hero-title">
              PG management that runs itself,
              <br className="hide-sm" /> <span className="accent">and an app your tenants will like</span>
            </h1>
            <p className="lead">Fill beds, collect rent and fix issues from one screen. Your tenants get an app to join, pay and ask for help — and every step updates both sides.</p>
            <div className="hero-ctas">
              <Link href="/signup/" className="btn btn-primary btn-lg">
                Create a free account <ArrowRight size={18} aria-hidden />
              </Link>
              <a href="#journey" className="btn btn-ghost btn-lg">
                See how it works
              </a>
            </div>
            <p className="faint small" style={{ marginTop: 16 }}>
              Free for tenants. Owners pay ₹30 per bed a month for active properties.
            </p>

            <div className="hero-visual">
              <BrowserFrame name="owner-home" url="onestay360 · Owner dashboard" alt="Owner dashboard: ₹1,59,500 collected this month, 59% occupancy, 17 active tenants, a six-month collections chart and a list of items that need attention." eager />
              <PhoneFrame name="tenant-home" alt="Tenant app home on a phone: Room 101, Bed A at Sunrise Residency with rent all paid, and shortcuts to stay, rent, maintenance and pinboard." eager />
            </div>
          </div>
        </section>

        {/* ── The journey: three features, one story ──── */}
        <section className="section" id="journey" aria-labelledby="journey-title">
          <div className="container">
            <div className="section-head reveal">
              <p className="eyebrow">How it works</p>
              <h2 className="h2" id="journey-title">
                One stay, from empty bed to monthly rent
              </h2>
              <p className="lead">Follow a real stay through OneStay360. Each chapter shows who does what — and what the app does for you.</p>
            </div>

            <div className="journey">
              <Chapter
                n={1}
                kicker="List your PG"
                title="Set up once. See every bed, live."
                promise="Describe your PG in a short, guided form. From then on, one floor plan shows which beds are free, held for someone or taken."
                steps={[
                  { who: "you", title: "Add rooms, beds and rent", body: "Floor by floor, with sharing, AC, deposit, food and house rules." },
                  { who: "auto", title: "Your floor plan stays current", body: "Beds turn taken when a tenant moves in and free again when they leave." },
                  { who: "you", title: "Go live", body: "Activate the property to appear on Explore, and print its QR code for your gate." },
                ]}
                visual={<BrowserFrame name="owner-layout" url="onestay360 · Sunrise Residency" alt="Floor plan of Sunrise Residency: rooms with each bed marked free, held for a request or occupied, with tenant names." />}
              />

              <Chapter
                n={2}
                flip
                kicker="Fill a bed"
                title="From “Is a bed free?” to moved in — without the calls."
                promise="Tenants find you, ask for a bed and pay the first bill in the app. You stay in control of who gets which bed."
                steps={[
                  { who: "tenant", title: "Finds your PG and asks to join", body: "Real rooms, prices, food and rules — then a request with a move-in date." },
                  { who: "you", title: "Pick a bed and send the first bill", body: "Rent, deposit and maintenance in one bill, payable by UPI, bank or cash." },
                  { who: "tenant", title: "Pays and shares the payment ID", body: "You confirm it, and they're a tenant — bed taken, first invoice ready." },
                ]}
                visual={
                  <>
                    <div className="crop pad-left">
                      <BrowserFrame name="owner-approve" url="onestay360 · Join request" alt="Owner approving Priya Desai's request: choosing bed C in Room 302 on a floor plan and sending a ₹27,000 first bill by UPI." />
                    </div>
                    <PhoneFrame className="float-left" name="tenant-explore" alt="Tenant browsing verified PGs on Explore, with rent from ₹9,500 and free beds shown on each card." />
                  </>
                }
              />

              <Chapter
                n={3}
                kicker="Collect rent"
                title="Rent that collects itself."
                promise="Every tenant gets an invoice on their billing day. They pay from their phone; you see it the moment it lands."
                steps={[
                  { who: "auto", title: "Invoices go out every month", body: "On each tenant's billing day, with overdue ones flagged for you." },
                  { who: "tenant", title: "Pays online, by UPI or in cash", body: "Online payments close the invoice by themselves." },
                  { who: "you", title: "Confirm UPI and cash in one tap", body: "Match the payment ID, tap Confirm — your collections update instantly." },
                ]}
                visual={
                  <>
                    <BrowserFrame name="owner-payments" url="onestay360 · Rent & payments" alt="Rent and payments page: ₹ received this month, one UPI payment waiting to be confirmed with its UTR, and overdue amounts." />
                    <PhoneFrame className="float-right" name="tenant-pay" alt="Tenant paying October rent of ₹14,000 on a phone, choosing between online, UPI and cash." />
                  </>
                }
              />
            </div>

            <div className="next-up reveal">
              <Link href="/features/business/" className="btn btn-ghost">
                Everything owners get <ArrowRight size={16} aria-hidden />
              </Link>
              <Link href="/features/tenant/" className="btn btn-ghost">
                Everything tenants get <ArrowRight size={16} aria-hidden />
              </Link>
            </div>
          </div>
        </section>

        {/* ── Pricing ──────────────────────────────────── */}
        <section className="section section-tight" id="pricing" aria-labelledby="pricing-title">
          <div className="container">
            <div className="section-head reveal">
              <p className="eyebrow">Pricing</p>
              <h2 className="h2" id="pricing-title">
                Pay for beds, not seats
              </h2>
              <p className="lead">Tenants never pay. Owners pay a simple per-bed price for each property they activate.</p>
            </div>
            <div className={site.contactEmail ? "grid-3" : "grid-2"} style={{ alignItems: "stretch", maxWidth: site.contactEmail ? undefined : 880, margin: "0 auto" }}>
              <div className="glass price-card reveal">
                <h3 className="h3">Tenants</h3>
                <div className="price">
                  ₹0 <small>always</small>
                </div>
                <p className="muted">Everything a resident needs, on the web and on mobile.</p>
                <ul className="ticks" style={{ marginTop: 0 }}>
                  {["Explore and join PGs", "Pay rent online, by UPI or cash", "Maintenance requests and pinboard", "Invitations and notifications"].map((t) => (
                    <li key={t}>
                      <Check size={18} aria-hidden /> {t}
                    </li>
                  ))}
                </ul>
                <Link href="/signup/?kind=tenant" className="btn btn-ghost btn-block" style={{ marginTop: "auto" }}>
                  Join as a tenant
                </Link>
              </div>
              <div className="glass price-card featured reveal">
                <div className="row-between">
                  <h3 className="h3">Owners</h3>
                  <span className="badge badge-green">Most popular</span>
                </div>
                <div className="price">
                  ₹30 <small>per bed / month</small>
                </div>
                <p className="muted">For each active property. A 20-bed PG costs ₹600 a month.</p>
                <ul className="ticks" style={{ marginTop: 0 }}>
                  {["Unlimited tenants and invoices", "Join requests, rent and maintenance", "Team roles with per-property access", "Reports, CSV export and a QR listing"].map((t) => (
                    <li key={t}>
                      <Check size={18} aria-hidden /> {t}
                    </li>
                  ))}
                </ul>
                <Link href="/signup/?kind=business" className="btn btn-primary btn-block" style={{ marginTop: "auto" }}>
                  Start as an owner
                </Link>
              </div>
              {site.contactEmail && (
                <div className="glass price-card reveal">
                  <h3 className="h3">Chains and co-living brands</h3>
                  <div className="price" style={{ fontSize: 34 }}>
                    Custom
                  </div>
                  <p className="muted">For 500+ beds across cities, with help moving your properties in.</p>
                  <a href={`mailto:${site.contactEmail}`} className="btn btn-ghost btn-block" style={{ marginTop: "auto" }}>
                    Email our team
                  </a>
                </div>
              )}
            </div>
          </div>
        </section>

        {/* ── FAQ ──────────────────────────────────────── */}
        <section className="section section-tight" id="faq" aria-labelledby="faq-title">
          <div className="container" style={{ maxWidth: 820 }}>
            <div className="section-head reveal">
              <p className="eyebrow">FAQ</p>
              <h2 className="h2" id="faq-title">
                Common questions
              </h2>
            </div>
            <div className="faq">
              {faqs.map((f) => (
                <details key={f.q} className="glass">
                  <summary>{f.q}</summary>
                  <p>{f.a}</p>
                </details>
              ))}
            </div>
          </div>
        </section>

        <section className="section section-tight" aria-labelledby="cta-title">
          <div className="container">
            <div className="cta-band reveal">
              <h2 className="h2" id="cta-title">
                Ready to run a calmer PG?
              </h2>
              <p className="lead" style={{ maxWidth: 560, margin: "16px auto 0" }}>
                Create your account in a minute. Sign in once and OneStay360 takes owners to their business and tenants to their stay.
              </p>
              <div className="hero-ctas">
                <Link href="/signup/?kind=business" className="btn btn-lg btn-light">
                  I own a PG <ArrowRight size={18} aria-hidden />
                </Link>
                <Link href="/signup/?kind=tenant" className="btn btn-lg btn-outline">
                  I&apos;m looking for a PG
                </Link>
              </div>
            </div>
          </div>
        </section>
      </main>
      <SiteFooter />
    </>
  );
}

