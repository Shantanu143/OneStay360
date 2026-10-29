"use client";
// Public PG page that property QR codes open. Joining needs a tenant account.
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Search } from "lucide-react";
import { SiteFooter, SiteNav } from "@/components/site";
import { PropertyView } from "@/components/property-view";
import { Empty, Loading } from "@/components/ui";
import { useAccount, useQuery } from "@/lib/hooks";

export default function PublicPgPage() {
  const router = useRouter();
  const { account } = useAccount();
  const [id, setId] = useState<string | null>(null);
  useEffect(() => setId(new URLSearchParams(window.location.search).get("id")), []);
  const { data, loading } = useQuery((b) => (id ? b.getPublicProperty(id) : Promise.resolve(null)), [id]);
  const here = id ? `/dashboard/tenant/pg/?id=${encodeURIComponent(id)}` : "/dashboard/tenant/explore/";
  return (
    <>
      <SiteNav />
      <main className="container" style={{ paddingTop: 16, paddingBottom: 40 }}>
        {loading || !id ? (
          <Loading rows={4} />
        ) : !data ? (
          <div className="glass card">
            <Empty icon={Search} title="This PG isn't listed right now" body="It may be fully set up soon. Explore other verified PGs instead." />
          </div>
        ) : (
          <PropertyView
            p={data}
            account={account}
            onRequireAuth={() => router.push(`/signup/?kind=tenant&next=${encodeURIComponent(here)}`)}
            onJoined={() => router.push("/dashboard/tenant/requests/")}
          />
        )}
      </main>
      <SiteFooter />
    </>
  );
}
