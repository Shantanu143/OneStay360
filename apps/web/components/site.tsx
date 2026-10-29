"use client";
// Marketing chrome: nav, footer, and the product previews used as pictures.
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { ArrowRight, Menu, X } from "lucide-react";
import { Brand, ThemeToggle } from "./ui";
import { useAccount } from "@/lib/hooks";
import { site } from "@/lib/site";

const links = [
  { href: "/#journey", label: "How it works" },
  { href: "/features/business/", label: "For owners" },
  { href: "/features/tenant/", label: "For tenants" },
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
            <Link href="/#journey">How it works</Link>
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
