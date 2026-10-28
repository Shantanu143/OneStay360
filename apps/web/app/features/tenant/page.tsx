import type { Metadata } from "next";
import { FeaturePage } from "@/components/feature-page";

export const metadata: Metadata = {
  title: "Tenant app features — OneStay360",
  description: "Explore PGs, join, pay rent online or by UPI, raise maintenance, accept invitations and use your PG's pinboard.",
};

export default function Page() {
  return <FeaturePage kind="tenant" />;
}
