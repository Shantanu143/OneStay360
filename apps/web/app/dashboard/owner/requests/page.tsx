"use client";
// Join requests: pending → approved → bill_sent → payment_submitted →
// confirmed (or rejected), as in the Business app's approval screens.
import Link from "next/link";
import { useEffect, useState } from "react";
import { Check, ClipboardCheck, Phone, Send, X } from "lucide-react";
import { Page, useShell } from "@/components/dash/shell";
import { BedPicker, useHeldBeds } from "@/components/dash/owner-forms";
import { Avatar } from "@/components/dash/widgets";
import { Confirm, Empty, Field, Loading, Modal, Segmented, StatusBadge } from "@/components/ui";
import { useAction, useQuery } from "@/lib/hooks";
import { ago, cls, date, fromInputDate, money, toInputDate } from "@/lib/format";
import { permissions } from "@/lib/permissions";
import type { EnrollmentRequest, PayoutMethod, Property } from "@/lib/types";

type Filter = "open" | "all" | "confirmed" | "rejected";
const stages = ["pending", "approved", "bill_sent", "payment_submitted", "confirmed"] as const;
const stageLabels = ["Requested", "Approved", "Bill sent", "Payment submitted", "Confirmed"];

function Timeline({ r }: { r: EnrollmentRequest }) {
  const idx = r.status === "rejected" ? -1 : stages.indexOf(r.status as (typeof stages)[number]);
  return (
    <div className="timeline">
      {stageLabels.map((l, i) => (
        <div key={l} className={cls("tl-item", i < idx && "done", i === idx && (r.status === "confirmed" ? "done" : "current"))}>
          <span className="tl-dot">{i < idx || r.status === "confirmed" ? <Check size={13} /> : i + 1}</span>
          <div style={{ fontSize: 14, fontWeight: i === idx ? 700 : 500, color: i > idx ? "var(--ink-faint)" : undefined }}>{l}</div>
        </div>
      ))}
    </div>
  );
}

function BillForm({ r, property, methods, mode, onDone }: { r: EnrollmentRequest; property: Property; methods: PayoutMethod[]; mode: "approve" | "bill"; onDone: () => void }) {
  const { busy, run } = useAction();
  const held = useHeldBeds(property.id, r.id);
  const room = property.rooms.find((x) => x.number === r.roomNumber);
  const [bed, setBed] = useState<{ room: string; bed: string; rent: number } | undefined>(r.roomNumber && r.bedNumber && room ? { room: r.roomNumber, bed: r.bedNumber, rent: r.monthlyRent ?? room.rentPerBed } : undefined);
  const [terms, setTerms] = useState({ rent: r.monthlyRent ?? 0, deposit: r.deposit ?? property.pricing.deposit, maintenance: r.maintenance ?? property.pricing.maintenance, moveIn: toInputDate(r.moveIn) });
  const [payMode, setPayMode] = useState<"upi" | "bank" | "cash">(r.paymentMode ?? "upi");
  const active = methods.filter((m) => m.active);
  const [methodId, setMethodId] = useState(active.find((m) => m.type === "upi" && m.preferred)?.id ?? active[0]?.id ?? "");
  useEffect(() => {
    if (bed && !r.monthlyRent) setTerms((t) => ({ ...t, rent: bed.rent }));
  }, [bed, r.monthlyRent]);
  useEffect(() => {
    const m = active.find((x) => x.type === payMode);
    if (m && !active.find((x) => x.id === methodId && x.type === payMode)) setMethodId(m.id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [payMode]);
  const total = terms.rent + terms.deposit + terms.maintenance;

  const submit = async () => {
    if (!bed) return;
    const placement = { roomNumber: bed.room, bedNumber: bed.bed, monthlyRent: terms.rent, deposit: terms.deposit, maintenance: terms.maintenance, moveIn: fromInputDate(terms.moveIn) };
    const out = mode === "approve" ? await run((b) => b.approveRequest(r.id, placement), `Bed ${bed.room}-${bed.bed} reserved for ${r.tenantName}`) : await run((b) => b.sendBill(r.id, { ...placement, paymentMode: payMode, methodId: payMode === "cash" ? undefined : methodId }), `Bill of ${money(total)} sent to ${r.tenantName}`);
    if (out.ok) onDone();
  };

  return (
    <div className="stack-lg">
      <div>
        <h3 style={{ fontSize: 17, fontWeight: 700 }}>1. Assign a bed</h3>
        <p className="faint" style={{ fontSize: 14, margin: "2px 0 10px" }}>
          Wants: {r.sharing || "any sharing"}
        </p>
        <BedPicker property={property} value={bed && { room: bed.room, bed: bed.bed }} onChange={setBed} held={held} />
      </div>
      <div>
        <h3 style={{ fontSize: 17, fontWeight: 700 }}>2. First bill</h3>
        <div className="form-grid" style={{ marginTop: 10 }}>
          <Field label="Monthly rent (₹)">
            <input className="input" type="number" value={terms.rent} onChange={(e) => setTerms({ ...terms, rent: +e.target.value })} />
          </Field>
          <Field label="Deposit (₹)">
            <input className="input" type="number" value={terms.deposit} onChange={(e) => setTerms({ ...terms, deposit: +e.target.value })} />
          </Field>
          <Field label="Maintenance (₹)">
            <input className="input" type="number" value={terms.maintenance} onChange={(e) => setTerms({ ...terms, maintenance: +e.target.value })} />
          </Field>
          <Field label="Move-in date">
            <input className="input" type="date" value={terms.moveIn} onChange={(e) => setTerms({ ...terms, moveIn: e.target.value })} />
          </Field>
        </div>
      </div>
      {mode === "bill" && (
        <div>
          <h3 style={{ fontSize: 17, fontWeight: 700 }}>3. How should they pay?</h3>
          <div className="chips" style={{ margin: "10px 0" }}>
            {(["upi", "bank", "cash"] as const).map((m) => (
              <button key={m} type="button" className="chip" aria-pressed={payMode === m} onClick={() => setPayMode(m)}>
                {m === "upi" ? "UPI" : m === "bank" ? "Bank transfer" : "Cash at the PG"}
              </button>
            ))}
          </div>
          {payMode !== "cash" &&
            (active.filter((m) => m.type === payMode).length ? (
              <select className="select" value={methodId} onChange={(e) => setMethodId(e.target.value)} aria-label="Receive into">
                {active
                  .filter((m) => m.type === payMode)
                  .map((m) => (
                    <option key={m.id} value={m.id}>
                      {m.label} — {m.type === "upi" ? m.upiId : `${m.bankName} ••${m.accountNumber?.slice(-4)}`}
                    </option>
                  ))}
              </select>
            ) : (
              <div className="alert alert-amber">
                No {payMode === "upi" ? "UPI ID" : "bank account"} yet. <Link href="/dashboard/owner/collections/">Add one under Payment methods</Link>.
              </div>
            ))}
        </div>
      )}
      <div className="glass card-tight row-between">
        <span className="muted">First bill (rent + deposit + maintenance)</span>
        <b style={{ fontSize: 20, color: "var(--brand)" }} className="num">
          {money(total)}
        </b>
      </div>
      <div className="row" style={{ justifyContent: "flex-end" }}>
        <button className="btn btn-primary" disabled={busy || !bed} onClick={submit}>
          {mode === "approve" ? (
            <>
              <Check size={16} aria-hidden /> Approve &amp; reserve bed
            </>
          ) : (
            <>
              <Send size={16} aria-hidden /> Send bill
            </>
          )}
        </button>
      </div>
    </div>
  );
}

function RequestDetail({ r, onClose }: { r: EnrollmentRequest; onClose: () => void }) {
  const { account } = useShell();
  const can = permissions(account.role);
  const { busy, run } = useAction();
  const [mode, setMode] = useState<"approve" | "bill" | null>(null);
  const [reject, setReject] = useState<"request" | "payment" | null>(null);
  const [reason, setReason] = useState("");
  const { data } = useQuery(async (b) => ({ property: await b.getProperty(r.propertyId), methods: await b.listPayoutMethods().catch(() => [] as PayoutMethod[]) }), [r.propertyId]);

  return (
    <Modal wide title={r.tenantName} subtitle={`${r.propertyName} · requested ${ago(r.createdAt)}`} onClose={onClose}>
      <div className="cols-wr" style={{ alignItems: "start" }}>
        <div className="stack">
          <StatusBadge status={r.status} />
          <Timeline r={r} />
          <dl className="kv">
            <dt>Phone</dt>
            <dd>
              <a href={`tel:+91${r.tenantPhone}`}>{r.tenantPhone}</a>
            </dd>
            <dt>Move-in</dt>
            <dd>{date(r.moveIn)}</dd>
            <dt>Sharing</dt>
            <dd>{r.sharing || "Any"}</dd>
            {r.roomNumber && (
              <>
                <dt>Bed</dt>
                <dd>
                  Room {r.roomNumber} · Bed {r.bedNumber}
                </dd>
              </>
            )}
            {r.total !== undefined && (
              <>
                <dt>First bill</dt>
                <dd>{money(r.total)}</dd>
              </>
            )}
            {r.transactionId && (
              <>
                <dt>Transaction ID</dt>
                <dd>{r.transactionId}</dd>
              </>
            )}
          </dl>
          {r.notes && <div className="alert alert-blue">“{r.notes}”</div>}
          {r.rejectionReason && <div className="alert alert-red">Declined: {r.rejectionReason}</div>}
          {r.paymentRejectionReason && r.status === "bill_sent" && <div className="alert alert-amber">Last payment rejected: {r.paymentRejectionReason}</div>}
        </div>
        <div className="stack">
          {!can.canApproveRequests ? (
            <div className="alert alert-amber">Staff can view requests; the owner or a manager approves them.</div>
          ) : mode && data?.property ? (
            <BillForm r={r} property={data.property} methods={data.methods} mode={mode} onDone={onClose} />
          ) : (
            <>
              {r.status === "pending" && (
                <>
                  <p className="muted">Pick a bed and send the first bill in one go, or just reserve the bed and bill later.</p>
                  <div className="row wrap">
                    <button className="btn btn-primary" onClick={() => setMode("bill")}>
                      <Send size={16} aria-hidden /> Approve &amp; send bill
                    </button>
                    <button className="btn btn-ghost" onClick={() => setMode("approve")}>
                      <Check size={16} aria-hidden /> Approve only
                    </button>
                  </div>
                </>
              )}
              {r.status === "approved" && (
                <button className="btn btn-primary" onClick={() => setMode("bill")}>
                  <Send size={16} aria-hidden /> Send first bill
                </button>
              )}
              {r.status === "bill_sent" && (
                <>
                  <div className="alert alert-blue">
                    Waiting for {r.tenantName} to pay {money(r.total ?? 0)} by {r.paymentMode === "cash" ? "cash" : r.paymentMode === "bank" ? "bank transfer" : `UPI (${r.ownerUpiId})`}.
                  </div>
                  <div className="row wrap">
                    {r.paymentMode === "cash" && (
                      <button className="btn btn-primary" disabled={busy} onClick={() => run((b) => b.confirmRequestPayment(r.id), `${r.tenantName} is now a tenant`).then((x) => x.ok && onClose())}>
                        <Check size={16} aria-hidden /> Cash received — confirm
                      </button>
                    )}
                    <button className="btn btn-ghost" onClick={() => setMode("bill")}>
                      Edit &amp; resend bill
                    </button>
                  </div>
                </>
              )}
              {r.status === "payment_submitted" && (
                <>
                  <div className="alert alert-amber">
                    {r.tenantName} says they paid {money(r.total ?? 0)}. Match transaction <b>{r.transactionId}</b> in your {r.paymentMode === "bank" ? "bank" : "UPI"} app before confirming.
                  </div>
                  <div className="row wrap">
                    <button className="btn btn-primary" disabled={busy} onClick={() => run((b) => b.confirmRequestPayment(r.id), `${r.tenantName} is now a tenant`).then((x) => x.ok && onClose())}>
                      <Check size={16} aria-hidden /> Confirm payment &amp; move in
                    </button>
                    <button className="btn btn-danger" onClick={() => setReject("payment")}>
                      <X size={16} /> Payment not received
                    </button>
                  </div>
                </>
              )}
              {r.status === "confirmed" && r.tenantId && (
                <Link href={`/dashboard/owner/tenant/?id=${r.tenantId}`} className="btn btn-primary" style={{ alignSelf: "flex-start" }}>
                  Open tenant
                </Link>
              )}
              {["pending", "approved", "bill_sent"].includes(r.status) && (
                <button className="btn btn-danger" style={{ alignSelf: "flex-start" }} onClick={() => setReject("request")}>
                  <X size={16} /> Decline request
                </button>
              )}
              <a className="btn btn-ghost" href={`tel:+91${r.tenantPhone}`} style={{ alignSelf: "flex-start" }}>
                <Phone size={16} aria-hidden /> Call {r.tenantName.split(" ")[0]}
              </a>
            </>
          )}
        </div>
      </div>
      {reject && (
        <Confirm
          title={reject === "request" ? "Decline this request?" : "Reject this payment?"}
          body={reject === "request" ? "The tenant is told why and any held bed is released." : "The tenant sees your reason and can pay again."}
          confirmLabel={reject === "request" ? "Decline" : "Reject payment"}
          danger
          busy={busy}
          onClose={() => setReject(null)}
          onConfirm={() =>
            run((b) => (reject === "request" ? b.rejectRequest(r.id, reason) : b.rejectRequestPayment(r.id, reason)), reject === "request" ? "Request declined" : "Payment rejected").then((x) => {
              if (x.ok) {
                setReject(null);
                onClose();
              }
            })
          }
        >
          <Field label="Reason (shown to the tenant)">
            <input className="input" value={reason} onChange={(e) => setReason(e.target.value)} placeholder={reject === "request" ? "e.g. No double rooms free this month" : "e.g. No payment with this UTR"} />
          </Field>
        </Confirm>
      )}
    </Modal>
  );
}

export default function RequestsPage() {
  const [filter, setFilter] = useState<Filter>("open");
  const [selected, setSelected] = useState<string | null>(null);
  const { data, loading, error, reload } = useQuery((b) => b.listRequests());
  useEffect(() => {
    const id = new URLSearchParams(window.location.search).get("id");
    if (id) setSelected(id);
  }, []);
  const list = (data ?? []).filter((r) => (filter === "all" ? true : filter === "open" ? !["confirmed", "rejected"].includes(r.status) : r.status === filter));
  const current = data?.find((r) => r.id === selected);
  const counts = { open: data?.filter((r) => !["confirmed", "rejected"].includes(r.status)).length ?? 0 };

  return (
    <Page error={error} onRetry={reload} title="Join requests" sub="Tenants who found you on Explore or scanned your QR">
      <Segmented<Filter>
        value={filter}
        onChange={setFilter}
        options={[
          { value: "open", label: `Open (${counts.open})` },
          { value: "confirmed", label: "Confirmed" },
          { value: "rejected", label: "Declined" },
          { value: "all", label: "All" },
        ]}
      />
      <div className="glass card">
        {loading ? (
          <Loading />
        ) : list.length === 0 ? (
          <Empty icon={ClipboardCheck} title={filter === "open" ? "No open requests" : "Nothing here"} body="When a tenant requests to join one of your PGs, it shows up here with everything you need to approve it." />
        ) : (
          <div className="list">
            {list.map((r) => (
              <button key={r.id} className="list-row" onClick={() => setSelected(r.id)}>
                <Avatar name={r.tenantName} />
                <div className="grow">
                  <div className="title">{r.tenantName}</div>
                  <div className="meta">
                    {r.propertyName} · {r.sharing || "any sharing"} · moves in {date(r.moveIn)}
                    {r.roomNumber ? ` · Room ${r.roomNumber}-${r.bedNumber}` : ""}
                  </div>
                </div>
                <span className="faint hide-sm" style={{ fontSize: 14 }}>
                  {ago(r.updatedAt)}
                </span>
                <StatusBadge status={r.status} />
              </button>
            ))}
          </div>
        )}
      </div>
      {current && <RequestDetail key={current.id + current.status} r={current} onClose={() => setSelected(null)} />}
    </Page>
  );
}
