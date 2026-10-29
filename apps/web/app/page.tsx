import type { Metadata } from "next";
import { Landing } from "@/components/landing";
import { JsonLd } from "@/components/json-ld";
import { faqs } from "@/lib/content";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: { absolute: site.title },
  alternates: { canonical: "/" },
};

export default function Page() {
  return (
    <>
      <JsonLd
        data={{
          "@context": "https://schema.org",
          "@graph": [
            { "@type": "Organization", "@id": `${site.url}/#org`, name: site.name, url: site.url, logo: `${site.url}/brand/icon-512.png` },
            { "@type": "WebSite", "@id": `${site.url}/#website`, url: site.url, name: site.name, publisher: { "@id": `${site.url}/#org` }, inLanguage: "en-IN" },
            {
              "@type": "SoftwareApplication",
              name: site.name,
              applicationCategory: "BusinessApplication",
              operatingSystem: "Web, Android, iOS",
              description: site.description,
              url: site.url,
              offers: [
                { "@type": "Offer", name: "Tenants", price: "0", priceCurrency: "INR" },
                {
                  "@type": "Offer",
                  name: "Owners",
                  price: "30",
                  priceCurrency: "INR",
                  priceSpecification: { "@type": "UnitPriceSpecification", price: "30", priceCurrency: "INR", unitText: "per bed per month" },
                },
              ],
            },
            {
              "@type": "FAQPage",
              mainEntity: faqs.map((f) => ({ "@type": "Question", name: f.q, acceptedAnswer: { "@type": "Answer", text: f.a } })),
            },
          ],
        }}
      />
      <Landing />
    </>
  );
}
