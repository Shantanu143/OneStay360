import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "PG details",
  description: "Rooms, rent, amenities, food and house rules for a PG on OneStay360. Request a bed in a few taps.",
  robots: { index: false, follow: true },
};

export default function Layout({ children }: { children: React.ReactNode }) {
  return children;
}
