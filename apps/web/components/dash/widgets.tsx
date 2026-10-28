"use client";
import type { ReactNode } from "react";
import { Building2 } from "lucide-react";
import { initials, moneyCompact } from "@/lib/format";
import type { Property } from "@/lib/types";

export function Avatar({ name, size }: { name: string; size?: "lg" }) {
  return <span className={`avatar ${size ?? ""}`}>{initials(name)}</span>;
}

export function Cover({ p, height = 150, children }: { p: Pick<Property, "coverHue" | "name">; height?: number; children?: ReactNode }) {
  const h = p.coverHue;
  return (
    <div
      className="prop-cover"
      style={{
        height,
        background: `radial-gradient(120% 90% at 0% 0%, hsl(${(h + 40) % 360} 70% 70% / .9), transparent 60%), linear-gradient(135deg, hsl(${h} 55% 42%), hsl(${(h + 300) % 360} 45% 22%))`,
      }}
    >
      <Building2 size={height > 120 ? 44 : 28} strokeWidth={1.4} />
      {children}
    </div>
  );
}

export function bedStats(p: Property) {
  let total = 0;
  let occupied = 0;
  for (const r of p.rooms) {
    total += r.beds.length;
    occupied += r.beds.filter((b) => b.tenantId).length;
  }
  return { total, occupied, free: total - occupied, pct: total ? Math.round((occupied / total) * 100) : 0 };
}

export function minRent(p: Property) {
  return p.rooms.length ? Math.min(...p.rooms.map((r) => r.rentPerBed)) : 0;
}

export function Progress({ value }: { value: number }) {
  return (
    <div className="progress" role="progressbar" aria-valuenow={Math.round(value)} aria-valuemin={0} aria-valuemax={100}>
      <i style={{ width: `${Math.max(0, Math.min(100, value))}%` }} />
    </div>
  );
}

/** Paired bars: collected (solid) over expected (tinted). */
export function Bars({ data }: { data: { label: string; value: number; total: number }[] }) {
  const max = Math.max(1, ...data.map((d) => Math.max(d.value, d.total)));
  return (
    <div>
      <div className="bars" role="img" aria-label={data.map((d) => `${d.label}: ${moneyCompact(d.value)} of ${moneyCompact(d.total)}`).join(", ")}>
        {data.map((d) => (
          <div className="bar" key={d.label}>
            <b>{moneyCompact(d.value)}</b>
            <div style={{ position: "relative", width: "100%", maxWidth: 44, height: `${(d.total / max) * 100}%`, minHeight: 3, display: "flex", alignItems: "flex-end" }}>
              <i className="due" style={{ position: "absolute", inset: 0, height: "100%", maxWidth: "none" }} />
              <i style={{ position: "relative", height: `${d.total ? (d.value / d.total) * 100 : 0}%`, maxWidth: "none" }} />
            </div>
            <span>{d.label}</span>
          </div>
        ))}
      </div>
      <div className="legend" style={{ marginTop: 10 }}>
        <span>
          <i style={{ background: "var(--brand)" }} />
          Collected
        </span>
        <span>
          <i style={{ background: "var(--tint-amber)" }} />
          Expected
        </span>
      </div>
    </div>
  );
}

export function Donut({ parts, center }: { parts: { label: string; value: number; color: string }[]; center?: ReactNode }) {
  const total = parts.reduce((s, p) => s + p.value, 0) || 1;
  let acc = 0;
  const r = 52;
  const c = 2 * Math.PI * r;
  return (
    <div className="row" style={{ gap: 20, flexWrap: "wrap" }}>
      <div style={{ position: "relative" }}>
        <svg viewBox="0 0 140 140" className="donut" role="img" aria-label={parts.map((p) => `${p.label} ${Math.round((p.value / total) * 100)}%`).join(", ")}>
          <circle cx="70" cy="70" r={r} fill="none" stroke="var(--tint-grey)" strokeWidth="18" />
          {parts.map((p) => {
            const len = (p.value / total) * c;
            const el = <circle key={p.label} cx="70" cy="70" r={r} fill="none" stroke={p.color} strokeWidth="18" strokeDasharray={`${len} ${c - len}`} strokeDashoffset={-acc} transform="rotate(-90 70 70)" />;
            acc += len;
            return el;
          })}
        </svg>
        {center && <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", textAlign: "center", fontWeight: 800 }}>{center}</div>}
      </div>
      <div className="stack" style={{ gap: 8 }}>
        {parts.map((p) => (
          <div key={p.label} className="row" style={{ gap: 8, fontSize: 13.5 }}>
            <i style={{ width: 10, height: 10, borderRadius: 3, background: p.color, display: "inline-block" }} />
            <span className="muted">{p.label}</span>
            <b className="num">{Math.round((p.value / total) * 100)}%</b>
          </div>
        ))}
      </div>
    </div>
  );
}

export const categoryLabels: Record<string, string> = {
  plumbing: "Plumbing",
  electrical: "Electrical",
  furniture: "Furniture",
  cleaning: "Cleaning",
  appliance: "Appliance",
  internet: "Internet",
  other: "Other",
};

export const pinCategories: Record<string, { label: string; emoji: string }> = {
  social: { label: "Social", emoji: "👋" },
  food: { label: "Food", emoji: "🍛" },
  lost_found: { label: "Lost & found", emoji: "🔎" },
  ride: { label: "Ride share", emoji: "🚗" },
  sell: { label: "For sale", emoji: "🏷️" },
  alert: { label: "Alert", emoji: "⚠️" },
};

export function genderLabel(g: Property["gender"]) {
  return g === "male" ? "Men" : g === "female" ? "Women" : "Co-living";
}
