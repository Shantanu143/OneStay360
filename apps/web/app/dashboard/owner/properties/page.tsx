"use client";
import Link from "next/link";
import { useState } from "react";
import { Building2, MapPin, Plus, Search } from "lucide-react";
import { Page, useShell } from "@/components/dash/shell";
import { bedStats, Cover, genderLabel, minRent, Progress } from "@/components/dash/widgets";
import { Empty, Loading, StatusBadge } from "@/components/ui";
import { useQuery } from "@/lib/hooks";
import { money } from "@/lib/format";
import { permissions } from "@/lib/permissions";

export default function PropertiesPage() {
  const { account } = useShell();
  const can = permissions(account.role);
  const { data, loading } = useQuery((b) => b.listProperties());
  const [q, setQ] = useState("");
  const list = (data ?? []).filter((p) => [p.name, p.city, p.address].join(" ").toLowerCase().includes(q.toLowerCase()));
  return (
    <Page
      title="Properties"
      sub={data ? `${data.length} propert${data.length === 1 ? "y" : "ies"}` : undefined}
      actions={
        can.canEditProperties && (
          <Link href="/dashboard/owner/property-form/" className="btn btn-primary btn-sm">
            <Plus size={16} /> <span className="hide-sm">Add property</span>
          </Link>
        )
      }
    >
      <div style={{ position: "relative", maxWidth: 420 }}>
        <Search size={16} style={{ position: "absolute", left: 14, top: 14, color: "var(--ink-faint)" }} />
        <input className="input" placeholder="Search by name, city or area" value={q} onChange={(e) => setQ(e.target.value)} style={{ paddingLeft: 40 }} aria-label="Search properties" />
      </div>
      {loading ? (
        <Loading />
      ) : list.length === 0 ? (
        <div className="glass card">
          <Empty
            icon={Building2}
            title={q ? "No matches" : "No properties yet"}
            body={q ? "Try another search." : can.canEditProperties ? "Add rooms, beds and rent for your first PG." : "The owner hasn't given you access to a property yet."}
            action={
              can.canEditProperties && !q && (
                <Link href="/dashboard/owner/property-form/" className="btn btn-primary">
                  <Plus size={16} /> Add property
                </Link>
              )
            }
          />
        </div>
      ) : (
        <div className="grid-3">
          {list.map((p) => {
            const s = bedStats(p);
            return (
              <Link key={p.id} href={`/dashboard/owner/property/?id=${p.id}`} className="glass prop-card">
                <Cover p={p}>
                  <span className="badge badge-grey" style={{ background: "rgba(0,0,0,.35)", color: "#fff" }}>
                    {genderLabel(p.gender)}
                  </span>
                  <span style={{ position: "absolute", top: 12, right: 12 }}>
                    <StatusBadge status={p.status === "inactive" ? "inactive" : p.billingStatus} />
                  </span>
                </Cover>
                <div className="prop-body">
                  <b style={{ fontSize: 16.5 }}>{p.name}</b>
                  <span className="muted row" style={{ fontSize: 13.5, gap: 6 }}>
                    <MapPin size={14} /> {p.address}, {p.city}
                  </span>
                  <div className="row-between" style={{ fontSize: 13.5, marginTop: 4 }}>
                    <span>
                      <b>{s.occupied}</b>
                      <span className="muted">/{s.total} beds occupied</span>
                    </span>
                    <span className="muted">from {money(minRent(p))}</span>
                  </div>
                  <Progress value={s.pct} />
                </div>
              </Link>
            );
          })}
        </div>
      )}
    </Page>
  );
}
