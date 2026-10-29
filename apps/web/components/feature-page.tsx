"use client";
// /features/business and /features/tenant: every feature with why it
// matters, a use case, what's included and a link into the live demo.
import Link from "next/link";
import { ArrowRight, CheckCircle2, Lightbulb, Quote } from "lucide-react";
import { SiteFooter, SiteNav } from "./site";
import { BrowserFrame, PhoneFrame } from "./shots";
import { useReveal } from "./ui";
import { businessFeatures, tenantFeatures } from "@/lib/content";

export function FeaturePage({ kind }: { kind: "business" | "tenant" }) {
  useReveal();
  const features = kind === "business" ? businessFeatures : tenantFeatures;
  return (
    <>
      <SiteNav />
      <main id="main">
        <section className="hero" style={{ paddingBottom: 16 }}>
          <div className="container split" style={{ textAlign: "left" }}>
            <div>
              <p className="eyebrow">{kind === "business" ? "OneStay360 Business app" : "OneStay360 Tenant app"}</p>
              <h1 className="h1" style={{ marginTop: 12, fontSize: "clamp(34px, 4.6vw, 54px)" }}>
                {kind === "business" ? (
                  <>
                    Every tool to <span className="accent">run your PG</span>
                  </>
                ) : (
                  <>
                    A better way to <span className="accent">live in a PG</span>
                  </>
                )}
              </h1>
              <p className="lead" style={{ marginTop: 18 }}>
                {kind === "business"
                  ? "Properties and beds, onboarding, join requests, rent, maintenance, team, reports and billing. Available as the Business mobile app and in this web dashboard."
                  : "Find a verified PG, join it, pay rent with proof, raise maintenance and meet your housemates. Free, on the Tenant mobile app and on the web."}
              </p>
              <div className="hero-ctas" style={{ justifyContent: "flex-start" }}>
                <Link href={`/signup/?kind=${kind}`} className="btn btn-primary btn-lg">
                  {kind === "business" ? "Start as an owner" : "Join as a tenant"} <ArrowRight size={18} aria-hidden />
                </Link>
                <Link href="/#journey" className="btn btn-ghost btn-lg">
                  See how it works
                </Link>
              </div>
              <nav className="chips" style={{ marginTop: 32 }} aria-label="Jump to a feature">
                {features.map((f) => (
                  <a key={f.id} href={`#${f.id}`} className="chip">
                    {f.title}
                  </a>
                ))}
              </nav>
            </div>
            <div style={{ display: "flex", justifyContent: "center" }}>
              {kind === "business" ? (
                <BrowserFrame name="owner-layout" url="onestay360 · Sunrise Residency" eager alt="Owner floor plan of Sunrise Residency with each bed marked free, held or occupied, and tenant names." />
              ) : (
                <PhoneFrame name="tenant-home" eager alt="Tenant app home on a phone: Room 101, Bed A at Sunrise Residency with rent all paid." />
              )}
            </div>
          </div>
        </section>

        <section className="section" style={{ paddingTop: 48 }} aria-label="Features">
          <div className="container stack-lg" style={{ gap: 32 }}>
            {features.map((f, i) => {
              const Icon = f.icon;
              return (
                <article key={f.id} id={f.id} className="glass reveal" style={{ padding: "clamp(24px, 4vw, 48px)", scrollMarginTop: 104 }}>
                  <div className="split" style={{ alignItems: "start", gap: 32 }}>
                    <div>
                      <div className="row" style={{ gap: 14 }}>
                        <span className="feature-ic" aria-hidden>
                          <Icon size={22} />
                        </span>
                        <span className="muted" style={{ fontWeight: 600, fontSize: 14 }}>
                          Feature {i + 1} of {features.length}
                        </span>
                      </div>
                      <h2 className="h2" style={{ fontSize: "clamp(24px, 2.8vw, 30px)", marginTop: 16 }}>
                        {f.title}
                      </h2>
                      <p className="lead" style={{ marginTop: 12, fontSize: 17 }}>
                        {f.summary}
                      </p>
                      <ul className="ticks">
                        {f.points.map((p) => (
                          <li key={p}>
                            <CheckCircle2 size={20} aria-hidden /> {p}
                          </li>
                        ))}
                      </ul>
                    </div>
                    <div className="stack">
                      <div style={{ padding: 20, borderRadius: 16, background: "var(--tint-green)" }}>
                        <h3 className="row" style={{ fontWeight: 700, fontSize: 16, marginBottom: 8, color: "var(--tint-green-ink)" }}>
                          <Lightbulb size={18} aria-hidden /> Why it matters
                        </h3>
                        <p>{f.why}</p>
                      </div>
                      <div style={{ padding: 20, borderRadius: 16, background: "var(--tint-blue)" }}>
                        <h3 className="row" style={{ fontWeight: 700, fontSize: 16, marginBottom: 8, color: "var(--tint-blue-ink)" }}>
                          <Quote size={18} aria-hidden /> Example
                        </h3>
                        <p>{f.useCase}</p>
                      </div>
                    </div>
                  </div>
                </article>
              );
            })}
          </div>
        </section>

        <section className="section section-tight">
          <div className="container">
            <div className="cta-band">
              <h2 className="h2">{kind === "business" ? "Bring your first property online today" : "Find your next home"}</h2>
              <div className="hero-ctas">
                <Link href={`/signup/?kind=${kind}`} className="btn btn-lg btn-light">
                  Create a free account <ArrowRight size={18} aria-hidden />
                </Link>
                <Link href={kind === "business" ? "/features/tenant/" : "/features/business/"} className="btn btn-outline btn-lg">
                  {kind === "business" ? "See the Tenant app" : "Run a PG? See the Business app"}
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
