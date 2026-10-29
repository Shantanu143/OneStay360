"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { MailOpen, UserPlus, Users, X } from "lucide-react";
import { Page, useShell } from "@/components/dash/shell";
import { AddTenantModal } from "@/components/dash/owner-forms";
import { Avatar } from "@/components/dash/widgets";
import { Empty, Field, Loading, SearchField, Segmented, StatusBadge } from "@/components/ui";
import { useAction, useQuery } from "@/lib/hooks";
import { date, money } from "@/lib/format";
import { permissions } from "@/lib/permissions";

type Tab = "active" | "invitations" | "past";

export default function TenantsPage() {
  const { account } = useShell();
  const can = permissions(account.role);
  const [tab, setTab] = useState<Tab>("active");
  const [q, setQ] = useState("");
  const [property, setProperty] = useState("all");
  const [adding, setAdding] = useState(false);
  const { busy, run } = useAction();
  const { data, loading, error, reload } = useQuery(async (b) => {
    const [tenants, invitations, properties, invoices] = await Promise.all([b.listTenants(), b.listTenantInvitations(), b.listProperties(), b.listInvoices()]);
    return { tenants, invitations, properties, invoices };
  });
  useEffect(() => {
    const t = new URLSearchParams(window.location.search).get("tab") as Tab | null;
    if (t) setTab(t);
  }, []);

  const match = (s: string) => s.toLowerCase().includes(q.toLowerCase());
  const tenants = (data?.tenants ?? []).filter((t) => (tab === "past" ? t.status === "vacated" : t.status === "active")).filter((t) => property === "all" || t.propertyId === property).filter((t) => match([t.name, t.phone, t.roomNumber, t.propertyName].join(" ")));
  const invitations = (data?.invitations ?? []).filter((i) => property === "all" || i.propertyId === property).filter((i) => match([i.tenantName, i.tenantPhone, i.roomNumber].join(" ")));
  const pendingInv = data?.invitations.filter((i) => i.status === "pending").length ?? 0;

  return (
    <Page error={error} onRetry={reload}
      title="Tenants"
      sub={data ? `${data.tenants.filter((t) => t.status === "active").length} active · ${pendingInv} invitation${pendingInv === 1 ? "" : "s"} pending` : undefined}
      actions={
        can.canManageTenants && (
          <button className="btn btn-primary btn-sm" onClick={() => setAdding(true)}>
            <UserPlus size={16} aria-hidden /> Add a tenant
          </button>
        )
      }
    >
      <div className="row-between wrap">
        <Segmented<Tab>
          value={tab}
          onChange={setTab}
          options={[
            { value: "active", label: "Active" },
            { value: "invitations", label: `Invitations${pendingInv ? ` (${pendingInv})` : ""}` },
            { value: "past", label: "Past" },
          ]}
        />
        <div className="filters" style={{ flex: "1 1 420px", justifyContent: "flex-end" }}>
          <Field label="Property">
          <select className="select" value={property} onChange={(e) => setProperty(e.target.value)}>
            <option value="all">All properties</option>
            {data?.properties.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
          </Field>
          <SearchField label="Search tenants" value={q} onChange={setQ} placeholder="Name, phone or room" />
        </div>
      </div>
      <div className="glass card">
        {loading ? (
          <Loading />
        ) : tab === "invitations" ? (
          invitations.length === 0 ? (
            <Empty icon={MailOpen} title="No invitations" body="Invite a tenant to a bed; they accept from the tenant app or web." />
          ) : (
            <div className="list">
              {invitations.map((i) => (
                <div key={i.id} className="list-row">
                  <Avatar name={i.tenantName} />
                  <div className="grow">
                    <div className="title">{i.tenantName}</div>
                    <div className="meta">
                      {i.propertyName} · Room {i.roomNumber} · Bed {i.bedNumber} · {money(i.monthlyRent)}/mo · moves in {date(i.moveIn)}
                    </div>
                    {i.reason && <div className="meta">“{i.reason}”</div>}
                  </div>
                  <StatusBadge status={i.status} />
                  {i.status === "pending" && can.canManageTenants && (
                    <button className="btn btn-ghost btn-sm" disabled={busy} onClick={() => run((b) => b.cancelTenantInvitation(i.id), "Invitation cancelled")}>
                      <X size={14} /> Cancel
                    </button>
                  )}
                  {i.status === "accepted" && i.tenantId && (
                    <Link href={`/dashboard/owner/tenant/?id=${i.tenantId}`} className="btn btn-ghost btn-sm">
                      View tenant
                    </Link>
                  )}
                </div>
              ))}
            </div>
          )
        ) : tenants.length === 0 ? (
          <Empty icon={Users} title={tab === "past" ? "No past tenants" : "No tenants found"} body={tab === "active" && !q ? "Add a tenant or approve a join request." : undefined} />
        ) : (
          <div className="table-wrap">
            <table className="table">
              <thead>
                <tr>
                  <th>Tenant</th>
                  <th>Property</th>
                  <th>Bed</th>
                  <th style={{ textAlign: "right" }}>Rent</th>
                  <th>{tab === "past" ? "Moved out" : "Rent status"}</th>
                </tr>
              </thead>
              <tbody>
                {tenants.map((t) => {
                  const open = data!.invoices.filter((i) => i.tenantId === t.id && i.status !== "paid");
                  return (
                    <tr key={t.id}>
                      <td>
                        <Link href={`/dashboard/owner/tenant/?id=${t.id}`} className="row" style={{ gap: 10 }}>
                          <Avatar name={t.name} />
                          <span>
                            <b style={{ display: "block" }}>{t.name}</b>
                            <span className="faint" style={{ fontSize: 14 }}>
                              {t.id} · {t.phone}
                            </span>
                          </span>
                        </Link>
                      </td>
                      <td>{t.propertyName}</td>
                      <td>
                        {t.roomNumber}-{t.bedNumber}
                      </td>
                      <td className="num" style={{ textAlign: "right" }}>
                        {money(t.monthlyRent)}
                      </td>
                      <td>{tab === "past" ? date(t.moveOut) : open.some((i) => i.status === "overdue") ? <StatusBadge status="overdue" /> : open.length ? <StatusBadge status="unpaid" /> : <StatusBadge status="paid" />}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
      {adding && <AddTenantModal onClose={() => setAdding(false)} />}
    </Page>
  );
}
