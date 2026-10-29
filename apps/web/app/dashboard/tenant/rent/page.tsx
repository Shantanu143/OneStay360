"use client";
import Link from "next/link";
import { useState } from "react";
import { Banknote, Check, Copy, CreditCard, Smartphone, Wallet } from "lucide-react";
import { Page } from "@/components/dash/shell";
import { Empty, Field, Loading, Modal, StatusBadge } from "@/components/ui";
import { useAction, useQuery, useToast } from "@/lib/hooks";
import { date, money } from "@/lib/format";
import type { RentInvoice } from "@/lib/types";

function PayModal({ inv, settings, onClose }: { inv: RentInvoice; settings: { onlineEnabled: boolean; upiId?: string }; onClose: () => void }) {
  const [mode, setMode] = useState<"online" | "UPI" | "Cash">(settings.onlineEnabled ? "online" : "UPI");
  const [reference, setReference] = useState("");
  const [amount, setAmount] = useState(inv.amount);
  const { busy, run } = useAction();
  const toast = useToast();
  const [checkout, setCheckout] = useState(false);
  const upiLink = settings.upiId ? `upi://pay?pa=${encodeURIComponent(settings.upiId)}&am=${amount}&cu=INR&tn=${encodeURIComponent(`Rent ${inv.month}`)}` : undefined;

  const submit = () =>
    mode === "online"
      ? run((b) => b.payOnline(inv.id), `Paid ${money(inv.amount)} for ${inv.month}`).then((r) => r.ok && onClose())
      : run((b) => b.submitRentPayment({ amount, month: inv.month, mode, reference, invoiceId: inv.id }), "Sent to your owner to confirm").then((r) => r.ok && onClose());

  return (
    <Modal
      title={`Pay ${inv.month} rent`}
      subtitle={`${money(inv.amount)} · due ${date(inv.dueDate)}`}
      onClose={onClose}
      footer={
        <>
          <button className="btn btn-ghost" onClick={onClose}>
            Cancel
          </button>
          {mode === "online" && !checkout ? (
            <button className="btn btn-primary" onClick={() => setCheckout(true)}>
              <CreditCard size={16} /> Continue to pay {money(inv.amount)}
            </button>
          ) : (
            <button className="btn btn-primary" disabled={busy} onClick={submit}>
              {mode === "online" ? "Complete payment" : mode === "UPI" ? "I've paid — notify owner" : "Report cash payment"}
            </button>
          )}
        </>
      }
    >
      <div className="chips" style={{ marginBottom: 16 }}>
        {settings.onlineEnabled && (
          <button className="chip" aria-pressed={mode === "online"} onClick={() => setMode("online")}>
            <CreditCard size={14} /> Pay online
          </button>
        )}
        <button className="chip" aria-pressed={mode === "UPI"} onClick={() => setMode("UPI")}>
          <Smartphone size={14} /> UPI
        </button>
        <button className="chip" aria-pressed={mode === "Cash"} onClick={() => setMode("Cash")}>
          <Banknote size={14} /> Cash
        </button>
      </div>
      {mode === "online" ? (
        checkout ? (
          <div className="alert alert-blue">In production this opens a secure Razorpay payment page (createPaymentLink); the invoice closes when the payment is captured. In demo mode, completing pays instantly.</div>
        ) : (
          <p className="muted">Pay by card, UPI or netbanking through a secure link. Your invoice is marked paid automatically — no screenshot needed.</p>
        )
      ) : mode === "UPI" ? (
        <div className="stack">
          {settings.upiId ? (
            <div className="glass card-tight row-between">
              <div>
                <div className="faint" style={{ fontSize: 12 }}>
                  Pay to
                </div>
                <b>{settings.upiId}</b>
              </div>
              <div className="row" style={{ gap: 6 }}>
                <button className="icon-btn" aria-label="Copy UPI ID" onClick={() => navigator.clipboard?.writeText(settings.upiId!).then(() => toast("UPI ID copied", "success"))}>
                  <Copy size={15} />
                </button>
                {upiLink && (
                  <a className="btn btn-soft btn-sm" href={upiLink}>
                    Open UPI app
                  </a>
                )}
              </div>
            </div>
          ) : (
            <div className="alert alert-amber">Your owner hasn&apos;t added a UPI ID yet. Ask them for payment details.</div>
          )}
          <div className="form-grid">
            <Field label="Amount paid (₹)">
              <input className="input" type="number" value={amount} onChange={(e) => setAmount(+e.target.value)} />
            </Field>
            <Field label="UPI transaction ID (UTR)" hint="12 digits, in your UPI app's payment details.">
              <input className="input" value={reference} onChange={(e) => setReference(e.target.value)} placeholder="e.g. 412345678901" />
            </Field>
          </div>
        </div>
      ) : (
        <div className="stack">
          <p className="muted">Paid cash at the PG? Report it so your owner can confirm and close the invoice.</p>
          <Field label="Amount paid (₹)">
            <input className="input" type="number" value={amount} onChange={(e) => setAmount(+e.target.value)} />
          </Field>
        </div>
      )}
    </Modal>
  );
}

export default function RentPage() {
  const [paying, setPaying] = useState<RentInvoice | null>(null);
  const { data, loading } = useQuery(async (b) => {
    const stay = await b.getStay();
    const [invoices, payments, settings] = await Promise.all([b.listMyInvoices(), b.listMyPayments(), stay ? b.paymentSettings(stay.tenant.businessId) : Promise.resolve({ onlineEnabled: false })]);
    return { stay, invoices, payments, settings };
  });
  if (loading || !data) {
    return (
      <Page title="Rent & payments">
        <Loading rows={4} />
      </Page>
    );
  }
  const { stay, invoices, payments, settings } = data;
  const open = invoices.filter((i) => i.status !== "paid").sort((a, b) => a.dueDate - b.dueDate);
  const pendingFor = (inv: RentInvoice) => payments.find((p) => p.status === "pending" && (p.invoiceId === inv.id || p.month === inv.month));
  return (
    <Page title="Rent & payments" sub={stay ? `${money(stay.tenant.monthlyRent)} / month · due on day ${stay.tenant.billingDay}` : undefined}>
      {!stay && payments.length === 0 ? (
        <div className="glass card">
          <Empty icon={Wallet} title="No rent yet" body="Once you have a stay, your monthly invoices appear here." action={<Link href="/dashboard/tenant/explore/" className="btn btn-primary">Explore PGs</Link>} />
        </div>
      ) : (
        <>
          <div className="glass card">
            <div className="section-title">
              <h2>To pay</h2>
              {settings.onlineEnabled && <span className="badge badge-green">Online payments accepted</span>}
            </div>
            {open.length === 0 ? (
              <Empty icon={Check} title="You're all paid up" body="Nice. We'll notify you when the next invoice is raised." />
            ) : (
              <div className="list">
                {open.map((i) => {
                  const pending = pendingFor(i);
                  return (
                    <div key={i.id} className="list-row wrap">
                      <span className={`tile-ic ${i.status === "overdue" ? "red" : "blue"}`}>
                        <Wallet size={18} />
                      </span>
                      <div className="grow" style={{ minWidth: 180 }}>
                        <div className="title">
                          {i.month} · {money(i.amount)}
                        </div>
                        <div className="meta">Due {date(i.dueDate)}</div>
                      </div>
                      {pending ? <span className="badge badge-amber">{pending.method} payment awaiting confirmation</span> : <StatusBadge status={i.status} />}
                      {!pending && (
                        <button className="btn btn-primary btn-sm" onClick={() => setPaying(i)}>
                          Pay
                        </button>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </div>
          <div className="glass card">
            <div className="section-title">
              <h2>Payment history</h2>
            </div>
            {payments.length === 0 ? (
              <Empty icon={Wallet} title="No payments yet" />
            ) : (
              <div className="table-wrap">
                <table className="table">
                  <thead>
                    <tr>
                      <th>Date</th>
                      <th>For</th>
                      <th>Method</th>
                      <th>Reference</th>
                      <th style={{ textAlign: "right" }}>Amount</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {payments.map((p) => (
                      <tr key={p.id}>
                        <td>{date(p.createdAt)}</td>
                        <td>{p.note ?? p.month}</td>
                        <td>{p.method}</td>
                        <td className="faint">{p.reference ?? "—"}</td>
                        <td className="num" style={{ textAlign: "right", fontWeight: 650 }}>
                          {money(p.amount)}
                        </td>
                        <td>
                          <StatusBadge status={p.status} />
                          {p.rejectionReason && <div className="faint" style={{ fontSize: 12, whiteSpace: "normal" }}>{p.rejectionReason}</div>}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>
      )}
      {paying && <PayModal inv={paying} settings={settings} onClose={() => setPaying(null)} />}
    </Page>
  );
}
