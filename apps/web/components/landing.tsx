"use client";
import Link from "next/link";
import { useState } from "react";
import { ArrowRight, Briefcase, Building, Building2, Check, CheckCircle2, GraduationCap, PlayCircle, UserCog, Users } from "lucide-react";
import { DashboardPreview, OwnerPhonePreview, SiteFooter, SiteNav, TenantPhonePreview } from "./site";
import { useReveal } from "./ui";
import { businessFeatures, faqs, flows, tenantFeatures, trust, type Feature } from "@/lib/content";
import { site } from "@/lib/site";

function FeatureCard({ f, kind }: { f: Feature; kind: "business" | "tenant" }) {
  const Icon = f.icon;
  return (
    <article className="glass feature-card reveal">
      <span className="feature-ic" aria-hidden>
        <Icon size={22} />
      </span>
      <h3 className="h3">{f.title}</h3>
      <p>{f.summary}</p>
      <p className="usecase">
        <b>Example: </b>
        {f.useCase}
      </p>
      <Link href={`/features/${kind}/#${f.id}`} className="text-link" style={{ fontSize: 15 }}>
        Read more about {f.title.toLowerCase()}
      </Link>
    </article>
  );
}

const personas = [
  { icon: Building, title: "Single-PG owners", body: "Replace the notebook and WhatsApp reminders. See every bed, collect rent on time and answer requests from your phone or laptop." },
  { icon: Building2, title: "Multi-property operators", body: "One dashboard across PGs and cities, managers who only see what they run, and reports that compare properties." },
  { icon: UserCog, title: "Managers and staff", body: "Handle join requests, verify payments and close maintenance tickets for the properties you're assigned — nothing more." },
  { icon: GraduationCap, title: "Students and professionals", body: "Find a verified PG, see real prices and rules, join in a few taps and keep proof of every rent payment." },
];

export function Landing() {
  const [tab, setTab] = useState<"business" | "tenant">("business");
  useReveal();
  const list = tab === "business" ? businessFeatures : tenantFeatures;

  return (
    <>
      <SiteNav />
      <main id="main">
        <section className="hero" aria-labelledby="hero-title">
          <div className="container">
            <Link href="/signin/?demo=owner" className="pill glass">
              <span className="badge badge-green">New</span>
              Owner and tenant dashboards are now on the web <ArrowRight size={15} aria-hidden />
            </Link>
            <h1 className="h1" id="hero-title">
              PG management that runs itself,
              <br className="hide-sm" /> <span className="accent">and an app your tenants will like</span>
            </h1>
            <p className="lead">
              OneStay360 connects PG owners, their teams and their tenants. Track rooms and beds, onboard tenants, collect rent by UPI, cash or online, and handle maintenance — in one place.
            </p>
            <div className="hero-ctas">
              <Link href="/signup/" className="btn btn-primary btn-lg">
                Create a free account <ArrowRight size={18} aria-hidden />
              </Link>
              <Link href="/signin/?demo=owner" className="btn btn-ghost btn-lg">
                <PlayCircle size={18} aria-hidden /> Try the owner demo
              </Link>
            </div>
            <p className="faint small" style={{ marginTop: 16 }}>
              Free for tenants. Owners pay per bed, per active property. No setup fee.
            </p>

            <div className="hero-stage">
              <div className="hero-frame glass">
                <DashboardPreview />
              </div>
            </div>

            <div className="facts" role="list" aria-label="OneStay360 at a glance">
              <div role="listitem">
                <b>2 apps</b>
                <span>Business and Tenant, one platform</span>
              </div>
              <div role="listitem">
                <b>3 ways</b>
                <span>to collect rent: online, UPI, cash</span>
              </div>
              <div role="listitem">
                <b>Every bed</b>
                <span>tracked across all your properties</span>
              </div>
              <div role="listitem">
                <b>₹30</b>
                <span>per bed per month for owners</span>
              </div>
            </div>
          </div>
        </section>

        <section className="section" id="features" aria-labelledby="features-title">
          <div className="container">
            <div className="section-head reveal">
              <p className="eyebrow">Features</p>
              <h2 className="h2" id="features-title">
                Two apps for every step of a stay
              </h2>
              <p className="lead">The Business app runs your PG. The Tenant app gives residents one place for rent, requests and their housemates. Pick an app to see what it does.</p>
              <div className="tabs" role="tablist" aria-label="Choose an app" style={{ marginTop: 28 }}>
                <button role="tab" aria-selected={tab === "business"} onClick={() => setTab("business")}>
                  <Briefcase size={17} aria-hidden /> Business app
                </button>
                <button role="tab" aria-selected={tab === "tenant"} onClick={() => setTab("tenant")}>
                  <Users size={17} aria-hidden /> Tenant app
                </button>
              </div>
            </div>
            <div className="grid-3" key={tab} role="tabpanel">
              {list.map((f) => (
                <FeatureCard key={f.id} f={f} kind={tab} />
              ))}
            </div>
            <div style={{ textAlign: "center", marginTop: 40 }}>
              <Link href={tab === "business" ? "/features/business/" : "/features/tenant/"} className="btn btn-ghost">
                See every {tab === "business" ? "owner" : "tenant"} feature in detail <ArrowRight size={16} aria-hidden />
              </Link>
            </div>
          </div>
        </section>

        <section className="section section-tight" aria-label="App highlights">
          <div className="container" style={{ display: "flex", flexDirection: "column", gap: 96 }}>
            <div className="split">
              <div className="reveal">
                <p className="eyebrow">For owners and teams</p>
                <h2 className="h2" style={{ marginTop: 12 }}>
                  From join request to confirmed bed in minutes
                </h2>
                <p className="lead" style={{ marginTop: 16 }}>
                  A tenant finds you on Explore or scans the QR code at your gate. You pick a free bed and send an itemised first bill. When their payment is confirmed, they become a tenant, the bed is marked occupied and their first invoice is ready.
                </p>
                <ul className="ticks">
                  {["Beds are held while a request is open, so nothing is double-booked", "First bills by UPI, bank transfer or cash", "Reject a payment with a reason; the tenant pays again", "Managers handle it all for the properties you assign"].map((t) => (
                    <li key={t}>
                      <CheckCircle2 size={20} aria-hidden /> {t}
                    </li>
                  ))}
                </ul>
                <Link href="/features/business/" className="btn btn-primary" style={{ marginTop: 32 }}>
                  Explore the Business app <ArrowRight size={16} aria-hidden />
                </Link>
              </div>
              <div className="reveal">
                <OwnerPhonePreview />
              </div>
            </div>
            <div className="split reverse">
              <div className="reveal">
                <p className="eyebrow">For tenants</p>
                <h2 className="h2" style={{ marginTop: 12 }}>
                  Your stay, rent and requests in one place
                </h2>
                <p className="lead" style={{ marginTop: 16 }}>
                  Find a verified PG and join in a few taps. Then keep everything about your stay together: rent with receipts, maintenance with status updates, and a pinboard to meet the people you live with.
                </p>
                <ul className="ticks">
                  {["Pay online, or report UPI and cash with proof", "Follow maintenance from open to resolved", "Accept an owner's invitation with all terms in writing", "Pinboard notes for food runs, rides and lost & found"].map((t) => (
                    <li key={t}>
                      <CheckCircle2 size={20} aria-hidden /> {t}
                    </li>
                  ))}
                </ul>
                <Link href="/features/tenant/" className="btn btn-primary" style={{ marginTop: 32 }}>
                  Explore the Tenant app <ArrowRight size={16} aria-hidden />
                </Link>
              </div>
              <div className="reveal">
                <TenantPhonePreview />
              </div>
            </div>
          </div>
        </section>

        <section className="section" id="how" aria-labelledby="how-title">
          <div className="container">
            <div className="section-head reveal">
              <p className="eyebrow">How it works</p>
              <h2 className="h2" id="how-title">
                The whole tenant lifecycle, connected
              </h2>
              <p className="lead">Every action on one side updates the other, so owners and tenants always see the same information.</p>
            </div>
            <ol className="steps" style={{ listStyle: "none" }}>
              {flows.map((f, i) => {
                const Icon = f.icon;
                return (
                  <li key={f.title} className="glass step reveal">
                    <span className="feature-ic" aria-hidden>
                      <Icon size={22} />
                    </span>
                    <span className="step-num">Step {i + 1}</span>
                    <h3 className="h3" style={{ fontSize: 18 }}>
                      {f.title}
                    </h3>
                    <p className="muted">{f.body}</p>
                  </li>
                );
              })}
            </ol>
          </div>
        </section>

        <section className="section section-tight" id="use-cases" aria-labelledby="who-title">
          <div className="container">
            <div className="section-head reveal">
              <p className="eyebrow">Who it&apos;s for</p>
              <h2 className="h2" id="who-title">
                Built for everyone under the roof
              </h2>
            </div>
            <div className="grid-4">
              {personas.map((p) => {
                const Icon = p.icon;
                return (
                  <div key={p.title} className="glass feature-card reveal">
                    <span className="feature-ic" aria-hidden>
                      <Icon size={22} />
                    </span>
                    <h3 className="h3" style={{ fontSize: 18 }}>
                      {p.title}
                    </h3>
                    <p>{p.body}</p>
                  </div>
                );
              })}
            </div>
            <div className="grid-3" style={{ marginTop: 64 }}>
              {trust.map((t) => {
                const Icon = t.icon;
                return (
                  <div key={t.title} className="row reveal" style={{ alignItems: "flex-start", gap: 16 }}>
                    <span className="tile-ic" aria-hidden>
                      <Icon size={20} />
                    </span>
                    <div>
                      <h3 style={{ fontSize: 17, fontWeight: 700 }}>{t.title}</h3>
                      <p className="muted" style={{ marginTop: 4 }}>
                        {t.body}
                      </p>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </section>

        <section className="section" id="pricing" aria-labelledby="pricing-title">
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
                  <ul className="ticks" style={{ marginTop: 0 }}>
                    {["Volume per-bed pricing", "Bulk property onboarding", "Priority support"].map((t) => (
                      <li key={t}>
                        <Check size={18} aria-hidden /> {t}
                      </li>
                    ))}
                  </ul>
                  <a href={`mailto:${site.contactEmail}`} className="btn btn-ghost btn-block" style={{ marginTop: "auto" }}>
                    Email our team
                  </a>
                </div>
              )}
            </div>
          </div>
        </section>

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
                Create your account in a minute, or walk through a fully loaded demo as an owner or a tenant.
              </p>
              <div className="hero-ctas">
                <Link href="/signup/" className="btn btn-lg btn-light">
                  Create a free account <ArrowRight size={18} aria-hidden />
                </Link>
                <Link href="/signin/?demo=tenant" className="btn btn-lg btn-outline">
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
