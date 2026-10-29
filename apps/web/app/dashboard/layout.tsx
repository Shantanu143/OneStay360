import type { Metadata } from "next";
import { DashboardGate } from "@/components/dash/gate";

export const metadata: Metadata = {
  title: { default: "Dashboard", template: "%s | OneStay360" },
  robots: { index: false, follow: false },
  alternates: { canonical: null },
};

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return <DashboardGate>{children}</DashboardGate>;
}
