"use client";
// Dashboard chrome: glass sidebar with role-aware navigation and live counts,
// a sticky top bar per page, and the demo-mode banner.
import Link from "next/link";
import { usePathname } from "next/navigation";
import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import {
  BarChart3,
  Bell,
  Building2,
  ClipboardCheck,
  Home,
  KeyRound,
  Landmark,
  LogOut,
  MailOpen,
  Menu,
  MessageSquareText,
  Receipt,
  RotateCcw,
  Search,
  UserCircle,
  Users,
  Wallet,
  Wrench,
  type LucideIcon,
} from "lucide-react";
import { Brand, ErrorNote, ThemeToggle } from "../ui";
import { useBackend, useQuery } from "@/lib/hooks";
import { cls, initials } from "@/lib/format";
import { permissions } from "@/lib/permissions";
import type { Account } from "@/lib/types";

interface NavItem {
  href: string;
  label: string;
  icon: LucideIcon;
  count?: number;
}

const ShellCtx = createContext<{ openNav: () => void; account: Account } | null>(null);

export function useShell() {
  const ctx = useContext(ShellCtx);
  if (!ctx) throw new Error("useShell outside Shell");
  return ctx;
}

function useCounts(account: Account) {
  return useQuery(async (b) => {
    const unread = (await b.listNotifications()).filter((n) => !n.read).length;
    if (account.kind === "tenant") {
      const invites = (await b.listMyInvitations()).filter((i) => i.status === "pending").length;
      const bills = (await b.listMyRequests()).filter((r) => r.status === "bill_sent").length;
      const due = (await b.listMyInvoices()).filter((i) => i.status !== "paid").length;
      return { unread, invites, bills, due, requests: 0, payments: 0, maintenance: 0 };
    }
    if (!account.businessId) return { unread, invites: 0, bills: 0, due: 0, requests: 0, payments: 0, maintenance: 0 };
    const [reqs, pays, mnt] = await Promise.all([b.listRequests(), b.listPayments({ status: "pending" }), b.listMaintenance()]);
    return {
      unread,
      invites: 0,
      bills: 0,
      due: 0,
      requests: reqs.filter((r) => r.status === "pending" || r.status === "payment_submitted").length,
      payments: pays.length,
      maintenance: mnt.filter((m) => m.status === "open").length,
    };
  }, [account.uid, account.businessId]);
}

export function Shell({ account, children }: { account: Account; children: ReactNode }) {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();
  const backend = useBackend();
  const { data: c } = useCounts(account);
  useEffect(() => setOpen(false), [pathname]);

  const can = permissions(account.role);
  const groups: { title: string; items: NavItem[] }[] =
    account.kind === "tenant"
      ? [
          {
            title: "Home",
            items: [
              { href: "/dashboard/tenant/", label: "Home", icon: Home },
              { href: "/dashboard/tenant/explore/", label: "Explore PGs", icon: Search },
              { href: "/dashboard/tenant/requests/", label: "My requests", icon: KeyRound, count: c?.bills },
              { href: "/dashboard/tenant/invitations/", label: "Invitations", icon: MailOpen, count: c?.invites },
            ],
          },
          {
            title: "My stay",
            items: [
              { href: "/dashboard/tenant/stay/", label: "My stay", icon: Building2 },
              { href: "/dashboard/tenant/rent/", label: "Rent & payments", icon: Wallet, count: c?.due },
              { href: "/dashboard/tenant/maintenance/", label: "Maintenance", icon: Wrench },
              { href: "/dashboard/tenant/pinboard/", label: "Pinboard", icon: MessageSquareText },
            ],
          },
          {
            title: "Account",
            items: [
              { href: "/dashboard/tenant/notifications/", label: "Notifications", icon: Bell, count: c?.unread },
              { href: "/dashboard/tenant/profile/", label: "Profile", icon: UserCircle },
            ],
          },
        ]
      : !account.businessId
        ? [{ title: "Get started", items: [{ href: "/dashboard/owner/", label: "Set up business", icon: Home }] }]
        : [
            {
              title: "Overview",
              items: [
                { href: "/dashboard/owner/", label: "Home", icon: Home },
                { href: "/dashboard/owner/properties/", label: "Properties", icon: Building2 },
                { href: "/dashboard/owner/tenants/", label: "Tenants", icon: Users },
                { href: "/dashboard/owner/requests/", label: "Join requests", icon: ClipboardCheck, count: c?.requests },
              ],
            },
            {
              title: "Money",
              items: [
                { href: "/dashboard/owner/payments/", label: "Rent & payments", icon: Wallet, count: c?.payments },
                { href: "/dashboard/owner/reports/", label: "Reports", icon: BarChart3 },
                ...(can.canEditPaymentMethods ? [{ href: "/dashboard/owner/collections/", label: "Payment methods", icon: Landmark }] : []),
                ...(can.canViewBilling ? [{ href: "/dashboard/owner/billing/", label: "Billing", icon: Receipt }] : []),
              ],
            },
            {
              title: "Operations",
              items: [
                { href: "/dashboard/owner/maintenance/", label: "Maintenance", icon: Wrench, count: c?.maintenance },
                ...(can.canInviteMembers ? [{ href: "/dashboard/owner/team/", label: "Team", icon: Users }] : []),
                { href: "/dashboard/owner/notifications/", label: "Notifications", icon: Bell, count: c?.unread },
                { href: "/dashboard/owner/profile/", label: "Profile & KYC", icon: UserCircle },
              ],
            },
          ];

  const home = account.kind === "tenant" ? "/dashboard/tenant/" : "/dashboard/owner/";
  const isActive = (href: string) => (href === home ? pathname === href || pathname === href.slice(0, -1) : pathname.startsWith(href.slice(0, -1)));

  return (
    <ShellCtx.Provider value={{ openNav: () => setOpen(true), account }}>
      <div className="app">
        <aside id="dash-nav" className={cls("sidebar", open && "open")} aria-label="Dashboard navigation">
          <Brand href={home} />
          {groups.map((g) => (
            <div key={g.title}>
              <div className="side-group">{g.title}</div>
              {g.items.map((it) => {
                const Icon = it.icon;
                return (
                  <Link key={it.href} href={it.href} className={cls("side-link", isActive(it.href) && "active")} aria-current={isActive(it.href) ? "page" : undefined}>
                    <Icon size={19} aria-hidden />
                    {it.label}
                    {!!it.count && (
                      <span className="count" aria-label={`${it.count} need attention`}>
                        {it.count > 99 ? "99+" : it.count}
                      </span>
                    )}
                  </Link>
                );
              })}
            </div>
          ))}
          <div className="sidebar-foot">
            <ThemeToggle withLabel />
            <div className="user-chip">
              <span className="avatar" aria-hidden>
                {initials(account.name)}
              </span>
              <div style={{ minWidth: 0, flex: 1 }}>
                <div style={{ fontWeight: 650, fontSize: 15, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{account.name}</div>
                <div className="muted" style={{ fontSize: 14 }}>
                  {account.kind === "tenant" ? "Tenant" : account.role === "manager" ? "Manager" : account.role === "staff" ? "Staff" : "Owner"}
                </div>
              </div>
            </div>
            <button className="btn btn-ghost btn-sm" onClick={() => backend.signOut().then(() => (window.location.href = "/"))}>
              <LogOut size={16} aria-hidden /> Sign out
            </button>
          </div>
        </aside>
        <div className={cls("scrim", open && "open")} onClick={() => setOpen(false)} aria-hidden />
        <div className="main">
          {backend.mode === "demo" && (
            <section className="demo-banner" aria-label="Demo mode notice">
              <b>Demo mode.</b>
              <span className="hide-sm">Sample data, saved only in this browser. Sign in as other demo accounts to see both sides of a flow.</span>
              <span className="show-sm">Sample data, saved in this browser.</span>
              {backend.resetDemo && (
                <button className="btn btn-sm btn-text" style={{ marginLeft: "auto", color: "inherit", minHeight: 32 }} onClick={() => backend.resetDemo!().then(() => (window.location.href = "/signin/"))}>
                  <RotateCcw size={15} aria-hidden /> Reset demo data
                </button>
              )}
            </section>
          )}
          <header className="mobile-bar">
            <button className="icon-btn" onClick={() => setOpen(true)} aria-label="Open navigation" aria-expanded={open} aria-controls="dash-nav">
              <Menu size={20} />
            </button>
            <Brand href={home} />
            <span className="spacer" />
            <ThemeToggle />
          </header>
          <TableLabels />
          {children}
        </div>
      </div>
    </ShellCtx.Provider>
  );
}

/** Copies each table's column headings onto its cells (data-label), so
 *  tables can stack into labelled cards on phones. */
function TableLabels() {
  useEffect(() => {
    const label = () => {
      document.querySelectorAll<HTMLTableElement>("table.table").forEach((t) => {
        const heads = [...t.querySelectorAll("thead th")].map((th) => th.textContent?.trim() ?? "");
        t.querySelectorAll("tbody tr").forEach((tr) =>
          [...tr.children].forEach((td, i) => {
            if (td.getAttribute("data-label") !== (heads[i] ?? "")) td.setAttribute("data-label", heads[i] ?? "");
          }),
        );
      });
    };
    label();
    const mo = new MutationObserver(label);
    mo.observe(document.body, { childList: true, subtree: true });
    return () => mo.disconnect();
  }, []);
  return null;
}

/** A dashboard screen: one clear heading, a short description and the
 *  screen's main actions, then the content. Shows an error state with a
 *  retry instead of an endless spinner when its data fails to load. */
export function Page({ title, sub, actions, error, onRetry, children }: { title: string; sub?: ReactNode; actions?: ReactNode; error?: string | null; onRetry?: () => void; children: ReactNode }) {
  useEffect(() => {
    document.title = `${title} | OneStay360`;
  }, [title]);
  return (
    <main id="main" className="content">
      <div className="page-head">
        <div style={{ minWidth: 0 }}>
          <h1>{title}</h1>
          {sub && <p className="sub">{sub}</p>}
        </div>
        {actions && <div className="page-actions">{actions}</div>}
      </div>
      {error ? <ErrorNote message={`We couldn't load this page. ${error}`} onRetry={onRetry} /> : children}
    </main>
  );
}
