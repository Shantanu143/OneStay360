"use client";
// Auth guard for every dashboard route: signed-out visitors go to sign in,
// and owners/tenants are kept inside their own section.
import { usePathname, useRouter } from "next/navigation";
import { useEffect, type ReactNode } from "react";
import { Shell } from "./shell";
import { useAccount } from "@/lib/hooks";

export function DashboardGate({ children }: { children: ReactNode }) {
  const { account, loading } = useAccount();
  const router = useRouter();
  const pathname = usePathname();
  const section = account?.kind === "tenant" ? "/dashboard/tenant" : "/dashboard/owner";
  const misplaced = !!account && !pathname.startsWith(section);

  useEffect(() => {
    if (loading) return;
    if (!account) {
      router.replace(`/signin/?next=${encodeURIComponent(pathname + window.location.search)}`);
    } else if (misplaced) {
      router.replace(`${section}/`);
    }
  }, [account, loading, misplaced, pathname, router, section]);

  if (loading || !account || misplaced) {
    return (
      <main id="main" style={{ minHeight: "100vh", display: "grid", placeItems: "center" }}>
        <div className="stack" style={{ alignItems: "center" }} role="status">
          <div className="skeleton" style={{ width: 48, height: 48, borderRadius: 16 }} />
          <span className="muted">{!loading && !account ? "Taking you to sign in…" : "Loading your dashboard…"}</span>
        </div>
      </main>
    );
  }
  return <Shell account={account}>{children}</Shell>;
}
