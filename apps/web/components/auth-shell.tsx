"use client";
import Link from "next/link";
import type { ReactNode } from "react";
import { ArrowLeft, CheckCircle2 } from "lucide-react";
import { Brand, ThemeToggle } from "./ui";

export function AuthShell({ children }: { children: ReactNode }) {
  return (
    <div className="auth-shell">
      <aside className="auth-side" aria-label="About OneStay360">
        <span className="brand" style={{ color: "#fff" }}>
          <span className="brand-mark">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/brand/mark-96.png" alt="" width={22} height={28} />
          </span>
          <span>
            OneStay<b style={{ color: "var(--mint)" }}>360</b>
          </span>
        </span>
        <div>
          <p className="h2" style={{ color: "#fff", maxWidth: 460 }}>
            One platform for owners, teams and tenants.
          </p>
          <ul className="ticks" style={{ marginTop: 32 }}>
            {["Every bed, tenant and rupee in one dashboard", "Rent by UPI, cash or online, matched to invoices", "Requests, maintenance and invitations that update both sides"].map((t) => (
              <li key={t} style={{ color: "rgba(255,255,255,0.88)" }}>
                <CheckCircle2 size={20} color="var(--mint)" aria-hidden /> {t}
              </li>
            ))}
          </ul>
        </div>
        <p style={{ color: "rgba(255,255,255,0.75)", fontSize: 15 }}>Free for tenants. ₹30 per bed per month for owners.</p>
      </aside>
      <main id="main" className="auth-main">
        <div style={{ width: "100%", maxWidth: 460 }}>
          <div className="row-between" style={{ marginBottom: 24 }}>
            <Link href="/" className="btn btn-text" style={{ paddingLeft: 0 }}>
              <ArrowLeft size={16} aria-hidden /> Back to home
            </Link>
            <ThemeToggle />
          </div>
          <div className="glass auth-card">
            <div style={{ marginBottom: 24 }}>
              <Brand />
            </div>
            {children}
          </div>
        </div>
      </main>
    </div>
  );
}

/** Where to go after signing in: ?next= when it's an in-app path, else the dashboard. */
export function nextPath() {
  if (typeof window === "undefined") return "/dashboard/";
  const next = new URLSearchParams(window.location.search).get("next");
  return next && next.startsWith("/") && !next.startsWith("//") ? next : "/dashboard/";
}
