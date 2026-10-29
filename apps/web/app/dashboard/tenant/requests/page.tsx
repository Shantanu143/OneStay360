"use client";
import Link from "next/link";
import { useState } from "react";
import { Check, Copy, KeyRound, Search, Trash2 } from "lucide-react";
import { Page } from "@/components/dash/shell";
import { Confirm, Empty, Field, Loading, StatusBadge } from "@/components/ui";
import { useAction, useQuery, useToast } from "@/lib/hooks";
import { ago, cls, date, money } from "@/lib/format";
import type { EnrollmentRequest } from "@/lib/types";

const steps = [
  ["pending", "Request sent", "The owner is reviewing your request."],
  ["approved", "Approved", "A bed is reserved for you."],
  ["bill_sent", "First bill", "Pay rent, deposit and maintenance to confirm."],
  ["payment_submitted", "Payment submitted", "The owner is matching your payment."],
  ["confirmed", "Confirmed", "Welcome home!"],
] as const;

function RequestCard({ r }: { r: EnrollmentRequest }) {
  const { busy, run } = useAction();
  const toast = useToast();
  const [utr, setUtr] = useState("");
  const [withdraw, setWithdraw] = useState(false);
  const idx = steps.findIndex(([s]) => s === r.status);
  return (
    <div className="glass card stack-lg">
      <div className="row-between wrap">
        <div>
          <h2 className="h3">{r.propertyName}</h2>
          <div className="faint" style={{ fontSize: 13 }}>
            Requested {ago(r.createdAt)} · moving in {date(r.moveIn)} · {r.sharing}
          </div>
        </div>
        <StatusBadge status={r.status} />
      </div>
      {r.status === "rejected" ? (
        <div className="alert alert-red">The owner declined: {r.rejectionReason}</div>
      ) : (
        <div className="cols-wr" style={{ alignItems: "start" }}>
          <div className="timeline">
            {steps.map(([s, label, hint], i) => (
              <div key={s} className={cls("tl-item", (i < idx || r.status === "confirmed") && "done", i === idx && r.status !== "confirmed" && "current")}>
                <span className="tl-dot">{i < idx || r.status === "confirmed" ? <Check size={13} /> : i + 1}</span>
                <div>
                  <div style={{ fontSize: 14, fontWeight: i === idx ? 700 : 550, color: i > idx ? "var(--ink-faint)" : undefined }}>{label}</div>
                  {i === idx && <div className="faint" style={{ fontSize: 12.5 }}>{hint}</div>}
                </div>
              </div>
            ))}
          </div>
          <div className="stack">
            {r.roomNumber && (
              <div className="glass card-tight">
                <dl className="kv">
                  <dt>Bed</dt>
                  <dd>
                    Room {r.roomNumber} · Bed {r.bedNumber}
                  </dd>
                  <dt>Monthly rent</dt>
                  <dd>{money(r.monthlyRent ?? 0)}</dd>
                  <dt>Security deposit</dt>
                  <dd>{money(r.deposit ?? 0)}</dd>
                  <dt>Maintenance</dt>
                  <dd>{money(r.maintenance ?? 0)}</dd>
                  <dt style={{ fontWeight: 700, color: "var(--ink)" }}>Total first bill</dt>
                  <dd style={{ fontSize: 18, color: "var(--brand)" }}>{money(r.total ?? 0)}</dd>
                </dl>
              </div>
            )}
            {r.status === "bill_sent" && (
              <>
                {r.paymentRejectionReason && <div className="alert alert-red">Your last payment wasn&apos;t found: {r.paymentRejectionReason}. Please check and resubmit.</div>}
                {r.paymentMode === "cash" ? (
                  <div className="alert alert-blue">Pay {money(r.total ?? 0)} in cash at the PG. The owner confirms it there.</div>
                ) : (
                  <>
                    <div className="glass card-tight row-between">
                      <div>
                        <div className="faint" style={{ fontSize: 12 }}>
                          Pay by {r.paymentMode === "bank" ? "bank transfer" : "UPI"} to
                        </div>
                        {r.paymentMode === "bank" && r.bank ? (
                          <div style={{ fontSize: 14 }}>
                            <b>{r.bank.holder}</b>
                            <div>
                              {r.bank.bankName} · A/C {r.bank.accountNumber} · IFSC {r.bank.ifsc}
                            </div>
                          </div>
                        ) : (
                          <b>{r.ownerUpiId}</b>
                        )}
                      </div>
                      {r.ownerUpiId && (
                        <button className="icon-btn" aria-label="Copy UPI ID" onClick={() => navigator.clipboard?.writeText(r.ownerUpiId!).then(() => toast("Copied", "success"))}>
                          <Copy size={15} />
                        </button>
                      )}
                    </div>
                    <Field label="Transaction ID / UTR" hint="Find it in your payment app after paying.">
                      <input className="input" value={utr} onChange={(e) => setUtr(e.target.value)} placeholder="e.g. 412345678901" />
                    </Field>
                    <button className="btn btn-primary" disabled={busy} onClick={() => run((b) => b.payBill(r.id, utr), "Payment submitted to the owner")}>
                      I&apos;ve paid {money(r.total ?? 0)}
                    </button>
                  </>
                )}
              </>
            )}
            {r.status === "payment_submitted" && <div className="alert alert-amber">Payment {r.transactionId} submitted. You&apos;ll be notified once the owner confirms it.</div>}
            {r.status === "confirmed" && (
              <Link href="/dashboard/tenant/stay/" className="btn btn-primary" style={{ alignSelf: "flex-start" }}>
                View my stay
              </Link>
            )}
            {r.status === "pending" && (
              <button className="btn btn-ghost" style={{ alignSelf: "flex-start" }} onClick={() => setWithdraw(true)}>
                <Trash2 size={15} /> Withdraw request
              </button>
            )}
          </div>
        </div>
      )}
      {withdraw && <Confirm title="Withdraw this request?" body="The owner won't see it anymore. You can request again later." confirmLabel="Withdraw" danger busy={busy} onClose={() => setWithdraw(false)} onConfirm={() => run((b) => b.withdrawRequest(r.id), "Request withdrawn").then(() => setWithdraw(false))} />}
    </div>
  );
}

export default function TenantRequestsPage() {
  const { data, loading } = useQuery((b) => b.listMyRequests());
  return (
    <Page title="My requests" sub="Track your requests to join PGs">
      {loading ? (
        <Loading />
      ) : !data?.length ? (
        <div className="glass card">
          <Empty icon={KeyRound} title="No requests yet" body="Find a PG you like and request a bed — you'll track every step here." action={<Link href="/dashboard/tenant/explore/" className="btn btn-primary"><Search size={16} /> Explore PGs</Link>} />
        </div>
      ) : (
        data.map((r) => <RequestCard key={r.id} r={r} />)
      )}
    </Page>
  );
}
