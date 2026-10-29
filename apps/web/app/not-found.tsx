import type { Metadata } from "next";
import Link from "next/link";
import { ArrowRight, Compass } from "lucide-react";
import { SiteFooter, SiteNav } from "@/components/site";

export const metadata: Metadata = { title: "Page not found", robots: { index: false } };

export default function NotFound() {
  return (
    <>
      <SiteNav />
      <main id="main" className="container" style={{ padding: "96px 16px", textAlign: "center" }}>
        <span className="feature-ic" style={{ margin: "0 auto 24px", width: 56, height: 56 }} aria-hidden>
          <Compass size={26} />
        </span>
        <h1 className="h2">We couldn&apos;t find that page</h1>
        <p className="lead" style={{ maxWidth: 520, margin: "16px auto 0" }}>
          The link may be old or mistyped. Head back to the home page, or open your dashboard if you&apos;re signed in.
        </p>
        <div className="hero-ctas">
          <Link href="/" className="btn btn-primary btn-lg">
            Go to the home page <ArrowRight size={18} aria-hidden />
          </Link>
          <Link href="/dashboard/" className="btn btn-ghost btn-lg">
            Open my dashboard
          </Link>
        </div>
      </main>
      <SiteFooter />
    </>
  );
}
