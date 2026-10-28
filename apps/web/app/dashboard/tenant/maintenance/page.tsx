"use client";
import Link from "next/link";
import { useState } from "react";
import { Plus, Wrench, X } from "lucide-react";
import { Page } from "@/components/dash/shell";
import { categoryLabels } from "@/components/dash/widgets";
import { Badge, Empty, Field, Loading, Modal, StatusBadge } from "@/components/ui";
import { useAction, useQuery } from "@/lib/hooks";
import { ago, date } from "@/lib/format";
import type { MaintenanceCategory } from "@/lib/types";

export default function TenantMaintenancePage() {
  const { data, loading } = useQuery(async (b) => ({ stay: await b.getStay(), list: await b.listMyMaintenance() }));
  const { busy, run } = useAction();
  const [raising, setRaising] = useState(false);
  const [form, setForm] = useState({ category: "plumbing" as MaintenanceCategory, title: "", description: "", urgent: false });
  return (
    <Page
      title="Maintenance"
      sub={data?.stay ? `${data.stay.property.name} · Room ${data.stay.tenant.roomNumber}` : undefined}
      actions={
        data?.stay && (
          <button className="btn btn-primary btn-sm" onClick={() => setRaising(true)}>
            <Plus size={16} /> Raise request
          </button>
        )
      }
    >
      {loading ? (
        <Loading />
      ) : !data?.stay && !data?.list.length ? (
        <div className="glass card">
          <Empty icon={Wrench} title="No active stay" body="Maintenance requests go to the PG you live in." action={<Link href="/dashboard/tenant/explore/" className="btn btn-primary">Explore PGs</Link>} />
        </div>
      ) : !data?.list.length ? (
        <div className="glass card">
          <Empty icon={Wrench} title="Nothing broken?" body="If something needs fixing, raise a request. Your owner is notified and you'll see every update here." action={<button className="btn btn-primary" onClick={() => setRaising(true)}><Plus size={16} /> Raise request</button>} />
        </div>
      ) : (
        <div className="grid-2">
          {data.list.map((m) => (
            <div key={m.id} className="glass card stack" style={{ gap: 10 }}>
              <div className="row-between">
                <div className="row" style={{ gap: 6 }}>
                  <StatusBadge status={m.status} />
                  {m.urgent && <Badge tone="red">Urgent</Badge>}
                  <Badge tone="grey">{categoryLabels[m.category]}</Badge>
                </div>
                <span className="faint" style={{ fontSize: 12 }}>
                  {ago(m.createdAt)}
                </span>
              </div>
              <b>{m.title}</b>
              {m.description && <p className="muted" style={{ fontSize: 14 }}>{m.description}</p>}
              {m.ownerNote && <div className="alert alert-blue">Owner: {m.ownerNote}</div>}
              <div className="row-between">
                <span className="faint" style={{ fontSize: 12.5 }}>
                  Updated {date(m.updatedAt)}
                </span>
                {m.status === "open" && (
                  <button className="btn btn-ghost btn-sm" disabled={busy} onClick={() => run((b) => b.cancelMaintenance(m.id), "Request cancelled")}>
                    <X size={14} /> Cancel
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
      {raising && (
        <Modal
          title="Raise a maintenance request"
          onClose={() => setRaising(false)}
          footer={
            <>
              <button className="btn btn-ghost" onClick={() => setRaising(false)}>
                Cancel
              </button>
              <button
                className="btn btn-primary"
                disabled={busy}
                onClick={() =>
                  run((b) => b.raiseMaintenance(form), "Request sent to your owner").then((r) => {
                    if (r.ok) {
                      setRaising(false);
                      setForm({ category: "plumbing", title: "", description: "", urgent: false });
                    }
                  })
                }
              >
                Submit
              </button>
            </>
          }
        >
          <div className="stack">
            <div className="field">
              <span>Category</span>
              <div className="chips">
                {(Object.keys(categoryLabels) as MaintenanceCategory[]).map((c) => (
                  <button key={c} type="button" className="chip" aria-pressed={form.category === c} onClick={() => setForm({ ...form, category: c })}>
                    {categoryLabels[c]}
                  </button>
                ))}
              </div>
            </div>
            <Field label="What's wrong?">
              <input className="input" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} placeholder="e.g. Fan not working" />
            </Field>
            <Field label="Details (optional)">
              <textarea className="textarea" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} placeholder="When did it start? Anything the technician should know?" />
            </Field>
            <label className="check">
              <input type="checkbox" checked={form.urgent} onChange={(e) => setForm({ ...form, urgent: e.target.checked })} /> This is urgent (safety, water, power)
            </label>
          </div>
        </Modal>
      )}
    </Page>
  );
}
