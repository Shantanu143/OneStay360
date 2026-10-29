"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { ArrowLeft, LogOut, MessageCircle, Pencil, Phone, Users, Wallet } from "lucide-react";
import { Page, useShell } from "@/components/dash/shell";
import { RecordPaymentModal } from "@/components/dash/owner-forms";
import { Avatar, categoryLabels } from "@/components/dash/widgets";
import { Confirm, Empty, Field, Loading, Modal, StatusBadge } from "@/components/ui";
import { useAction, useQuery } from "@/lib/hooks";
import { date, fromInputDate, money, toInputDate } from "@/lib/format";
import { permissions } from "@/lib/permissions";

export default function TenantDetailPage() {
  const { account } = useShell();
  const can = permissions(account.role);
  const [id, setId] = useState<string | null>(null);
  const [modal, setModal] = useState<"pay" | "edit" | "vacate" | null>(null);
  const { busy, run } = useAction();
  useEffect(() => setId(new URLSearchParams(window.location.search).get("id")), []);
  const { data, loading, error, reload } = useQuery(
    async (b) => {
      if (!id) return null;
      const tenant = await b.getTenant(id);
      if (!tenant) return null;
      const [invoices, payments, maintenance] = await Promise.all([b.listInvoices({ tenantId: id }), b.listPayments({ tenantId: id }), b.listMaintenance()]);
      return { tenant, invoices, payments, maintenance: maintenance.filter((m) => m.tenantId === id) };
    },
    [id],
  );
  const [edit, setEdit] = useState({ name: "", phone: "", email: "", monthlyRent: 0, billingDay: 1, occupation: "", emergencyContact: "" });
  const [moveOut, setMoveOut] = useState(toInputDate(Date.now()));

  if (loading || !id) {
    return (
      <Page error={error} onRetry={reload} title="Tenant">
        <Loading />
      </Page>
    );
  }
  if (!data) {
    return (
      <Page error={error} onRetry={reload} title="Tenant">
        <div className="glass card">
          <Empty icon={Users} title="Tenant not found" action={<Link href="/dashboard/owner/tenants/" className="btn btn-ghost">Back to tenants</Link>} />
        </div>
      </Page>
    );
  }
  const { tenant: t, invoices, payments, maintenance } = data;
  const due = invoices.filter((i) => i.status !== "paid");
  const dueTotal = due.reduce((s, i) => s + i.amount, 0);
  const paidTotal = payments.filter((p) => p.status === "paid").reduce((s, p) => s + p.amount, 0);

  return (
    <Page error={error} onRetry={reload}
      title={t.name}
      sub={`${t.id} · ${t.propertyName}`}
      actions={
        <Link href="/dashboard/owner/tenants/" className="btn btn-ghost btn-sm">
          <ArrowLeft size={16} aria-hidden /> All tenants
        </Link>
      }
    >
      <div className="cols-wr">
        <div className="glass card stack">
          <div className="row">
            <Avatar name={t.name} size="lg" />
            <div>
              <h2 className="h3">{t.name}</h2>
              <div className="row" style={{ gap: 6, marginTop: 4 }}>
                <StatusBadge status={t.status} />
                {t.uid ? <span className="badge badge-blue">On the app</span> : <span className="badge badge-grey">No app</span>}
              </div>
            </div>
          </div>
          <div className="row wrap" style={{ gap: 8 }}>
            <a className="btn btn-ghost btn-sm" href={`tel:+91${t.phone}`}>
              <Phone size={15} aria-hidden /> Call
            </a>
            <a className="btn btn-ghost btn-sm" href={`https://wa.me/91${t.phone}`} target="_blank" rel="noreferrer">
              <MessageCircle size={15} aria-hidden /> WhatsApp
            </a>
            {t.status === "active" && can.canManageTenants && (
              <button
                className="btn btn-ghost btn-sm"
                onClick={() => {
                  setEdit({ name: t.name, phone: t.phone, email: t.email, monthlyRent: t.monthlyRent, billingDay: t.billingDay, occupation: t.occupation ?? "", emergencyContact: t.emergencyContact ?? "" });
                  setModal("edit");
                }}
              >
                <Pencil size={15} aria-hidden /> Edit details
              </button>
            )}
          </div>
          <dl className="kv">
            <dt>Phone</dt>
            <dd>{t.phone}</dd>
            <dt>Email</dt>
            <dd>{t.email || "—"}</dd>
            <dt>Occupation</dt>
            <dd>{t.occupation || "—"}</dd>
            <dt>Emergency contact</dt>
            <dd>{t.emergencyContact || "—"}</dd>
            <dt>Bed</dt>
            <dd>
              Room {t.roomNumber} · Bed {t.bedNumber}
            </dd>
            <dt>Moved in</dt>
            <dd>{date(t.moveIn)}</dd>
            {t.moveOut && (
              <>
                <dt>Moved out</dt>
                <dd>{date(t.moveOut)}</dd>
              </>
            )}
            <dt>Rent</dt>
            <dd>{money(t.monthlyRent)} / month</dd>
            <dt>Billing day</dt>
            <dd>{t.billingDay}</dd>
            <dt>Deposit held</dt>
            <dd>{money(t.deposit)}</dd>
          </dl>
          {t.status === "active" && can.canVacateTenants && (
            <button className="btn btn-danger" onClick={() => setModal("vacate")}>
              <LogOut size={16} aria-hidden /> Vacate tenant
            </button>
          )}
        </div>
        <div className="stack-lg">
          <div className="grid-2">
            <div className={`glass kpi ${dueTotal ? "" : "kpi-hero"}`}>
              <div className="label">Outstanding</div>
              <div className="value num" style={{ color: dueTotal ? "var(--tint-red-ink)" : undefined }}>
                {money(dueTotal)}
              </div>
              <div className="hint">{due.length ? `${due.length} open invoice${due.length > 1 ? "s" : ""}` : "All rent paid"}</div>
            </div>
            <div className="glass kpi">
              <div className="label">Paid to date</div>
              <div className="value num">{money(paidTotal)}</div>
              <div className="hint">{payments.filter((p) => p.status === "paid").length} payments</div>
            </div>
          </div>
          <div className="glass card">
            <div className="section-title">
              <h2>Rent invoices</h2>
              {t.status === "active" && can.canVerifyPayments && (
                <button className="btn btn-primary btn-sm" onClick={() => setModal("pay")}>
                  <Wallet size={15} aria-hidden /> Record payment
                </button>
              )}
            </div>
            <div className="table-wrap">
              <table className="table">
                <thead>
                  <tr>
                    <th>Month</th>
                    <th>Due</th>
                    <th style={{ textAlign: "right" }}>Amount</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {invoices.map((i) => (
                    <tr key={i.id}>
                      <td>{i.month}</td>
                      <td>{date(i.dueDate)}</td>
                      <td className="num" style={{ textAlign: "right" }}>
                        {money(i.amount)}
                      </td>
                      <td>
                        <StatusBadge status={i.status} />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
          <div className="glass card">
            <div className="section-title">
              <h2>Payments</h2>
            </div>
            {payments.length === 0 ? (
              <Empty icon={Wallet} title="No payments yet" />
            ) : (
              <div className="list">
                {payments.map((p) => (
                  <div key={p.id} className="list-row">
                    <div className="grow">
                      <div className="title">
                        {money(p.amount)} · {p.month}
                      </div>
                      <div className="meta">
                        {p.method}
                        {p.reference ? ` · ${p.reference}` : ""} · {date(p.createdAt)}
                        {p.rejectionReason ? ` · ${p.rejectionReason}` : ""}
                      </div>
                    </div>
                    <StatusBadge status={p.status} />
                  </div>
                ))}
              </div>
            )}
          </div>
          {maintenance.length > 0 && (
            <div className="glass card">
              <div className="section-title">
                <h2>Maintenance</h2>
              </div>
              <div className="list">
                {maintenance.map((m) => (
                  <div key={m.id} className="list-row">
                    <div className="grow">
                      <div className="title">{m.title}</div>
                      <div className="meta">
                        {categoryLabels[m.category]} · {date(m.createdAt)}
                      </div>
                    </div>
                    <StatusBadge status={m.status} />
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>

      {modal === "pay" && <RecordPaymentModal tenantId={t.id} onClose={() => setModal(null)} />}
      {modal === "edit" && (
        <Modal
          title="Edit tenant"
          onClose={() => setModal(null)}
          footer={
            <>
              <button className="btn btn-ghost" onClick={() => setModal(null)}>
                Cancel
              </button>
              <button className="btn btn-primary" disabled={busy} onClick={() => run((b) => b.updateTenant(t.id, edit), "Tenant updated").then((r) => r.ok && setModal(null))}>
                Save changes
              </button>
            </>
          }
        >
          <div className="form-grid">
            <Field label="Name" full>
              <input className="input" value={edit.name} onChange={(e) => setEdit({ ...edit, name: e.target.value })} />
            </Field>
            <Field label="Phone">
              <input className="input" value={edit.phone} onChange={(e) => setEdit({ ...edit, phone: e.target.value })} />
            </Field>
            <Field label="Email">
              <input className="input" value={edit.email} onChange={(e) => setEdit({ ...edit, email: e.target.value })} />
            </Field>
            <Field label="Monthly rent (₹)" hint="Applies from the next invoice.">
              <input className="input" type="number" value={edit.monthlyRent} onChange={(e) => setEdit({ ...edit, monthlyRent: +e.target.value })} />
            </Field>
            <Field label="Billing day">
              <input className="input" type="number" min={1} max={28} value={edit.billingDay} onChange={(e) => setEdit({ ...edit, billingDay: +e.target.value })} />
            </Field>
            <Field label="Occupation">
              <input className="input" value={edit.occupation} onChange={(e) => setEdit({ ...edit, occupation: e.target.value })} />
            </Field>
            <Field label="Emergency contact">
              <input className="input" value={edit.emergencyContact} onChange={(e) => setEdit({ ...edit, emergencyContact: e.target.value })} />
            </Field>
          </div>
        </Modal>
      )}
      {modal === "vacate" && (
        <Confirm
          title={`Vacate ${t.name}?`}
          body={`Room ${t.roomNumber} · Bed ${t.bedNumber} becomes free and their stay ends. ${dueTotal ? `They still owe ${money(dueTotal)}.` : ""}`}
          confirmLabel="Vacate"
          danger
          busy={busy}
          onClose={() => setModal(null)}
          onConfirm={() => run((b) => b.vacateTenant(t.id, fromInputDate(moveOut)), `${t.name} vacated`).then((r) => r.ok && setModal(null))}
        >
          <Field label="Move-out date">
            <input className="input" type="date" value={moveOut} onChange={(e) => setMoveOut(e.target.value)} />
          </Field>
        </Confirm>
      )}
    </Page>
  );
}
