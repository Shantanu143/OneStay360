"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { AlertTriangle, Check, Download, FileText, IndianRupee, Wallet, X } from "lucide-react";
import { Page, useShell } from "@/components/dash/shell";
import { dueIn, RecordPaymentModal } from "@/components/dash/owner-forms";
import { Avatar } from "@/components/dash/widgets";
import { Confirm, Empty, Field, Kpi, Loading, Segmented, StatusBadge } from "@/components/ui";
import { useAction, useQuery, useToast } from "@/lib/hooks";
import { ago, date, money, periodOf } from "@/lib/format";
import { downloadCsv } from "@/lib/csv";
import { permissions } from "@/lib/permissions";

type Tab = "verify" | "dues" | "history";

export default function PaymentsPage() {
  const { account } = useShell();
  const can = permissions(account.role);
  const toast = useToast();
  const [tab, setTab] = useState<Tab>("verify");
  const [recordFor, setRecordFor] = useState<string | null | undefined>(undefined);
  const [rejecting, setRejecting] = useState<string | null>(null);
  const [reason, setReason] = useState("");
  const [method, setMethod] = useState("all");
  const { busy, run } = useAction();
  const { data, loading } = useQuery(async (b) => {
    const [payments, invoices] = await Promise.all([b.listPayments(), b.listInvoices()]);
    return { payments, invoices };
  });
  useEffect(() => {
    const t = new URLSearchParams(window.location.search).get("tab") as Tab | null;
    if (t) setTab(t);
  }, []);

  const pending = data?.payments.filter((p) => p.status === "pending") ?? [];
  const dues = (data?.invoices.filter((i) => i.status !== "paid") ?? []).sort((a, b) => a.dueDate - b.dueDate);
  const history = (data?.payments ?? []).filter((p) => method === "all" || p.method === method);
  const period = periodOf(new Date());
  const monthPaid = data?.payments.filter((p) => p.status === "paid" && periodOf(new Date(p.createdAt)) === period).reduce((s, p) => s + p.amount, 0) ?? 0;
  const overdueTotal = dues.filter((i) => i.status === "overdue").reduce((s, i) => s + i.amount, 0);

  const exportCsv = () => {
    downloadCsv(`payments-${period}.csv`, [["Date", "Tenant", "Property", "Month", "Method", "Reference", "Amount", "Status"], ...history.map((p) => [date(p.createdAt), p.tenantName, p.propertyName, p.month, p.method, p.reference, p.amount, p.status])]);
  };

  return (
    <Page
      title="Rent & payments"
      sub="Verify UPI and cash, chase dues, record what you received"
      actions={
        can.canVerifyPayments && (
          <>
            <button
              className="btn btn-ghost btn-sm hide-sm"
              disabled={busy}
              onClick={async () => {
                const r = await run((b) => b.generateInvoices());
                if (r.ok) toast(r.value ? `${r.value} invoice${r.value > 1 ? "s" : ""} generated` : "This month's invoices already exist", "success");
              }}
            >
              <FileText size={15} /> Generate invoices
            </button>
            <button className="btn btn-primary btn-sm" onClick={() => setRecordFor(null)}>
              <Wallet size={15} /> Record
            </button>
          </>
        )
      }
    >
      <div className="grid-3">
        <Kpi icon={IndianRupee} label="Received this month" value={money(monthPaid)} />
        <Kpi icon={Wallet} label="Waiting to verify" value={pending.length} hint={money(pending.reduce((s, p) => s + p.amount, 0))} tone={pending.length ? "amber" : undefined} />
        <Kpi icon={AlertTriangle} label="Overdue" value={money(overdueTotal)} hint={`${dues.filter((i) => i.status === "overdue").length} invoices`} tone={overdueTotal ? "red" : undefined} />
      </div>
      <Segmented<Tab>
        value={tab}
        onChange={setTab}
        options={[
          { value: "verify", label: `To verify${pending.length ? ` (${pending.length})` : ""}` },
          { value: "dues", label: `Dues (${dues.length})` },
          { value: "history", label: "All payments" },
        ]}
      />
      <div className="glass card">
        {loading ? (
          <Loading />
        ) : tab === "verify" ? (
          pending.length === 0 ? (
            <Empty icon={Check} title="Nothing to verify" body="When tenants report a UPI or cash payment, match it with your bank or UPI app and confirm it here. Online payments confirm themselves." />
          ) : (
            <div className="list">
              {pending.map((p) => (
                <div key={p.id} className="list-row wrap">
                  <Avatar name={p.tenantName} />
                  <div className="grow" style={{ minWidth: 200 }}>
                    <div className="title">
                      {p.tenantName} · {money(p.amount)}
                    </div>
                    <div className="meta">
                      {p.method} {p.reference ? `· UTR ${p.reference}` : ""} · {p.month} · {p.propertyName} · {ago(p.createdAt)}
                    </div>
                  </div>
                  {can.canVerifyPayments ? (
                    <div className="row" style={{ gap: 8 }}>
                      <button className="btn btn-danger btn-sm" onClick={() => setRejecting(p.id)}>
                        <X size={14} /> Reject
                      </button>
                      <button className="btn btn-primary btn-sm" disabled={busy} onClick={() => run((b) => b.verifyPayment(p.id, "approve"), `${money(p.amount)} from ${p.tenantName} verified`)}>
                        <Check size={14} /> Confirm
                      </button>
                    </div>
                  ) : (
                    <StatusBadge status="pending" />
                  )}
                </div>
              ))}
            </div>
          )
        ) : tab === "dues" ? (
          dues.length === 0 ? (
            <Empty icon={Check} title="No dues" body="Every invoice is paid." />
          ) : (
            <div className="table-wrap">
              <table className="table">
                <thead>
                  <tr>
                    <th>Tenant</th>
                    <th>Month</th>
                    <th>Due</th>
                    <th style={{ textAlign: "right" }}>Amount</th>
                    <th>Status</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {dues.map((i) => (
                    <tr key={i.id}>
                      <td>
                        <Link href={`/dashboard/owner/tenant/?id=${i.tenantId}`} style={{ fontWeight: 600 }}>
                          {i.tenantName}
                        </Link>
                      </td>
                      <td>{i.month}</td>
                      <td>
                        {date(i.dueDate)} <span className="faint">({dueIn(i.dueDate)})</span>
                      </td>
                      <td className="num" style={{ textAlign: "right", fontWeight: 650 }}>
                        {money(i.amount)}
                      </td>
                      <td>
                        <StatusBadge status={i.status} />
                      </td>
                      <td>
                        {can.canVerifyPayments && (
                          <button className="btn btn-soft btn-sm" onClick={() => setRecordFor(i.tenantId)}>
                            Record
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )
        ) : (
          <>
            <div className="row-between wrap" style={{ marginBottom: 12 }}>
              <div className="chips">
                {["all", "Online", "UPI", "Cash", "Bank Transfer", "Cheque"].map((m) => (
                  <button key={m} className="chip" aria-pressed={method === m} onClick={() => setMethod(m)}>
                    {m === "all" ? "All methods" : m}
                  </button>
                ))}
              </div>
              <button className="btn btn-ghost btn-sm" onClick={exportCsv}>
                <Download size={15} /> Export CSV
              </button>
            </div>
            {history.length === 0 ? (
              <Empty icon={Wallet} title="No payments" />
            ) : (
              <div className="table-wrap">
                <table className="table">
                  <thead>
                    <tr>
                      <th>Date</th>
                      <th>Tenant</th>
                      <th>Month</th>
                      <th>Method</th>
                      <th>Reference</th>
                      <th style={{ textAlign: "right" }}>Amount</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {history.slice(0, 200).map((p) => (
                      <tr key={p.id}>
                        <td>{date(p.createdAt)}</td>
                        <td>
                          <Link href={`/dashboard/owner/tenant/?id=${p.tenantId}`}>{p.tenantName}</Link>
                        </td>
                        <td>{p.month}</td>
                        <td>{p.method}</td>
                        <td className="faint">{p.reference ?? "—"}</td>
                        <td className="num" style={{ textAlign: "right", fontWeight: 650 }}>
                          {money(p.amount)}
                        </td>
                        <td>
                          <StatusBadge status={p.status} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </>
        )}
      </div>
      {recordFor !== undefined && <RecordPaymentModal tenantId={recordFor ?? undefined} onClose={() => setRecordFor(undefined)} />}
      {rejecting && (
        <Confirm
          title="Reject this payment?"
          body="The tenant sees your reason and the invoice stays open."
          confirmLabel="Reject"
          danger
          busy={busy}
          onClose={() => setRejecting(null)}
          onConfirm={() =>
            run((b) => b.verifyPayment(rejecting, "reject", reason), "Payment rejected").then((r) => {
              if (r.ok) {
                setRejecting(null);
                setReason("");
              }
            })
          }
        >
          <Field label="Reason">
            <input className="input" value={reason} onChange={(e) => setReason(e.target.value)} placeholder="e.g. No credit with this UTR" />
          </Field>
        </Confirm>
      )}
    </Page>
  );
}
