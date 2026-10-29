"use client";
import Link from "next/link";
import { useState } from "react";
import {
  AlertTriangle,
  ArrowRight,
  BedDouble,
  Briefcase,
  Building2,
  ClipboardCheck,
  IndianRupee,
  Plus,
  Receipt,
  Sparkles,
  UserPlus,
  Users,
  Wallet,
  Wrench,
} from "lucide-react";
import { Page, useShell } from "@/components/dash/shell";
import { AddTenantModal, RecordPaymentModal } from "@/components/dash/owner-forms";
import { Bars, bedStats, Cover, Progress } from "@/components/dash/widgets";
import { Empty, Field, Kpi, Loading, StatusBadge } from "@/components/ui";
import { useAction, useQuery } from "@/lib/hooks";
import { ago, money, monthShort, periodOf } from "@/lib/format";
import { permissions } from "@/lib/permissions";

function SetupBusiness() {
  const { account } = useShell();
  const { busy, run } = useAction();
  const { data: invites } = useQuery((b) => b.listMyTeamInvites());
  const [form, setForm] = useState({ name: "", phone: account.phone, city: "Bangalore", address: "" });
  return (
    <Page title={`Welcome, ${account.name.split(" ")[0]}`} sub="Let's set up your business">
      {!!invites?.length && (
        <div className="glass card stack">
          <div className="section-title">
            <h2>You&apos;ve been invited to a team</h2>
          </div>
          {invites.map((m) => (
            <div key={m.id} className="list-row">
              <span className="tile-ic blue">
                <Users size={18} />
              </span>
              <div className="grow">
                <div className="title">Join as {m.role}</div>
                <div className="meta">Access to {m.propertyIds.length} propert{m.propertyIds.length > 1 ? "ies" : "y"}</div>
              </div>
              <button className="btn btn-primary btn-sm" disabled={busy} onClick={() => run((b) => b.acceptTeamInvite(m.id), "You joined the team")}>
                Accept and join
              </button>
            </div>
          ))}
        </div>
      )}
      <div className="grid-2">
        <form
          className="glass card stack"
          onSubmit={(e) => {
            e.preventDefault();
            void run((b) => b.createBusiness(form), "Business created");
          }}
        >
          <div className="row">
            <span className="feature-ic">
              <Briefcase size={22} />
            </span>
            <div>
              <h2 className="h3">Create your business</h2>
              <p className="muted" style={{ fontSize: 14 }}>
                You&apos;ll be its owner. Add properties and invite your team next.
              </p>
            </div>
          </div>
          <Field label="Business name">
            <input className="input" required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="e.g. Sunrise Stays" />
          </Field>
          <div className="form-grid">
            <Field label="Business phone">
              <input className="input" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
            </Field>
            <Field label="City">
              <input className="input" value={form.city} onChange={(e) => setForm({ ...form, city: e.target.value })} />
            </Field>
          </div>
          <Field label="Office address">
            <input className="input" value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} placeholder="Street, area" />
          </Field>
          <button className="btn btn-primary btn-lg" disabled={busy}>
            Create business <ArrowRight size={18} />
          </button>
        </form>
        <div className="glass card stack">
          <h2 className="h3">What happens next</h2>
          {[
            [Building2, "Add a property", "Rooms, beds, rent, amenities and rules in a stepped form."],
            [Receipt, "Activate it", "Pay per bed to list it on Explore for tenants."],
            [UserPlus, "Add tenants", "Invite tenants to beds or accept join requests."],
            [Wallet, "Collect rent", "Monthly invoices, online, UPI and cash payments."],
          ].map(([Icon, t, d]) => {
            const I = Icon as typeof Building2;
            return (
              <div className="list-row" key={t as string}>
                <span className="tile-ic">
                  <I size={18} />
                </span>
                <div className="grow">
                  <div className="title">{t as string}</div>
                  <div className="meta" style={{ whiteSpace: "normal" }}>
                    {d as string}
                  </div>
                </div>
              </div>
            );
          })}
          <p className="faint" style={{ fontSize: 14 }}>
            Joining someone else&apos;s team? Ask the owner to invite {account.phone || account.email}; the invitation will appear here.
          </p>
        </div>
      </div>
    </Page>
  );
}

function OwnerHome() {
  const { account } = useShell();
  const can = permissions(account.role);
  const [modal, setModal] = useState<"tenant" | "payment" | null>(null);
  const { data, loading, error, reload } = useQuery(async (b) => {
    const [business, properties, tenants, invoices, payments, requests, maintenance, activity] = await Promise.all([
      b.getBusiness(),
      b.listProperties(),
      b.listTenants({ status: "active" }),
      b.listInvoices(),
      b.listPayments(),
      b.listRequests(),
      b.listMaintenance(),
      b.listActivity(),
    ]);
    return { business, properties, tenants, invoices, payments, requests, maintenance, activity };
  });

  if (loading || !data) {
    return (
      <Page error={error} onRetry={reload} title="Home">
        <Loading rows={4} />
      </Page>
    );
  }
  const { business, properties, tenants, invoices, payments, requests, maintenance, activity } = data;
  const period = periodOf(new Date());
  const thisMonth = invoices.filter((i) => i.periodMonth === period);
  const expected = thisMonth.reduce((s, i) => s + i.amount, 0);
  const collected = thisMonth.filter((i) => i.status === "paid").reduce((s, i) => s + i.amount, 0);
  const overdue = invoices.filter((i) => i.status === "overdue");
  const beds = properties.reduce(
    (acc, p) => {
      const s = bedStats(p);
      return { total: acc.total + s.total, occupied: acc.occupied + s.occupied };
    },
    { total: 0, occupied: 0 },
  );
  const pendingPayments = payments.filter((p) => p.status === "pending");
  const newRequests = requests.filter((r) => r.status === "pending");
  const toConfirm = requests.filter((r) => r.status === "payment_submitted");
  const openMaint = maintenance.filter((m) => m.status === "open" || m.status === "in_progress");
  const urgent = openMaint.filter((m) => m.urgent && m.status === "open");
  const unpaidProps = properties.filter((p) => p.billingStatus !== "paid");

  const months = Array.from({ length: 6 }, (_, i) => {
    const d = new Date();
    d.setDate(1);
    d.setMonth(d.getMonth() - (5 - i));
    return periodOf(d);
  });
  const chart = months.map((m) => {
    const inv = invoices.filter((i) => i.periodMonth === m);
    return { label: monthShort(m), total: inv.reduce((s, i) => s + i.amount, 0), value: inv.filter((i) => i.status === "paid").reduce((s, i) => s + i.amount, 0) };
  });

  const attention = [
    newRequests.length && { href: "/dashboard/owner/requests/", icon: ClipboardCheck, tone: "blue", title: `${newRequests.length} new join request${newRequests.length > 1 ? "s" : ""}`, meta: newRequests.map((r) => r.tenantName).join(", ") },
    toConfirm.length && { href: "/dashboard/owner/requests/", icon: BedDouble, tone: "amber", title: `${toConfirm.length} first bill${toConfirm.length > 1 ? "s" : ""} to confirm`, meta: toConfirm.map((r) => `${r.tenantName} · ${money(r.total ?? 0)}`).join(", ") },
    pendingPayments.length && { href: "/dashboard/owner/payments/", icon: Wallet, tone: "amber", title: `${pendingPayments.length} payment${pendingPayments.length > 1 ? "s" : ""} to verify`, meta: pendingPayments.map((p) => `${p.tenantName} · ${money(p.amount)}`).join(", ") },
    overdue.length && { href: "/dashboard/owner/payments/?tab=dues", icon: AlertTriangle, tone: "red", title: `${overdue.length} overdue invoice${overdue.length > 1 ? "s" : ""}`, meta: `${money(overdue.reduce((s, i) => s + i.amount, 0))} outstanding` },
    urgent.length && { href: "/dashboard/owner/maintenance/", icon: Wrench, tone: "red", title: `${urgent.length} urgent maintenance`, meta: urgent.map((m) => `${m.title} · Room ${m.roomNumber}`).join(", ") },
    can.canViewBilling && unpaidProps.length && { href: "/dashboard/owner/billing/", icon: Receipt, tone: "amber", title: `${unpaidProps.length} propert${unpaidProps.length > 1 ? "ies" : "y"} not yet activated`, meta: "Pay to list on Explore" },
  ].filter(Boolean) as { href: string; icon: typeof Wallet; tone: string; title: string; meta: string }[];

  const hour = new Date().getHours();
  const greeting = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening";

  return (
    <Page error={error} onRetry={reload}
      title={`${greeting}, ${account.name.split(" ")[0]}`}
      sub={`${business?.name ?? "Your business"} — here’s how your ${properties.length === 1 ? "property is" : `${properties.length} properties are`} doing today.`}
      actions={
        properties.length > 0 && (
          <>
            {can.canVerifyPayments && (
              <button className="btn btn-ghost" onClick={() => setModal("payment")}>
                <Wallet size={17} aria-hidden /> Record a payment
              </button>
            )}
            {can.canManageTenants && (
              <button className="btn btn-primary" onClick={() => setModal("tenant")}>
                <UserPlus size={17} aria-hidden /> Add a tenant
              </button>
            )}
          </>
        )
      }
    >
      {properties.length === 0 ? (
        <div className="glass card">
          <Empty
            icon={Building2}
            title={can.canEditProperties ? "Add your first property" : "No properties assigned to you yet"}
            body={can.canEditProperties ? "Set up rooms and beds, then invite tenants or list it on Explore." : "Ask the owner to give you access to a property."}
            action={
              can.canEditProperties && (
                <Link href="/dashboard/owner/property-form/" className="btn btn-primary">
                  <Plus size={16} aria-hidden /> Add property
                </Link>
              )
            }
          />
        </div>
      ) : (
        <>
          <div className="grid-4">
            <div className="glass kpi kpi-hero" style={{ gridColumn: "span 2" }}>
              <div className="label">
                <IndianRupee size={16} aria-hidden /> Collected in {new Date().toLocaleDateString("en-US", { month: "long" })}
              </div>
              <div className="value num" style={{ fontSize: 34 }}>
                {money(collected)}
              </div>
              <Progress value={expected ? (collected / expected) * 100 : 0} label="Share of this month's rent collected" />
              <div className="hint">
                {expected ? Math.round((collected / expected) * 100) : 0}% of {money(expected)} expected · {money(expected - collected)} to collect
              </div>
            </div>
            <Kpi icon={BedDouble} label="Occupancy" value={`${beds.total ? Math.round((beds.occupied / beds.total) * 100) : 0}%`} hint={`${beds.occupied} of ${beds.total} beds · ${beds.total - beds.occupied} free`} />
            <Kpi icon={Users} label="Active tenants" value={tenants.length} hint={`${overdue.length} overdue · ${pendingPayments.length} to verify`} tone={overdue.length ? "red" : undefined} />
          </div>

          <div className="cols-wl">
            <div className="glass card">
              <div className="section-title">
                <h2>Collections</h2>
                <Link href="/dashboard/owner/reports/" className="btn btn-ghost btn-sm">
                  Open reports <ArrowRight size={15} aria-hidden />
                </Link>
              </div>
              <Bars data={chart} />
              <hr className="divider" style={{ margin: "16px 0" }} />
              <div className="grid-3" style={{ gap: 12 }}>
                <div>
                  <div className="faint" style={{ fontSize: 14 }}>6-month collected</div>
                  <b className="num">{money(chart.reduce((x, c) => x + c.value, 0))}</b>
                </div>
                <div>
                  <div className="faint" style={{ fontSize: 14 }}>Collection rate</div>
                  <b className="num">{Math.round((chart.reduce((x, c) => x + c.value, 0) / Math.max(1, chart.reduce((x, c) => x + c.total, 0))) * 100)}%</b>
                </div>
                <div>
                  <div className="faint" style={{ fontSize: 14 }}>Outstanding</div>
                  <b className="num" style={{ color: overdue.length ? "var(--tint-red-ink)" : undefined }}>{money(invoices.filter((i) => i.status !== "paid").reduce((x, i) => x + i.amount, 0))}</b>
                </div>
              </div>
            </div>
            <div className="glass card">
              <div className="section-title">
                <h2>Needs attention</h2>
                {attention.length > 0 && <span className="badge badge-red">{attention.length}</span>}
              </div>
              {attention.length === 0 ? (
                <Empty icon={Sparkles} title="All caught up" body="No requests, payments or urgent issues waiting for you." />
              ) : (
                <div className="list">
                  {attention.map((a) => {
                    const Icon = a.icon;
                    return (
                      <Link key={a.title} href={a.href} className="list-row">
                        <span className={`tile-ic ${a.tone}`}>
                          <Icon size={18} />
                        </span>
                        <div className="grow">
                          <div className="title">{a.title}</div>
                          <div className="meta">{a.meta}</div>
                        </div>
                        <ArrowRight size={16} className="faint" />
                      </Link>
                    );
                  })}
                </div>
              )}
            </div>
          </div>

          <div className="grid-2">
            <div className="glass card">
              <div className="section-title">
                <h2>Portfolio</h2>
                <Link href="/dashboard/owner/properties/" className="btn btn-ghost btn-sm">
                  View all properties <ArrowRight size={15} aria-hidden />
                </Link>
              </div>
              <div className="list">
                {properties.map((p) => {
                  const s = bedStats(p);
                  return (
                    <Link key={p.id} href={`/dashboard/owner/property/?id=${p.id}`} className="list-row">
                      <div style={{ width: 52, borderRadius: 12, overflow: "hidden", flex: "none" }}>
                        <Cover p={p} height={44} />
                      </div>
                      <div className="grow">
                        <div className="row-between">
                          <div className="title">{p.name}</div>
                          <StatusBadge status={p.billingStatus} />
                        </div>
                        <div className="meta" style={{ marginBottom: 6 }}>
                          {s.occupied}/{s.total} beds · {p.city}
                        </div>
                        <Progress value={s.pct} label={`${p.name} occupancy`} />
                      </div>
                    </Link>
                  );
                })}
              </div>
            </div>
            <div className="glass card">
              <div className="section-title">
                <h2>Recent activity</h2>
              </div>
              {activity.length === 0 ? (
                <Empty icon={Sparkles} title="Nothing yet" body="Your team's actions will show up here." />
              ) : (
                <div className="list">
                  {activity.slice(0, 8).map((a) => (
                    <div key={a.id} className="list-row" style={{ padding: "10px 4px" }}>
                      <div className="grow">
                        <div style={{ fontSize: 14 }}>{a.text}</div>
                      </div>
                      <span className="faint" style={{ fontSize: 14, whiteSpace: "nowrap" }}>
                        {ago(a.at)}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </>
      )}
      {modal === "tenant" && <AddTenantModal onClose={() => setModal(null)} />}
      {modal === "payment" && <RecordPaymentModal onClose={() => setModal(null)} />}
    </Page>
  );
}

export default function OwnerHomePage() {
  const { account } = useShell();
  return account.businessId ? <OwnerHome /> : <SetupBusiness />;
}
