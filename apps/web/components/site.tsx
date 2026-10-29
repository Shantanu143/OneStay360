"use client";
// Marketing chrome: glass nav, footer, and the product previews in the hero.
import Link from "next/link";
import { useEffect, useState } from "react";
import { ArrowRight, BedDouble, Bell, CheckCircle2, Home, Menu, Search, Wallet, Wrench, X } from "lucide-react";
import { Brand, ThemeToggle } from "./ui";
import { useAccount } from "@/lib/hooks";

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
  useEffect(() => {
    const close = () => setOpen(false);
    window.addEventListener("hashchange", close);
    return () => window.removeEventListener("hashchange", close);
  }, []);
  return (
    <div className="nav-wrap">
      <div className="container">
        <nav className="nav glass" aria-label="Main">
          <Brand />
          <div className="nav-links">
            {links.map((l) => (
              <Link key={l.href} href={l.href}>
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
                Open dashboard <ArrowRight size={16} />
              </Link>
            ) : (
              <>
                <Link href="/signin/" className="btn btn-ghost btn-sm hide-sm">
                  Sign in
                </Link>
                <Link href="/signup/" className="btn btn-primary btn-sm">
                  Get started
                </Link>
              </>
            )}
            <button className="icon-btn nav-burger" onClick={() => setOpen((o) => !o)} aria-label="Menu" aria-expanded={open}>
              {open ? <X size={18} /> : <Menu size={18} />}
            </button>
          </div>
        </nav>
        <div className={`mobile-menu glass ${open ? "open" : ""}`}>
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
        </div>
      </div>
    </div>
  );
}

export function SiteFooter() {
  return (
    <footer className="footer">
      <div className="container">
        <div className="footer-grid">
          <div className="stack">
            <Brand />
            <p className="muted" style={{ maxWidth: 320, fontSize: 14.5 }}>
              PG, hostel and co-living management for India. One platform for owners, their teams and their tenants.
            </p>
          </div>
          <div>
            <h4>Product</h4>
            <Link href="/features/business/">Business app</Link>
            <Link href="/features/tenant/">Tenant app</Link>
            <Link href="/#pricing">Pricing</Link>
            <Link href="/#faq">FAQ</Link>
          </div>
          <div>
            <h4>Get started</h4>
            <Link href="/signup/">Create account</Link>
            <Link href="/signin/">Sign in</Link>
            <Link href="/signin/?demo=owner">Owner demo</Link>
            <Link href="/signin/?demo=tenant">Tenant demo</Link>
          </div>
          <div>
            <h4>Contact</h4>
            <a href="mailto:support@onestay360.in">support@onestay360.in</a>
            <span className="faint" style={{ fontSize: 14, display: "block", paddingTop: 4 }}>Made in India</span>
          </div>
        </div>
        <hr className="divider" style={{ margin: "32px 0 20px" }} />
        <p className="faint" style={{ fontSize: 13 }}>© {new Date().getFullYear()} OneStay360. All rights reserved.</p>
      </div>
    </footer>
  );
}

/** A static rendering of the owner dashboard for the hero. */
export function DashboardPreview() {
  const bars = [62, 74, 70, 88, 81, 92];
  const months = ["May", "Jun", "Jul", "Aug", "Sep", "Oct"];
  return (
    <div className="glass" style={{ borderRadius: 20, overflow: "hidden", textAlign: "left" }} aria-hidden>
      <div style={{ display: "grid", gridTemplateColumns: "190px 1fr", minHeight: 420 }} className="preview-grid">
        <div style={{ borderRight: "1px solid var(--line)", padding: 14, display: "flex", flexDirection: "column", gap: 4 }} className="hide-sm">
          <div style={{ padding: "4px 8px 12px" }}>
            <Brand href="#" />
          </div>
          {[
            [Home, "Home", true],
            [BedDouble, "Properties"],
            [Wallet, "Payments"],
            [Wrench, "Maintenance"],
            [Bell, "Notifications"],
          ].map(([Icon, label, active]) => {
            const I = Icon as typeof Home;
            return (
              <div key={label as string} className={`side-link ${active ? "active" : ""}`} style={{ fontSize: 13.5, padding: "9px 10px" }}>
                <I size={16} /> {label as string}
              </div>
            );
          })}
        </div>
        <div style={{ padding: 18, display: "flex", flexDirection: "column", gap: 14, minWidth: 0 }}>
          <div className="row-between">
            <div>
              <div style={{ fontWeight: 750, fontSize: 17 }}>Good morning, Asha</div>
              <div className="faint" style={{ fontSize: 12.5 }}>Sunrise Stays · 2 properties</div>
            </div>
            <div className="row" style={{ gap: 8 }}>
              <span className="icon-btn" style={{ width: 34, height: 34 }}>
                <Search size={15} />
              </span>
              <span className="avatar" style={{ width: 34, height: 34, fontSize: 12 }}>
                AR
              </span>
            </div>
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "1.4fr 1fr 1fr", gap: 10 }} className="preview-kpis">
            <div className="glass kpi kpi-hero" style={{ padding: 14 }}>
              <div className="label" style={{ fontSize: 12 }}>Collected this month</div>
              <div className="value" style={{ fontSize: 24 }}>₹1,86,500</div>
              <div className="progress">
                <i style={{ width: "82%" }} />
              </div>
              <div className="hint">82% of ₹2,27,000</div>
            </div>
            <div className="glass kpi" style={{ padding: 14 }}>
              <div className="label" style={{ fontSize: 12 }}>Occupancy</div>
              <div className="value" style={{ fontSize: 24 }}>78%</div>
              <div className="hint">25 of 32 beds</div>
            </div>
            <div className="glass kpi" style={{ padding: 14 }}>
              <div className="label" style={{ fontSize: 12 }}>Needs attention</div>
              <div className="value" style={{ fontSize: 24 }}>4</div>
              <div className="hint">2 requests · 1 payment</div>
            </div>
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "1.3fr 1fr", gap: 10 }} className="preview-kpis">
            <div className="glass" style={{ padding: 14, borderRadius: 16 }}>
              <div style={{ fontWeight: 650, fontSize: 13.5 }}>Collections</div>
              <div className="bars" style={{ height: 130 }}>
                {bars.map((b, i) => (
                  <div className="bar" key={i}>
                    <i style={{ height: `${b}%` }} />
                    <span>{months[i]}</span>
                  </div>
                ))}
              </div>
            </div>
            <div className="glass" style={{ padding: 14, borderRadius: 16 }}>
              <div style={{ fontWeight: 650, fontSize: 13.5, marginBottom: 6 }}>Recent activity</div>
              {[
                ["Kunal Shah paid the first bill", "2m"],
                ["AC not cooling · Room 103", "18m"],
                ["Priya requested to join", "1h"],
                ["₹14,000 received online", "3h"],
              ].map(([t, a]) => (
                <div key={t} className="row-between" style={{ fontSize: 12.5, padding: "7px 0", borderBottom: "1px solid var(--line)" }}>
                  <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{t}</span>
                  <span className="faint">{a}</span>
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

/** Tenant app screen in a phone frame. */
export function TenantPhonePreview() {
  return (
    <div className="phone" aria-hidden>
      <div className="phone-screen">
        <div className="row-between">
          <div>
            <div className="faint" style={{ fontSize: 11 }}>Welcome back</div>
            <div style={{ fontWeight: 750 }}>Rahul</div>
          </div>
          <span className="avatar" style={{ width: 32, height: 32, fontSize: 12 }}>
            RM
          </span>
        </div>
        <div className="kpi-hero glass" style={{ padding: 14, borderRadius: 18 }}>
          <div style={{ fontSize: 11, color: "#b9ccc5" }}>Sunrise Residency</div>
          <div style={{ fontWeight: 750, fontSize: 16, color: "#fff" }}>Room 101 · Bed A</div>
          <div style={{ marginTop: 10, fontSize: 11, color: "#b9ccc5" }}>October rent</div>
          <div style={{ fontWeight: 800, fontSize: 22, color: "#fff" }}>₹14,000</div>
          <div style={{ marginTop: 10, background: "var(--mint)", color: "#0b1f19", borderRadius: 12, padding: "8px 0", textAlign: "center", fontWeight: 700, fontSize: 13 }}>Pay now</div>
        </div>
        {[
          [Wrench, "WiFi drops every evening", "Resolved"],
          [Wallet, "September rent", "Paid"],
          [Bell, "Biryani order at 8pm 🍛", "Pinboard"],
        ].map(([Icon, t, s]) => {
          const I = Icon as typeof Home;
          return (
            <div key={t as string} className="glass row" style={{ padding: 10, borderRadius: 14, gap: 10 }}>
              <span className="tile-ic" style={{ width: 32, height: 32, borderRadius: 10 }}>
                <I size={15} />
              </span>
              <div style={{ minWidth: 0, flex: 1 }}>
                <div style={{ fontSize: 12.5, fontWeight: 600, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{t as string}</div>
                <div className="faint" style={{ fontSize: 11 }}>{s as string}</div>
              </div>
              <CheckCircle2 size={14} color="var(--brand)" />
            </div>
          );
        })}
      </div>
    </div>
  );
}

/** Owner app (request approval) in a phone frame. */
export function OwnerPhonePreview() {
  return (
    <div className="phone" aria-hidden>
      <div className="phone-screen">
        <div style={{ fontWeight: 750 }}>Join request</div>
        <div className="glass" style={{ padding: 12, borderRadius: 16 }}>
          <div className="row">
            <span className="avatar" style={{ width: 34, height: 34, fontSize: 12 }}>
              PD
            </span>
            <div>
              <div style={{ fontWeight: 650, fontSize: 13.5 }}>Priya Desai</div>
              <div className="faint" style={{ fontSize: 11.5 }}>Double sharing · moves in Mon</div>
            </div>
          </div>
        </div>
        <div style={{ fontSize: 11, fontWeight: 700, color: "var(--ink-faint)", letterSpacing: ".08em" }}>PICK A BED · FLOOR 2</div>
        <div className="beds">
          {["A", "B"].map((b, i) => (
            <span key={b} className={`bed ${i === 0 ? "taken" : "free"}`}>
              201-{b}
            </span>
          ))}
          {["A", "B", "C"].map((b, i) => (
            <span key={b} className={`bed ${i === 1 ? "free" : "taken"}`} style={i === 1 ? { background: "var(--brand)", color: "#fff" } : undefined}>
              202-{b}
            </span>
          ))}
        </div>
        <div className="glass" style={{ padding: 12, borderRadius: 16, fontSize: 12.5 }}>
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
          <hr className="divider" style={{ margin: "6px 0" }} />
          <div className="row-between">
            <b>First bill</b>
            <b style={{ color: "var(--brand)" }}>₹25,500</b>
          </div>
        </div>
        <div className="btn btn-primary btn-block" style={{ height: 40 }}>
          Send bill by UPI
        </div>
      </div>
    </div>
  );
}
