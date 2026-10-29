import type { Metadata } from "next";
import { FeaturePage } from "@/components/feature-page";
import { JsonLd } from "@/components/json-ld";
import { site, social } from "@/lib/site";

const title = "Tenant app features";
const description = "Every OneStay360 Tenant app feature: explore verified PGs, request to join, pay your first bill and monthly rent online or by UPI, raise maintenance requests, accept owner invitations and use your PG's pinboard.";

export const metadata: Metadata = {
  title,
  description,
  alternates: { canonical: "/features/tenant/" },
  ...social(`${title} | OneStay360`, description, "/features/tenant/"),
};

export default function Page() {
  return (
    <>
      <JsonLd
        data={{
          "@context": "https://schema.org",
          "@type": "BreadcrumbList",
          itemListElement: [
            { "@type": "ListItem", position: 1, name: "Home", item: `${site.url}/` },
            { "@type": "ListItem", position: 2, name: title, item: `${site.url}/features/tenant/` },
          ],
        }}
      />
      <FeaturePage kind="tenant" />
    </>
  );
}
