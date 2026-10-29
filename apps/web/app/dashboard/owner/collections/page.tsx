"use client";
import { useState } from "react";
import { Landmark, Pencil, Plus, Star, Trash2, Zap } from "lucide-react";
import { Page, useShell } from "@/components/dash/shell";
import { Badge, Confirm, Empty, Field, Loading, Modal } from "@/components/ui";
import { useAction, useQuery } from "@/lib/hooks";
import { permissions } from "@/lib/permissions";
import type { PayoutMethod } from "@/lib/types";

type Draft = Omit<PayoutMethod, "id" | "businessId" | "createdAt"> & { id?: string };
const blankUpi: Draft = { type: "upi", label: "UPI", upiId: "", preferred: false, active: true };
const blankBank: Draft = { type: "bank", label: "Bank account", bankName: "", accountNumber: "", ifsc: "", holder: "", preferred: false, active: true };

export default function CollectionsPage() {
  const { account } = useShell();
  const { busy, run } = useAction();
  const { data, loading } = useQuery(async (b) => ({ methods: await b.listPayoutMethods(), business: await b.getBusiness() }));
  const [draft, setDraft] = useState<Draft | null>(null);
  const [removing, setRemoving] = useState<PayoutMethod | null>(null);
  if (!permissions(account.role).canEditPaymentMethods) {
    return (
      <Page title="Payment methods">
        <div className="alert alert-amber">Only the owner can manage payment methods.</div>
      </Page>
    );
  }
  const business = data?.business;
  return (
    <Page
      title="Payment methods"
      sub="Where tenants pay you"
      actions={
        <button className="btn btn-primary btn-sm" onClick={() => setDraft({ ...blankUpi })}>
          <Plus size={16} /> Add method
        </button>
      }
    >
      <div className="glass card row wrap" style={{ gap: 16 }}>
        <span className="feature-ic">
          <Zap size={22} />
        </span>
        <div className="grow" style={{ flex: 1, minWidth: 220 }}>
          <b>Online rent payments</b>
          <p className="muted" style={{ fontSize: 14 }}>
            Tenants pay rent through a secure payment link and invoices close automatically — no manual verification. Requires KYC.
          </p>
        </div>
        <label className="check" style={{ fontWeight: 650 }}>
          <input type="checkbox" checked={!!business?.onlinePaymentsEnabled} disabled={busy || !business} onChange={(e) => run((b) => b.setOnlinePayments(e.target.checked), e.target.checked ? "Online payments on" : "Online payments off")} />
          {business?.onlinePaymentsEnabled ? "On" : "Off"}
        </label>
      </div>
      <div className="glass card">
        {loading ? (
          <Loading />
        ) : !data?.methods.length ? (
          <Empty icon={Landmark} title="No payment methods yet" body="Add a UPI ID or bank account. It's shown on first bills and on the tenant's rent screen." action={<button className="btn btn-primary" onClick={() => setDraft({ ...blankUpi })}><Plus size={16} /> Add UPI ID</button>} />
        ) : (
          <div className="list">
            {data.methods.map((m) => (
              <div key={m.id} className="list-row wrap">
                <span className="tile-ic blue">
                  <Landmark size={18} />
                </span>
                <div className="grow" style={{ minWidth: 200 }}>
                  <div className="title">
                    {m.label} {m.preferred && <Badge tone="green"><Star size={11} /> Preferred</Badge>} {!m.active && <Badge tone="grey">Inactive</Badge>}
                  </div>
                  <div className="meta">{m.type === "upi" ? m.upiId : `${m.bankName} · ${m.holder} · A/C ••••${m.accountNumber?.slice(-4)} · ${m.ifsc}`}</div>
                </div>
                {!m.preferred && (
                  <button className="btn btn-ghost btn-sm" disabled={busy} onClick={() => run((b) => b.savePayoutMethod({ ...m, preferred: true }), "Preferred method updated")}>
                    Make preferred
                  </button>
                )}
                <button className="icon-btn" aria-label="Edit" onClick={() => setDraft({ ...m })}>
                  <Pencil size={15} />
                </button>
                <button className="icon-btn" aria-label="Delete" onClick={() => setRemoving(m)}>
                  <Trash2 size={15} />
                </button>
              </div>
            ))}
          </div>
        )}
      </div>
      {draft && (
        <Modal
          title={draft.id ? "Edit payment method" : "Add payment method"}
          onClose={() => setDraft(null)}
          footer={
            <>
              <button className="btn btn-ghost" onClick={() => setDraft(null)}>
                Cancel
              </button>
              <button className="btn btn-primary" disabled={busy} onClick={() => run((b) => b.savePayoutMethod(draft), "Saved").then((r) => r.ok && setDraft(null))}>
                Save
              </button>
            </>
          }
        >
          {!draft.id && (
            <div className="chips" style={{ marginBottom: 14 }}>
              <button className="chip" aria-pressed={draft.type === "upi"} onClick={() => setDraft({ ...blankUpi })}>
                UPI ID
              </button>
              <button className="chip" aria-pressed={draft.type === "bank"} onClick={() => setDraft({ ...blankBank })}>
                Bank account
              </button>
            </div>
          )}
          <div className="form-grid">
            <Field label="Label" full>
              <input className="input" value={draft.label} onChange={(e) => setDraft({ ...draft, label: e.target.value })} />
            </Field>
            {draft.type === "upi" ? (
              <Field label="UPI ID" full>
                <input className="input" value={draft.upiId} onChange={(e) => setDraft({ ...draft, upiId: e.target.value })} placeholder="yourname@okhdfc" />
              </Field>
            ) : (
              <>
                <Field label="Bank name">
                  <input className="input" value={draft.bankName} onChange={(e) => setDraft({ ...draft, bankName: e.target.value })} />
                </Field>
                <Field label="Account holder">
                  <input className="input" value={draft.holder} onChange={(e) => setDraft({ ...draft, holder: e.target.value })} />
                </Field>
                <Field label="Account number">
                  <input className="input" inputMode="numeric" value={draft.accountNumber} onChange={(e) => setDraft({ ...draft, accountNumber: e.target.value })} />
                </Field>
                <Field label="IFSC">
                  <input className="input" value={draft.ifsc} onChange={(e) => setDraft({ ...draft, ifsc: e.target.value.toUpperCase() })} placeholder="HDFC0001234" />
                </Field>
              </>
            )}
            <label className="check">
              <input type="checkbox" checked={draft.preferred} onChange={(e) => setDraft({ ...draft, preferred: e.target.checked })} /> Preferred
            </label>
            <label className="check">
              <input type="checkbox" checked={draft.active} onChange={(e) => setDraft({ ...draft, active: e.target.checked })} /> Active
            </label>
          </div>
        </Modal>
      )}
      {removing && <Confirm title={`Delete ${removing.label}?`} confirmLabel="Delete" danger busy={busy} onClose={() => setRemoving(null)} onConfirm={() => run((b) => b.deletePayoutMethod(removing.id), "Deleted").then((r) => r.ok && setRemoving(null))} />}
    </Page>
  );
}
