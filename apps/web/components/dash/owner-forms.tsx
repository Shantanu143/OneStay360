"use client";
// Owner workflows opened from several screens: the bed picker, the add-tenant
// wizard (invite or direct) and recording a payment.
import { useEffect, useMemo, useState } from "react";
import { ArrowLeft, ArrowRight, Check, Send, UserPlus } from "lucide-react";
import { Field, Loading, Modal } from "../ui";
import { useAction, useQuery } from "@/lib/hooks";
import { cls, DAY, fromInputDate, money, monthLabel, proratedRent, sharingLabel, toInputDate } from "@/lib/format";
import type { PaymentMethodLabel, Property } from "@/lib/types";

/** Beds by floor; free ones are selectable. [held] are "room/bed" keys reserved elsewhere. */
export function BedPicker({ property, value, onChange, held }: { property: Property; value?: { room: string; bed: string }; onChange: (v: { room: string; bed: string; rent: number }) => void; held: Set<string> | undefined }) {
  const floors = useMemo(() => {
    const map = new Map<number, Property["rooms"]>();
    for (const r of property.rooms) map.set(r.floor, [...(map.get(r.floor) ?? []), r]);
    return [...map.entries()].sort((a, b) => a[0] - b[0]);
  }, [property]);
  if (!held) return <Loading rows={2} />;
  return (
    <div>
      {floors.map(([floor, rooms]) => (
        <div className="floor" key={floor}>
          <h4>{floor === 0 ? "Ground floor" : `Floor ${floor}`}</h4>
          <div className="rooms">
            {rooms.map((r) => (
              <div className="room" key={r.number}>
                <div className="room-head">
                  <span>Room {r.number}</span>
                  <span className="faint" style={{ fontSize: 12, fontWeight: 600 }}>
                    {money(r.rentPerBed)}
                  </span>
                </div>
                <div className="faint" style={{ fontSize: 12, marginBottom: 8 }}>
                  {sharingLabel(r.sharing)}
                  {r.ac ? " · AC" : ""}
                </div>
                <div className="beds">
                  {r.beds.map((b) => {
                    const key = `${r.number}/${b.number}`;
                    const isHeld = held.has(key);
                    const taken = !!b.tenantId;
                    const selected = value?.room === r.number && value.bed === b.number;
                    return (
                      <button
                        type="button"
                        key={b.number}
                        className={cls("bed", taken ? "taken" : isHeld ? "held" : "free", selected && "selected")}
                        disabled={taken || isHeld}
                        title={taken ? "Occupied" : isHeld ? "Held for another tenant" : "Free"}
                        aria-pressed={selected}
                        aria-label={`Room ${r.number} bed ${b.number}${taken ? " occupied" : isHeld ? " held" : " free"}`}
                        onClick={() => onChange({ room: r.number, bed: b.number, rent: r.rentPerBed })}
                      >
                        {b.number}
                      </button>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>
        </div>
      ))}
      <div className="legend">
        <span>
          <i style={{ background: "var(--tint-green)" }} />
          Free
        </span>
        <span>
          <i style={{ background: "var(--tint-amber)" }} />
          Held
        </span>
        <span>
          <i style={{ background: "var(--tint-grey)" }} />
          Occupied
        </span>
      </div>
    </div>
  );
}

/** Beds held by open requests or pending invitations for one property. */
export function useHeldBeds(propertyId: string | undefined, exceptId?: string) {
  const { data } = useQuery(
    async (b) => {
      const held = new Set<string>();
      if (!propertyId) return { propertyId, held };
      const [reqs, invs] = await Promise.all([b.listRequests(), b.listTenantInvitations()]);
      for (const r of reqs) if (r.propertyId === propertyId && r.id !== exceptId && ["approved", "bill_sent", "payment_submitted"].includes(r.status) && r.roomNumber) held.add(`${r.roomNumber}/${r.bedNumber}`);
      for (const i of invs) if (i.propertyId === propertyId && i.status === "pending") held.add(`${i.roomNumber}/${i.bedNumber}`);
      return { propertyId, held };
    },
    [propertyId, exceptId],
  );
  // undefined until loaded for this property, so a reserved bed can't be picked meanwhile.
  return data && data.propertyId === propertyId ? data.held : undefined;
}

const steps = ["Property & bed", "Tenant", "Terms", "Review"];

export function AddTenantModal({ onClose, propertyId: initialProperty, room: initialRoom }: { onClose: () => void; propertyId?: string; room?: { room: string; bed: string; rent: number } }) {
  const { data: properties } = useQuery((b) => b.listProperties());
  const { busy, run } = useAction();
  const [step, setStep] = useState(0);
  const [propertyId, setPropertyId] = useState(initialProperty ?? "");
  const [bed, setBed] = useState<{ room: string; bed: string; rent: number } | undefined>(initialRoom);
  const [direct, setDirect] = useState(false);
  const [t, setT] = useState({ name: "", phone: "", email: "", gender: "male" as "male" | "female" | "other" });
  const [terms, setTerms] = useState({ rent: 0, deposit: 0, maintenance: 0, moveIn: toInputDate(Date.now()), billingDay: new Date().getDate() > 28 ? 1 : new Date().getDate(), notice: 30, lockIn: 3 });
  const property = properties?.find((p) => p.id === propertyId);
  const held = useHeldBeds(propertyId || undefined);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!propertyId && properties?.length) setPropertyId(properties[0]!.id);
  }, [properties, propertyId]);
  useEffect(() => {
    if (property) {
      setTerms((x) => ({ ...x, deposit: property.pricing.deposit, maintenance: property.pricing.maintenance, notice: property.rules.noticeDays, lockIn: property.rules.lockInMonths }));
      if (property.gender === "female") setT((x) => ({ ...x, gender: "female" }));
    }
  }, [property]);
  useEffect(() => {
    if (bed) setTerms((x) => ({ ...x, rent: bed.rent }));
  }, [bed]);

  const moveIn = fromInputDate(terms.moveIn);
  const prorated = proratedRent(terms.rent, moveIn, terms.billingDay);

  const next = () => {
    setError(null);
    if (step === 0 && !bed) return setError("Pick a free bed.");
    if (step === 1) {
      if (!t.name.trim()) return setError("Enter the tenant's name.");
      if (t.phone.replace(/\D/g, "").length < 10) return setError("Enter a 10-digit mobile number.");
    }
    if (step === 2) {
      if (terms.rent <= 0) return setError("Set the monthly rent.");
      if (terms.billingDay < 1 || terms.billingDay > 28) return setError("Billing day must be 1–28.");
    }
    setStep((s) => s + 1);
  };

  const submit = async () => {
    if (!property || !bed) return;
    const out = await run(
      (b) =>
        b.addTenant({
          propertyId: property.id,
          roomNumber: bed.room,
          bedNumber: bed.bed,
          tenantName: t.name,
          tenantPhone: t.phone,
          tenantEmail: t.email,
          gender: t.gender,
          monthlyRent: terms.rent,
          deposit: terms.deposit,
          maintenance: terms.maintenance,
          billingDay: terms.billingDay,
          moveIn,
          noticeDays: terms.notice,
          lockInMonths: terms.lockIn,
          direct,
        }),
      direct ? `${t.name} added to Room ${bed.room} · Bed ${bed.bed}` : `Invitation sent to ${t.name}`,
    );
    if (out.ok) onClose();
  };

  return (
    <Modal
      wide
      title="Add a tenant"
      subtitle={steps[step]}
      onClose={onClose}
      footer={
        <>
          {step > 0 && (
            <button className="btn btn-ghost" onClick={() => setStep((s) => s - 1)}>
              <ArrowLeft size={16} /> Back
            </button>
          )}
          <span className="spacer" />
          {step < 3 ? (
            <button className="btn btn-primary" onClick={next}>
              Continue <ArrowRight size={16} />
            </button>
          ) : (
            <button className="btn btn-primary" onClick={submit} disabled={busy}>
              {direct ? <UserPlus size={16} /> : <Send size={16} />} {direct ? "Add tenant" : "Send invitation"}
            </button>
          )}
        </>
      }
    >
      <div className="stepper" aria-hidden>
        {steps.map((s, i) => (
          <span key={s} className={i <= step ? "done" : ""} />
        ))}
      </div>
      {error && (
        <div className="alert alert-red" style={{ marginBottom: 14 }}>
          {error}
        </div>
      )}
      {step === 0 && (
        <div className="stack">
          <Field label="Property">
            <select
              className="select"
              value={propertyId}
              onChange={(e) => {
                setPropertyId(e.target.value);
                setBed(undefined);
              }}
            >
              {properties?.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </Field>
          {property ? <BedPicker property={property} value={bed && { room: bed.room, bed: bed.bed }} onChange={setBed} held={held} /> : <p className="muted">Add a property first.</p>}
        </div>
      )}
      {step === 1 && (
        <div className="form-grid">
          <Field label="Full name" full>
            <input className="input" value={t.name} onChange={(e) => setT({ ...t, name: e.target.value })} placeholder="Tenant's name" />
          </Field>
          <Field label="Mobile number" hint="The tenant signs in with this number to accept.">
            <input className="input" inputMode="numeric" value={t.phone} onChange={(e) => setT({ ...t, phone: e.target.value })} placeholder="98765 43210" />
          </Field>
          <Field label="Email (optional)">
            <input className="input" type="email" value={t.email} onChange={(e) => setT({ ...t, email: e.target.value })} placeholder="name@example.com" />
          </Field>
          <Field label="Gender">
            <select className="select" value={t.gender} onChange={(e) => setT({ ...t, gender: e.target.value as typeof t.gender })}>
              <option value="male">Male</option>
              <option value="female">Female</option>
              <option value="other">Other</option>
            </select>
          </Field>
          <div className="full">
            <span style={{ fontSize: 13, fontWeight: 600, color: "var(--ink-soft)" }}>How should they join?</span>
            <div className="role-pick" style={{ marginTop: 6 }}>
              <button type="button" aria-pressed={!direct} onClick={() => setDirect(false)}>
                <b>Send an invitation</b>
                <small>They review the terms and accept in the app. The bed is held meanwhile.</small>
              </button>
              <button type="button" aria-pressed={direct} onClick={() => setDirect(true)}>
                <b>Add directly</b>
                <small>For tenants without the app. Their account links if they sign up later.</small>
              </button>
            </div>
          </div>
        </div>
      )}
      {step === 2 && (
        <div className="form-grid">
          <Field label="Monthly rent (₹)">
            <input className="input" type="number" min={0} value={terms.rent} onChange={(e) => setTerms({ ...terms, rent: +e.target.value })} />
          </Field>
          <Field label="Security deposit (₹)">
            <input className="input" type="number" min={0} value={terms.deposit} onChange={(e) => setTerms({ ...terms, deposit: +e.target.value })} />
          </Field>
          <Field label="Maintenance (₹, one-time)">
            <input className="input" type="number" min={0} value={terms.maintenance} onChange={(e) => setTerms({ ...terms, maintenance: +e.target.value })} />
          </Field>
          <Field label="Move-in date">
            <input className="input" type="date" value={terms.moveIn} onChange={(e) => setTerms({ ...terms, moveIn: e.target.value })} />
          </Field>
          <Field label="Billing day of month" hint="Rent invoices are due on this day.">
            <input className="input" type="number" min={1} max={28} value={terms.billingDay} onChange={(e) => setTerms({ ...terms, billingDay: +e.target.value })} />
          </Field>
          <Field label="Notice period (days)">
            <input className="input" type="number" min={0} value={terms.notice} onChange={(e) => setTerms({ ...terms, notice: +e.target.value })} />
          </Field>
          <Field label="Lock-in (months)">
            <input className="input" type="number" min={0} value={terms.lockIn} onChange={(e) => setTerms({ ...terms, lockIn: +e.target.value })} />
          </Field>
          {prorated > 0 && (
            <div className="alert alert-blue full">
              Moving in on {new Date(moveIn).getDate()} with billing on the {terms.billingDay}: prorated rent until the first billing day is <b>{money(prorated)}</b>.
            </div>
          )}
        </div>
      )}
      {step === 3 && property && bed && (
        <div className="grid-2">
          <div className="glass card-tight">
            <dl className="kv">
              <dt>Tenant</dt>
              <dd>{t.name}</dd>
              <dt>Mobile</dt>
              <dd>{t.phone}</dd>
              <dt>Property</dt>
              <dd>{property.name}</dd>
              <dt>Bed</dt>
              <dd>
                Room {bed.room} · Bed {bed.bed}
              </dd>
              <dt>Move-in</dt>
              <dd>{new Date(moveIn).toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" })}</dd>
            </dl>
          </div>
          <div className="glass card-tight">
            <dl className="kv">
              <dt>Rent</dt>
              <dd>{money(terms.rent)} / month</dd>
              <dt>Deposit</dt>
              <dd>{money(terms.deposit)}</dd>
              <dt>Maintenance</dt>
              <dd>{money(terms.maintenance)}</dd>
              <dt>Billing day</dt>
              <dd>{terms.billingDay}</dd>
              <dt>Notice · lock-in</dt>
              <dd>
                {terms.notice} days · {terms.lockIn} months
              </dd>
            </dl>
          </div>
          <div className={`alert ${direct ? "alert-amber" : "alert-green"} full`} style={{ gridColumn: "1 / -1" }}>
            <Check size={14} style={{ verticalAlign: -2 }} />{" "}
            {direct ? "The tenant is created now, the bed turns occupied and this month's invoice is raised." : "The bed is held and the tenant is notified. Accepting creates their stay and first invoice."}
          </div>
        </div>
      )}
    </Modal>
  );
}

const methods: PaymentMethodLabel[] = ["Cash", "UPI", "Bank Transfer", "Cheque"];

export function RecordPaymentModal({ onClose, tenantId: initialTenant }: { onClose: () => void; tenantId?: string }) {
  const { data: tenants } = useQuery((b) => b.listTenants({ status: "active" }));
  const { data: invoices } = useQuery((b) => b.listInvoices());
  const { busy, run } = useAction();
  const [tenantId, setTenantId] = useState(initialTenant ?? "");
  const [method, setMethod] = useState<PaymentMethodLabel>("Cash");
  const [amount, setAmount] = useState(0);
  const [month, setMonth] = useState(monthLabel(new Date()));
  const [reference, setReference] = useState("");
  const [note, setNote] = useState("");
  const open = invoices?.filter((i) => i.tenantId === tenantId && i.status !== "paid") ?? [];

  useEffect(() => {
    if (!tenantId && tenants?.length) setTenantId(tenants[0]!.id);
  }, [tenants, tenantId]);
  useEffect(() => {
    const first = open.sort((a, b) => a.dueDate - b.dueDate)[0];
    const tenant = tenants?.find((x) => x.id === tenantId);
    if (first) {
      setMonth(first.month);
      setAmount(first.amount);
    } else if (tenant) {
      setAmount(tenant.monthlyRent);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tenantId, invoices, tenants]);

  const months = useMemo(() => {
    const set = new Set(open.map((i) => i.month));
    for (let i = -1; i < 3; i++) {
      const d = new Date();
      d.setMonth(d.getMonth() - i);
      set.add(monthLabel(d));
    }
    return [...set];
  }, [open]);

  const submit = async () => {
    const ok = await run((b) => b.recordPayment({ tenantId, amount, month, method, reference, note }), "Payment recorded");
    if (ok.ok) onClose();
  };

  return (
    <Modal
      title="Record a payment"
      subtitle="Cash, bank transfer or cheque you received directly."
      onClose={onClose}
      footer={
        <>
          <button className="btn btn-ghost" onClick={onClose}>
            Cancel
          </button>
          <button className="btn btn-primary" onClick={submit} disabled={busy || !tenantId}>
            Record {money(amount)}
          </button>
        </>
      }
    >
      <div className="form-grid">
        <Field label="Tenant" full>
          <select className="select" value={tenantId} onChange={(e) => setTenantId(e.target.value)}>
            {tenants?.map((x) => (
              <option key={x.id} value={x.id}>
                {x.name} — {x.propertyName}, {x.roomNumber}-{x.bedNumber}
              </option>
            ))}
          </select>
        </Field>
        <Field label="For month" hint={open.length ? `${open.length} open invoice${open.length > 1 ? "s" : ""}` : "No open invoices"}>
          <select className="select" value={month} onChange={(e) => setMonth(e.target.value)}>
            {months.map((m) => (
              <option key={m}>{m}</option>
            ))}
          </select>
        </Field>
        <Field label="Amount (₹)">
          <input className="input" type="number" min={0} value={amount} onChange={(e) => setAmount(+e.target.value)} />
        </Field>
        <div className="field full">
          <span>Method</span>
          <div className="chips">
            {methods.map((m) => (
              <button key={m} type="button" className="chip" aria-pressed={method === m} onClick={() => setMethod(m)}>
                {m}
              </button>
            ))}
          </div>
        </div>
        {method !== "Cash" && (
          <Field label={method === "Cheque" ? "Cheque number" : "Reference / UTR"}>
            <input className="input" value={reference} onChange={(e) => setReference(e.target.value)} />
          </Field>
        )}
        <Field label="Note (optional)" full={method === "Cash"}>
          <input className="input" value={note} onChange={(e) => setNote(e.target.value)} placeholder="e.g. paid at reception" />
        </Field>
      </div>
    </Modal>
  );
}

export const dueIn = (ms: number) => {
  const d = Math.round((ms - Date.now()) / DAY);
  return d === 0 ? "today" : d > 0 ? `in ${d}d` : `${-d}d ago`;
};
