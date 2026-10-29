"use client";
import Link from "next/link";
import { useState } from "react";
import {
  ArrowRight,
  BedDouble,
  Briefcase,
  Building,
  Building2,
  Check,
  CheckCircle2,
  GraduationCap,
  PlayCircle,
  Sparkles,
  UserCog,
  Users,
  Wallet,
  Wrench,
} from "lucide-react";
import { DashboardPreview, OwnerPhonePreview, SiteFooter, SiteNav, TenantPhonePreview } from "@/components/site";
import { useReveal } from "@/components/ui";
import { businessFeatures, faqs, flows, tenantFeatures, trust, type Feature } from "@/lib/content";

function FeatureCard({ f }: { f: Feature }) {
  const Icon = f.icon;
  return (
    <article className="glass feature-card reveal">
      <span className="feature-ic">
        <Icon size={22} />
      </span>
      <h3 className="h3">{f.title}</h3>
      <p>{f.summary}</p>
      <p style={{ fontSize: 13.5 }}>
        <b style={{ color: "var(--ink)" }}>Why it matters: </b>
        {f.why}
      </p>
      <div className="usecase">
        <b>Use case: </b>
        {f.useCase}
      </div>
    </article>
  );
}

const personas = [
  { icon: Building, title: "Single-PG owners", body: "Replace the notebook and WhatsApp reminders. See every bed, collect rent on time and answer requests from your phone or laptop.", points: ["Bed map", "Auto invoices", "UPI & cash verification"] },
  { icon: Building2, title: "Multi-property operators", body: "One dashboard across PGs and cities, with managers who only see what they run and reports that compare properties.", points: ["Per-property access", "Reports & CSV", "Per-bed billing"] },
  { icon: UserCog, title: "Managers & staff", body: "Handle join requests, verify payments and close maintenance tickets for the properties you're assigned — nothing more.", points: ["Role-based screens", "Needs-attention queue", "Activity log"] },
  { icon: GraduationCap, title: "Students & professionals", body: "Find a verified PG, see real prices and rules, join in a few taps and pay rent with proof of every payment.", points: ["Explore by city", "Track your request", "Pay online or UPI"] },
];

export default function LandingPage() {
  const [tab, setTab] = useState<"business" | "tenant">("business");
  useReveal();
  const list = tab === "business" ? businessFeatures : tenantFeatures;

  return (
    <>
      <SiteNav />
      <main>
        {/* ── Hero ───────────────────────────────────────── */}
        <section className="hero">
          <div className="container">
            <Link href="/signin/?demo=owner" className="pill glass">
              <span className="badge badge-green">
                <Sparkles size={12} /> New
              </span>
              Owner &amp; tenant dashboards are now on the web <ArrowRight size={14} />
            </Link>
            <h1 className="h1">
              Run your PG on <span className="gradient-text">autopilot</span>.
              <br />
              Give tenants an app they&apos;ll love.
            </h1>
            <p className="lead">
              OneStay360 connects PG owners, their teams and their tenants: rooms and beds, onboarding, rent by UPI, cash or online, maintenance and reports — in one place.
            </p>
            <div className="hero-ctas">
              <Link href="/signup/" className="btn btn-primary btn-lg">
                Start for free <ArrowRight size={18} />
              </Link>
              <Link href="/signin/?demo=owner" className="btn btn-ghost btn-lg">
                <PlayCircle size={18} /> Try the live demo
              </Link>
            </div>
            <p className="faint" style={{ fontSize: 13, marginTop: 14 }}>
              Free for tenants · Owners pay per active bed · No setup fee
            </p>

            <div className="hero-stage">
              <div className="hero-frame glass">
                <DashboardPreview />
              </div>
              <div className="float-card glass" style={{ left: -18, top: 90 }}>
                <span className="ic" style={{ background: "var(--tint-green)", color: "var(--brand)" }}>
                  <Wallet size={18} />
                </span>
                <div>
                  <b>₹14,000 received</b>
                  <small>Rahul · paid online · just now</small>
                </div>
              </div>
              <div className="float-card glass" style={{ right: -14, top: 230, animationDelay: "-3s" }}>
                <span className="ic" style={{ background: "var(--tint-amber)", color: "var(--tint-amber-ink)" }}>
                  <Wrench size={18} />
                </span>
                <div>
                  <b>AC fixed · Room 103</b>
                  <small>Marked resolved by Vikram</small>
                </div>
              </div>
              <div className="float-card glass" style={{ left: 40, bottom: -24, animationDelay: "-1.5s" }}>
                <span className="ic" style={{ background: "var(--tint-blue)", color: "var(--tint-blue-ink)" }}>
                  <BedDouble size={18} />
                </span>
                <div>
                  <b>Bed 202-B confirmed</b>
                  <small>Priya moves in Monday</small>
                </div>
              </div>
            </div>

            <div className="stats-strip glass">
              <div>
                <b className="gradient-text">2 apps</b>
                <span>Business &amp; Tenant, one platform</span>
              </div>
              <div>
                <b className="gradient-text">3 ways</b>
                <span>to collect rent: online, UPI, cash</span>
              </div>
              <div>
                <b className="gradient-text">Bed-level</b>
                <span>occupancy across every property</span>
              </div>
              <div>
                <b className="gradient-text">₹30</b>
                <span>per bed per month for owners</span>
              </div>
            </div>
          </div>
        </section>

        {/* ── Features ───────────────────────────────────── */}
        <section className="section" id="features">
          <div className="container">
            <div className="section-head reveal">
              <span className="eyebrow">Everything in one platform</span>
              <h2 className="h2" style={{ marginTop: 10 }}>
                Two apps. Every step of a stay.
              </h2>
              <p className="lead">The Business app runs your PG; the Tenant app gives residents a home for rent, requests and community. Here&apos;s what each feature does, why it matters and how it&apos;s used.</p>
              <div className="tabs glass" role="tablist" style={{ marginTop: 26 }}>
                <button role="tab" aria-selected={tab === "business"} onClick={() => setTab("business")}>
                  <Briefcase size={16} /> Business app
                </button>
                <button role="tab" aria-selected={tab === "tenant"} onClick={() => setTab("tenant")}>
                  <Users size={16} /> Tenant app
                </button>
              </div>
            </div>
            <div className="grid-3" key={tab}>
              {list.map((f) => (
                <FeatureCard key={f.id} f={f} />
              ))}
            </div>
            <div style={{ textAlign: "center", marginTop: 32 }}>
              <Link href={tab === "business" ? "/features/business/" : "/features/tenant/"} className="btn btn-ghost">
                Explore every {tab === "business" ? "owner" : "tenant"} feature in depth <ArrowRight size={16} />
              </Link>
            </div>
          </div>
        </section>

        {/* ── App spotlights ─────────────────────────────── */}
        <section className="section" style={{ paddingTop: 0 }}>
          <div className="container stack-lg" style={{ gap: 88 }}>
            <div className="split">
              <div className="reveal">
                <span className="eyebrow">For owners &amp; teams</span>
                <h2 className="h2" style={{ marginTop: 10 }}>
                  From join request to confirmed bed in minutes
                </h2>
                <p className="lead" style={{ marginTop: 14 }}>
                  A tenant finds you on Explore or scans your gate QR. You pick a free bed, send an itemised first bill, and the moment their payment is confirmed they become a tenant, the bed turns occupied and their first invoice is ready.
                </p>
                <ul className="ticks">
                  {["Beds are held while a request is in progress — no double-booking", "UPI, bank transfer or cash for the first bill", "Reject a payment with a reason; the tenant resubmits", "Managers do it all for the properties you assign"].map((t) => (
                    <li key={t}>
                      <CheckCircle2 size={20} /> {t}
                    </li>
                  ))}
                </ul>
                <Link href="/features/business/" className="btn btn-primary" style={{ marginTop: 24 }}>
                  See the Business app <ArrowRight size={16} />
                </Link>
              </div>
              <div className="reveal">
                <OwnerPhonePreview />
              </div>
            </div>
            <div className="split reverse">
              <div className="reveal">
                <span className="eyebrow">For tenants</span>
                <h2 className="h2" style={{ marginTop: 10 }}>
                  Your stay, your rent, your requests — sorted
                </h2>
                <p className="lead" style={{ marginTop: 14 }}>
                  Find a verified PG, join with a few taps and keep everything about your stay in one place: rent with receipts, maintenance with status updates, and a pinboard to meet the people you live with.
                </p>
                <ul className="ticks">
                  {["Pay online, or report UPI and cash with proof", "Track maintenance from open to resolved", "Accept an owner's invitation with all terms in writing", "Pinboard notes for food runs, rides and lost & found"].map((t) => (
                    <li key={t}>
                      <CheckCircle2 size={20} /> {t}
                    </li>
                  ))}
                </ul>
                <Link href="/features/tenant/" className="btn btn-primary" style={{ marginTop: 24 }}>
                  See the Tenant app <ArrowRight size={16} />
                </Link>
              </div>
              <div className="reveal">
                <TenantPhonePreview />
              </div>
            </div>
          </div>
        </section>

        {/* ── How it works ───────────────────────────────── */}
        <section className="section" id="how">
          <div className="container">
            <div className="section-head reveal">
              <span className="eyebrow">How it works</span>
              <h2 className="h2" style={{ marginTop: 10 }}>
                The whole tenant lifecycle, connected
              </h2>
              <p className="lead">Every action on one side updates the other: owners and tenants always see the same truth.</p>
            </div>
            <div className="steps">
              {flows.map((f) => {
                const Icon = f.icon;
                return (
                  <div key={f.title} className="glass step reveal">
                    <span className="feature-ic" style={{ marginBottom: 14 }}>
                      <Icon size={22} />
                    </span>
                    <h3 className="h3" style={{ fontSize: 17 }}>
                      {f.title}
                    </h3>
                    <p className="muted" style={{ fontSize: 14.5, marginTop: 8 }}>
                      {f.body}
                    </p>
                  </div>
                );
              })}
            </div>
          </div>
        </section>

        {/* ── Use cases ──────────────────────────────────── */}
        <section className="section" id="use-cases" style={{ paddingTop: 0 }}>
          <div className="container">
            <div className="section-head reveal">
              <span className="eyebrow">Who it&apos;s for</span>
              <h2 className="h2" style={{ marginTop: 10 }}>
                Built for everyone under the roof
              </h2>
            </div>
            <div className="grid-4">
              {personas.map((p) => {
                const Icon = p.icon;
                return (
                  <div key={p.title} className="glass feature-card reveal">
                    <span className="feature-ic">
                      <Icon size={22} />
                    </span>
                    <h3 className="h3" style={{ fontSize: 18 }}>
                      {p.title}
                    </h3>
                    <p>{p.body}</p>
                    <div className="chips" style={{ marginTop: "auto" }}>
                      {p.points.map((x) => (
                        <span key={x} className="badge badge-green">
                          {x}
                        </span>
                      ))}
                    </div>
                  </div>
                );
              })}
            </div>
            <div className="grid-3" style={{ marginTop: 16 }}>
              {trust.map((t) => {
                const Icon = t.icon;
                return (
                  <div key={t.title} className="glass card row reveal" style={{ alignItems: "flex-start", gap: 14 }}>
                    <span className="tile-ic">
                      <Icon size={20} />
                    </span>
                    <div>
                      <b>{t.title}</b>
                      <p className="muted" style={{ fontSize: 14, marginTop: 4 }}>
                        {t.body}
                      </p>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </section>

        {/* ── Pricing ────────────────────────────────────── */}
        <section className="section" id="pricing">
          <div className="container">
            <div className="section-head reveal">
              <span className="eyebrow">Pricing</span>
              <h2 className="h2" style={{ marginTop: 10 }}>
                Pay for beds, not seats
              </h2>
              <p className="lead">Tenants are always free. Owners pay a simple per-bed price for each property they activate.</p>
            </div>
            <div className="grid-3" style={{ alignItems: "stretch" }}>
              <div className="glass price-card reveal">
                <span className="eyebrow">Tenants</span>
                <div className="price">
                  ₹0 <small>forever</small>
                </div>
                <p className="muted">Everything a resident needs, on web and mobile.</p>
                <ul className="ticks" style={{ marginTop: 0 }}>
                  {["Explore & join PGs", "Pay rent online, UPI or cash", "Maintenance & pinboard", "Invitations & notifications"].map((t) => (
                    <li key={t}>
                      <Check size={18} /> {t}
                    </li>
                  ))}
                </ul>
                <Link href="/signup/?kind=tenant" className="btn btn-ghost btn-block" style={{ marginTop: "auto" }}>
                  Join as a tenant
                </Link>
              </div>
              <div className="glass price-card featured reveal">
                <span className="badge badge-green" style={{ position: "absolute", top: 18, right: 18 }}>
                  Most popular
                </span>
                <span className="eyebrow">Owners</span>
                <div className="price">
                  ₹30 <small>/ bed / month</small>
                </div>
                <p className="muted">Per active property. A 20-bed PG is ₹600 a month.</p>
                <ul className="ticks" style={{ marginTop: 0 }}>
                  {["Unlimited tenants & invoices", "Requests, rent and maintenance", "Team roles & per-property access", "Reports, CSV export, QR listing"].map((t) => (
                    <li key={t}>
                      <Check size={18} /> {t}
                    </li>
                  ))}
                </ul>
                <Link href="/signup/?kind=business" className="btn btn-primary btn-block" style={{ marginTop: "auto" }}>
                  Start as an owner
                </Link>
              </div>
              <div className="glass price-card reveal">
                <span className="eyebrow">Chains &amp; co-living</span>
                <div className="price" style={{ fontSize: 36 }}>
                  Let&apos;s talk
                </div>
                <p className="muted">For 500+ beds across cities, with onboarding help.</p>
                <ul className="ticks" style={{ marginTop: 0 }}>
                  {["Volume per-bed pricing", "Bulk property onboarding", "Priority support", "Promo codes for launches"].map((t) => (
                    <li key={t}>
                      <Check size={18} /> {t}
                    </li>
                  ))}
                </ul>
                <a href="mailto:support@onestay360.in" className="btn btn-ghost btn-block" style={{ marginTop: "auto" }}>
                  Contact us
                </a>
              </div>
            </div>
          </div>
        </section>

        {/* ── FAQ ────────────────────────────────────────── */}
        <section className="section" id="faq" style={{ paddingTop: 0 }}>
          <div className="container" style={{ maxWidth: 820 }}>
            <div className="section-head reveal">
              <span className="eyebrow">FAQ</span>
              <h2 className="h2" style={{ marginTop: 10 }}>
                Questions, answered
              </h2>
            </div>
            <div className="faq">
              {faqs.map((f) => (
                <details key={f.q} className="glass reveal">
                  <summary>{f.q}</summary>
                  <p>{f.a}</p>
                </details>
              ))}
            </div>
          </div>
        </section>

        {/* ── CTA ────────────────────────────────────────── */}
        <section className="section" style={{ paddingTop: 0 }}>
          <div className="container">
            <div className="cta-band reveal">
              <h2 className="h2">Ready to run a calmer PG?</h2>
              <p className="lead" style={{ maxWidth: 560, margin: "14px auto 0" }}>
                Create your account in a minute, or walk through a fully loaded demo workspace as an owner or a tenant.
              </p>
              <div className="hero-ctas">
                <Link href="/signup/" className="btn btn-lg" style={{ background: "#fff", color: "#0a6c58" }}>
                  Create free account <ArrowRight size={18} />
                </Link>
                <Link href="/signin/?demo=tenant" className="btn btn-ghost btn-lg">
                  Try the tenant demo
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
