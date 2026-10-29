"use client";
import { useState } from "react";
import { Check, Pencil, Shield, Trash2, UserPlus, Users } from "lucide-react";
import { Page, useShell } from "@/components/dash/shell";
import { Avatar } from "@/components/dash/widgets";
import { Badge, Confirm, Empty, Field, Loading, Modal, StatusBadge } from "@/components/ui";
import { useAction, useQuery } from "@/lib/hooks";
import { date } from "@/lib/format";
import { permissions } from "@/lib/permissions";
import type { Member } from "@/lib/types";

const roleInfo = {
  manager: "Handles tenants, join requests, payments and maintenance for assigned properties.",
  staff: "Sees assigned properties and updates maintenance. Can't approve or verify money.",
};

export default function TeamPage() {
  const { account } = useShell();
  const { busy, run } = useAction();
  const { data, loading, error, reload } = useQuery(async (b) => ({ members: await b.listMembers(), properties: await b.listProperties() }));
  const [editing, setEditing] = useState<Member | "new" | null>(null);
  const [removing, setRemoving] = useState<Member | null>(null);
  const [form, setForm] = useState({ name: "", phone: "", email: "", role: "manager" as "manager" | "staff", propertyIds: [] as string[] });

  if (!permissions(account.role).canInviteMembers) {
    return (
      <Page error={error} onRetry={reload} title="Team">
        <div className="alert alert-amber">Team management is owner-only.</div>
      </Page>
    );
  }
  const open = (m: Member | "new") => {
    setForm(m === "new" ? { name: "", phone: "", email: "", role: "manager", propertyIds: data?.properties.map((p) => p.id) ?? [] } : { name: m.name, phone: m.phone, email: m.email, role: m.role === "owner" ? "manager" : m.role, propertyIds: m.propertyIds });
    setEditing(m);
  };
  const save = async () => {
    const r = editing === "new" ? await run((b) => b.inviteMember(form), `Invitation sent to ${form.name}`) : await run((b) => b.updateMember((editing as Member).id, form.role, form.propertyIds), "Access updated");
    if (r.ok) setEditing(null);
  };
  const propName = (id: string) => data?.properties.find((p) => p.id === id)?.name ?? id;

  return (
    <Page error={error} onRetry={reload}
      title="Team"
      sub="Owner, managers and staff"
      actions={
        <button className="btn btn-primary btn-sm" onClick={() => open("new")}>
          <UserPlus size={16} aria-hidden /> Invite a team member
        </button>
      }
    >
      <div className="grid-3">
        {[
          ["Owner", "Everything, including billing, payment methods and team."],
          ["Manager", roleInfo.manager],
          ["Staff", roleInfo.staff],
        ].map(([r, d]) => (
          <div key={r} className="glass card-tight row" style={{ alignItems: "flex-start", gap: 12 }}>
            <span className="tile-ic">
              <Shield size={18} />
            </span>
            <div>
              <b>{r}</b>
              <p className="muted" style={{ fontSize: 14 }}>
                {d}
              </p>
            </div>
          </div>
        ))}
      </div>
      <div className="glass card">
        {loading ? (
          <Loading />
        ) : !data?.members.length ? (
          <Empty icon={Users} title="Just you so far" />
        ) : (
          <div className="list">
            {data.members.map((m) => (
              <div key={m.id} className="list-row wrap">
                <Avatar name={m.name} />
                <div className="grow" style={{ minWidth: 200 }}>
                  <div className="title">
                    {m.name} {m.uid === account.uid && <span className="faint">(you)</span>}
                  </div>
                  <div className="meta">
                    {[m.phone, m.email].filter(Boolean).join(" · ")} · {m.status === "invited" ? `invited ${date(m.invitedAt)}` : `joined ${date(m.joinedAt)}`}
                  </div>
                  {m.role !== "owner" && (
                    <div className="chips" style={{ marginTop: 6 }}>
                      {m.propertyIds.map((id) => (
                        <Badge key={id} tone="grey">
                          {propName(id)}
                        </Badge>
                      ))}
                    </div>
                  )}
                </div>
                <Badge tone={m.role === "owner" ? "green" : m.role === "manager" ? "blue" : "grey"}>{m.role}</Badge>
                {m.status === "invited" && <StatusBadge status="invited" />}
                {m.role !== "owner" && (
                  <div className="row" style={{ gap: 6 }}>
                    <button className="btn btn-ghost btn-sm" onClick={() => open(m)} aria-label={`Change access for ${m.name}`}>
                      <Pencil size={15} aria-hidden /> Change access
                    </button>
                    <button className="btn btn-danger btn-sm" onClick={() => setRemoving(m)} aria-label={`Remove ${m.name}`}>
                      <Trash2 size={15} aria-hidden /> Remove
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
      {editing && (
        <Modal
          title={editing === "new" ? "Invite a team member" : `Edit ${editing.name}`}
          subtitle={editing === "new" ? "They sign up with this phone or email and accept from their dashboard." : undefined}
          onClose={() => setEditing(null)}
          footer={
            <>
              <button className="btn btn-ghost" onClick={() => setEditing(null)}>
                Cancel
              </button>
              <button className="btn btn-primary" disabled={busy} onClick={save}>
                {editing === "new" ? "Send invite" : "Save"}
              </button>
            </>
          }
        >
          <div className="form-grid">
            {editing === "new" && (
              <>
                <Field label="Name" full>
                  <input className="input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
                </Field>
                <Field label="Phone">
                  <input className="input" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} placeholder="10-digit mobile" />
                </Field>
                <Field label="Email">
                  <input className="input" type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
                </Field>
              </>
            )}
            <div className="field full" role="group" aria-label="Role">
              <span className="field-label">Role</span>
              <div className="role-pick">
                {(["manager", "staff"] as const).map((r) => (
                  <button key={r} type="button" aria-pressed={form.role === r} onClick={() => setForm({ ...form, role: r })}>
                    <b style={{ textTransform: "capitalize" }}>{r}</b>
                    <small>{roleInfo[r]}</small>
                  </button>
                ))}
              </div>
            </div>
            <div className="field full" role="group" aria-label="Property access">
              <span className="field-label">Property access</span>
              <div className="chips">
                {data?.properties.map((p) => {
                  const on = form.propertyIds.includes(p.id);
                  return (
                    <button key={p.id} type="button" className="chip" aria-pressed={on} onClick={() => setForm({ ...form, propertyIds: on ? form.propertyIds.filter((x) => x !== p.id) : [...form.propertyIds, p.id] })}>
                      {on && <Check size={14} />} {p.name}
                    </button>
                  );
                })}
              </div>
            </div>
          </div>
        </Modal>
      )}
      {removing && (
        <Confirm
          title={removing.status === "invited" ? `Withdraw ${removing.name}'s invite?` : `Remove ${removing.name}?`}
          body="They lose access to your business immediately."
          confirmLabel="Remove"
          danger
          busy={busy}
          onClose={() => setRemoving(null)}
          onConfirm={() => run((b) => b.removeMember(removing.id), "Removed").then((r) => r.ok && setRemoving(null))}
        />
      )}
    </Page>
  );
}
