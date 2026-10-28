"use client";
import { useState } from "react";
import { CheckCircle2, Phone, PlayCircle, Wrench } from "lucide-react";
import { Page } from "@/components/dash/shell";
import { categoryLabels } from "@/components/dash/widgets";
import { Badge, Empty, Field, Kpi, Loading, Modal, Segmented, StatusBadge } from "@/components/ui";
import { useAction, useQuery } from "@/lib/hooks";
import { ago, date } from "@/lib/format";
import type { MaintenanceRequest, MaintenanceStatus } from "@/lib/types";

type Filter = "active" | "resolved" | "all";

export default function MaintenancePage() {
  const [filter, setFilter] = useState<Filter>("active");
  const [acting, setActing] = useState<{ m: MaintenanceRequest; to: MaintenanceStatus } | null>(null);
  const [note, setNote] = useState("");
  const { busy, run } = useAction();
  const { data, loading } = useQuery((b) => b.listMaintenance());
  const list = (data ?? [])
    .filter((m) => (filter === "active" ? m.status === "open" || m.status === "in_progress" : filter === "resolved" ? m.status === "resolved" || m.status === "cancelled" : true))
    .sort((a, b) => Number(b.urgent && b.status === "open") - Number(a.urgent && a.status === "open") || b.createdAt - a.createdAt);
  const open = data?.filter((m) => m.status === "open").length ?? 0;
  const progress = data?.filter((m) => m.status === "in_progress").length ?? 0;
  const resolved = data?.filter((m) => m.status === "resolved").length ?? 0;

  return (
    <Page title="Maintenance" sub="Issues raised by your tenants">
      <div className="grid-3">
        <Kpi icon={Wrench} label="Open" value={open} hint={`${data?.filter((m) => m.status === "open" && m.urgent).length ?? 0} urgent`} tone={open ? "amber" : undefined} />
        <Kpi icon={PlayCircle} label="In progress" value={progress} tone="blue" />
        <Kpi icon={CheckCircle2} label="Resolved" value={resolved} />
      </div>
      <Segmented<Filter>
        value={filter}
        onChange={setFilter}
        options={[
          { value: "active", label: "Active" },
          { value: "resolved", label: "Closed" },
          { value: "all", label: "All" },
        ]}
      />
      {loading ? (
        <Loading />
      ) : list.length === 0 ? (
        <div className="glass card">
          <Empty icon={Wrench} title={filter === "active" ? "No open issues" : "Nothing here"} body="Tenants raise requests from their app; you'll be notified and they'll see every update." />
        </div>
      ) : (
        <div className="grid-2">
          {list.map((m) => (
            <div key={m.id} className="glass card stack" style={{ gap: 10 }}>
              <div className="row-between">
                <div className="row" style={{ gap: 8 }}>
                  <StatusBadge status={m.status} />
                  {m.urgent && <Badge tone="red">Urgent</Badge>}
                  <Badge tone="grey">{categoryLabels[m.category]}</Badge>
                </div>
                <span className="faint" style={{ fontSize: 12 }}>
                  {ago(m.createdAt)}
                </span>
              </div>
              <b style={{ fontSize: 16 }}>{m.title}</b>
              {m.description && <p className="muted" style={{ fontSize: 14 }}>{m.description}</p>}
              <div className="faint" style={{ fontSize: 13 }}>
                {m.tenantName} · {m.propertyName} · Room {m.roomNumber}-{m.bedNumber}
              </div>
              {m.ownerNote && <div className="alert alert-blue">Note: {m.ownerNote}</div>}
              <div className="row wrap" style={{ gap: 8, marginTop: 4 }}>
                {m.status === "open" && (
                  <button className="btn btn-soft btn-sm" onClick={() => { setNote(m.ownerNote ?? ""); setActing({ m, to: "in_progress" }); }}>
                    <PlayCircle size={15} /> Start work
                  </button>
                )}
                {(m.status === "open" || m.status === "in_progress") && (
                  <button className="btn btn-primary btn-sm" onClick={() => { setNote(m.ownerNote ?? ""); setActing({ m, to: "resolved" }); }}>
                    <CheckCircle2 size={15} /> Mark resolved
                  </button>
                )}
                <a className="btn btn-ghost btn-sm" href={`tel:+91${m.tenantPhone}`}>
                  <Phone size={15} /> Call
                </a>
                {m.status === "resolved" && <span className="faint" style={{ fontSize: 12.5 }}>Resolved {date(m.updatedAt)}</span>}
              </div>
            </div>
          ))}
        </div>
      )}
      {acting && (
        <Modal
          title={acting.to === "in_progress" ? "Start work" : "Mark resolved"}
          subtitle={acting.m.title}
          onClose={() => setActing(null)}
          footer={
            <>
              <button className="btn btn-ghost" onClick={() => setActing(null)}>
                Cancel
              </button>
              <button className="btn btn-primary" disabled={busy} onClick={() => run((b) => b.updateMaintenance(acting.m.id, acting.to, note), acting.to === "in_progress" ? "Marked in progress" : "Marked resolved").then((r) => r.ok && setActing(null))}>
                {acting.to === "in_progress" ? "Start work" : "Resolve"}
              </button>
            </>
          }
        >
          <Field label="Note for the tenant (optional)">
            <textarea className="textarea" value={note} onChange={(e) => setNote(e.target.value)} placeholder={acting.to === "in_progress" ? "e.g. Electrician visiting tomorrow at 10am" : "e.g. Replaced the faulty capacitor"} />
          </Field>
        </Modal>
      )}
    </Page>
  );
}
