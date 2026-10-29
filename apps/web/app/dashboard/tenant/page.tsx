"use client";
import Link from "next/link";
import { ArrowRight, Building2, KeyRound, MailOpen, MessageSquareText, Search, Wallet, Wrench } from "lucide-react";
import { Page, useShell } from "@/components/dash/shell";
import { Cover, pinCategories } from "@/components/dash/widgets";
import { Empty, Loading, StatusBadge } from "@/components/ui";
import { useQuery } from "@/lib/hooks";
import { ago, date, money } from "@/lib/format";

export default function TenantHome() {
  const { account } = useShell();
  const { data, loading, error, reload } = useQuery(async (b) => {
    const [stay, invoices, invitations, requests, maintenance, pins] = await Promise.all([b.getStay(), b.listMyInvoices(), b.listMyInvitations(), b.listMyRequests(), b.listMyMaintenance(), b.listPins()]);
    return { stay, invoices, invitations, requests, maintenance, pins };
  });
  const first = account.name.split(" ")[0];
  if (loading || !data) {
    return (
      <Page error={error} onRetry={reload} title={`Hi, ${first}`}>
        <Loading rows={4} />
      </Page>
    );
  }
  const { stay, invoices, invitations, requests, maintenance, pins } = data;
  const open = invoices.filter((i) => i.status !== "paid").sort((a, b) => a.dueDate - b.dueDate);
  const pendingInv = invitations.filter((i) => i.status === "pending");
  const activeReq = requests.filter((r) => !["confirmed", "rejected"].includes(r.status));

  return (
    <Page error={error} onRetry={reload} title={`Hi, ${first}`} sub={stay ? `${stay.property.name} · Room ${stay.tenant.roomNumber} · Bed ${stay.tenant.bedNumber}` : "Let's find you a place"}>
      {pendingInv.map((i) => (
        <Link key={i.id} href="/dashboard/tenant/invitations/" className="alert alert-green row-between">
          <span className="row" style={{ gap: 10 }}>
            <MailOpen size={18} /> <b>{i.businessName}</b> invited you to {i.propertyName}, Room {i.roomNumber} · Bed {i.bedNumber}.
          </span>
          <ArrowRight size={16} />
        </Link>
      ))}
      {activeReq.map((r) => (
        <Link key={r.id} href="/dashboard/tenant/requests/" className={`alert ${r.status === "bill_sent" ? "alert-amber" : "alert-blue"} row-between`}>
          <span className="row" style={{ gap: 10 }}>
            <KeyRound size={18} aria-hidden /> {r.propertyName}: {r.status === "bill_sent" ? `your first bill of ${money(r.total ?? 0)} is ready to pay` : r.status === "payment_submitted" ? "payment submitted, waiting for the owner" : r.status === "approved" ? "approved — bill coming soon" : "request sent, waiting for the owner"}
          </span>
          <ArrowRight size={16} />
        </Link>
      ))}

      {stay ? (
        <>
          <div className="cols-wl">
            <div className="glass kpi kpi-hero" style={{ padding: 24, gap: 10 }}>
              <div className="label">{stay.property.name}</div>
              <div style={{ fontSize: 22, fontWeight: 800 }}>
                Room {stay.tenant.roomNumber} · Bed {stay.tenant.bedNumber}
              </div>
              {open.length ? (
                <>
                  <div className="label" style={{ marginTop: 6 }}>
                    {open[0]!.month} rent · due {date(open[0]!.dueDate)}
                  </div>
                  <div className="value num">{money(open.reduce((s, i) => s + i.amount, 0))}</div>
                  <Link href="/dashboard/tenant/rent/" className="btn" style={{ background: "var(--mint)", color: "#0b1f19", alignSelf: "flex-start" }}>
                    <Wallet size={16} aria-hidden /> Pay rent
                  </Link>
                </>
              ) : (
                <>
                  <div className="value">All paid ✓</div>
                  <div className="hint">Next rent {money(stay.tenant.monthlyRent)} on day {stay.tenant.billingDay}</div>
                </>
              )}
            </div>
            <div className="tiles">
              {[
                ["/dashboard/tenant/stay/", Building2, "My stay", "Room, rent & contacts"],
                ["/dashboard/tenant/rent/", Wallet, "Rent", `${open.length} due`],
                ["/dashboard/tenant/maintenance/", Wrench, "Maintenance", `${maintenance.filter((m) => m.status === "open" || m.status === "in_progress").length} active`],
                ["/dashboard/tenant/pinboard/", MessageSquareText, "Pinboard", `${pins.length} notes`],
              ].map(([href, Icon, t, s]) => {
                const I = Icon as typeof Wallet;
                return (
                  <Link key={href as string} href={href as string} className="glass card-tight stack" style={{ gap: 8 }}>
                    <span className="tile-ic">
                      <I size={18} />
                    </span>
                    <b>{t as string}</b>
                    <span className="faint" style={{ fontSize: 14 }}>
                      {s as string}
                    </span>
                  </Link>
                );
              })}
            </div>
          </div>
          <div className="grid-2">
            <div className="glass card">
              <div className="section-title">
                <h2>Maintenance</h2>
                <Link href="/dashboard/tenant/maintenance/" className="btn btn-ghost btn-sm">
                  Raise / view <ArrowRight size={14} />
                </Link>
              </div>
              {maintenance.length === 0 ? (
                <Empty icon={Wrench} title="No requests" body="Something broken? Raise a request and track it here." />
              ) : (
                <div className="list">
                  {maintenance.slice(0, 4).map((m) => (
                    <div key={m.id} className="list-row">
                      <div className="grow">
                        <div className="title">{m.title}</div>
                        <div className="meta">{m.ownerNote ?? ago(m.updatedAt)}</div>
                      </div>
                      <StatusBadge status={m.status} />
                    </div>
                  ))}
                </div>
              )}
            </div>
            <div className="glass card">
              <div className="section-title">
                <h2>Pinboard</h2>
                <Link href="/dashboard/tenant/pinboard/" className="btn btn-ghost btn-sm">
                  Open <ArrowRight size={14} />
                </Link>
              </div>
              {pins.length === 0 ? (
                <Empty icon={MessageSquareText} title="Quiet today" body="Post a note for your housemates — it disappears after 48 hours." />
              ) : (
                <div className="list">
                  {pins.slice(0, 4).map((p) => (
                    <div key={p.id} className="list-row">
                      <span style={{ fontSize: 22 }}>{pinCategories[p.category]?.emoji}</span>
                      <div className="grow">
                        <div className="title" style={{ whiteSpace: "normal", fontWeight: 500 }}>
                          {p.content}
                        </div>
                        <div className="meta">
                          {p.authorName} · {ago(p.createdAt)}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </>
      ) : (
        <div className="glass card split" style={{ gap: 24 }}>
          <div className="stack">
            <h2 className="h2" style={{ fontSize: 28 }}>
              Find your next PG
            </h2>
            <p className="muted">Browse verified PGs by city, compare rooms, food and rules, and request a bed. If an owner already added you, their invitation will appear here.</p>
            <div className="row wrap">
              <Link href="/dashboard/tenant/explore/" className="btn btn-primary btn-lg">
                <Search size={18} aria-hidden /> Explore PGs
              </Link>
              <Link href="/dashboard/tenant/invitations/" className="btn btn-ghost btn-lg">
                <MailOpen size={18} aria-hidden /> Invitations
              </Link>
            </div>
          </div>
          <div style={{ borderRadius: 22, overflow: "hidden" }}>
            <Cover p={{ coverHue: 160, name: "" }} height={220} />
          </div>
        </div>
      )}
    </Page>
  );
}
