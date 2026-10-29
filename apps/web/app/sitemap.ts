import type { MetadataRoute } from "next";
import { site } from "@/lib/site";

export const dynamic = "force-static";

export default function sitemap(): MetadataRoute.Sitemap {
  const pages: [string, number][] = [
    ["/", 1],
    ["/features/business/", 0.9],
    ["/features/tenant/", 0.9],
    ["/signup/", 0.6],
  ];
  return pages.map(([path, priority]) => ({ url: `${site.url}${path}`, changeFrequency: "monthly", priority }));
}
