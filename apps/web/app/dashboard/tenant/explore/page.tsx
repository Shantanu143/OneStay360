"use client";
import Link from "next/link";
import { useState } from "react";
import { Heart, MapPin, Search, Star } from "lucide-react";
import { Page, useShell } from "@/components/dash/shell";
import { Cover, genderLabel, minRent } from "@/components/dash/widgets";
import { freeBeds } from "@/components/property-view";
import { Empty, Field, Loading, SearchField } from "@/components/ui";
import { useAction, useQuery } from "@/lib/hooks";
import { money } from "@/lib/format";
import type { Gender } from "@/lib/types";

const cities = ["All", "Bangalore", "Mumbai", "Delhi", "Pune", "Hyderabad", "Chennai", "Kolkata", "Ahmedabad"];

export default function ExplorePage() {
  const { account } = useShell();
  const [city, setCity] = useState("All");
  const [gender, setGender] = useState<Gender | "any">("any");
  const [q, setQ] = useState("");
  const [favOnly, setFavOnly] = useState(false);
  const { run } = useAction();
  const { data, loading, error, reload } = useQuery((b) => b.explore({ city, gender, query: q }), [city, gender, q]);
  const list = (data ?? []).filter((p) => !favOnly || account.favorites.includes(p.id));

  return (
    <Page error={error} onRetry={reload} title="Explore PGs" sub="Verified PGs run on OneStay360">
      <div className="filters">
        <SearchField label="Search PGs" value={q} onChange={setQ} placeholder="Area, PG name or amenity" />
        <Field label="Who is it for?">
        <select className="select" value={gender} onChange={(e) => setGender(e.target.value as Gender | "any")}>
          <option value="any">Anyone</option>
          <option value="male">Men</option>
          <option value="female">Women</option>
          <option value="coed">Co-living</option>
        </select>
        </Field>
        <button className="chip" style={{ minHeight: 46 }} aria-pressed={favOnly} onClick={() => setFavOnly((f) => !f)}>
          <Heart size={14} aria-hidden /> Favourites
        </button>
      </div>
      <div className="chips">
        {cities.map((c) => (
          <button key={c} className="chip" aria-pressed={city === c} onClick={() => setCity(c)}>
            {c}
          </button>
        ))}
      </div>
      {loading ? (
        <Loading />
      ) : list.length === 0 ? (
        <div className="glass card">
          <Empty icon={Search} title="No PGs found" body={favOnly ? "You haven't saved any PGs matching this filter." : "Try another city or clear the search."} />
        </div>
      ) : (
        <div className="grid-3">
          {list.map((p) => {
            const fav = account.favorites.includes(p.id);
            return (
              <div key={p.id} className="glass prop-card" style={{ position: "relative" }}>
                <Link href={`/dashboard/tenant/pg/?id=${p.id}`}>
                  <Cover p={p}>
                    <span className="badge" style={{ background: "rgba(0,0,0,.4)", color: "#fff" }}>
                      {genderLabel(p.gender)}
                    </span>
                  </Cover>
                </Link>
                <button className="icon-btn fav" style={{ position: "absolute", top: 10, right: 10, zIndex: 2, background: "var(--glass-strong)" }} aria-label={fav ? "Remove favourite" : "Save favourite"} aria-pressed={fav} onClick={() => run((b) => b.setFavorite(p.id, !fav))}>
                  <Heart size={17} fill={fav ? "var(--danger)" : "none"} color={fav ? "var(--danger)" : "currentColor"} />
                </button>
                <Link href={`/dashboard/tenant/pg/?id=${p.id}`} className="prop-body">
                  <div className="row-between">
                    <b style={{ fontSize: 16.5 }}>{p.name}</b>
                    {p.rating > 0 && (
                      <span className="row" style={{ gap: 4, fontSize: 14, fontWeight: 650 }}>
                        <Star size={14} fill="#f5b301" color="#f5b301" /> {p.rating.toFixed(1)}
                      </span>
                    )}
                  </div>
                  <span className="muted row" style={{ fontSize: 14, gap: 6 }}>
                    <MapPin size={14} aria-hidden /> {p.landmarks || p.address}, {p.city}
                  </span>
                  <div className="chips" style={{ gap: 6 }}>
                    {p.amenities.slice(0, 3).map((a) => (
                      <span key={a} className="badge badge-grey">
                        {a}
                      </span>
                    ))}
                  </div>
                  <div className="row-between" style={{ marginTop: "auto", paddingTop: 6 }}>
                    <span>
                      <b style={{ fontSize: 18 }}>{money(minRent(p))}</b>
                      <span className="muted" style={{ fontSize: 14 }}>
                        {" "}
                        /mo onwards
                      </span>
                    </span>
                    <span className={`badge ${freeBeds(p) ? "badge-green" : "badge-grey"}`}>{freeBeds(p) ? `${freeBeds(p)} free` : "Full"}</span>
                  </div>
                </Link>
              </div>
            );
          })}
        </div>
      )}
    </Page>
  );
}
