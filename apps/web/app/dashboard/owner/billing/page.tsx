"use client";
import { useEffect, useState } from "react";
import { CreditCard, Receipt, ShieldCheck, Tag } from "lucide-react";
import { Page, useShell } from "@/components/dash/shell";
import { bedStats } from "@/components/dash/widgets";
import { Empty, Field, Loading, Modal, StatusBadge } from "@/components/ui";
import { useAction, useBackend, useQuery } from "@/lib/hooks";
import { date, money } from "@/lib/format";
import { permissions } from "@/lib/permissions";
import type { CheckoutQuote, Property } from "@/lib/types";

function Checkout({ p, onClose }: { p: Property; onClose: () => void }) {
  const backend = useBackend();
  const { busy, run } = useAction();
  const [promo, setPromo] = useState("");
  const [applied, setApplied] = useState<string | undefined>();
  const [quote, setQuote] = useState<CheckoutQuote | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [step, setStep] = useState<"quote" | "pay">("quote");
  useEffect(() => {
    backend
      .checkoutQuote(p.id, applied)
      .then((q) => {
        setQuote(q);
        setError(null);
      })
      .catch((e: Error) => {
        setError(e.message);
        setApplied(undefined);
      });
  }, [backend, p.id, applied]);
  return (
    <Modal
      title={`Activate ${p.name}`}
      subtitle="30 days of OneStay360 for this property"
      onClose={onClose}
      footer={
        step === "quote" ? (
          <>
            <button className="btn btn-ghost" onClick={onClose}>
              Cancel
            </button>
            <button className="btn btn-primary" disabled={!quote} onClick={() => setStep("pay")}>
              <CreditCard size={16} /> Pay {quote ? money(quote.finalAmount) : ""}
            </button>
          </>
        ) : (
          <>
            <button className="btn btn-ghost" onClick={() => setStep("quote")}>
              Back
            </button>
            <button className="btn btn-primary" disabled={busy} onClick={() => run((b) => b.payActivation(p.id, applied), `${p.name} is active`).then((r) => r.ok && onClose())}>
              Complete payment
            </button>
          </>
        )
      }
    >
      {!quote ? (
        <Loading rows={2} />
      ) : step === "quote" ? (
        <div className="stack">
          <dl className="kv">
            <dt>Beds</dt>
            <dd>{quote.beds}</dd>
            <dt>Price per bed</dt>
            <dd>{money(quote.pricePerBed)} / month</dd>
            <dt>Subtotal</dt>
            <dd>{money(quote.baseAmount)}</dd>
            {quote.promo && (
              <>
                <dt>Promo {quote.promo.code}</dt>
                <dd style={{ color: "var(--brand)" }}>− {money(quote.discount)}</dd>
              </>
            )}
            <dt style={{ fontWeight: 700, color: "var(--ink)" }}>Total</dt>
            <dd style={{ fontSize: 20 }}>{money(quote.finalAmount)}</dd>
            <dt>Period</dt>
            <dd>
              {date(quote.periodStart)} – {date(quote.periodEnd)}
            </dd>
          </dl>
          <div className="row" style={{ alignItems: "flex-end" }}>
            <Field label="Promo code">
              <input className="input" value={promo} onChange={(e) => setPromo(e.target.value.toUpperCase())} placeholder="e.g. WELCOME20" />
            </Field>
            <button className="btn btn-ghost" onClick={() => setApplied(promo || undefined)}>
              <Tag size={15} /> Apply
            </button>
          </div>
          {error && <div className="alert alert-red">{error}</div>}
          <p className="faint" style={{ fontSize: 12.5 }}>Demo promo codes: WELCOME20, ONESTAY50.</p>
        </div>
      ) : (
        <div className="stack">
          <div className="glass card-tight row" style={{ gap: 12 }}>
            <ShieldCheck size={22} color="var(--brand)" />
            <div>
              <b>Secure checkout</b>
              <p className="muted" style={{ fontSize: 13.5 }}>
                In production this opens Razorpay checkout (createActivationOrder → confirmActivationPayment). In demo mode, completing marks the property paid.
              </p>
            </div>
          </div>
          <div className="row-between glass card-tight">
            <span>Amount</span>
            <b style={{ fontSize: 20 }}>{money(quote.finalAmount)}</b>
          </div>
        </div>
      )}
    </Modal>
  );
}

export default function BillingPage() {
  const { account } = useShell();
  const [checkout, setCheckout] = useState<string | null>(null);
  const { data, loading } = useQuery(async (b) => ({ properties: await b.listProperties(), invoices: await b.listPlatformInvoices() }));
  useEffect(() => {
    const id = new URLSearchParams(window.location.search).get("checkout");
    if (id) setCheckout(id);
  }, []);
  if (!permissions(account.role).canViewBilling) {
    return (
      <Page title="Billing">
        <div className="alert alert-amber">Billing is owner-only.</div>
      </Page>
    );
  }
  const target = data?.properties.find((p) => p.id === checkout);
  const monthly = data?.properties.filter((p) => p.billingStatus === "paid").reduce((s, p) => s + bedStats(p).total * p.pricePerBed, 0) ?? 0;
  return (
    <Page title="Billing" sub="Your OneStay360 plan: pay per bed, per active property">
      <div className="glass card kpi-hero row wrap" style={{ gap: 20 }}>
        <div className="grow" style={{ flex: 1 }}>
          <div className="label" style={{ color: "#b9ccc5" }}>
            Current monthly cost
          </div>
          <div style={{ fontSize: 32, fontWeight: 800 }}>{money(monthly)}</div>
          <div style={{ color: "#b9ccc5", fontSize: 13 }}>₹30 per bed per month on active properties</div>
        </div>
      </div>
      <div className="glass card">
        <div className="section-title">
          <h2>Properties</h2>
        </div>
        {loading ? (
          <Loading />
        ) : (
          <div className="list">
            {data?.properties.map((p) => {
              const beds = bedStats(p).total;
              return (
                <div key={p.id} className="list-row wrap">
                  <span className="tile-ic">
                    <Receipt size={18} />
                  </span>
                  <div className="grow" style={{ minWidth: 200 }}>
                    <div className="title">{p.name}</div>
                    <div className="meta">
                      {beds} beds × {money(p.pricePerBed)} = {money(beds * p.pricePerBed)}/month · {p.billingStatus === "paid" ? `renews ${date(p.nextBillingDate)}` : "not active on Explore"}
                    </div>
                  </div>
                  <StatusBadge status={p.billingStatus} />
                  {p.billingStatus !== "paid" ? (
                    <button className="btn btn-primary btn-sm" onClick={() => setCheckout(p.id)}>
                      Activate
                    </button>
                  ) : (
                    <button className="btn btn-ghost btn-sm" onClick={() => setCheckout(p.id)}>
                      Renew early
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
          <h2>Invoices</h2>
        </div>
        {!data?.invoices.length ? (
          <Empty icon={Receipt} title="No invoices yet" />
        ) : (
          <div className="table-wrap">
            <table className="table">
              <thead>
                <tr>
                  <th>Period</th>
                  <th>Property</th>
                  <th>Beds</th>
                  <th>Promo</th>
                  <th style={{ textAlign: "right" }}>Amount</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {data.invoices.map((i) => (
                  <tr key={i.id}>
                    <td>
                      {date(i.periodStart)} – {date(i.periodEnd)}
                    </td>
                    <td>{i.propertyName}</td>
                    <td>{i.beds}</td>
                    <td>{i.promoCode ? `${i.promoCode} (−${money(i.discount)})` : "—"}</td>
                    <td className="num" style={{ textAlign: "right", fontWeight: 650 }}>
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
        )}
      </div>
      {target && <Checkout p={target} onClose={() => setCheckout(null)} />}
    </Page>
  );
}
