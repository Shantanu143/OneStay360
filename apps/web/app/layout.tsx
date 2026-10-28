import type { Metadata, Viewport } from "next";
import "./globals.css";
import { Aurora, Toasts } from "@/components/ui";

export const metadata: Metadata = {
  title: "OneStay360 — PG management for owners and tenants",
  description:
    "Run your PG, hostel or co-living from one place: properties, rooms and beds, tenant onboarding, rent by UPI, cash or online, maintenance and your team. Tenants find a PG, join, pay rent and raise requests.",
  icons: { icon: "/brand/mark.png" },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#eef3f1" },
    { media: "(prefers-color-scheme: dark)", color: "#07110e" },
  ],
};

// Applies the saved theme before first paint so dark mode never flashes.
const themeScript = `try{var t=localStorage.getItem("onestay360.theme");if(t==="light"||t==="dark")document.documentElement.setAttribute("data-theme",t)}catch(e){}`;

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
      </head>
      <body>
        <Aurora />
        {children}
        <Toasts />
      </body>
    </html>
  );
}
