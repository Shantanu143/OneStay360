"use client";
import Link from "next/link";
import { Building2, Check, MapPin, MessageCircle, Phone } from "lucide-react";
import { Page } from "@/components/dash/shell";
import { Cover } from "@/components/dash/widgets";
import { Badge, Empty, Loading } from "@/components/ui";
import { useQuery } from "@/lib/hooks";
import { date, money, sharingLabel } from "@/lib/format";

export default function StayPage() {
  const { data: stay, loading, error, reload } = useQuery((b) => b.getStay());
  if (loading) {
    return (
      <Page error={error} onRetry={reload} title="My stay">
        <Loading rows={3} />
      </Page>
    );
  }
  if (!stay) {
    return (
      <Page error={error} onRetry={reload} title="My stay">
        <div className="glass card">
          <Empty icon={Building2} title="No active stay" body="Join a PG from Explore, or accept an invitation from your owner." action={<Link href="/dashboard/tenant/explore/" className="btn btn-primary">Explore PGs</Link>} />
        </div>
      </Page>
    );
  }
  const { tenant: t, property: p, room } = stay;
  return (
    <Page error={error} onRetry={reload} title="My stay" sub={`${p.name} · since ${date(t.moveIn)}`}>
      <div className="glass" style={{ overflow: "hidden", padding: 0 }}>
        <Cover p={p} height={160} />
        <div className="card row-between wrap">
          <div>
            <h2 className="h2" style={{ fontSize: 26 }}>
              Room {t.roomNumber} · Bed {t.bedNumber}
            </h2>
            <div className="muted row" style={{ gap: 6 }}>
              <MapPin size={15} aria-hidden /> {p.address}, {p.city} {p.pincode}
            </div>
          </div>
          <div className="row wrap">
            <a className="btn btn-ghost" href={`tel:+91${p.businessPhone}`}>
              <Phone size={16} aria-hidden /> Call {p.businessName}
            </a>
            <a className="btn btn-ghost" href={`https://wa.me/91${p.businessPhone}`} target="_blank" rel="noreferrer">
              <MessageCircle size={16} aria-hidden /> WhatsApp
            </a>
          </div>
        </div>
      </div>
      <div className="grid-2">
        <div className="glass card">
          <div className="section-title">
            <h2>Your terms</h2>
          </div>
          <dl className="kv">
            <dt>Tenant ID</dt>
            <dd>{t.id}</dd>
            <dt>Monthly rent</dt>
            <dd>{money(t.monthlyRent)}</dd>
            <dt>Billing day</dt>
            <dd>{t.billingDay} of every month</dd>
            <dt>Security deposit</dt>
            <dd>{money(t.deposit)}</dd>
            <dt>Moved in</dt>
            <dd>{date(t.moveIn)}</dd>
            <dt>Notice period</dt>
            <dd>{p.rules.noticeDays} days</dd>
            <dt>Lock-in</dt>
            <dd>{p.rules.lockInMonths} months</dd>
          </dl>
        </div>
        <div className="glass card">
          <div className="section-title">
            <h2>Your room</h2>
          </div>
          <dl className="kv">
            <dt>Sharing</dt>
            <dd>{room ? sharingLabel(room.sharing) : "—"}</dd>
            <dt>AC</dt>
            <dd>{room?.ac ? "Yes" : "No"}</dd>
            <dt>Bathroom</dt>
            <dd>{room?.attachedBath ? "Attached" : "Common"}</dd>
            <dt>Floor</dt>
            <dd>{room?.floor ?? "—"}</dd>
            <dt>Food</dt>
            <dd>{p.food.included ? p.food.meals.join(", ") : "Not included"}</dd>
            <dt>Gate closes</dt>
            <dd>{p.rules.gateClosesAt}</dd>
          </dl>
        </div>
      </div>
      <div className="glass card">
        <div className="section-title">
          <h2>Amenities</h2>
        </div>
        <div className="chips">
          {p.amenities.map((a) => (
            <Badge key={a} tone="green">
              <Check size={12} aria-hidden /> {a}
            </Badge>
          ))}
        </div>
      </div>
    </Page>
  );
}
