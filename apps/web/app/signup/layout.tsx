import type { Metadata } from "next";
import { social } from "@/lib/site";

export const metadata: Metadata = {
  title: "Create your account",
  description: "Create a free OneStay360 account. Owners manage PGs, beds, tenants and rent; tenants find a PG, join and pay rent online.",
  alternates: { canonical: "/signup/" },
  ...social("Create your OneStay360 account", "Create a free OneStay360 account. Owners manage PGs, beds, tenants and rent; tenants find a PG, join and pay rent online.", "/signup/"),
};

export default function Layout({ children }: { children: React.ReactNode }) {
  return children;
}
