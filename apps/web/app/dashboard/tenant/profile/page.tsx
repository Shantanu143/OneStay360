"use client";
import Link from "next/link";
import { Heart } from "lucide-react";
import { Page, useShell } from "@/components/dash/shell";
import { AccountCard } from "@/components/dash/account";
import { Cover, minRent } from "@/components/dash/widgets";
import { Empty } from "@/components/ui";
import { useQuery } from "@/lib/hooks";
import { money } from "@/lib/format";

export default function TenantProfilePage() {
  const { account } = useShell();
  const { data } = useQuery(async (b) => (await b.explore()).filter((p) => account.favorites.includes(p.id)), [account.favorites.join(",")]);
  return (
    <Page title="Profile" sub="Your account and saved PGs">
      <AccountCard />
      <div className="glass card">
        <div className="section-title">
          <h2>Favourite PGs</h2>
        </div>
        {!data?.length ? (
          <Empty icon={Heart} title="No favourites yet" body="Tap the heart on any PG in Explore to save it here." />
        ) : (
          <div className="list">
            {data.map((p) => (
              <Link key={p.id} href={`/dashboard/tenant/pg/?id=${p.id}`} className="list-row">
                <div style={{ width: 52, borderRadius: 12, overflow: "hidden", flex: "none" }}>
                  <Cover p={p} height={44} />
                </div>
                <div className="grow">
                  <div className="title">{p.name}</div>
                  <div className="meta">
                    {p.city} · from {money(minRent(p))}
                  </div>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </Page>
  );
}
