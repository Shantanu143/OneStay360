"use client";
// Marketing chrome: nav, footer, and the product previews used as pictures.
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { ArrowRight, BedDouble, Bell, CheckCircle2, Home, Menu, Wallet, Wrench, X } from "lucide-react";
import { Brand, ThemeToggle } from "./ui";
import { useAccount } from "@/lib/hooks";
import { site } from "@/lib/site";

const links = [
  { href: "/#features", label: "Features" },
  { href: "/features/business/", label: "For owners" },
  { href: "/features/tenant/", label: "For tenants" },
  { href: "/#how", label: "How it works" },
  { href: "/#pricing", label: "Pricing" },
  { href: "/#faq", label: "FAQ" },
];

export function SiteNav() {
  const [open, setOpen] = useState(false);
  const { account } = useAccount();
  const pathname = usePathname();
  useEffect(() => {
    const close = () => setOpen(false);
    window.addEventListener("hashchange", close);
    return () => window.removeEventListener("hashchange", close);
  }, []);
  const current = (href: string) => (!href.includes("#") && pathname.startsWith(href.slice(0, -1)) ? "page" : undefined);
  return (
    <header className="nav-wrap">
      <div className="container">
        <nav className="nav glass" aria-label="Main">
          <Brand />
          <div className="nav-links">
            {links.map((l) => (
              <Link key={l.href} href={l.href} aria-current={current(l.href)} style={current(l.href) ? { color: "var(--ink)", fontWeight: 650 } : undefined}>
                {l.label}
              </Link>
            ))}
          </div>
          <div className="nav-actions">
            <span className="hide-xs">
              <ThemeToggle />
            </span>
            {account ? (
              <Link href="/dashboard/" className="btn btn-primary btn-sm">
                Open dashboard <ArrowRight size={16} aria-hidden />
              </Link>
            ) : (
              <>
                <Link href="/signin/" className="btn btn-ghost btn-sm hide-md">
                  Sign in
                </Link>
                <Link href="/signup/" className="btn btn-primary btn-sm">
                  Get started
                </Link>
              </>
            )}
            <button className="icon-btn nav-burger" onClick={() => setOpen((o) => !o)} aria-label={open ? "Close menu" : "Open menu"} aria-expanded={open} aria-controls="mobile-menu">
              {open ? <X size={20} /> : <Menu size={20} />}
            </button>
          </div>
        </nav>
        <nav id="mobile-menu" className={`mobile-menu glass ${open ? "open" : ""}`} aria-label="Main (mobile)">
          {links.map((l) => (
            <Link key={l.href} href={l.href} onClick={() => setOpen(false)}>
              {l.label}
            </Link>
          ))}
          {!account && (
            <Link href="/signin/" onClick={() => setOpen(false)}>
              Sign in
            </Link>
          )}
          <div style={{ padding: "8px 4px 0" }}>
            <ThemeToggle withLabel />
          </div>
        </nav>
      </div>
    </header>
  );
}

export function SiteFooter() {
  return (
    <footer className="footer">
      <div className="container">
        <div className="footer-grid">
          <div className="stack">
            <Brand />
            <p className="muted" style={{ maxWidth: 340 }}>
              PG, hostel and co-living management for India. One platform for owners, their teams and their tenants.
            </p>
          </div>
          <nav aria-labelledby="f-product">
            <h2 id="f-product">Product</h2>
            <Link href="/features/business/">Business app features</Link>
            <Link href="/features/tenant/">Tenant app features</Link>
            <Link href="/#pricing">Pricing</Link>
            <Link href="/#faq">FAQ</Link>
          </nav>
          <nav aria-labelledby="f-start">
            <h2 id="f-start">Get started</h2>
            <Link href="/signup/">Create an account</Link>
            <Link href="/signin/">Sign in</Link>
            <Link href="/signin/?demo=owner">Try the owner demo</Link>
            <Link href="/signin/?demo=tenant">Try the tenant demo</Link>
          </nav>
          <div>
            <h2>{site.contactEmail ? "Contact" : "Made in India"}</h2>
            {site.contactEmail ? <a href={`mailto:${site.contactEmail}`}>{site.contactEmail}</a> : <p className="muted">Built for PGs, hostels and co-living across Indian cities.</p>}
          </div>
        </div>
        <hr className="divider" style={{ margin: "40px 0 24px" }} />
        <p className="muted small">© {new Date().getFullYear()} OneStay360. All rights reserved.</p>
      </div>
    </footer>
  );
}

/** A picture of the owner dashboard for the hero (not interactive). */
export function DashboardPreview() {
  const bars = [62, 74, 70, 88, 81, 92];
  const months = ["May", "Jun", "Jul", "Aug", "Sep", "Oct"];
  return (
    <div
      className="glass"
      role="img"
      aria-label="Owner dashboard showing ₹1,86,500 collected this month (82% of expected), 78% occupancy, 4 items needing attention, a collections chart and recent activity."
      style={{ borderRadius: 18, overflow: "hidden", textAlign: "left", pointerEvents: "none", userSelect: "none" }}
    >
      <div aria-hidden style={{ display: "grid", gridTemplateColumns: "200px 1fr", minHeight: 420 }} className="preview-grid">
        <div style={{ borderRight: "1px solid var(--line)", padding: 16, display: "flex", flexDirection: "column", gap: 4 }} className="hide-sm">
          <div style={{ padding: "4px 8px 16px" }}>
            <Brand asLink={false} />
          </div>
          {(
            [
              [Home, "Home", true],
              [BedDouble, "Properties"],
              [Wallet, "Payments"],
              [Wrench, "Maintenance"],
              [Bell, "Notifications"],
            ] as const
          ).map(([Icon, label, active]) => (
            <div key={label} className={`side-link ${active ? "active" : ""}`} style={{ fontSize: 14.5, minHeight: 40 }}>
              <Icon size={17} /> {label}
            </div>
          ))}
        </div>
        <div style={{ padding: 24, display: "flex", flexDirection: "column", gap: 16, minWidth: 0 }}>
          <div>
            <div style={{ fontWeight: 800, fontSize: 20 }}>Good morning, Asha</div>
            <div className="muted" style={{ fontSize: 14 }}>
              Sunrise Stays · 2 properties
            </div>
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "1.4fr 1fr 1fr", gap: 12 }} className="preview-kpis">
            <div className="glass kpi kpi-hero" style={{ padding: 16 }}>
              <div className="label" style={{ fontSize: 13.5 }}>Collected this month</div>
              <div className="value" style={{ fontSize: 26 }}>₹1,86,500</div>
              <div className="progress">
                <i style={{ width: "82%" }} />
              </div>
              <div className="hint" style={{ fontSize: 13 }}>82% of ₹2,27,000</div>
            </div>
            <div className="glass kpi" style={{ padding: 16 }}>
              <div className="label" style={{ fontSize: 13.5 }}>Occupancy</div>
              <div className="value" style={{ fontSize: 26 }}>78%</div>
              <div className="hint" style={{ fontSize: 13 }}>25 of 32 beds</div>
            </div>
            <div className="glass kpi" style={{ padding: 16 }}>
              <div className="label" style={{ fontSize: 13.5 }}>Needs attention</div>
              <div className="value" style={{ fontSize: 26 }}>4</div>
              <div className="hint" style={{ fontSize: 13 }}>2 requests · 1 payment</div>
            </div>
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "1.3fr 1fr", gap: 12 }} className="preview-kpis">
            <div className="glass" style={{ padding: 16, borderRadius: 14 }}>
              <div style={{ fontWeight: 700, fontSize: 15 }}>Collections</div>
              <div className="bars" style={{ height: 130 }}>
                {bars.map((b, i) => (
                  <div className="bar" key={i}>
                    <i style={{ height: `${b}%` }} />
                    <span style={{ fontSize: 12.5 }}>{months[i]}</span>
                  </div>
                ))}
              </div>
            </div>
            <div className="glass" style={{ padding: 16, borderRadius: 14 }}>
              <div style={{ fontWeight: 700, fontSize: 15, marginBottom: 6 }}>Recent activity</div>
              {[
                ["Kunal paid the first bill", "2m"],
                ["AC not cooling · Room 103", "18m"],
                ["Priya asked to join", "1h"],
                ["₹14,000 received online", "3h"],
              ].map(([t, a]) => (
                <div key={t} className="row-between" style={{ fontSize: 13.5, padding: "8px 0", borderBottom: "1px solid var(--line)" }}>
                  <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{t}</span>
                  <span className="muted">{a}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
      <style>{`
        @media (max-width: 640px) {
          .preview-grid { grid-template-columns: 1fr !important; }
          .preview-kpis { grid-template-columns: 1fr !important; }
        }
      `}</style>
    </div>
  );
}

/** A picture of the tenant app home screen in a phone frame. */
export function TenantPhonePreview() {
  return (
    <div className="phone" role="img" aria-label="Tenant app home: Room 101 Bed A at Sunrise Residency, October rent of ₹14,000 with a Pay now button, a resolved WiFi request and a paid September rent.">
      <div className="phone-screen" aria-hidden>
        <div>
          <div className="muted" style={{ fontSize: 13 }}>
            Welcome back
          </div>
          <div style={{ fontWeight: 800, fontSize: 18 }}>Rahul</div>
        </div>
        <div className="kpi-hero" style={{ padding: 16, borderRadius: 18 }}>
          <div style={{ fontSize: 13, color: "var(--hero-soft)" }}>Sunrise Residency</div>
          <div style={{ fontWeight: 800, fontSize: 17, color: "#fff" }}>Room 101 · Bed A</div>
          <div style={{ marginTop: 12, fontSize: 13, color: "var(--hero-soft)" }}>October rent</div>
          <div style={{ fontWeight: 800, fontSize: 24, color: "#fff" }}>₹14,000</div>
          <div style={{ marginTop: 12, background: "var(--mint)", color: "#0b1f19", borderRadius: 12, padding: "10px 0", textAlign: "center", fontWeight: 700, fontSize: 14 }}>Pay rent</div>
        </div>
        {(
          [
            [Wrench, "WiFi drops every evening", "Resolved"],
            [Wallet, "September rent", "Paid"],
          ] as const
        ).map(([Icon, t, s]) => (
          <div key={t} className="glass row" style={{ padding: 12, borderRadius: 14, gap: 12 }}>
            <span className="tile-ic" style={{ width: 34, height: 34, borderRadius: 10 }}>
              <Icon size={16} />
            </span>
            <div style={{ minWidth: 0, flex: 1 }}>
              <div style={{ fontSize: 14, fontWeight: 600, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{t}</div>
              <div className="muted" style={{ fontSize: 13 }}>
                {s}
              </div>
            </div>
            <CheckCircle2 size={16} color="var(--brand-text)" />
          </div>
        ))}
      </div>
    </div>
  );
}

/** A picture of the owner approving a join request in a phone frame. */
export function OwnerPhonePreview() {
  return (
    <div className="phone" role="img" aria-label="Business app: approving Priya Desai's join request by picking bed 202-B and sending a ₹25,500 first bill by UPI.">
      <div className="phone-screen" aria-hidden>
        <div style={{ fontWeight: 800, fontSize: 18 }}>Join request</div>
        <div className="glass row" style={{ padding: 12, borderRadius: 14 }}>
          <span className="avatar" style={{ width: 36, height: 36, fontSize: 13 }}>
            PD
          </span>
          <div>
            <div style={{ fontWeight: 650, fontSize: 15 }}>Priya Desai</div>
            <div className="muted" style={{ fontSize: 13 }}>
              Double sharing · moves in Monday
            </div>
          </div>
        </div>
        <div style={{ fontSize: 14, fontWeight: 700, color: "var(--ink-soft)" }}>Pick a bed on floor 2</div>
        <div className="beds">
          <span className="bed taken">201-A</span>
          <span className="bed free">201-B</span>
          <span className="bed taken">202-A</span>
          <span className="bed free" style={{ background: "var(--brand)", color: "#fff" }}>
            202-B
          </span>
        </div>
        <div className="glass" style={{ padding: 14, borderRadius: 14, fontSize: 14 }}>
          {[
            ["Rent", "₹9,500"],
            ["Deposit", "₹15,000"],
            ["Maintenance", "₹1,000"],
          ].map(([k, v]) => (
            <div key={k} className="row-between" style={{ padding: "3px 0" }}>
              <span className="muted">{k}</span>
              <b>{v}</b>
            </div>
          ))}
          <hr className="divider" style={{ margin: "8px 0" }} />
          <div className="row-between">
            <b>First bill</b>
            <b className="accent">₹25,500</b>
          </div>
        </div>
        <div className="btn btn-primary btn-block">Send bill by UPI</div>
      </div>
    </div>
  );
}

