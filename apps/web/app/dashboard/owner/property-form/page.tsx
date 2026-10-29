"use client";
// Stepped add/edit property, like the Business app: basics → rooms & beds →
// amenities & food → rules & pricing → review.
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { ArrowLeft, ArrowRight, Check, Copy, Plus, Trash2 } from "lucide-react";
import { Page, useShell } from "@/components/dash/shell";
import { Field, Loading } from "@/components/ui";
import { useAction, useBackend } from "@/lib/hooks";
import { money, sharingLabel } from "@/lib/format";
import { permissions } from "@/lib/permissions";
import type { PropertyDraft } from "@/lib/backend/api";

const cities = ["Bangalore", "Mumbai", "Delhi", "Pune", "Hyderabad", "Chennai", "Kolkata", "Ahmedabad"];
const amenityOptions = ["WiFi", "Power backup", "Housekeeping", "Laundry", "Hot water", "CCTV", "Gym", "Parking", "Fridge", "TV lounge", "Study room", "Lift", "Biometric entry", "Water purifier", "Microwave", "Terrace"];
const mealOptions = ["Breakfast", "Lunch", "Dinner", "Snacks"];
const steps = ["Basics", "Rooms & beds", "Amenities & food", "Rules & pricing", "Review"];

type RoomDraft = PropertyDraft["rooms"][number];

const blank: PropertyDraft = {
  name: "",
  address: "",
  city: "Bangalore",
  pincode: "",
  description: "",
  landmarks: "",
  mapsLink: "",
  gender: "coed",
  amenities: ["WiFi", "Power backup", "Housekeeping", "Hot water"],
  food: { included: true, meals: ["Breakfast", "Dinner"], monthlyDeduction: 2500 },
  rules: { noticeDays: 30, lockInMonths: 3, gateClosesAt: "23:00", visitorsAllowed: true, smokingAllowed: false },
  pricing: { deposit: 10000, maintenance: 1000 },
  rooms: [{ number: "101", floor: 1, sharing: 2, ac: false, attachedBath: true, rentPerBed: 9000, beds: [] }],
};

export default function PropertyFormPage() {
  const { account } = useShell();
  const backend = useBackend();
  const router = useRouter();
  const { busy, run } = useAction();
  const [id, setId] = useState<string | null | undefined>(undefined);
  const [d, setD] = useState<PropertyDraft>(blank);
  const [step, setStep] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [fieldErr, setFieldErr] = useState<Record<string, string | undefined>>({});
  const [gen, setGen] = useState({ floor: 2, count: 4, sharing: 2, rent: 9000, ac: false });

  useEffect(() => {
    const pid = new URLSearchParams(window.location.search).get("id");
    setId(pid);
    if (pid) {
      backend.getProperty(pid).then((p) => {
        if (!p) return;
        const { rooms, name, address, city, pincode, description, landmarks, mapsLink, gender, amenities, food, rules, pricing } = p;
        setD({ name, address, city, pincode, description, landmarks, mapsLink, gender, amenities, food, rules, pricing, rooms: rooms.map(({ id: _id, ...r }) => r) });
      });
    }
  }, [backend]);

  if (!permissions(account.role).canEditProperties) {
    return (
      <Page title="Property">
        <div className="alert alert-amber">Only the owner can add or edit properties.</div>
      </Page>
    );
  }
  if (id === undefined) {
    return (
      <Page title="Property">
        <Loading />
      </Page>
    );
  }

  const set = <K extends keyof PropertyDraft>(k: K, v: PropertyDraft[K]) => setD((x) => ({ ...x, [k]: v }));
  const setRoom = (i: number, patch: Partial<RoomDraft>) => set("rooms", d.rooms.map((r, j) => (j === i ? { ...r, ...patch } : r)));
  const beds = d.rooms.reduce((s, r) => s + r.sharing, 0);

  const validate = () => {
    if (step === 0) {
      const errs = {
        name: d.name.trim() ? undefined : "Give the property a name tenants will recognise.",
        address: d.address.trim() ? undefined : "Add the street address.",
        pincode: d.pincode && !/^\d{6}$/.test(d.pincode) ? "A pincode has 6 digits." : undefined,
      };
      setFieldErr(errs);
      if (Object.values(errs).some(Boolean)) return "Fix the highlighted fields to continue.";
    }
    if (step === 1) {
      if (!d.rooms.length) return "Add at least one room.";
      const nums = d.rooms.map((r) => r.number.trim());
      if (nums.some((n) => !n)) return "Every room needs a number.";
      if (new Set(nums).size !== nums.length) return "Room numbers must be unique.";
      if (d.rooms.some((r) => r.rentPerBed <= 0)) return "Set rent per bed for every room.";
    }
    return null;
  };
  const next = () => {
    const e = validate();
    setError(e);
    if (!e) setStep((s) => s + 1);
  };
  const save = async () => {
    const out = id ? await run((b) => b.updateProperty(id, d), "Property updated") : await run((b) => b.createProperty(d), "Property added");
    if (out.ok) router.push(id ? `/dashboard/owner/property/?id=${id}` : `/dashboard/owner/property/?id=${(out.value as { id: string }).id}`);
  };
  const addGenerated = () => {
    const existing = new Set(d.rooms.map((r) => r.number));
    const add: RoomDraft[] = [];
    for (let i = 1; add.length < gen.count && i < 100; i++) {
      const number = `${gen.floor}${String(i).padStart(2, "0")}`;
      if (!existing.has(number)) add.push({ number, floor: gen.floor, sharing: gen.sharing, ac: gen.ac, attachedBath: true, rentPerBed: gen.rent, beds: [] });
    }
    set("rooms", [...d.rooms, ...add]);
  };

  return (
    <Page
      title={id ? `Edit ${d.name || "property"}` : "Add a property"}
      sub={`Step ${step + 1} of ${steps.length} · ${steps[step]}`}
      actions={
        <Link href={id ? `/dashboard/owner/property/?id=${id}` : "/dashboard/owner/properties/"} className="btn btn-ghost btn-sm">
          Cancel
        </Link>
      }
    >
      <div className="glass card">
        <nav className="chips" style={{ marginBottom: 32 }} aria-label="Form steps">
          {steps.map((s, i) => (
            <button key={s} className="chip" aria-pressed={i === step} aria-current={i === step ? "step" : undefined} onClick={() => (i < step ? setStep(i) : undefined)} disabled={i > step}>
              {i < step && <Check size={14} />} {s}
            </button>
          ))}
        </nav>
        {error && (
          <div className="alert alert-red" style={{ marginBottom: 14 }}>
            {error}
          </div>
        )}

        {step === 0 && (
          <div className="form-grid">
            <Field label="Property name" full required error={fieldErr.name}>
              <input className="input" aria-invalid={!!fieldErr.name} value={d.name} onChange={(e) => set("name", e.target.value)} placeholder="e.g. Sunrise Residency" />
            </Field>
            <div className="field full" role="group" aria-label="Who is it for?">
              <span className="field-label">Who is it for?</span>
              <div className="chips">
                {(["male", "female", "coed"] as const).map((g) => (
                  <button key={g} type="button" className="chip" aria-pressed={d.gender === g} onClick={() => set("gender", g)}>
                    {g === "male" ? "Men" : g === "female" ? "Women" : "Co-living"}
                  </button>
                ))}
              </div>
            </div>
            <Field label="City">
              <select className="select" value={d.city} onChange={(e) => set("city", e.target.value)}>
                {cities.map((c) => (
                  <option key={c}>{c}</option>
                ))}
              </select>
            </Field>
            <Field label="Pincode" error={fieldErr.pincode}>
              <input className="input" inputMode="numeric" aria-invalid={!!fieldErr.pincode} value={d.pincode} onChange={(e) => set("pincode", e.target.value)} placeholder="560034" />
            </Field>
            <Field label="Street address" full required error={fieldErr.address}>
              <input className="input" aria-invalid={!!fieldErr.address} value={d.address} onChange={(e) => set("address", e.target.value)} placeholder="Building, street, area" />
            </Field>
            <Field label="Landmark">
              <input className="input" value={d.landmarks} onChange={(e) => set("landmarks", e.target.value)} placeholder="Near…" />
            </Field>
            <Field label="Google Maps link">
              <input className="input" value={d.mapsLink} onChange={(e) => set("mapsLink", e.target.value)} placeholder="https://maps.google.com/…" />
            </Field>
            <Field label="Description" full hint="Shown to tenants on Explore.">
              <textarea className="textarea" value={d.description} onChange={(e) => set("description", e.target.value)} placeholder="What makes your PG great?" />
            </Field>
          </div>
        )}

        {step === 1 && (
          <div className="stack">
            <div className="glass card-tight" style={{ background: "var(--tint-grey)" }}>
              <h3 style={{ fontSize: 17, fontWeight: 700 }}>Quick add a floor</h3>
              <div className="row wrap" style={{ marginTop: 10, alignItems: "flex-end" }}>
                <Field label="Floor">
                  <input className="input" type="number" min={0} value={gen.floor} onChange={(e) => setGen({ ...gen, floor: +e.target.value })} style={{ width: 90 }} />
                </Field>
                <Field label="Rooms">
                  <input className="input" type="number" min={1} max={30} value={gen.count} onChange={(e) => setGen({ ...gen, count: +e.target.value })} style={{ width: 90 }} />
                </Field>
                <Field label="Sharing">
                  <select className="select" value={gen.sharing} onChange={(e) => setGen({ ...gen, sharing: +e.target.value })} style={{ width: 130 }}>
                    {[1, 2, 3, 4, 5, 6].map((n) => (
                      <option key={n} value={n}>
                        {sharingLabel(n)}
                      </option>
                    ))}
                  </select>
                </Field>
                <Field label="Rent / bed (₹)">
                  <input className="input" type="number" min={0} value={gen.rent} onChange={(e) => setGen({ ...gen, rent: +e.target.value })} style={{ width: 120 }} />
                </Field>
                <label className="check" style={{ height: 44 }}>
                  <input type="checkbox" checked={gen.ac} onChange={(e) => setGen({ ...gen, ac: e.target.checked })} /> AC
                </label>
                <button type="button" className="btn btn-soft" onClick={addGenerated}>
                  <Plus size={16} aria-hidden /> Add rooms
                </button>
              </div>
            </div>
            <div className="table-wrap">
              <table className="table">
                <thead>
                  <tr>
                    <th>Room</th>
                    <th>Floor</th>
                    <th>Sharing</th>
                    <th>Rent / bed (₹)</th>
                    <th>AC</th>
                    <th>Attached bath</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {d.rooms.map((r, i) => (
                    <tr key={i}>
                      <td>
                        <input className="input" style={{ width: 90, height: 38 }} value={r.number} onChange={(e) => setRoom(i, { number: e.target.value })} aria-label="Room number" />
                      </td>
                      <td>
                        <input className="input" type="number" min={0} style={{ width: 70, height: 38 }} value={r.floor} onChange={(e) => setRoom(i, { floor: +e.target.value })} aria-label="Floor" />
                      </td>
                      <td>
                        <select className="select" style={{ width: 140, height: 38 }} value={r.sharing} onChange={(e) => setRoom(i, { sharing: +e.target.value })} aria-label="Sharing">
                          {[1, 2, 3, 4, 5, 6, 7, 8].map((n) => (
                            <option key={n} value={n}>
                              {sharingLabel(n)}
                            </option>
                          ))}
                        </select>
                      </td>
                      <td>
                        <input className="input" type="number" min={0} style={{ width: 110, height: 38 }} value={r.rentPerBed} onChange={(e) => setRoom(i, { rentPerBed: +e.target.value })} aria-label="Rent per bed" />
                      </td>
                      <td>
                        <input type="checkbox" checked={r.ac} onChange={(e) => setRoom(i, { ac: e.target.checked })} aria-label="AC" style={{ width: 18, height: 18, accentColor: "var(--brand)" }} />
                      </td>
                      <td>
                        <input type="checkbox" checked={r.attachedBath} onChange={(e) => setRoom(i, { attachedBath: e.target.checked })} aria-label="Attached bath" style={{ width: 18, height: 18, accentColor: "var(--brand)" }} />
                      </td>
                      <td>
                        <div className="row" style={{ gap: 4 }}>
                          <button type="button" className="icon-btn" style={{ width: 40, height: 40 }} aria-label={`Duplicate room ${r.number}`} title="Duplicate room" onClick={() => set("rooms", [...d.rooms.slice(0, i + 1), { ...r, number: `${r.number}-copy` }, ...d.rooms.slice(i + 1)])}>
                            <Copy size={15} />
                          </button>
                          <button type="button" className="icon-btn" style={{ width: 40, height: 40 }} aria-label={`Remove room ${r.number}`} title="Remove room" onClick={() => set("rooms", d.rooms.filter((_, j) => j !== i))}>
                            <Trash2 size={15} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="row-between wrap">
              <button type="button" className="btn btn-ghost" onClick={() => set("rooms", [...d.rooms, { number: "", floor: d.rooms.at(-1)?.floor ?? 1, sharing: 2, ac: false, attachedBath: true, rentPerBed: d.rooms.at(-1)?.rentPerBed ?? 9000, beds: [] }])}>
                <Plus size={16} aria-hidden /> Add a room
              </button>
              <span className="muted">
                {d.rooms.length} rooms · <b>{beds} beds</b>
              </span>
            </div>
            {id && <div className="alert alert-blue">Occupied beds can&apos;t be removed: reduce sharing or delete a room only after vacating its tenants.</div>}
          </div>
        )}

        {step === 2 && (
          <div className="stack-lg">
            <div className="field" role="group" aria-label="Amenities">
              <span className="field-label">Amenities</span>
              <div className="chips">
                {amenityOptions.map((a) => {
                  const on = d.amenities.includes(a);
                  return (
                    <button key={a} type="button" className="chip" aria-pressed={on} onClick={() => set("amenities", on ? d.amenities.filter((x) => x !== a) : [...d.amenities, a])}>
                      {on && <Check size={14} />} {a}
                    </button>
                  );
                })}
              </div>
            </div>
            <label className="check">
              <input type="checkbox" checked={d.food.included} onChange={(e) => set("food", { ...d.food, included: e.target.checked })} /> Meals included in rent
            </label>
            {d.food.included && (
              <div className="form-grid">
                <div className="field full" role="group" aria-label="Meals served">
                  <span className="field-label">Meals served</span>
                  <div className="chips">
                    {mealOptions.map((m) => {
                      const on = d.food.meals.includes(m);
                      return (
                        <button key={m} type="button" className="chip" aria-pressed={on} onClick={() => set("food", { ...d.food, meals: on ? d.food.meals.filter((x) => x !== m) : [...d.food.meals, m] })}>
                          {m}
                        </button>
                      );
                    })}
                  </div>
                </div>
                <Field label="Discount if a tenant opts out of food (₹/month)">
                  <input className="input" type="number" min={0} value={d.food.monthlyDeduction} onChange={(e) => set("food", { ...d.food, monthlyDeduction: +e.target.value })} />
                </Field>
              </div>
            )}
          </div>
        )}

        {step === 3 && (
          <div className="form-grid">
            <Field label="Security deposit (₹)">
              <input className="input" type="number" min={0} value={d.pricing.deposit} onChange={(e) => set("pricing", { ...d.pricing, deposit: +e.target.value })} />
            </Field>
            <Field label="One-time maintenance (₹)">
              <input className="input" type="number" min={0} value={d.pricing.maintenance} onChange={(e) => set("pricing", { ...d.pricing, maintenance: +e.target.value })} />
            </Field>
            <Field label="Notice period (days)">
              <input className="input" type="number" min={0} value={d.rules.noticeDays} onChange={(e) => set("rules", { ...d.rules, noticeDays: +e.target.value })} />
            </Field>
            <Field label="Lock-in (months)">
              <input className="input" type="number" min={0} value={d.rules.lockInMonths} onChange={(e) => set("rules", { ...d.rules, lockInMonths: +e.target.value })} />
            </Field>
            <Field label="Gate closes at">
              <input className="input" type="time" value={d.rules.gateClosesAt} onChange={(e) => set("rules", { ...d.rules, gateClosesAt: e.target.value })} />
            </Field>
            <div className="field" role="group" aria-label="House rules">
              <span className="field-label">House rules</span>
              <label className="check">
                <input type="checkbox" checked={d.rules.visitorsAllowed} onChange={(e) => set("rules", { ...d.rules, visitorsAllowed: e.target.checked })} /> Visitors allowed
              </label>
              <label className="check">
                <input type="checkbox" checked={d.rules.smokingAllowed} onChange={(e) => set("rules", { ...d.rules, smokingAllowed: e.target.checked })} /> Smoking allowed
              </label>
            </div>
          </div>
        )}

        {step === 4 && (
          <div className="grid-2">
            <div className="glass card-tight">
              <dl className="kv">
                <dt>Name</dt>
                <dd>{d.name}</dd>
                <dt>For</dt>
                <dd>{d.gender === "male" ? "Men" : d.gender === "female" ? "Women" : "Co-living"}</dd>
                <dt>Address</dt>
                <dd>
                  {d.address}, {d.city} {d.pincode}
                </dd>
                <dt>Rooms · beds</dt>
                <dd>
                  {d.rooms.length} · {beds}
                </dd>
                <dt>Rent range</dt>
                <dd>
                  {money(Math.min(...d.rooms.map((r) => r.rentPerBed)))} – {money(Math.max(...d.rooms.map((r) => r.rentPerBed)))}
                </dd>
              </dl>
            </div>
            <div className="glass card-tight">
              <dl className="kv">
                <dt>Deposit</dt>
                <dd>{money(d.pricing.deposit)}</dd>
                <dt>Maintenance</dt>
                <dd>{money(d.pricing.maintenance)}</dd>
                <dt>Food</dt>
                <dd>{d.food.included ? d.food.meals.join(", ") : "Not included"}</dd>
                <dt>Amenities</dt>
                <dd>{d.amenities.length}</dd>
                <dt>Notice · lock-in</dt>
                <dd>
                  {d.rules.noticeDays}d · {d.rules.lockInMonths}m
                </dd>
              </dl>
            </div>
            {!id && (
              <div className="alert alert-blue" style={{ gridColumn: "1 / -1" }}>
                After saving, activate the property ({beds} beds × ₹30 = {money(beds * 30)}/month) to list it on Explore. You can add tenants right away.
              </div>
            )}
          </div>
        )}

        <div className="modal-foot">
          {step > 0 && (
            <button className="btn btn-ghost" onClick={() => setStep((s) => s - 1)}>
              <ArrowLeft size={16} aria-hidden /> Back
            </button>
          )}
          <span className="spacer" />
          {step < steps.length - 1 ? (
            <button className="btn btn-primary" onClick={next}>
              Continue <ArrowRight size={16} />
            </button>
          ) : (
            <button className="btn btn-primary" onClick={save} disabled={busy}>
              <Check size={16} aria-hidden /> {id ? "Save changes" : "Create property"}
            </button>
          )}
        </div>
      </div>
    </Page>
  );
}
