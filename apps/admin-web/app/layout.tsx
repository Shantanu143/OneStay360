import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "OneStay360 | PG Operations Platform",
  description:
    "OneStay360 connects PG owners, tenants, payments, rooms, beds, approvals, and admin operations in one enterprise platform.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
