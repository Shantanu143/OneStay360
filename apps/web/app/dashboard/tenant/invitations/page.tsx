"use client";
import { useState } from "react";
import { Check, MailOpen, X } from "lucide-react";
import { Page } from "@/components/dash/shell";
import { Confirm, Empty, Field, Loading, StatusBadge } from "@/components/ui";
import { useAction, useQuery } from "@/lib/hooks";
import { ago, date, money } from "@/lib/format";

export default function InvitationsPage() {
  const { data, loading } = useQuery((b) => b.listMyInvitations());
  const { busy, run } = useAction();
  const [declining, setDeclining] = useState<string | null>(null);
  const [reason, setReason] = useState("");
  return (
    <Page title="Invitations" sub="Owners who added you to a bed">
      {loading ? (
        <Loading />
      ) : !data?.length ? (
        <div className="glass card">
          <Empty icon={MailOpen} title="No invitations" body="When an owner adds you with your mobile number, the invitation shows up here for you to accept." />
        </div>
      ) : (
        data.map((i) => (
          <div key={i.id} className="glass card stack">
            <div className="row-between wrap">
              <div>
                <h2 className="h3">{i.propertyName}</h2>
                <div className="faint" style={{ fontSize: 13 }}>
                  From {i.businessName} · {ago(i.createdAt)}
                </div>
              </div>
              <StatusBadge status={i.status} />
            </div>
            <div className="grid-2">
              <dl className="kv glass card-tight">
                <dt>Bed</dt>
                <dd>
                  Room {i.roomNumber} · Bed {i.bedNumber}
                </dd>
                <dt>Move-in</dt>
                <dd>{date(i.moveIn)}</dd>
                <dt>Billing day</dt>
                <dd>{i.billingDay} of each month</dd>
                <dt>Notice · lock-in</dt>
                <dd>
                  {i.noticeDays} days · {i.lockInMonths} months
                </dd>
              </dl>
              <dl className="kv glass card-tight">
                <dt>Monthly rent</dt>
                <dd>{money(i.monthlyRent)}</dd>
                <dt>Deposit</dt>
                <dd>{money(i.deposit)}</dd>
                <dt>Maintenance</dt>
                <dd>{money(i.maintenance)}</dd>
                {i.proratedRent > 0 && (
                  <>
                    <dt>Prorated first rent</dt>
                    <dd>{money(i.proratedRent)}</dd>
                  </>
                )}
              </dl>
            </div>
            {i.status === "pending" && (
              <div className="row wrap">
                <button className="btn btn-primary" disabled={busy} onClick={() => run((b) => b.acceptInvitation(i.id), "Welcome! Your stay is set up")}>
                  <Check size={16} /> Accept &amp; move in
                </button>
                <button className="btn btn-ghost" onClick={() => setDeclining(i.id)}>
                  <X size={16} /> Decline
                </button>
              </div>
            )}
            {i.reason && <div className="alert alert-blue">You said: “{i.reason}”</div>}
          </div>
        ))
      )}
      {declining && (
        <Confirm title="Decline this invitation?" body="The owner is notified and the bed is released." confirmLabel="Decline" danger busy={busy} onClose={() => setDeclining(null)} onConfirm={() => run((b) => b.declineInvitation(declining, reason), "Invitation declined").then(() => setDeclining(null))}>
          <Field label="Reason (optional)">
            <input className="input" value={reason} onChange={(e) => setReason(e.target.value)} placeholder="e.g. Found a place closer to work" />
          </Field>
        </Confirm>
      )}
    </Page>
  );
}
