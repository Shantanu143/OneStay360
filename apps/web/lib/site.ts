// Site-wide constants for SEO. Set NEXT_PUBLIC_SITE_URL to the production
// origin at build time so canonical URLs, the sitemap and Open Graph tags
// point at the right host.
export const site = {
  name: "OneStay360",
  url: (process.env.NEXT_PUBLIC_SITE_URL || "https://app.onestay360.brandedpatil.in").replace(/\/$/, ""),
  /** Shown as a contact link only when set. */
  contactEmail: process.env.NEXT_PUBLIC_CONTACT_EMAIL || "",
  title: "OneStay360 — PG & hostel management software for owners and tenants",
  description:
    "Run your PG, hostel or co-living from one place: rooms and beds, tenant onboarding, rent by UPI, cash or online, maintenance, team roles and reports. Tenants find a PG, join, pay rent and raise requests — free.",
  keywords: [
    "PG management software",
    "hostel management software India",
    "co-living management",
    "rent collection app",
    "PG owner app",
    "tenant app",
    "UPI rent payment",
    "paying guest management",
  ],
};

const ogImage = { url: "/og.png", width: 1200, height: 630, alt: "OneStay360 owner dashboard with rent collected, occupancy and items that need attention" };

/** Full Open Graph + Twitter tags for a page (Next replaces, not merges, these objects). */
export function social(title: string, description: string, path: string) {
  return {
    openGraph: { type: "website" as const, siteName: site.name, locale: "en_IN", url: path, title, description, images: [ogImage] },
    twitter: { card: "summary_large_image" as const, title, description, images: [ogImage.url] },
  };
}
