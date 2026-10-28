"use client";
// /features/business and /features/tenant: every feature with why it
// matters, a use case, what's included and a link into the live demo.
import Link from "next/link";
import { ArrowRight, CheckCircle2, Lightbulb, PlayCircle, Quote } from "lucide-react";
import { OwnerPhonePreview, SiteFooter, SiteNav, TenantPhonePreview } from "./site";
import { useReveal } from "./ui";
import { businessFeatures, tenantFeatures } from "@/lib/content";

export function FeaturePage({ kind }: { kind: "business" | "tenant" }) {
  useReveal();
  const features = kind === "business" ? businessFeatures : tenantFeatures;
  const demo = kind === "business" ? "owner" : "tenant";
  return (
    <>
      <SiteNav />
      <main>
        <section className="hero" style={{ paddingBottom: 24 }}>
          <div className="container split" style={{ textAlign: "left" }}>
            <div>
              <span className="eyebrow">{kind === "business" ? "OneStay360 Business" : "OneStay360 Tenant"}</span>
              <h1 className="h1" style={{ marginTop: 12, fontSize: "clamp(34px, 5vw, 56px)" }}>
                {kind === "business" ? (
                  <>
                    Every tool to <span className="gradient-text">run your PG</span>
                  </>
                ) : (
                  <>
                    A better way to <span className="gradient-text">live in a PG</span>
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
                  Get started <ArrowRight size={18} />
                </Link>
                <Link href={`/signin/?demo=${demo}`} className="btn btn-ghost btn-lg">
                  <PlayCircle size={18} /> Live demo
                </Link>
              </div>
              <nav className="chips" style={{ marginTop: 28 }} aria-label="Features on this page">
                {features.map((f) => (
                  <a key={f.id} href={`#${f.id}`} className="chip">
                    {f.title}
                  </a>
                ))}
              </nav>
            </div>
            <div>{kind === "business" ? <OwnerPhonePreview /> : <TenantPhonePreview />}</div>
          </div>
        </section>

        <section className="section" style={{ paddingTop: 40 }}>
          <div className="container stack-lg">
            {features.map((f, i) => {
              const Icon = f.icon;
              return (
                <article key={f.id} id={f.id} className="glass reveal" style={{ padding: "clamp(22px, 4vw, 40px)", scrollMarginTop: 96 }}>
                  <div className="split" style={{ alignItems: "start", gap: 32 }}>
                    <div>
                      <div className="row" style={{ gap: 14 }}>
                        <span className="feature-ic">
                          <Icon size={22} />
                        </span>
                        <span className="faint" style={{ fontWeight: 700, fontSize: 13 }}>
                          {String(i + 1).padStart(2, "0")} / {String(features.length).padStart(2, "0")}
                        </span>
                      </div>
                      <h2 className="h2" style={{ fontSize: "clamp(24px, 3vw, 32px)", marginTop: 16 }}>
                        {f.title}
                      </h2>
                      <p className="lead" style={{ marginTop: 10, fontSize: 17 }}>
                        {f.summary}
                      </p>
                      <ul className="ticks">
                        {f.points.map((p) => (
                          <li key={p}>
                            <CheckCircle2 size={20} /> {p}
                          </li>
                        ))}
                      </ul>
                    </div>
                    <div className="stack">
                      <div className="alert alert-green" style={{ padding: 18, borderRadius: 18 }}>
                        <div className="row" style={{ fontWeight: 700, marginBottom: 6 }}>
                          <Lightbulb size={18} /> Why it matters
                        </div>
                        <p style={{ color: "var(--ink)" }}>{f.why}</p>
                      </div>
                      <div className="alert alert-blue" style={{ padding: 18, borderRadius: 18 }}>
                        <div className="row" style={{ fontWeight: 700, marginBottom: 6 }}>
                          <Quote size={18} /> Use case
                        </div>
                        <p style={{ color: "var(--ink)" }}>{f.useCase}</p>
                      </div>
                      <Link href={`/signin/?demo=${demo}&next=${encodeURIComponent(f.href)}`} className="btn btn-ghost" style={{ alignSelf: "flex-start" }}>
                        <PlayCircle size={16} /> Try it in the demo
                      </Link>
                    </div>
                  </div>
                </article>
              );
            })}
          </div>
        </section>

        <section className="section" style={{ paddingTop: 0 }}>
          <div className="container">
            <div className="cta-band">
              <h2 className="h2">{kind === "business" ? "Bring your first property online today" : "Find your next home"}</h2>
              <div className="hero-ctas">
                <Link href={`/signup/?kind=${kind}`} className="btn btn-lg" style={{ background: "#fff", color: "#0a6c58" }}>
                  Create account <ArrowRight size={18} />
                </Link>
                <Link href={kind === "business" ? "/features/tenant/" : "/features/business/"} className="btn btn-ghost btn-lg">
                  {kind === "business" ? "See the tenant app" : "Are you an owner?"}
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
