"use client";
import { useEffect, useState } from "react";
import { LogOut, Palette } from "lucide-react";
import { useShell } from "./shell";
import { Avatar } from "./widgets";
import { Field, ThemeToggle } from "../ui";
import { useAction, useBackend } from "@/lib/hooks";
import { date } from "@/lib/format";

/** Name/phone editing, theme and sign-out: the shared part of both profiles. */
export function AccountCard() {
  const { account } = useShell();
  const backend = useBackend();
  const { busy, run } = useAction();
  const [form, setForm] = useState({ name: account.name, phone: account.phone });
  useEffect(() => setForm({ name: account.name, phone: account.phone }), [account.name, account.phone]);
  return (
    <div className="glass card stack">
      <div className="row">
        <Avatar name={account.name} size="lg" />
        <div style={{ minWidth: 0 }}>
          <h2 className="h3">{account.name}</h2>
          <div className="muted" style={{ fontSize: 14 }}>
            {account.email}
          </div>
          <div className="faint" style={{ fontSize: 14 }}>
            Member since {date(account.createdAt)}
          </div>
        </div>
      </div>
      <div className="form-grid">
        <Field label="Full name">
          <input className="input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
        </Field>
        <Field label="Mobile number" hint={account.kind === "tenant" ? "Owner invitations are matched to this number." : undefined}>
          <input className="input" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
        </Field>
      </div>
      <div className="row wrap">
        <button className="btn btn-primary" disabled={busy || (form.name === account.name && form.phone === account.phone)} onClick={() => run((b) => b.updateAccount(form), "Profile saved")}>
          Save profile
        </button>
        <span className="spacer" />
        <span className="row muted" style={{ gap: 8, fontSize: 14 }}>
          <Palette size={16} aria-hidden /> Theme
        </span>
        <ThemeToggle withLabel />
        <button className="btn btn-ghost" onClick={() => backend.signOut().then(() => (window.location.href = "/"))}>
          <LogOut size={16} aria-hidden /> Sign out
        </button>
      </div>
    </div>
  );
}
