"use client";
import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import QRCode from "qrcode";
import { ArrowLeft, BedDouble, Building2, Copy, Download, Eye, EyeOff, IndianRupee, MapPin, Pencil, Receipt, UserPlus, Users } from "lucide-react";
import { Page, useShell } from "@/components/dash/shell";
import { AddTenantModal, useHeldBeds } from "@/components/dash/owner-forms";
import { Avatar, bedStats, Cover, genderLabel } from "@/components/dash/widgets";
import { Badge, Empty, Kpi, Loading, Segmented, StatusBadge } from "@/components/ui";
import { useAction, useQuery, useToast } from "@/lib/hooks";
import { cls, date, money, periodOf, sharingLabel } from "@/lib/format";
import { permissions } from "@/lib/permissions";
import type { Property, Tenant } from "@/lib/types";

type Tab = "overview" | "layout" | "tenants" | "payments" | "requests" | "qr";

function useId() {
  const [id, setId] = useState<string | null>(null);
  useEffect(() => {
    const p = new URLSearchParams(window.location.search);
    setId(p.get("id"));
  }, []);
  return id;
}

function Layout({ p, tenants, canAdd, onAdd }: { p: Property; tenants: Tenant[]; canAdd: boolean; onAdd: (room: string, bed: string, rent: number) => void }) {
  const held = useHeldBeds(p.id) ?? new Set<string>();
  const floors = useMemo(() => {
    const m = new Map<number, Property["rooms"]>();
    for (const r of p.rooms) m.set(r.floor, [...(m.get(r.floor) ?? []), r]);
    return [...m.entries()].sort((a, b) => a[0] - b[0]);
  }, [p]);
  const byId = new Map(tenants.map((t) => [t.id, t]));
  return (
    <div className="glass card">
      <div className="section-title">
        <h2>Floor plan</h2>
        <div className="legend">
          <span>
            <i className="swatch free" aria-hidden />
            Free{canAdd ? " (click to add tenant)" : ""}
          </span>
          <span>
            <i className="swatch held" aria-hidden />
            Held
          </span>
          <span>
            <i className="swatch taken" aria-hidden />
            Occupied
          </span>
        </div>
      </div>
      {floors.map(([floor, rooms]) => (
        <div key={floor} className="floor">
          <h3>{floor === 0 ? "Ground floor" : `Floor ${floor}`}</h3>
          <div className="rooms" style={{ gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))" }}>
            {rooms.map((r) => (
              <div key={r.number} className="room">
                <div className="room-head">
                  <span>Room {r.number}</span>
                  <span className="row" style={{ gap: 4 }}>
                    {r.ac && <Badge tone="blue">AC</Badge>}
                    <span className="faint" style={{ fontSize: 14 }}>
                      {money(r.rentPerBed)}
                    </span>
                  </span>
                </div>
                <div className="faint" style={{ fontSize: 14, marginBottom: 8 }}>
                  {sharingLabel(r.sharing)}
                  {r.attachedBath ? " · attached bath" : ""}
                </div>
                <div className="stack" style={{ gap: 6 }}>
                  {r.beds.map((b) => {
                    const t = b.tenantId ? byId.get(b.tenantId) : undefined;
                    const isHeld = held.has(`${r.number}/${b.number}`);
                    if (t) {
                      return (
                        <Link key={b.number} href={`/dashboard/owner/tenant/?id=${t.id}`} className="row" style={{ gap: 8, fontSize: 14 }}>
                          <span className="bed taken">{b.number}</span>
                          <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{t.name}</span>
                        </Link>
                      );
                    }
                    return (
                      <button
                        key={b.number}
                        className="row"
                        style={{ gap: 8, fontSize: 14, border: 0, background: "none", padding: 0, textAlign: "left", cursor: canAdd && !isHeld ? "pointer" : "default" }}
                        disabled={!canAdd || isHeld}
                        onClick={() => onAdd(r.number, b.number, r.rentPerBed)}
                      >
                        <span className={cls("bed", isHeld ? "held" : "free")}>{b.number}</span>
                        <span className={isHeld ? "muted" : ""} style={{ color: isHeld ? undefined : "var(--brand)", fontWeight: 600 }}>
                          {isHeld ? "Held for a request" : "Free"}
                        </span>
                      </button>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

function QrTab({ p }: { p: Property }) {
  const [url, setUrl] = useState("");
  const [img, setImg] = useState("");
  const toast = useToast();
  useEffect(() => {
    const link = `${window.location.origin}/pg/?id=${encodeURIComponent(p.id)}`;
    setUrl(link);
    QRCode.toDataURL(link, { margin: 1, width: 480, color: { dark: "#0b1f19", light: "#ffffff" } }).then(setImg);
  }, [p.id]);
  return (
    <div className="glass card split" style={{ alignItems: "center" }}>
      <div style={{ textAlign: "center" }}>
        <div className="qr-box">{img && <img src={img} alt={`QR code for ${p.name}`} />}</div>
      </div>
      <div className="stack">
        <h2 className="h3">Scan to view &amp; join {p.name}</h2>
        <p className="muted">Print this at your gate or reception. Visitors see rooms, prices, amenities and rules, and can send a join request that lands in Join requests.</p>
        <code style={{ fontSize: 14, padding: 10, borderRadius: 10, background: "var(--tint-grey)", overflowWrap: "anywhere" }}>{url}</code>
        <div className="row wrap">
          <a className="btn btn-primary" href={img} download={`${p.name.replace(/\s+/g, "-")}-qr.png`}>
            <Download size={16} aria-hidden /> Download PNG
          </a>
          <button className="btn btn-ghost" onClick={() => navigator.clipboard?.writeText(url).then(() => toast("Link copied", "success"))}>
            <Copy size={16} aria-hidden /> Copy link
          </button>
          <Link className="btn btn-ghost" href={`/pg/?id=${encodeURIComponent(p.id)}`} target="_blank">
            <Eye size={16} aria-hidden /> Preview page
          </Link>
        </div>
        {p.billingStatus !== "paid" && <div className="alert alert-amber">This property isn&apos;t activated yet, so its page isn&apos;t public. Activate it under Billing.</div>}
      </div>
    </div>
  );
}

export default function PropertyPage() {
  const id = useId();
  const { account } = useShell();
  const can = permissions(account.role);
  const [tab, setTab] = useState<Tab>("overview");
  const [addAt, setAddAt] = useState<{ room: string; bed: string; rent: number } | null>(null);
  const { busy, run } = useAction();
  const { data, loading, error, reload } = useQuery(
    async (b) => {
      if (!id) return null;
      const property = await b.getProperty(id);
      if (!property) return null;
      const [tenants, payments, invoices, requests] = await Promise.all([b.listTenants({ propertyId: id }), b.listPayments(), b.listInvoices(), b.listRequests()]);
      return {
        property,
        tenants,
        payments: payments.filter((x) => x.propertyId === id),
        invoices: invoices.filter((x) => x.propertyId === id),
        requests: requests.filter((x) => x.propertyId === id),
      };
    },
    [id],
  );
  useEffect(() => {
    const t = new URLSearchParams(window.location.search).get("tab") as Tab | null;
    if (t) setTab(t);
  }, []);

  if (loading || id === null) {
    return (
      <Page error={error} onRetry={reload} title="Property">
        <Loading />
      </Page>
    );
  }
  if (!data) {
    return (
      <Page error={error} onRetry={reload} title="Property">
        <div className="glass card">
          <Empty icon={Building2} title="Property not found" body="It may have been removed, or you don't have access." action={<Link href="/dashboard/owner/properties/" className="btn btn-ghost">Back to properties</Link>} />
        </div>
      </Page>
    );
  }
  const { property: p, tenants, payments, invoices, requests } = data;
  const s = bedStats(p);
  const active = tenants.filter((t) => t.status === "active");
  const thisMonth = invoices.filter((i) => i.periodMonth === periodOf(new Date()));
  const collected = thisMonth.filter((i) => i.status === "paid").reduce((x, i) => x + i.amount, 0);
  const expected = thisMonth.reduce((x, i) => x + i.amount, 0);
  const openReq = requests.filter((r) => !["confirmed", "rejected"].includes(r.status));

  return (
    <Page error={error} onRetry={reload}
      title={p.name}
      sub={
        <span className="row" style={{ gap: 6 }}>
          <MapPin size={13} aria-hidden /> {p.city} · {genderLabel(p.gender)}
        </span>
      }
      actions={
        <>
          <Link href="/dashboard/owner/properties/" className="btn btn-ghost btn-sm">
            <ArrowLeft size={16} aria-hidden /> All properties
          </Link>
          {can.canEditProperties && (
            <Link href={`/dashboard/owner/property-form/?id=${p.id}`} className="btn btn-primary btn-sm">
              <Pencil size={15} aria-hidden /> Edit property
            </Link>
          )}
        </>
      }
    >
      <div style={{ borderRadius: "var(--radius-lg)", overflow: "hidden" }}>
      <Cover p={p} height={140}>
        <span style={{ position: "absolute", left: 16, bottom: 14, display: "flex", gap: 8 }}>
          <StatusBadge status={p.billingStatus} />
          {p.status === "inactive" && <StatusBadge status="inactive" />}
        </span>
      </Cover>
      </div>
      <Segmented<Tab>
        value={tab}
        onChange={setTab}
        options={[
          { value: "overview", label: "Overview" },
          { value: "layout", label: "Layout" },
          { value: "tenants", label: `Tenants (${active.length})` },
          { value: "payments", label: "Payments" },
          { value: "requests", label: `Requests${openReq.length ? ` (${openReq.length})` : ""}` },
          { value: "qr", label: "QR & listing" },
        ]}
      />

      {tab === "overview" && (
        <>
          <div className="grid-4">
            <Kpi icon={BedDouble} label="Occupancy" value={`${s.pct}%`} hint={`${s.occupied} of ${s.total} beds`} />
            <Kpi icon={Users} label="Tenants" value={active.length} hint={`${p.rooms.length} rooms`} />
            <Kpi icon={IndianRupee} label="Collected this month" value={money(collected)} hint={`of ${money(expected)}`} />
            <Kpi icon={Receipt} label="Platform billing" value={<StatusBadge status={p.billingStatus} />} hint={p.billingStatus === "paid" ? `Renews ${date(p.nextBillingDate)}` : `${s.total} beds × ${money(p.pricePerBed)}`} tone={p.billingStatus === "paid" ? undefined : "amber"} />
          </div>
          <div className="grid-2">
            <div className="glass card stack">
              <h2 className="h3" style={{ fontSize: 17 }}>
                About
              </h2>
              <p className="muted">{p.description || "No description yet."}</p>
              <dl className="kv">
                <dt>Address</dt>
                <dd>
                  {p.address}, {p.city} {p.pincode}
                </dd>
                {p.landmarks && (
                  <>
                    <dt>Landmark</dt>
                    <dd>{p.landmarks}</dd>
                  </>
                )}
                <dt>Deposit</dt>
                <dd>{money(p.pricing.deposit)}</dd>
                <dt>Maintenance</dt>
                <dd>{money(p.pricing.maintenance)}</dd>
                <dt>Food</dt>
                <dd>{p.food.included ? `${p.food.meals.join(", ")}` : "Not included"}</dd>
                <dt>Notice · lock-in</dt>
                <dd>
                  {p.rules.noticeDays} days · {p.rules.lockInMonths} months
                </dd>
                <dt>Gate closes</dt>
                <dd>{p.rules.gateClosesAt}</dd>
                <dt>Visitors · smoking</dt>
                <dd>
                  {p.rules.visitorsAllowed ? "Visitors allowed" : "No visitors"} · {p.rules.smokingAllowed ? "Smoking allowed" : "No smoking"}
                </dd>
              </dl>
            </div>
            <div className="stack">
              <div className="glass card">
                <h2 className="h3" style={{ fontSize: 17, marginBottom: 12 }}>
                  Amenities
                </h2>
                <div className="chips">
                  {p.amenities.map((a) => (
                    <span key={a} className="badge badge-green">
                      {a}
                    </span>
                  ))}
                </div>
              </div>
              <div className="glass card stack">
                <h2 className="h3" style={{ fontSize: 17 }}>
                  Actions
                </h2>
                <div className="chips">
                  {can.canManageTenants && (
                    <button className="btn btn-soft" onClick={() => setTab("layout")}>
                      <UserPlus size={16} aria-hidden /> Add tenant to a bed
                    </button>
                  )}
                  {can.canEditProperties && (
                    <button className="btn btn-ghost" disabled={busy} onClick={() => run((b) => b.setPropertyStatus(p.id, p.status === "active" ? "inactive" : "active"), p.status === "active" ? "Hidden from Explore" : "Listed on Explore")}>
                      {p.status === "active" ? <EyeOff size={16} /> : <Eye size={16} />} {p.status === "active" ? "Hide from Explore" : "List on Explore"}
                    </button>
                  )}
                  {can.canViewBilling && p.billingStatus !== "paid" && (
                    <Link href={`/dashboard/owner/billing/?checkout=${p.id}`} className="btn btn-primary">
                      <Receipt size={16} aria-hidden /> Activate property
                    </Link>
                  )}
                </div>
              </div>
            </div>
          </div>
        </>
      )}

      {tab === "layout" && <Layout p={p} tenants={tenants} canAdd={can.canManageTenants} onAdd={(room, bed, rent) => setAddAt({ room, bed, rent })} />}

      {tab === "tenants" && (
        <div className="glass card">
          {active.length === 0 ? (
            <Empty icon={Users} title="No tenants yet" body="Add a tenant from the Layout tab or accept a join request." />
          ) : (
            <div className="list">
              {active.map((t) => {
                const due = invoices.filter((i) => i.tenantId === t.id && i.status !== "paid");
                return (
                  <Link key={t.id} href={`/dashboard/owner/tenant/?id=${t.id}`} className="list-row">
                    <Avatar name={t.name} />
                    <div className="grow">
                      <div className="title">{t.name}</div>
                      <div className="meta">
                        Room {t.roomNumber} · Bed {t.bedNumber} · {money(t.monthlyRent)}/mo
                      </div>
                    </div>
                    {due.some((i) => i.status === "overdue") ? <StatusBadge status="overdue" /> : due.length ? <StatusBadge status="unpaid" /> : <StatusBadge status="paid" />}
                  </Link>
                );
              })}
            </div>
          )}
        </div>
      )}

      {tab === "payments" && (
        <div className="glass card">
          {payments.length === 0 ? (
            <Empty icon={IndianRupee} title="No payments yet" />
          ) : (
            <div className="table-wrap">
              <table className="table">
                <thead>
                  <tr>
                    <th>Tenant</th>
                    <th>Month</th>
                    <th>Method</th>
                    <th>Date</th>
                    <th style={{ textAlign: "right" }}>Amount</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {payments.slice(0, 50).map((x) => (
                    <tr key={x.id}>
                      <td>{x.tenantName}</td>
                      <td>{x.month}</td>
                      <td>{x.method}</td>
                      <td>{date(x.createdAt)}</td>
                      <td className="num" style={{ textAlign: "right", fontWeight: 650 }}>
                        {money(x.amount)}
                      </td>
                      <td>
                        <StatusBadge status={x.status} />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {tab === "requests" && (
        <div className="glass card">
          {requests.length === 0 ? (
            <Empty icon={Users} title="No join requests" body="Requests from the Explore tab and your QR code show up here." />
          ) : (
            <div className="list">
              {requests.map((r) => (
                <Link key={r.id} href={`/dashboard/owner/requests/?id=${r.id}`} className="list-row">
                  <Avatar name={r.tenantName} />
                  <div className="grow">
                    <div className="title">{r.tenantName}</div>
                    <div className="meta">
                      {r.sharing} · moves in {date(r.moveIn)}
                    </div>
                  </div>
                  <StatusBadge status={r.status} />
                </Link>
              ))}
            </div>
          )}
        </div>
      )}

      {tab === "qr" && <QrTab p={p} />}
      {addAt && <AddTenantModal propertyId={p.id} room={addAt} onClose={() => setAddAt(null)} />}
    </Page>
  );
}
