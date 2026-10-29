import type { Metadata } from "next";
import { FeaturePage } from "@/components/feature-page";
import { JsonLd } from "@/components/json-ld";
import { site, social } from "@/lib/site";

const title = "Business app features for PG owners";
const description = "Every OneStay360 Business app feature for PG and hostel owners: properties and beds, tenant onboarding, join requests, rent collection by UPI, cash or online, maintenance, team roles, reports and per-bed billing.";

export const metadata: Metadata = {
  title,
  description,
  alternates: { canonical: "/features/business/" },
  ...social(`${title} | OneStay360`, description, "/features/business/"),
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
            { "@type": "ListItem", position: 2, name: title, item: `${site.url}/features/business/` },
          ],
        }}
      />
      <FeaturePage kind="business" />
    </>
  );
}
