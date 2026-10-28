"use client";
// A PG's public page: used inside the tenant dashboard (Explore) and on the
// public /pg page that property QR codes open.
import { useState } from "react";
import { BedDouble, Check, Clock, Heart, MapPin, Phone, Star, Utensils } from "lucide-react";
import { Cover, genderLabel, minRent } from "./dash/widgets";
import { Badge, Field, Modal } from "./ui";
import { useAction } from "@/lib/hooks";
import { fromInputDate, money, sharingLabel, toInputDate, DAY } from "@/lib/format";
import type { Account, Property } from "@/lib/types";

export function freeBeds(p: Property) {
  return p.rooms.reduce((s, r) => s + r.beds.filter((b) => !b.tenantId).length, 0);
}

export function PropertyView({ p, account, onRequireAuth, onJoined }: { p: Property; account: Account | null; onRequireAuth?: () => void; onJoined?: () => void }) {
  const [joining, setJoining] = useState(false);
  const { busy, run } = useAction();
  const fav = !!account?.favorites.includes(p.id);
  const sharings = [...new Set(p.rooms.map((r) => r.sharing))].sort();
  const [form, setForm] = useState({ name: account?.name ?? "", phone: account?.phone ?? "", moveIn: toInputDate(Date.now() + 7 * DAY), sharing: sharingLabel(sharings[0] ?? 2), notes: "" });

  const start = () => {
    if (!account) return onRequireAuth?.();
    setJoining(true);
  };

  return (
    <div className="stack-lg">
      <div className="glass" style={{ overflow: "hidden", padding: 0 }}>
        <Cover p={p} height={200}>
          <span className="badge" style={{ background: "rgba(0,0,0,.4)", color: "#fff" }}>
            {genderLabel(p.gender)}
          </span>
        </Cover>
        <div className="card stack">
          <div className="row-between wrap">
            <div>
              <h2 className="h2" style={{ fontSize: 28 }}>
                {p.name}
              </h2>
              <div className="muted row" style={{ gap: 6, marginTop: 4 }}>
                <MapPin size={15} /> {p.address}, {p.city} {p.pincode}
              </div>
            </div>
            <div className="row wrap" style={{ gap: 8 }}>
              {p.rating > 0 && (
                <Badge tone="amber">
                  <Star size={12} /> {p.rating.toFixed(1)}
                </Badge>
              )}
              <Badge tone="green">
                <BedDouble size={12} /> {freeBeds(p)} beds free
              </Badge>
            </div>
          </div>
          {p.description && <p className="muted">{p.description}</p>}
          <div className="row wrap">
            <div style={{ marginRight: "auto" }}>
              <span className="faint" style={{ fontSize: 13 }}>
                Rent from
              </span>
              <div style={{ fontSize: 26, fontWeight: 800 }}>
                {money(minRent(p))}
                <span className="muted" style={{ fontSize: 14, fontWeight: 500 }}>
                  {" "}
                  / month
                </span>
              </div>
            </div>
            {account?.kind !== "business" && (
              <>
                {account && (
                  <button className="btn btn-ghost" disabled={busy} onClick={() => run((b) => b.setFavorite(p.id, !fav), fav ? "Removed from favourites" : "Saved to favourites")} aria-pressed={fav}>
                    <Heart size={16} fill={fav ? "currentColor" : "none"} /> {fav ? "Saved" : "Save"}
                  </button>
                )}
                <a className="btn btn-ghost" href={`tel:+91${p.businessPhone}`}>
                  <Phone size={16} /> Call owner
                </a>
                <button className="btn btn-primary" onClick={start} disabled={freeBeds(p) === 0}>
                  {freeBeds(p) === 0 ? "Fully occupied" : "Request to join"}
                </button>
              </>
            )}
          </div>
        </div>
      </div>

      <div className="grid-2">
        <div className="glass card">
          <div className="section-title">
            <h2>Rooms</h2>
          </div>
          <div className="list">
            {p.rooms.map((r) => {
              const free = r.beds.filter((b) => !b.tenantId).length;
              return (
                <div key={r.number} className="list-row">
                  <span className="tile-ic">
                    <BedDouble size={18} />
                  </span>
                  <div className="grow">
                    <div className="title">
                      {sharingLabel(r.sharing)} {r.ac && <Badge tone="blue">AC</Badge>}
                    </div>
                    <div className="meta">
                      Room {r.number} · floor {r.floor}
                      {r.attachedBath ? " · attached bath" : ""}
                    </div>
                  </div>
                  <div style={{ textAlign: "right" }}>
                    <b className="num">{money(r.rentPerBed)}</b>
                    <div className="faint" style={{ fontSize: 12 }}>
                      {free ? `${free} free` : "full"}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
        <div className="stack">
          <div className="glass card">
            <div className="section-title">
              <h2>Amenities</h2>
            </div>
            <div className="chips">
              {p.amenities.map((a) => (
                <span key={a} className="badge badge-green">
                  <Check size={12} /> {a}
                </span>
              ))}
            </div>
          </div>
          <div className="glass card stack">
            <div className="row">
              <Utensils size={18} color="var(--brand)" />
              <b>Food</b>
            </div>
            <p className="muted" style={{ fontSize: 14 }}>
              {p.food.included ? `${p.food.meals.join(", ")} included. Opt out for ${money(p.food.monthlyDeduction)} less per month.` : "Meals not included."}
            </p>
          </div>
          <div className="glass card">
            <div className="row" style={{ marginBottom: 10 }}>
              <Clock size={18} color="var(--brand)" />
              <b>Rules &amp; charges</b>
            </div>
            <dl className="kv">
              <dt>Security deposit</dt>
              <dd>{money(p.pricing.deposit)}</dd>
              <dt>Maintenance (one-time)</dt>
              <dd>{money(p.pricing.maintenance)}</dd>
              <dt>Notice period</dt>
              <dd>{p.rules.noticeDays} days</dd>
              <dt>Lock-in</dt>
              <dd>{p.rules.lockInMonths} months</dd>
              <dt>Gate closes</dt>
              <dd>{p.rules.gateClosesAt}</dd>
              <dt>Visitors</dt>
              <dd>{p.rules.visitorsAllowed ? "Allowed" : "Not allowed"}</dd>
              <dt>Smoking</dt>
              <dd>{p.rules.smokingAllowed ? "Allowed" : "Not allowed"}</dd>
            </dl>
          </div>
        </div>
      </div>

      {joining && (
        <Modal
          title={`Join ${p.name}`}
          subtitle="The owner reviews your request, assigns a bed and sends your first bill."
          onClose={() => setJoining(false)}
          footer={
            <>
              <button className="btn btn-ghost" onClick={() => setJoining(false)}>
                Cancel
              </button>
              <button
                className="btn btn-primary"
                disabled={busy}
                onClick={() =>
                  run((b) => b.submitEnrollment({ propertyId: p.id, name: form.name, phone: form.phone, moveIn: fromInputDate(form.moveIn), sharing: form.sharing, notes: form.notes }), "Request sent to the owner").then((r) => {
                    if (r.ok) {
                      setJoining(false);
                      onJoined?.();
                    }
                  })
                }
              >
                Send request
              </button>
            </>
          }
        >
          <div className="form-grid">
            <Field label="Your name">
              <input className="input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
            </Field>
            <Field label="Mobile number">
              <input className="input" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
            </Field>
            <Field label="Move-in date">
              <input className="input" type="date" value={form.moveIn} min={toInputDate(Date.now())} onChange={(e) => setForm({ ...form, moveIn: e.target.value })} />
            </Field>
            <Field label="Preferred sharing">
              <select className="select" value={form.sharing} onChange={(e) => setForm({ ...form, sharing: e.target.value })}>
                {sharings.map((s) => (
                  <option key={s}>{sharingLabel(s)}</option>
                ))}
              </select>
            </Field>
            <Field label="Note for the owner (optional)" full>
              <textarea className="textarea" value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} placeholder="e.g. joining a new job nearby, prefer AC" />
            </Field>
          </div>
        </Modal>
      )}
    </div>
  );
}
