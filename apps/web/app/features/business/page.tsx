import type { Metadata } from "next";
import { FeaturePage } from "@/components/feature-page";

export const metadata: Metadata = {
  title: "Business app features — OneStay360",
  description: "Properties, beds, tenant onboarding, join requests, rent collection, maintenance, team roles, reports and billing for PG owners.",
};

export default function Page() {
  return <FeaturePage kind="business" />;
}
