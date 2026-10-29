"use client";
import Link from "next/link";
import { useState } from "react";
import { Building2, MapPin, Plus } from "lucide-react";
import { Page, useShell } from "@/components/dash/shell";
import { bedStats, Cover, genderLabel, minRent, Progress } from "@/components/dash/widgets";
import { Empty, Loading, SearchField, StatusBadge } from "@/components/ui";
import { useQuery } from "@/lib/hooks";
import { money } from "@/lib/format";
import { permissions } from "@/lib/permissions";

export default function PropertiesPage() {
  const { account } = useShell();
  const can = permissions(account.role);
  const { data, loading, error, reload } = useQuery((b) => b.listProperties());
  const [q, setQ] = useState("");
  const list = (data ?? []).filter((p) => [p.name, p.city, p.address].join(" ").toLowerCase().includes(q.toLowerCase()));
  return (
    <Page error={error} onRetry={reload}
      title="Properties"
      sub={data ? `${data.length} propert${data.length === 1 ? "y" : "ies"}` : undefined}
      actions={
        can.canEditProperties && (
          <Link href="/dashboard/owner/property-form/" className="btn btn-primary btn-sm">
            <Plus size={16} aria-hidden /> Add a property
          </Link>
        )
      }
    >
      {(data?.length ?? 0) > 3 && (
        <div className="filters">
          <SearchField label="Search properties" value={q} onChange={setQ} placeholder="Name, city or area" />
        </div>
      )}
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
                  <Plus size={16} aria-hidden /> Add property
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
                  <span className="muted row" style={{ fontSize: 14, gap: 6 }}>
                    <MapPin size={14} aria-hidden /> {p.address}, {p.city}
                  </span>
                  <div className="row-between" style={{ fontSize: 14, marginTop: 4 }}>
                    <span>
                      <b>{s.occupied}</b>
                      <span className="muted">/{s.total} beds occupied</span>
                    </span>
                    <span className="muted">from {money(minRent(p))}</span>
                  </div>
                  <Progress value={s.pct} label={`${p.name} occupancy`} />
                </div>
              </Link>
            );
          })}
        </div>
      )}
    </Page>
  );
}
