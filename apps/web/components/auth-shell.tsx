"use client";
import type { ReactNode } from "react";
import { CheckCircle2 } from "lucide-react";
import { Brand, ThemeToggle } from "./ui";

export function AuthShell({ children }: { children: ReactNode }) {
  return (
    <div className="auth-shell">
      <aside className="auth-side">
        <div className="row-between">
          <span className="brand" style={{ color: "#fff" }}>
            <span className="brand-mark">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src="/brand/mark.png" alt="" width={24} height={28} />
            </span>
            <span>
              OneStay<b style={{ color: "var(--mint)" }}>360</b>
            </span>
          </span>
        </div>
        <div>
          <h2 className="h2" style={{ color: "#fff", maxWidth: 460 }}>
            One platform for owners, teams and tenants.
          </h2>
          <ul className="ticks" style={{ marginTop: 24 }}>
            {["Every bed, tenant and rupee in one dashboard", "Rent by UPI, cash or online — matched to invoices", "Join requests, maintenance and invitations that update both sides"].map((t) => (
              <li key={t} style={{ color: "rgba(255,255,255,0.85)" }}>
                <CheckCircle2 size={20} color="var(--mint)" /> {t}
              </li>
            ))}
          </ul>
        </div>
        <p style={{ color: "rgba(255,255,255,0.6)", fontSize: 13 }}>Free for tenants · ₹30 per bed per month for owners</p>
      </aside>
      <main className="auth-main">
        <div style={{ width: "100%", maxWidth: 440 }}>
          <div className="row-between" style={{ marginBottom: 18 }}>
            <Brand />
            <ThemeToggle />
          </div>
          <div className="glass auth-card">{children}</div>
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
