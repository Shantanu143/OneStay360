"use client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { ArrowLeft, Search } from "lucide-react";
import { Page, useShell } from "@/components/dash/shell";
import { PropertyView } from "@/components/property-view";
import { Empty, Loading } from "@/components/ui";
import { useQuery } from "@/lib/hooks";

export default function TenantPgPage() {
  const { account } = useShell();
  const router = useRouter();
  const [id, setId] = useState<string | null>(null);
  useEffect(() => setId(new URLSearchParams(window.location.search).get("id")), []);
  const { data, loading, error, reload } = useQuery((b) => (id ? b.getPublicProperty(id) : Promise.resolve(null)), [id]);
  return (
    <Page error={error} onRetry={reload}
      title={data?.name ?? "PG"}
      sub={data ? `${data.city} · by ${data.businessName}` : undefined}
      actions={
        <Link href="/dashboard/tenant/explore/" className="btn btn-ghost btn-sm">
          <ArrowLeft size={16} aria-hidden /> Explore
        </Link>
      }
    >
      {loading || !id ? <Loading rows={4} /> : !data ? <div className="glass card"><Empty icon={Search} title="This PG isn't listed right now" /></div> : <PropertyView p={data} account={account} onJoined={() => router.push("/dashboard/tenant/requests/")} />}
    </Page>
  );
}
