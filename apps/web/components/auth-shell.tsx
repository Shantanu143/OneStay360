"use client";
// Sign in / sign up frame: fits one screen (no page scroll on laptops and
// phones). Left: a real screenshot of the product; right: the form.
import Link from "next/link";
import type { ReactNode } from "react";
import { Brand, ThemeToggle } from "./ui";
import type { Account } from "@/lib/types";

export function AuthShell({ children, aside }: { children: ReactNode; aside: { title: string; body: string } }) {
  return (
    <div className="auth-shell">
      <aside className="auth-side" aria-label="About OneStay360">
        <Link href="/" className="brand" style={{ color: "#fff" }} aria-label="OneStay360 home">
          <span className="brand-mark">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/brand/mark-96.png" alt="" width={22} height={28} />
          </span>
          <span>
            OneStay<b style={{ color: "var(--mint)" }}>360</b>
          </span>
        </Link>
        <div className="auth-side-copy">
          <p className="auth-side-title">{aside.title}</p>
          <p className="auth-side-body">{aside.body}</p>
        </div>
        <div className="auth-shot">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/shots/owner-home-light.jpg" alt="The OneStay360 owner dashboard: rent collected this month, occupancy and what needs attention." width={1440} height={900} />
        </div>
      </aside>
      <main id="main" className="auth-main">
        <div className="auth-top">
          <span className="auth-brand-sm">
            <Brand />
          </span>
          <span className="spacer" />
          <ThemeToggle />
        </div>
        <div className="auth-card">{children}</div>
      </main>
    </div>
  );
}

/** Where to land after signing in: a valid ?next= inside the account's own
 *  area, otherwise that role's home. Owners, managers and staff go to the
 *  business dashboard; tenants to theirs. */
export function homeFor(account: Pick<Account, "kind">) {
  const home = account.kind === "tenant" ? "/dashboard/tenant/" : "/dashboard/owner/";
  if (typeof window === "undefined") return home;
  const next = new URLSearchParams(window.location.search).get("next");
  return next && next.startsWith(home) ? next : home;
}
